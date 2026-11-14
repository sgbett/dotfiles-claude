# frozen_string_literal: true

require_relative 'support/record_calls'

RSpec.describe Do::Tick do
  include Do::Testing::RecordCalls

  let(:ledger_path) { Do::Testing::RecordCalls::LEDGER_PATH }
  let(:issue_path) { Do::Testing::RecordCalls::ISSUE_PATH }
  let(:ledger) do
    <<~MARKDOWN
      ## Breakdown
      ```markdown
      - [ ] **L1 Quoted, not the item.**
      ```
      - [ ] **L1 One.**
        - [ ] **L2 a nested detail**
      - [x] **L2 Two.**
      - [ ] **L3 Three.**
    MARKDOWN
  end

  # Expects the issue query, answered with +response+, then the calls the
  # block expects, and ticks +flag+'s +value+.
  def tick(flag, value, response = record_response(ledger: ledger), dry_run: false)
    expect_gh_login
    expect_issue_query(response)
    yield if block_given?
    record('tick', 'sgbett/dotfiles-claude#24', flag, value, *('--dry-run' if dry_run))
  end

  def tick_ledger(ids, response = record_response(ledger: ledger), dry_run: false, &)
    tick('--ledger', ids, response, dry_run: dry_run, &)
  end

  def tick_issue(positions, response = record_response, dry_run: false, &)
    tick('--issue-boxes', positions, response, dry_run: dry_run, &)
  end

  describe 'the ledger' do
    it "ticks exactly the boxes named, outside code fences, and changes nothing else's bytes" do
      before = "#{Do::Testing::RecordCalls::MARKER}#{ledger}"
      after = before.sub('- [ ] **L1 One.**', '- [x] **L1 One.**').sub('- [ ] **L3', '- [x] **L3')

      exit_code, output = tick_ledger('L1,L3') { expect_edit(ledger_path, before, after) }

      expect([exit_code, output]).to eq([0, { 'status' => 'proceed', 'target' => 'ledger', 'flipped' => %w[L1 L3],
                                              'already' => [], 'dry_run' => false }])
      expect(after.lines - before.lines).to eq(["- [x] **L1 One.**\n", "- [x] **L3 Three.**\n"])
    end

    it 'reports a box already ticked, and writes nothing when every box named is' do
      exit_code, output = tick_ledger('L2')

      expect([exit_code, output.values_at('flipped', 'already'), gh_writes]).to eq([0, [[], ['L2']], []])
    end

    it 'stops, writing nothing, when a box named is missing or ambiguous' do
      [['L1,L9', ['L9']], ['L4', ['L4']]].each do |ids, missing|
        exit_code, output = tick_ledger(ids, record_response(ledger: "#{ledger}- [ ] **L4 Again.**\n- [ ] **L4**\n"))

        expect([exit_code, output['reason'], output['missing']]).to eq([2, 'box_missing', missing]), ids
      end
      expect(gh_writes).to eq([])
    end

    it 'stops, writing nothing, when the ledger changed between the read and the write' do
      changed = "#{Do::Testing::RecordCalls::MARKER}#{ledger}- [ ] **L4 Added meanwhile.**\n"

      exit_code, output = tick_ledger('L1') { expect_read(ledger_path, changed) }

      expect([exit_code, output['reason'], gh_writes]).to eq([2, 'body_changed', []])
    end

    it 'fails as a tool when what it wrote does not read back' do
      before = "#{Do::Testing::RecordCalls::MARKER}#{ledger}"
      after = before.sub('- [ ] **L1 One.**', '- [x] **L1 One.**')

      expect { tick_ledger('L1') { expect_edit(ledger_path, before, after, read_back: before) } }
        .to raise_error(SkillSupport::UnexpectedResponse, /doesn't read back as written/)
    end

    it 'reports what would flip on a dry run, reading and writing nothing more' do
      exit_code, output = tick_ledger('L1,L2', dry_run: true)

      expect([exit_code, output.values_at('flipped', 'already', 'dry_run')]).to eq([0, [['L1'], ['L2'], true]])
      expect(fake_runner.calls.length).to eq(2)
    end
  end

  describe 'the issue body' do
    let(:body) { "Intro\r\n- [ ] One\r\n```\r\n- [ ] Quoted\r\n```\r\n* [X] Two\r\n- [ ] Three" }

    it 'ticks boxes by position, keeping its line endings, once its fresh copy matches' do
      after = body.sub('- [ ] One', '- [x] One').sub('- [ ] Three', '- [x] Three')
      output = tick_issue('1,3,2') do
        expect_read(issue_path, body)
        expect_edit(issue_path, body, after)
      end.last

      expect(output.values_at('target', 'flipped', 'already')).to eq(['issue_body', [1, 3], [2]])
    end

    it 'stops on a position no top-level box outside a fence holds' do
      output = tick_issue('4') { expect_read(issue_path, body) }.last

      expect(output.values_at('reason', 'missing')).to eq(['box_missing', [4]])
    end

    it "stops, never reading the body, when the issue's author isn't trusted" do
      response = record_response { |issue| issue.merge!(authored_by('example-stranger', association: 'CONTRIBUTOR')) }

      exit_code, output = tick_issue('1', response)

      expect([exit_code, output['reason'], fake_runner.calls.length]).to eq([2, 'untrusted_issue_author', 2])
    end
  end
end
