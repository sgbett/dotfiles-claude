# frozen_string_literal: true

require_relative 'support/check_calls'

RSpec.describe Do::Check do
  include Do::Testing::CheckCalls

  let(:here) { Do::Testing::CheckCalls::HERE }
  let(:branch) { Do::Testing::CheckCalls::BRANCH }
  let(:origin_url) { Do::Testing::CheckCalls::ORIGIN_URL }
  let(:local_tip) { 'a' * 40 }
  let(:remote_tip) { 'b' * 40 }
  let(:tracking) { { remote: 'origin', merge: "refs/heads/#{branch}" } }

  # Calls that read a branch of the checkout or the push remote.
  def branch_lookups
    git_calls.select do |argv|
      argv.intersect?(%w[ls-remote fetch config log]) || argv.any? { |argument| argument.include?('refs/heads/') }
    end
  end

  def message(reason)
    Do::Reasons::MESSAGES.fetch(reason)
  end

  describe 'a run that passes' do
    it 'proceeds on a new branch, status first and the fields in the order the lead reads them' do
      expect_check
      exit_code, output = run_check

      expect([exit_code, output.keys])
        .to eq([0, %w[status summary repository push_remote push_remote_is_fork pr_target base branch
                      scripts_in_work_tree security_focus working_tree_clean read session_only]])
      expect(output['summary']).to eq('push_remote' => 'origin, this repository', 'pr_target' => here,
                                      'base' => 'master', 'branch' => branch,
                                      'resume_point' => 'none: the branch is new', 'security_focus' => 'none')
      expect(output['branch']).to eq('name' => branch, 'state' => 'new', 'accepted' => false,
                                     'fresh_worktree' => false, 'pull_requests' => [])
      expect(output.values_at('repository', 'push_remote_is_fork', 'scripts_in_work_tree', 'working_tree_clean',
                              'read'))
        .to eq([{ 'name_with_owner' => here, 'host' => 'github.com' }, false, false, true, []])
      expect(output['session_only']).to eq('push_urls' => [origin_url], 'push_remote_forks' => [],
                                           'changed_paths' => [])
    end

    it 'resumes on a local branch that tracks its copy on the push remote and is not ahead of it' do
      expect_check(branch: { remote_tip: remote_tip, local_tip: remote_tip, config: tracking })
      exit_code, output = run_check

      expect([exit_code, output['branch']['state'], output['summary']['resume_point'], output['read']])
        .to eq([0, 'resume_local', 'the local branch', ['references/resume.md']])
      expect(output['session_only']['local_branch_commits']).to eq([])
    end

    it "resumes from the push remote's copy when there is no local branch, at the tip it read" do
      expect_check(branch: { remote_tip: remote_tip })
      exit_code, output = run_check

      expect([exit_code, output['branch']['state'], output['branch']['remote_tip'], output['summary']['resume_point']])
        .to eq([0, 'resume_push_remote', remote_tip, "the push remote's copy"])
    end

    it 'reads the branch through the push URLs the remote passed with, never through the remote by name' do
      mirror = 'git@github.com:sgbett/dotfiles-claude.git'
      expect_check(remote: { urls: [origin_url, mirror] }, branch: { remote_tip: remote_tip })
      exit_code, output = run_check

      expect([exit_code, output['branch']['remote_tip']]).to eq([0, remote_tip])
      expect(git_calls.select { |argv| argv.include?('ls-remote') }.map { |argv| argv.last(2) })
        .to eq([[origin_url, "refs/heads/#{branch}"], [mirror, "refs/heads/#{branch}"]])
    end

    it 'lists a trusted pull request open on the branch, for the lead to update' do
      expect_check(pull_requests: { nodes: [pull_request_node(30, 'sgbett', viewer: true)] })

      expect(run_check.last['branch']['pull_requests'])
        .to eq([{ 'number' => 30, 'author' => 'sgbett', 'trusted' => true, 'trust_reason' => 'viewer' }])
    end

    it "gives the security focus from the base branch's commit, its text only under github_text" do
      claude_md = "# Example\n\n## Security focus\n\nTokens and signatures.\n\n## Code Style\n\nPlain.\n"
      expect_check(focus: { claude_md: claude_md,
                            rules: { '.claude/rules/security.md' => "## Security focus\n\nWebhooks.\n" } })
      output = run_check.last

      expect(output['security_focus'])
        .to eq('found' => true, 'sources' => ['CLAUDE.md', '.claude/rules/security.md'],
               'github_text' => { 'text' => "## Security focus\n\nTokens and signatures.\n\n## Security focus\n\n" \
                                            'Webhooks.' })
      expect(output['summary']['security_focus']).to eq('CLAUDE.md, .claude/rules/security.md')
    end

    it "reports the working tree's changes, their paths only in session_only" do
      expect_check(changes: { status: " M README.md\0?? notes/plan.md\0R  new.md\0old.md\0" })
      output = run_check.last

      expect(output['working_tree_clean']).to be(false)
      expect(output['session_only']['changed_paths']).to eq([' M README.md', '?? notes/plan.md', 'R  old.md -> new.md'])
    end
  end

  describe 'the remotes, all checked before any branch is looked up' do
    it 'stops when the PR target is another repository, before even listing the remotes' do
      expect_check(through: :issue)
      exit_code, output = run_check(check_arguments(pr_target: 'example-owner/elsewhere'))

      expect([exit_code, output['reason'], output['message']])
        .to eq([2, 'pr_target_not_this_repository', message(:pr_target_not_this_repository)])
      expect(git_calls.map { |argv| argv[1] }).to eq(%w[check-ref-format check-ref-format])
    end

    it 'stops when the push remote is not a remote of this checkout, or has no push URL' do
      [{ remotes: ['upstream'] }, { urls: [] }].each do |remote|
        expect_check(through: :remote, remote: remote)

        expect(run_check.last).to include('status' => 'stop', 'reason' => 'remote_missing'), remote.inspect
      end
      expect(branch_lookups).to be_empty
    end

    it 'stops when any push URL is on another host, before asking gh about any of them' do
      urls = [origin_url, 'https://gitlab.example.com/sgbett/dotfiles-claude.git']
      expect_check(through: :remote, remote: { urls: urls, views: {} })
      output = run_check.last

      expect([output['reason'], output['session_only']['push_urls']]).to eq(['host_mismatch', urls])
      expect(fake_runner.calls.map { |call| call[:argv][1] }).not_to include('repo')
    end

    it "stops when a push URL doesn't resolve through GitHub, with gh's answer in session_only" do
      stderr = "GraphQL: Could not resolve to a Repository with the name 'sgbett/dotfiles-claude'. (repository)\n"
      expect_check(through: :remote, remote: { views: { origin_url => { exit_status: 1, stderr: stderr } } })
      output = run_check.last

      expect([output['reason'], output['session_only']['stderr']]).to eq(['remote_unresolvable', stderr.strip])
      expect(branch_lookups).to be_empty
    end

    it 'stops when any push URL resolves to neither this repository nor a fork of it' do
      unrelated = 'git@github.com:example-owner/unrelated.git'
      expect_check(through: :remote,
                   remote: { urls: [origin_url, unrelated],
                             views: { origin_url => fixture('repo-view/push-origin.json'),
                                      unrelated => '{"nameWithOwner":"example-owner/unrelated","parent":null}' } })
      output = run_check.last

      expect([output['reason'], output.key?('push_remote_is_fork')]).to eq(['push_remote_not_this_repository', false])
      expect(output['message']).to end_with("from a checkout of the issue's repository or of a fork of it.")
      expect(branch_lookups).to be_empty
    end

    it "stops on a fork the user can't write to, naming it only in session_only, before any branch is looked up" do
      fork = 'example-fork-owner/dotfiles-claude'
      fork_url = "https://github.com/#{fork}.git"
      view = { 'nameWithOwner' => fork, 'parent' => { 'name' => 'dotfiles-claude', 'owner' => { 'login' => 'sgbett' } },
               'viewerPermission' => 'READ' }
      expect_check(through: :remote, remote: { urls: [fork_url], views: { fork_url => JSON.generate(view) } })
      exit_code, output = run_check

      expect([exit_code, output['reason'], output['message']])
        .to eq([2, 'fork_not_writable', message(:fork_not_writable)])
      expect(output['session_only']['push_remote_forks']).to eq([fork])
      expect(JSON.generate(output.except('session_only'))).not_to include('example-fork-owner')
      expect(branch_lookups).to be_empty
    end

    it 'masks credentials in the push URLs it reports' do
      url = 'https://x-access-token:example-secret@github.com/sgbett/dotfiles-claude.git'
      expect_check(through: :base, remote: { urls: [url] }, base: { response: fixture('graphql/base-missing.json') })
      output = run_check.last

      expect(output['session_only']['push_urls']).to eq(['https://***@github.com/sgbett/dotfiles-claude.git'])
      expect(JSON.generate(output)).not_to include('example-secret')
    end
  end

  describe 'the base branch' do
    it "stops when the base doesn't exist on this repository, before any branch is looked up" do
      base = 'feat/24+no-such-branch'
      expect_check(through: :base, arguments: { base: base },
                   base: { base: base, response: fixture('graphql/base-missing.json') })
      exit_code, output = run_check(check_arguments(base: base))

      expect([exit_code, output['reason'], output['message']]).to eq([2, 'base_missing', message(:base_missing)])
      expect(output['summary']['push_remote']).to eq('origin, this repository')
      expect(branch_lookups).to be_empty
    end
  end

  describe 'the branch' do
    it 'stops when it is the base or the default branch, in any case, before the remotes are listed' do
      [{ base: 'release', branch: 'release' }, { base: 'release', branch: 'Master' }].each do |names|
        expect_check(through: :issue, arguments: names)
        exit_code, output = run_check(check_arguments(**names))

        expect([exit_code, output['reason'], output['message']])
          .to eq([2, 'branch_is_base_or_default', message(:branch_is_base_or_default)]), names.inspect
      end
      expect(git_calls.map { |argv| argv[1] }.uniq).to eq(['check-ref-format'])
    end

    it 'stops on a checked-out pull request the push remote has no copy of, whatever the user accepted' do
      [{ remote: 'https://github.com/example-owner/dotfiles-claude.git', merge: "refs/heads/#{branch}" },
       { remote: 'upstream', merge: "refs/heads/#{branch}" }, { remote: 'origin', pushRemote: 'upstream' },
       { remote: 'origin', merge: 'refs/pull/31/head' }].each do |config|
        expect_check(through: :branch, branch: { local_tip: local_tip, config: config })
        exit_code, output = run_check(check_arguments(extra: ['--accept-local-branch', local_tip]))

        expect([exit_code, output['reason'], output['message'], output['branch']['fresh_worktree']])
          .to eq([2, 'checked_out_pr', message(:checked_out_pr), false]), config.inspect
        expect(output['branch']).not_to include('pull_requests')
      end
    end

    it "resumes beside a checked-out pull request from the push remote's copy, in a fresh worktree" do
      expect_check(branch: { remote_tip: remote_tip, local_tip: local_tip, config: { merge: 'refs/pull/31/head' },
                             lacking: ['1234567 Example Author Theirs'] })
      exit_code, output = run_check(check_arguments(extra: ['--accept-local-branch', local_tip]))

      expect([exit_code, output['branch'].values_at('state', 'remote_tip', 'fresh_worktree', 'accepted')])
        .to eq([0, ['resume_push_remote', remote_tip, true, false]])
      expect([output['summary']['resume_point'], output['read']])
        .to eq([Do::CheckReport::FRESH_WORKTREE, ['references/resume.md']])
    end

    it 'stops when the push URLs hold the branch at different commits, or only some of them hold it' do
      mirror = 'git@github.com:sgbett/dotfiles-claude.git'
      [[remote_tip, local_tip], [nil, remote_tip]].each do |tips|
        expect_check(through: :branch, remote: { urls: [origin_url, mirror] }, branch: { remote_tips: tips })
        exit_code, output = run_check

        expect([exit_code, output['reason'], output['message']])
          .to eq([2, 'remote_tips_differ', message(:remote_tips_differ)]), tips.inspect
        expect([output['branch']['remote_tips'], output['session_only']['push_urls']])
          .to eq([tips, [origin_url, mirror]])
      end
      expect(git_calls.select { |argv| argv.intersect?(%w[fetch config log]) }).to be_empty
    end

    it 'asks before resuming on a local branch never pushed, its commits only in session_only' do
      commits = ['1234567 Example Author Work the push remote lacks']
      expect_check(branch: { local_tip: local_tip, lacking: commits })
      exit_code, output = run_check

      expect([exit_code, output['asks']])
        .to eq([3, [{ 'reason' => 'local_branch_unpushed', 'message' => message(:local_branch_unpushed),
                      'accept_with' => ['--accept-local-branch', local_tip] }]])
      expect(output['session_only']).to include('local_branch_commits' => commits,
                                                'local_branch_commits_truncated' => false)
      expect(JSON.generate(output.except('session_only'))).not_to include('Work the push remote lacks')
      expect([output['branch']['state'], output['read']]).to eq(['local_branch_unpushed', ['references/resume.md']])
    end

    it 'asks about a local branch ahead of its copy on the push remote' do
      expect_check(branch: { remote_tip: remote_tip, local_tip: local_tip, config: tracking,
                             lacking: ['1234567 Example Author Ahead'] })

      expect(run_check.last['asks'].map { |ask| ask['reason'] }).to eq(['local_branch_unpushed'])
    end

    it 'resumes on the local branch once the user accepts its current tip' do
      expect_check(branch: { local_tip: local_tip, lacking: ['1234567 Example Author Work'] })
      exit_code, output = run_check(check_arguments(extra: ['--accept-local-branch', local_tip.upcase]))

      expect([exit_code, output['branch'].values_at('state', 'accepted')]).to eq([0, ['resume_local', true]])
      expect(output['summary']['resume_point'])
        .to eq('the local branch, which the user accepted with commits the push remote lacks')
    end

    it 'asks again when the branch has moved on since the yes' do
      expect_check(branch: { local_tip: local_tip, lacking: ['1234567 Example Author Work'] })
      exit_code, output = run_check(check_arguments(extra: ['--accept-local-branch', 'c' * 40]))

      expect([exit_code, output['asks'].first['accept_with']]).to eq([3, ['--accept-local-branch', local_tip]])
    end
  end

  describe 'pull requests open on the branch' do
    it "stops on one by an author the Trust rule doesn't trust, never adopting it" do
      expect_check(through: :pull_requests,
                   pull_requests: { nodes: [pull_request_node(30, 'sgbett', viewer: true),
                                            pull_request_node(31, 'example-stranger', association: 'NONE')] })
      exit_code, output = run_check

      expect([exit_code, output['reason']]).to eq([2, 'untrusted_pull_request'])
      expect(output['branch']['pull_requests'].map { |pull_request| pull_request.values_at('number', 'trust_reason') })
        .to eq([[30, 'viewer'], [31, 'untrusted_association']])
    end

    it 'counts one whose head repository GitHub no longer names, a deleted fork' do
      expect_check(through: :pull_requests,
                   pull_requests: { nodes: [pull_request_node(31, nil, association: 'NONE', head: nil)] })

      expect(run_check.last['reason']).to eq('untrusted_pull_request')
    end

    it 'ignores one from a branch of that name in a repository the push remote does not push to' do
      elsewhere = pull_request_node(32, 'example-stranger', association: 'NONE',
                                                            head: 'example-stranger/dotfiles-claude')
      expect_check(pull_requests: { nodes: [elsewhere] })

      expect(run_check.last.values_at('status', 'branch')).to match(['proceed', include('pull_requests' => [])])
    end
  end

  describe "the scripts' own checkout" do
    it "tells the lead to build in a worktree when the scripts live in the working directory's checkout" do
      skill_directory = File.join(sandbox.work_directory, 'skills', 'do')
      FileUtils.mkdir_p(skill_directory)
      expect_check(through: :pull_requests)
      expect_scripts_step(top: sandbox.work_directory, skill_directory: skill_directory)
      expect_focus_step
      expect_changes_step
      exit_code, output = run_check(skill_directory: skill_directory)

      expect([exit_code, output['scripts_in_work_tree']]).to eq([0, true])
      expect(output['session_only']).to include('scripts_checkout' => sandbox.work_directory, 'scripts_changes' => [])
    end

    it 'asks when the skill has changes there, naming them in session_only' do
      expect_check(scripts: { top: scripts_top, status: " M skills/do/lib/do/check.rb\0?? skills/_support/x.rb\0" })
      exit_code, output = run_check

      expect([exit_code, output['asks'].map { |ask| ask.values_at('reason', 'message') }])
        .to eq([3, [['scripts_unreviewed', message(:scripts_unreviewed)]]])
      expect(output['asks'].first['accept_with']).to match(['--accept-scripts', match(/\A\h{64}\z/)])
      expect(output['session_only']['scripts_changes'])
        .to eq([' M skills/do/lib/do/check.rb', '?? skills/_support/x.rb'])
    end

    it "asks when its HEAD isn't in origin's default branch, or nothing says which that is" do
      [{ ancestor: false }, { default: nil }].each do |scripts|
        expect_check(scripts: { top: scripts_top, **scripts })

        expect(run_check.last['asks'].map { |ask| ask['reason'] }).to eq(['scripts_unreviewed']), scripts.inspect
      end
    end

    it 'goes on once the user accepts that digest, and asks again when the scripts change' do
      expect_check(scripts: { top: scripts_top, ancestor: false })
      digest = run_check.last['asks'].first['accept_with'].last
      accepted = check_arguments(extra: ['--accept-scripts', digest])
      expect_check(scripts: { top: scripts_top, ancestor: false })
      expect_check(scripts: { top: scripts_top, ancestor: false, diff: "a change since the yes\n" })

      expect([run_check(accepted).first, run_check(accepted).first]).to eq([0, 3])
    end

    it 'asks for both the branch and the scripts at once' do
      expect_check(branch: { local_tip: local_tip }, scripts: { top: scripts_top, ancestor: false })

      expect(run_check.last['asks'].map { |ask| ask['reason'] }).to eq(%w[local_branch_unpushed scripts_unreviewed])
    end
  end

  describe 'the host' do
    it 'stops when gh has no account logged in to the issue host, sending it nothing' do
      expect_check(through: :login, login: { host: 'ghe.example.com', logged_in: false })
      exit_code, output = run_check(check_arguments('https://ghe.example.com/example-owner/example-repo/issues/7'))

      expect([exit_code, output]).to eq([2, { 'status' => 'stop', 'reason' => 'host_not_logged_in',
                                              'message' => message(:host_not_logged_in),
                                              'host' => 'ghe.example.com' }])
    end
  end

  describe 'what the issue reference names' do
    it 'stops on a pull request number, or a number that names nothing, before any remote is looked at' do
      pull_request = { 'data' => { 'viewer' => { 'login' => 'sgbett' },
                                   'repository' => { 'nameWithOwner' => here,
                                                     'issueOrPullRequest' => { '__typename' => 'PullRequest' } } } }
      expect_check(through: :issue, issue: { response: pull_request, number: 25 })
      expect_check(through: :issue, issue: { response: fixture('graphql/missing-issue.json'), number: 99_999,
                                             exit_status: 1 })

      %w[25 99999].zip(%i[pull_request missing_issue]).each do |number, why|
        expect(run_check(check_arguments("#{here}##{number}")))
          .to eq([2, { 'status' => 'stop', 'reason' => 'not_an_issue',
                       'message' => Do::Reasons::NOT_AN_ISSUE_MESSAGES.fetch(why) }])
      end
      expect(git_calls.map { |argv| argv[1] }.uniq).to eq(['check-ref-format'])
    end

    it 'asks for the repository when a bare number has no origin to resolve it through' do
      expect_check(through: :arguments)
      fake_runner.expect_call(%w[git remote get-url origin], exit_status: 2, stderr: "error: No such remote 'origin'\n")

      expect(run_check(check_arguments('24')).last).to include('status' => 'ask',
                                                               'asks' => [include('reason' => 'no_origin')])
    end
  end

  describe 'its arguments' do
    it 'fails as a tool on a value that is not valid, before calling gh' do
      [[check_arguments(push_remote: '-x'), 'invalid remote', false],
       [check_arguments(pr_target: 'sgbett'), 'invalid repository', false],
       [check_arguments(extra: ['--accept-local-branch', 'abc1234']), 'invalid commit_sha', true],
       [check_arguments(extra: ['--accept-scripts', 'not-a-digest']), 'invalid scripts_digest', true]]
        .each do |arguments, error, branches_checked|
          expect_check(through: :arguments) if branches_checked

          expect { run_check(arguments) }.to raise_error(SkillSupport::InvalidIdentifier, error), error
        end
      expect(fake_runner.calls.map { |call| call[:argv].first(2) }.uniq).to eq([%w[git check-ref-format]])
    end

    it 'fails as a tool on a flag that is missing, unknown, repeated or without its value, calling nothing' do
      [check_arguments[0..-3], check_arguments(extra: ['--force', 'yes']), check_arguments(extra: ['--base', 'main']),
       check_arguments(extra: ['--accept-scripts']), ['--push-remote', 'origin']].each do |arguments|
        expect { run_check(arguments) }.to raise_error(Do::UsageError), arguments.inspect
      end
      expect(fake_runner.calls).to be_empty
    end
  end
end
