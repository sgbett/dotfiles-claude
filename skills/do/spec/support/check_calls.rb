# frozen_string_literal: true

require_relative '../../lib/do/check'
require_relative 'check_branch_calls'
require_relative 'check_finish_calls'
require_relative 'check_responses'

module Do
  module Testing
    # The calls `preflight check` makes, step by step, expected on the fake
    # runner. Each step has defaults recorded from sgbett/dotfiles-claude#24
    # (a new branch, nothing open on it, no security focus, a clean working
    # tree, scripts outside any checkout), and a spec overrides only what its
    # case changes:
    #
    #   expect_check(through: :base, base: { response: fixture('graphql/base-missing.json') })
    module CheckCalls
      include CheckResponses
      include CheckBranchCalls
      include CheckFinishCalls

      STEPS = %i[arguments login issue remote base branch pull_requests scripts focus changes].freeze
      CONVENTIONS = { push_remote: 'origin', pr_target: HERE, base: 'master', branch: BRANCH }.freeze

      # check's arguments for the issue +reference+, with the CONVENTIONS
      # given or their defaults, then +extra+.
      def check_arguments(reference = "#{HERE}#24", extra: [], **conventions)
        flags = CONVENTIONS.merge(conventions).flat_map { |name, value| ["--#{name.to_s.tr('_', '-')}", value] }
        [reference, *flags, *extra]
      end

      # Runs Do::Check on +arguments+, returning the exit code and the output
      # as parsed JSON.
      def run_check(arguments = check_arguments, skill_directory: scripts_skill_directory)
        outcome = Do::Check.new(arguments, runner: fake_runner, skill_directory: skill_directory).call
        [outcome.exit_code, JSON.parse(outcome.to_json)]
      end

      # Expects every step's calls up to and including +through+; +steps+
      # holds each step's overrides by name. The branch is read through the
      # push URLs the remote step gives, unless it says otherwise.
      def expect_check(through: :changes, **steps)
        urls = steps.dig(:remote, :urls)
        steps[:branch] = { urls: urls, **steps.fetch(:branch, {}) } if urls
        STEPS.take(STEPS.index(through) + 1).each { |step| send(:"expect_#{step}_step", **steps.fetch(step, {})) }
      end

      def expect_arguments_step(base: 'master', branch: BRANCH)
        [base, branch].each do |name|
          fake_runner.expect_call(['git', 'check-ref-format', '--branch', name], stdout: "#{name}\n")
        end
      end

      def expect_login_step(host: 'github.com', logged_in: true)
        expect_gh_login(host, logged_in: logged_in)
      end

      def expect_issue_step(response: fixture('graphql/check-issue-24.json'), repository: HERE, number: 24, **result)
        fake_runner.expect_call(GRAPHQL, stdin: graphql_request(Do::CheckQuery::ISSUE_QUERY,
                                                                Do::CheckQuery.issue_variables(repository, number)),
                                         stdout: as_json(response), **result)
      end

      # +views+ maps each URL to gh's answer, a String or a Hash of result
      # fields; a URL it leaves out isn't expected to reach gh.
      def expect_remote_step(remotes: ['origin'], remote: 'origin', urls: [ORIGIN_URL], views: nil)
        fake_runner.expect_call(%w[git remote], stdout: lines(remotes))
        return unless remotes.include?(remote)

        fake_runner.expect_call(['git', 'remote', 'get-url', '--push', '--all', remote],
                                stdout: lines(urls), exit_status: urls.empty? ? 2 : 0)
        (views || urls.to_h { |url| [url, fixture('repo-view/push-origin.json')] }).each do |url, view|
          fake_runner.expect_call(['gh', 'repo', 'view', url, '--json', 'nameWithOwner,parent,viewerPermission'],
                                  **(view.is_a?(Hash) ? view : { stdout: view }))
        end
      end

      def expect_base_step(response: fixture('graphql/base-master.json'), base: 'master', repository: HERE)
        fake_runner.expect_call(GRAPHQL, stdin: graphql_request(Do::CheckQuery::BASE_QUERY,
                                                                Do::CheckQuery.base_variables(repository, base)),
                                         stdout: as_json(response))
      end

      # +nodes+ are pull request nodes, which pull_request_node builds, or
      # +response+ a whole answer.
      def expect_pull_requests_step(nodes: nil, response: nil, branch: BRANCH, repository: HERE)
        response ||= nodes ? pull_requests_response(nodes) : fixture('graphql/pull-requests-24.json')
        variables = Do::CheckQuery.pull_request_variables(repository, branch)
        fake_runner.expect_call(GRAPHQL, stdin: graphql_request(Do::CheckQuery::PULL_REQUESTS_QUERY, variables),
                                         stdout: as_json(response))
      end

      def git_calls
        fake_runner.calls.map { |call| call[:argv] }.select { |argv| argv.first == 'git' }
      end
    end
  end
end
