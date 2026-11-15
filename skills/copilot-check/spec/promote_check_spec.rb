# frozen_string_literal: true

require_relative 'support/gate_calls'

RSpec.describe 'skills/copilot-check/bin/promote-check' do
  include CopilotCheck::Testing::GateCalls

  let(:promote_check) { File.join(repository_root, 'skills', 'copilot-check', 'bin', 'promote-check') }
  let(:graphql) { %w[api graphql --hostname github.com --input -] }
  let(:repo_view) do
    { args: %w[repo view --json nameWithOwner,url], stdout_file: fixture_path('repo-view/checkout.json') }
  end
  let(:files) do
    { args: files_call.drop(1), stdout_file: fixture_path('rest/files-18.json') }
  end
  let(:checks_args) { CopilotCheck::Testing::GateCalls::CHECKS.drop(1) }

  def run(*arguments, environment: {})
    stdout, stderr, status = Open3.capture3(environment, promote_check, *arguments)
    [status.exitstatus, stdout, stderr]
  end

  # The request exactly as recorded, which the shim matches byte for byte.
  def recorded_request(name)
    JSON.generate(JSON.parse(fixture("graphql/#{name}.request.json")))
  end

  def recorded(name, **entry)
    { args: graphql, stdin: recorded_request(name), stdout_file: fixture_path("graphql/#{name}.json"), **entry }
  end

  # The sandbox's one commit, standing for the pull request's head.
  def local_commit
    system('git', 'commit', '--quiet', '--allow-empty', '-m', 'First', exception: true)
    Open3.capture2('git', 'rev-parse', 'HEAD').first.chomp
  end

  # What a calling directory can hand any Ruby started there: Bundler,
  # loaded against a Gemfile that names a gem which doesn't exist.
  def hostile_environment
    File.write('Gemfile', "source 'https://rubygems.org'\ngem 'skill-support-no-such-gem'\n")
    { 'RUBYOPT' => '-rbundler/setup', 'BUNDLE_GEMFILE' => File.expand_path('Gemfile') }
  end

  # The calls of a check that passes every condition on +head+, Copilot's
  # latest review of it included.
  def passing_entries(head)
    [repo_view,
     { args: graphql, stdin: recorded_request('pull-request-18'),
       stdout: JSON.generate(pull_request_response('headRefOid' => head)) },
     { args: graphql, stdin: recorded_request('threads-18'), stdout: JSON.generate(threads_reviewing(head)) },
     files, { args: checks_args, stdout: JSON.generate([check_entry('test', 'pass')]) }]
  end

  # #18's recorded thread fetch, with Copilot's latest review of +head+.
  def threads_reviewing(head)
    threads_response.tap do |threads|
      threads_pull_request(threads)['latest']['nodes'].first['commit']['oid'] = head
    end
  end

  it 'promotes a draft whose every condition holds, whatever RUBYOPT says' do
    head = local_commit
    shim = install_gh_shim(passing_entries(head))

    exit_code, stdout, stderr = run(*gate_arguments, environment: hostile_environment)

    expect([exit_code, stderr, shim.unmatched_calls]).to eq([0, '', []])
    expect(JSON.parse(stdout).values_at('status', 'verdict', 'reasons', 'local_head'))
      .to eq(['proceed', 'PROMOTE', [], head])
  end

  it "reads HEAD in the checkout the start file records, /do's linked worktree, not the working directory's" do
    local_commit
    worktree = sandbox.path('pr-worktree')
    system('git', 'worktree', 'add', '--quiet', '-b', 'feat/x', worktree, exception: true)
    system('git', '-C', worktree, 'commit', '--quiet', '--allow-empty', '-m', 'Head', exception: true)
    head = Open3.capture2('git', '-C', worktree, 'rev-parse', 'HEAD').first.chomp
    install_gh_shim(passing_entries(head))

    exit_code, stdout, stderr = run(*gate_arguments(start: start_file(checkout: worktree)))

    expect([exit_code, stderr, JSON.parse(stdout).values_at('verdict', 'local_head')]).to eq([0, '', ['PROMOTE', head]])
  end

  it 'holds #18 as recorded, merged and never a draft, for every reason the live run gave' do
    local_commit
    shim = install_gh_shim([repo_view, recorded('pull-request-18', repeat: true), recorded('threads-18'), files,
                            { args: checks_args, exit: 1, stderr: fixture('pr-checks/no-checks-18.stderr') }])
    arguments = gate_arguments(reviews: [], rules: rules_file(draft_flow: false, merge_is_owners_step: false),
                               start: start_file(draft: false))

    exit_code, stdout, stderr = run(*arguments)
    output = JSON.parse(stdout)

    expect([exit_code, stderr, shim.unmatched_calls]).to eq([0, '', []])
    expect(shim.calls.count { |call| call['stdin'] == recorded_request('pull-request-18') }).to eq(2)
    expect(output.values_at('status', 'verdict')).to eq(%w[proceed HOLD])
    expect(output['reasons'].map { |reason| reason['reason'] })
      .to eq(%w[not_open not_a_draft no_draft_flow merge_not_owners_step not_draft_at_start local_head_differs
                unanswered_reviews no_checks not_mergeable])
  end

  it 'verifies the head and the state after the ready: an open, ready pull request with that head goes on' do
    install_gh_shim([repo_view, { args: graphql, stdin: recorded_request('pull-request-18'),
                                  stdout: JSON.generate(pull_request_response('isDraft' => false)) }])

    exit_code, stdout, stderr = run('verify', '--pr', '18', '--head', CopilotCheck::Testing::GateCalls::HEAD)

    expect([exit_code, stderr, JSON.parse(stdout)['status']]).to eq([0, '', 'proceed'])
  end

  it "stops on #18 as recorded, merged, with the head checked, and on a head that isn't the one checked" do
    install_gh_shim([repo_view.merge(repeat: true), recorded('pull-request-18', repeat: true)])

    same = run('verify', '--pr', '18', '--head', CopilotCheck::Testing::GateCalls::HEAD)
    changed = run('verify', '--pr', '18', '--head', CopilotCheck::Testing::GateCalls::OTHER_COMMIT)

    expect([same.first, JSON.parse(same[1]).values_at('status', 'reason')])
      .to eq([2, %w[stop ready_state_unexpected]])
    expect([changed.first, JSON.parse(changed[1]).values_at('status', 'reason')]).to eq([2, %w[stop head_changed]])
  end

  it 'fails as a tool on any arguments it does not take, printing its usage and calling gh not at all' do
    shim = install_gh_shim([])

    [[], %w[check --pr 18], %w[verify --pr 18 --head nothex], %w[--help]].each do |arguments|
      exit_code, stdout, stderr = run(*arguments)

      expect([exit_code, stdout]).to eq([1, '']), arguments.inspect
      expect(stderr).to start_with('promote-check: tool failure: '), arguments.inspect
    end
    expect(shim.calls).to eq([])
  end
end
