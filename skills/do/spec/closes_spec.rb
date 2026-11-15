# frozen_string_literal: true

require_relative 'support/record_calls'

RSpec.describe Do::Closes do
  include Do::Testing::RecordCalls

  let(:upstream) { 'example-owner/upstream' }
  let(:body) { "## Acceptance criteria\n\n- [ ] One\n  - [ ] a detail\n- [ ] Two\n```\n- [ ] Quoted\n```\n" }
  let(:copilot) { {} }

  # Runs closes on the recorded issue answered with +response+ and, unless
  # its criteria live in the ledger, an issue body of +body+; any verified
  # boxes come with the body's digest, as facts gave it. The Copilot signal
  # answers with +copilot+ (CopilotSignalCalls), unless it is nil, for a run
  # that stops before reading it.
  def closes(response = record_response, body: self.body, base: 'master', items: nil, boxes: nil)
    expect_base(base)
    expect_located(response)
    expect_read(Do::Testing::RecordCalls::ISSUE_PATH, body) if body
    expect_copilot_signal(branch: base, ref: base, **copilot) if copilot
    record('closes', 'sgbett/dotfiles-claude#24', '--base', base, *(['--verified-items', items] if items),
           *(['--verified-boxes', boxes, '--boxes-digest', boxes_digest(body)] if boxes))
  end

  # closes with every box verified, once the body facts counted them in has
  # become +edited+.
  def closes_after(edited, base: 'master')
    expect_base(base)
    expect_located(record_response)
    expect_read(Do::Testing::RecordCalls::ISSUE_PATH, edited)
    expect_copilot_signal(branch: base, ref: base)
    record('closes', 'sgbett/dotfiles-claude#24', '--base', base, '--verified-boxes', '1,2,3',
           '--boxes-digest', boxes_digest(body))
  end

  def with_sub_issues(*nodes, ledger: "- [ ] **L1 One.**\n")
    record_response(ledger: ledger) { |issue| issue['subIssues'] = connection(nodes) }
  end

  describe "the issue's acceptance boxes" do
    it 'closes the issue once QA verified every box outside code fences, a nested one included' do
      exit_code, output = closes(boxes: '1,2,3')

      expect([exit_code, output['status'], output['criteria']]).to eq([0, 'proceed', 'issue_boxes'])
      expect(output.values_at('closes_lines', 'close_by_hand', 'held')).to eq([['Closes #24'], [], []])
    end

    it 'holds the issue open while one box is unverified, saying which' do
      _exit_code, output = closes(boxes: '1,3')

      expect([output['closes_lines'], output['held']])
        .to eq([[], [{ 'reference' => '#24', 'reasons' => ['unverified_boxes'], 'unverified' => [2] }]])
    end

    it 'counts a box already ticked as verified by an earlier run' do
      _exit_code, output = closes(body: "- [x] One\n- [ ] Two\n", boxes: '2')

      expect(output['closes_lines']).to eq(['Closes #24'])
    end

    it "holds the issue open on a box GitHub renders at the top level, however it's marked or indented" do
      _exit_code, output = closes(body: "1. [ ] One\n  - [ ] Two\n<!--\n- [ ] Not rendered\n-->\n", boxes: '1')

      expect(output['held']).to eq([{ 'reference' => '#24', 'reasons' => ['unverified_boxes'], 'unverified' => [2] }])
    end

    it 'takes every ledger item instead when the body holds no box' do
      response = record_response(ledger: "- [ ] **L1 One.**\n- [x] **L2 Two.**\n- [ ] Plain\n")

      held = closes(response, body: "No boxes.\n```\n- [ ] Quoted\n```\n", items: 'L1').last
      closed = closes(response, body: '', items: 'L1,P3').last

      expect(held.values_at('criteria', 'held'))
        .to eq(['ledger_items', [{ 'reference' => '#24', 'reasons' => ['unverified_items'], 'unverified' => ['P3'] }]])
      expect(closed['closes_lines']).to eq(['Closes #24'])
    end

    it "takes the ledger's items, never reading the body, when the issue's author isn't trusted" do
      adopted = "- [ ] **L1 One.**\n### Adopted acceptance criteria\n- [ ] **L2 Two.**\n"
      response = record_response(ledger: adopted) do |issue|
        issue.merge!(authored_by('example-stranger', association: 'NONE'))
      end

      exit_code, output = closes(response, body: nil, items: 'L1,L2', boxes: '1')

      expect([exit_code, output['criteria'], output['closes_lines']]).to eq([0, 'ledger_items', ['Closes #24']])
    end
  end

  describe 'sub-issues in another repository' do
    it 'holds the issue open while one is open, naming it' do
      _exit_code, output = closes(with_sub_issues(sub_issue_node(5, upstream)), boxes: '1,2,3')

      expect(output['closes_lines']).to eq([])
      expect(output['held']).to eq([{ 'reference' => '#24', 'reasons' => ['open_elsewhere'] },
                                    { 'reference' => 'example-owner/upstream#5', 'reasons' => ['open_elsewhere'] }])
    end

    it 'closes the issue once the sub-issue is closed' do
      _exit_code, output = closes(with_sub_issues(sub_issue_node(5, upstream, state: 'CLOSED')), boxes: '1,2,3')

      expect(output.values_at('closes_lines', 'held')).to eq([['Closes #24'], []])
    end

    it "holds the issue open for one whose author isn't trusted, even when it is closed" do
      stranger = sub_issue_node(5, upstream, state: 'CLOSED', by: authored_by('example-stranger', association: 'NONE'))
      _exit_code, output = closes(with_sub_issues(stranger), boxes: '1,2,3')

      expect(output.values_at('closes_lines', 'held'))
        .to eq([[], [{ 'reference' => '#24', 'reasons' => ['untrusted_elsewhere'] },
                     { 'reference' => 'example-owner/upstream#5', 'reasons' => ['untrusted_elsewhere'] }]])
    end

    it 'names one in a repository that may not be named only under session_only' do
      hidden = sub_issue_node(8, 'example-owner/hidden', visibility: 'PRIVATE')
      _exit_code, output = closes(with_sub_issues(hidden), boxes: '1,2,3')

      expect([output['held'], output['session_only']])
        .to eq([[{ 'reference' => '#24', 'reasons' => ['open_elsewhere'] }],
                { 'held' => [{ 'reference' => 'example-owner/hidden#8', 'reasons' => ['open_elsewhere'] }] }])
      expect(JSON.generate(output.except('session_only'))).not_to include('example-owner/hidden')
    end
  end

  describe "this repository's sub-issues" do
    let(:ledger) { "- [ ] **L1 One.**\n- [ ] #31 Ours\n- [x] #32 Done before\n" }
    let(:response) do
      with_sub_issues(sub_issue_node(31), sub_issue_node(32), sub_issue_node(33), ledger: ledger)
    end

    it 'closes each in the ledger whose box QA verified or an earlier run ticked, beside the issue' do
      _exit_code, output = closes(response, items: '#31', boxes: '1,2,3')

      expect(output['closes_lines']).to eq(['Closes #24', 'Closes #31', 'Closes #32'])
    end

    it 'leaves one whose box is unverified open, without holding the issue, and one not in the ledger' do
      _exit_code, output = closes(response, boxes: '1,2,3')

      expect([output['closes_lines'], output['held']])
        .to eq([['Closes #24', 'Closes #32'], [{ 'reference' => '#31', 'reasons' => ['unverified_items'] },
                                               { 'reference' => '#33', 'reasons' => ['not_in_ledger'] }]])
    end
  end

  describe 'the base' do
    it 'gives the numbers to close by hand, and no Closes lines, for a base other than the default branch' do
      response = with_sub_issues(sub_issue_node(31), ledger: "- [ ] #31 Ours\n")
      _exit_code, output = closes(response, base: 'feat/20-parent', items: '#31', boxes: '1,2,3')

      expect(output.values_at('base', 'default_branch', 'base_is_default', 'closes_lines', 'close_by_hand'))
        .to eq(['feat/20-parent', 'master', false, [], [24, 31]])
    end
  end

  describe 'the Copilot signal' do
    let(:copilot) { { rules: fixture('rest/branch-rules-copilot.json'), instructions: "# Review\n" } }

    it "reports the base's, read here again, after what is held open and before session_only" do
      _exit_code, output = closes(base: 'feat/20-parent', boxes: '1,2,3')

      expect(output.keys).to eq(%w[status base default_branch base_is_default closes_lines close_by_hand criteria held
                                   copilot_review session_only])
      expect(output['copilot_review']).to eq('ruleset' => true, 'instructions' => true, 'signal' => true)
    end
  end

  describe 'boxes it cannot place' do
    let(:held_open) { [{ 'reference' => '#24', 'reasons' => ['boxes_changed'] }] }

    it 'goes on past an edit elsewhere in the body, or a box ticked since facts counted them' do
      edits = ["#{body}\nA note added meanwhile.\n", body.sub('- [ ] Two', '- [x] Two')]

      edits.each do |edited|
        expect(closes_after(edited).last['closes_lines']).to eq(['Closes #24'])
      end
    end

    it 'holds the issue open, closing nothing, once its boxes are reordered or edited, every one verified' do
      edits = [body.sub("- [ ] One\n  - [ ] a detail\n", "- [ ] a detail\n- [ ] One\n"), body.sub('Two', 'Two, edited')]

      edits.each do |edited|
        exit_code, output = closes_after(edited)

        expect([exit_code, output.values_at('status', 'closes_lines', 'held')])
          .to eq([0, ['proceed', [], held_open]])
      end
    end

    it 'holds the issue open, closing nothing, on a line of the body that reads like a box it cannot place' do
      exit_code, output = closes(body: "- [ ] One\n- [ ]Two\n", boxes: '1')

      expect([exit_code, output.values_at('closes_lines', 'held')])
        .to eq([0, [[], [{ 'reference' => '#24', 'reasons' => ['boxes_ambiguous'] }]]])
    end

    it "holds the issue and this repository's open sub-issues open on a ledger line it cannot place" do
      response = with_sub_issues(sub_issue_node(31), sub_issue_node(5, upstream),
                                 ledger: "- [ ] #31 Ours\n[ ] **L2 No list marker.**\n")
      exit_code, output = closes(response, items: '#31,L9', boxes: '1,2,3')

      expect([exit_code, output.values_at('closes_lines', 'held')])
        .to eq([0, [[], [{ 'reference' => '#24', 'reasons' => %w[boxes_ambiguous open_elsewhere] },
                         { 'reference' => '#31', 'reasons' => ['boxes_ambiguous'] },
                         { 'reference' => 'example-owner/upstream#5', 'reasons' => ['open_elsewhere'] }]]])
    end

    it 'gives nothing to close by hand on a base other than the default branch' do
      edited = body.sub('Two', 'Two, edited')
      output = closes_after(edited, base: 'feat/20-parent').last

      expect(output.values_at('closes_lines', 'close_by_hand', 'held')).to eq([[], [], held_open])
    end
  end

  describe 'what it refuses' do
    let(:copilot) { nil }

    it 'stops, naming them, on ids or positions that match no box, or several' do
      response = record_response(ledger: "- [ ] **L1 One.**\n- [ ] **L1 Again.**\n- [ ] **L2 Two.**\n")
      exit_code, output = closes(response, items: 'L1,L2,L9', boxes: '2,4')

      expect([exit_code, output['reason'], output['missing']]).to eq([2, 'box_missing', ['L1', 'L9', 4]])
    end

    it 'stops when there is no ledger' do
      response = issue_response { |issue| issue['comments'] = connection([]) }
      expect_base
      expect_located(response)

      expect(record('closes', 'sgbett/dotfiles-claude#24', '--base', 'master').last['reason']).to eq('no_ledger')
    end
  end

  it 'takes no lock, as it writes nothing, so leaves no lock file behind' do
    expect(closes(boxes: '1,2,3').last['status']).to eq('proceed')
    expect(File).not_to exist(lock_directory)
  end
end
