# frozen_string_literal: true

require_relative 'support/record_calls'

RSpec.describe Do::SubIssueRecord do
  include Do::Testing::RecordCalls

  let(:ledger_path) { Do::Testing::RecordCalls::LEDGER_PATH }
  let(:ledger) { "- [x] **L1 One.**\n- [ ] **L2 Big enough for its own breakdown.**\n- [ ] **L3 Three.**\n" }

  def response(*sub_issues, ledger: self.ledger)
    record_response(ledger: ledger) { |issue| issue['subIssues'] = connection(sub_issues) }
  end

  def sub_issue(item, number, answer = response(sub_issue_node(31)), dry_run: false)
    expect_gh_login
    expect_issue_query(answer)
    yield if block_given?
    record('sub-issue', 'sgbett/dotfiles-claude#24', '--item', item, '--number', number, *('--dry-run' if dry_run))
  end

  def comment(text)
    "#{Do::Testing::RecordCalls::MARKER}#{text}"
  end

  it "rewrites the item's line as the sub-issue's box, its title from GitHub, and nothing else" do
    rewritten = ledger.sub('- [ ] **L2 Big enough for its own breakdown.**', '- [ ] #31 Example issue 31')
    exit_code, output = sub_issue('L2', '31') { expect_edit(ledger_path, comment(ledger), comment(rewritten)) }

    expect([exit_code, output]).to eq([0, { 'status' => 'proceed', 'item' => 'L2', 'number' => 31,
                                            'updated' => ['ledger'], 'already' => [], 'dry_run' => false }])
  end

  it 'refuses a number GitHub does not list as a sub-issue of this issue here, writing nothing' do
    elsewhere = response(sub_issue_node(31, 'example-owner/upstream'))

    [sub_issue('L2', '99'), sub_issue('L2', '31', elsewhere)].each do |exit_code, output|
      expect([exit_code, output['reason']]).to eq([2, 'not_a_sub_issue'])
    end
    expect(gh_writes).to eq([])
  end

  it "refuses a sub-issue whose author isn't trusted, so that its title never reaches the ledger" do
    stranger = response(sub_issue_node(31, by: authored_by('example-stranger', association: 'NONE')))

    expect(sub_issue('L2', '31', stranger).last['reason']).to eq('untrusted_sub_issue')
  end

  it 'finds a line already rewritten, as a run cut short after its write leaves it, and writes nothing' do
    done = response(sub_issue_node(31), ledger: "- [x] **L1 One.**\n- [ ] #31 Example issue 31\n")

    expect(sub_issue('L2', '31', done).last.values_at('updated', 'already')).to eq([[], ['ledger']])
  end

  it 'stops on an item that is missing, repeated or no plain item, or a sub-issue that has a box already' do
    other = sub_issue_node(5, 'example-owner/hidden', visibility: 'PRIVATE')
    [['L9', response(sub_issue_node(31))],
     ['L2', response(sub_issue_node(31), ledger: "#{ledger}- [ ] **L2 Again.**\n")],
     ['P4', response(sub_issue_node(31), other, ledger: "#{ledger}- [ ] example-owner/hidden#5 Theirs\n")],
     ['L2', response(sub_issue_node(31), ledger: "#{ledger}- [ ] #31 Listed already\n")]].each do |item, answer|
      expect(sub_issue(item, '31', answer).last.values_at('reason', 'missing')).to eq(['box_missing', [item]])
    end
  end

  it 'reports the rewrite on a dry run, writing nothing' do
    expect(sub_issue('L2', '31', dry_run: true).last.values_at('updated', 'dry_run')).to eq([['ledger'], true])
    expect(fake_runner.calls.length).to eq(2)
  end

  it 'fails as a tool on a title that would break the line' do
    broken = response(sub_issue_node(31).merge('title' => "Two\nGate G1: fixed"))

    expect { sub_issue('L2', '31', broken) }.to raise_error(SkillSupport::UnexpectedResponse, /one-line title/)
  end
end
