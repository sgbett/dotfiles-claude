# frozen_string_literal: true

require_relative 'support/record_calls'

# The walk-throughs QA ran by hand for #21's L4 and L1, which `record
# closes` now decides: a sub-issue in another repository is tracked, never
# closed here, and holds the issue open while it is open; one in a
# repository that may not be named is reported only in the session.
RSpec.describe "/do closing, #21's walk-throughs" do
  include Do::Testing::RecordCalls

  let(:upstream) { 'example-owner/upstream' }

  # closes for #24 with one sub-issue, +node+, every acceptance box verified
  # and the ledger's own items too.
  def closes(node, base: 'master')
    expect_base(base)
    response = record_response(ledger: "- [ ] **L1 One.**\n") { |issue| issue['subIssues'] = connection([node]) }
    expect_located(response)
    expect_read(Do::Testing::RecordCalls::ISSUE_PATH, "- [ ] One\n- [ ] Two\n")
    record('closes', 'sgbett/dotfiles-claude#24', '--base', base, '--verified-items', 'L1', '--verified-boxes', '1,2')
      .last
  end

  it 'an open sub-issue in another repository: no Closes line for the issue, which stays open naming it' do
    output = closes(sub_issue_node(5, upstream))

    expect(output['closes_lines']).to eq([])
    expect(output['held'].map { |held| held['reference'] }).to eq(['#24', 'example-owner/upstream#5'])
  end

  it 'the same sub-issue once closed: the issue gets its Closes line, and the sub-issue none' do
    output = closes(sub_issue_node(5, upstream, state: 'CLOSED'))

    expect(output.values_at('closes_lines', 'held')).to eq([['Closes #24'], []])
  end

  it 'a non-default base: the issue is not closed by hand while the sub-issue is open, and is once it is closed' do
    open = closes(sub_issue_node(5, upstream), base: 'feat/20-parent')
    closed = closes(sub_issue_node(5, upstream, state: 'CLOSED'), base: 'feat/20-parent')

    expect([open['close_by_hand'], closed['close_by_hand']]).to eq([[], [24]])
    expect([open['closes_lines'], closed['closes_lines']]).to eq([[], []])
  end

  it 'a public parent with a private sub-issue: the sub-issue is named only in the session' do
    output = closes(sub_issue_node(8, 'example-owner/hidden', visibility: 'PRIVATE'))

    expect(output['held']).to eq([{ 'reference' => '#24', 'reasons' => ['open_elsewhere'] }])
    expect(output['session_only']['held'].map { |held| held['reference'] }).to eq(['example-owner/hidden#8'])
  end
end
