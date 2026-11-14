# frozen_string_literal: true

require_relative '../lib/do/facts'
require_relative 'support/check_calls'
require_relative 'support/issue_responses'

# The walk-throughs QA ran by hand for #21's L2, which pre-flight's scripts
# now decide: /do acts only from a checkout of the issue's repository or a
# fork of it, and settles that before it looks at any branch.
RSpec.describe "/do pre-flight, #21's walk-throughs" do
  include Do::Testing::CheckCalls
  include Do::Testing::IssueResponses

  let(:here) { Do::Testing::CheckCalls::HERE }
  let(:origin_url) { Do::Testing::CheckCalls::ORIGIN_URL }
  let(:fork) { 'bettison-org/ai-software-architect' }
  let(:fork_url) { "https://github.com/#{fork}.git" }
  let(:upstream) { 'codenamev/ai-software-architect' }

  # Calls that read a branch of the checkout or the push remote.
  def branch_lookups
    git_calls.select do |argv|
      argv.intersect?(%w[ls-remote fetch config log]) || argv.any? { |argument| argument.include?('refs/heads/') }
    end
  end

  def unrelated_view
    '{"nameWithOwner":"example-owner/unrelated","parent":null}'
  end

  def expect_fork_origin
    fake_runner.expect_call(%w[git remote get-url origin], stdout: "#{fork_url}\n")
    expect_gh_login
    fake_runner.expect_call(['gh', 'repo', 'view', fork_url, '--json', 'nameWithOwner,url'],
                            stdout: JSON.generate('nameWithOwner' => fork, 'url' => "https://github.com/#{fork}"))
  end

  it 'an unrelated checkout stops before any branch is looked up' do
    unrelated_url = 'https://github.com/example-owner/unrelated.git'
    expect_check(through: :remote, remote: { urls: [unrelated_url], views: { unrelated_url => unrelated_view } })
    exit_code, output = run_check

    expect([exit_code, output['reason']]).to eq([2, 'push_remote_not_this_repository'])
    expect(output['message']).to include('Run /do owner/repo#N from a checkout')
    expect(branch_lookups).to be_empty
  end

  it 'a fork checkout given a bare number resolves the fork, as its own repository' do
    expect_fork_origin
    fake_runner.expect_call(graphql_command, stdin: issue_request(fork, 24), stdout: JSON.generate(
      issue_response do |issue, data|
        data['repository'].merge!('nameWithOwner' => fork, 'owner' => { 'login' => 'bettison-org' })
        issue['repository'].merge!('nameWithOwner' => fork, 'owner' => { 'login' => 'bettison-org' })
      end
    ))
    fake_runner.expect_call(%w[git rev-parse --path-format=absolute --git-common-dir],
                            stdout: "#{sandbox.work_directory}/.git\n")
    fake_runner.expect_call(['git', 'check-ref-format', '--branch', Do::Testing::CheckCalls::BRANCH],
                            stdout: "#{Do::Testing::CheckCalls::BRANCH}\n")
    outcome = Do::Facts.new('24', runner: fake_runner).call

    expect(JSON.parse(outcome.to_json)['summary']['issue']).to eq("#{fork}#24")
  end

  it 'a fork checkout given a bare number stops when the fork has issues disabled' do
    expect_fork_origin
    # What GitHub answers for an issue number in a repository with issues disabled.
    fake_runner.expect_call(graphql_command, stdin: issue_request(fork, 24), exit_status: 1, stdout: JSON.generate(
      'data' => { 'viewer' => { 'login' => 'sgbett' }, 'repository' => nil },
      'errors' => [{ 'type' => 'NOT_FOUND', 'path' => %w[repository issueOrPullRequest],
                     'message' => 'Could not resolve to an issue or pull request with the number of 24.' }]
    ))
    outcome = Do::Facts.new('24', runner: fake_runner).call

    expect(JSON.parse(outcome.to_json))
      .to eq('status' => 'stop', 'reason' => 'not_an_issue',
             'message' => Do::Reasons::NOT_AN_ISSUE_MESSAGES[:missing_issue])
  end

  it 'repository rules that send the pull request elsewhere stop, before the remotes are even listed' do
    expect_check(through: :issue)
    exit_code, output = run_check(check_arguments(pr_target: 'example-owner/elsewhere'))

    expect([exit_code, output['reason']]).to eq([2, 'pr_target_not_this_repository'])
    expect(git_calls.map { |argv| argv[1] }).to eq(%w[check-ref-format check-ref-format])
  end

  it "a fork's checkout working on its upstream's issue passes, the fork named only in session_only" do
    issue = { 'data' => { 'viewer' => { 'login' => 'sgbett' },
                          'repository' => { 'nameWithOwner' => upstream, 'issueOrPullRequest' => {
                            '__typename' => 'Issue', 'repository' => { 'nameWithOwner' => upstream }
                          } } } }
    base = { 'data' => { 'repository' => { 'ref' => { 'name' => 'main',
                                                      'target' => { 'oid' => Do::Testing::CheckCalls::BASE_SHA } } } } }
    expect_check(arguments: { base: 'main' }, issue: { response: issue, repository: upstream, number: 7 },
                 remote: { urls: [fork_url], views: { fork_url => fixture('repo-view/fork.json') } },
                 base: { response: base, base: 'main', repository: upstream },
                 pull_requests: { nodes: [], repository: upstream }, focus: { claude_md: nil, repository: upstream })
    exit_code, output = run_check(check_arguments("#{upstream}#7", pr_target: upstream, base: 'main'))

    expect([exit_code, output['push_remote_is_fork'], output['summary']['push_remote']])
      .to eq([0, true, 'origin, a fork of this repository'])
    expect([output['session_only']['push_remote_forks'], output['read']])
      .to eq([[fork], ['references/other-repositories.md']])
    expect(JSON.generate(output.except('session_only'))).not_to include('bettison-org')
  end

  it "a push URL under a repository's old name passes, by the name GitHub gives it now" do
    old_url = 'https://github.com/example-old-owner/old-name.git'
    expect_check(remote: { urls: [old_url], views: { old_url => fixture('repo-view/push-origin.json') } })

    expect(run_check.first).to eq(0)
  end

  it 'a mismatch in letter case only passes, in the issue, the push URL and the PR target' do
    url = 'https://github.com/SGBETT/DOTFILES-CLAUDE.git'
    expect_check(issue: { repository: 'SGBETT/Dotfiles-Claude' },
                 remote: { urls: [url], views: { url => fixture('repo-view/push-origin.json') } })
    exit_code, output = run_check(check_arguments('SGBETT/Dotfiles-Claude#24', pr_target: 'Sgbett/Dotfiles-Claude'))

    expect([exit_code, output['repository']['name_with_owner']]).to eq([0, here])
  end

  it 'an SSH host alias stops on its host, before gh is asked about it' do
    alias_url = 'git@github-work:sgbett/dotfiles-claude.git'
    expect_check(through: :remote, remote: { urls: [alias_url], views: {} })
    exit_code, output = run_check

    expect([exit_code, output['reason']]).to eq([2, 'host_mismatch'])
    expect(fake_runner.calls.map { |call| call[:argv].first(3) }).not_to include(%w[gh repo view])
  end

  it "a resume from the wrong checkout stops before its push remote's branches are looked at" do
    # A checkout of a fork of some other repository, whose push remote has a
    # feat/24-... branch of its own: nothing of it may be resumed.
    other_fork = 'https://github.com/example-fork-owner/other.git'
    view = '{"nameWithOwner":"example-fork-owner/other","parent":{"name":"other","owner":{"login":"example-owner"}}}'
    expect_check(through: :remote, remote: { urls: [other_fork], views: { other_fork => view } })
    exit_code, output = run_check

    expect([exit_code, output['reason']]).to eq([2, 'push_remote_not_this_repository'])
    expect([branch_lookups, output.key?('branch')]).to eq([[], false])
  end
end
