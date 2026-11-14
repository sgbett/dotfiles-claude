# frozen_string_literal: true

require_relative 'support/gate_calls'

# `promote-check check` end to end in process: every call it makes, in
# order, on the fake runner.
RSpec.describe CopilotCheck::PromotionGate do
  include CopilotCheck::Testing::GateCalls

  let(:head) { CopilotCheck::Testing::GateCalls::HEAD }
  let(:other) { CopilotCheck::Testing::GateCalls::OTHER_COMMIT }
  let(:job_link) { format(CopilotCheck::Testing::GateCalls::JOB_LINK, job: 41) }

  it 'promotes a converged draft when every condition holds, saying what it read' do
    expect_gate
    exit_code, output = run_promote_check(gate_arguments)

    expect([exit_code, output.keys.first, output['verdict'], output['reasons']]).to eq([0, 'status', 'PROMOTE', []])
    expect(output.except('status', 'verdict', 'reasons'))
      .to eq('repository' => { 'host' => 'github.com', 'name_with_owner' => 'sgbett/dotfiles-claude' },
             'pull_request' => { 'number' => 18, 'head' => head, 'is_draft' => true, 'state' => 'OPEN',
                                 'mergeable' => 'MERGEABLE' },
             'local_head' => head,
             'copilot' => { 'reviewed_commit' => head, 'todo_threads' => 0,
                            'todo_reviews' => CopilotCheck::Testing::GateCalls::REVIEWS },
             'files' => { 'complete' => true, 'protected_paths' => 0, 'github_text' => { 'protected_paths' => [] } },
             'checks' => [{ 'bucket' => 'pass', 'github_text' => { 'name' => 'test' } }])
  end

  it 'holds, giving every reason with its message, when many conditions fail together' do
    threads = threads_response
    threads_pull_request(threads)['latest']['nodes'].first['commit']['oid'] = other
    files = [{ 'filename' => 'CLAUDE.md' }, { 'filename' => 'lib/a.rb', 'previous_filename' => '.github/workflows/x' }]
    expect_gate(pull_request: { response: pull_request_response('isDraft' => false, 'mergeable' => 'CONFLICTING',
                                                                'author' => { 'login' => 'example-stranger' }) },
                threads: { response: threads }, local_head: { sha: other }, files: { pages: [files] },
                checks: { entries: [check_entry('lint', 'pending'), check_entry('test', 'fail')] })

    exit_code, output = run_promote_check(gate_arguments(outcome: 'timeout', reviews: [],
                                                         rules: rules_file(merge_is_owners_step: false)))

    expect([exit_code, output['verdict']]).to eq([0, 'HOLD'])
    expect(output['reasons'].map { |reason| reason['reason'] })
      .to eq(%w[not_a_draft merge_not_owners_step not_converged local_head_differs copilot_not_on_head
                unanswered_reviews not_viewers_own protected_paths_changed checks_pending undocumented_failures
                not_mergeable])
    expect(output['reasons']).to all(include('message' => be_a(String)))
    expect(output['files']['github_text']['protected_paths']).to eq(%w[CLAUDE.md .github/workflows/x])
  end

  it 'reads mergeable once more after the checks when it was UNKNOWN, and only once' do
    expect_gate(pull_request: { response: pull_request_response('mergeable' => 'UNKNOWN') },
                mergeable: { reread: pull_request_response })
    expect(run_promote_check(gate_arguments).last.values_at('verdict', 'reasons')).to eq(['PROMOTE', []])

    expect_gate(pull_request: { response: pull_request_response('mergeable' => 'UNKNOWN') },
                mergeable: { reread: pull_request_response('mergeable' => 'UNKNOWN') })
    output = run_promote_check(gate_arguments).last
    expect([output['reasons'].map { |reason| reason['reason'] }, output['pull_request']['mergeable']])
      .to eq([%w[not_mergeable], 'UNKNOWN'])
  end

  it 'promotes past a failure the rules document by name and annotation text' do
    expected = [{ name: 'CI result', text: 'The suite runs once the pull request is ready.' }]
    expect_gate(checks: { entries: [check_entry('CI result', 'fail', job_link), check_entry('test', 'pass')],
                          annotations: { 41 => ['The suite runs once the pull request is ready.'] } })

    output = run_promote_check(gate_arguments(rules: rules_file(expected_failures: expected))).last

    expect([output['verdict'], output['checks'].first])
      .to eq(['PROMOTE', { 'bucket' => 'fail', 'documented' => true, 'github_text' => { 'name' => 'CI result' } }])
  end

  it 'holds a failure documented by name only, or by text only' do
    name_only = [{ name: 'CI result', text: 'The suite runs once the pull request is ready.' }]
    expect_gate(checks: { entries: [check_entry('CI result', 'fail', job_link)],
                          annotations: { 41 => ['Tests failed.'] } })
    expect(run_promote_check(gate_arguments(rules: rules_file(expected_failures: name_only))).last['reasons'])
      .to eq([CopilotCheck::Reasons.hold(:undocumented_failures).transform_keys(&:to_s)])

    text_only = [{ name: 'CI', text: 'Tests failed.' }]
    expect_gate(checks: { entries: [check_entry('CI result', 'fail', job_link)] })
    expect(run_promote_check(gate_arguments(rules: rules_file(expected_failures: text_only))).last['verdict'])
      .to eq('HOLD')
  end

  it 'stops where the thread fetch stops, reading nothing more' do
    threads = threads_response
    threads_pull_request(threads)['reviews']['nodes'].first['author'] = { 'id' => 'BOT_kgDOOtherId' }
    expect_gate(through: :threads, threads: { response: threads })

    exit_code, output = run_promote_check(gate_arguments)

    expect([exit_code, output.values_at('status', 'reason', 'message')])
      .to eq([2, ['stop', 'copilot_id_changed', CopilotCheck::Reasons::MESSAGES[:copilot_id_changed]]])
    expect(output['pull_request']).to eq('number' => 18)
  end

  it "reads the lead's files before asking GitHub anything, failing as a tool on one it can't take" do
    rules = sandbox.path('rules.json').tap { |path| File.write(path, '{"draft_flow": true}') }

    expect { run_promote_check(gate_arguments(rules: rules)) }.to raise_error(CopilotCheck::UnusableRulesFile)
    expect { run_promote_check(gate_arguments(start: start_file(number: 19))) }
      .to raise_error(CopilotCheck::UnusableStartFile)
    expect(fake_runner.calls).to eq([])
  end
end
