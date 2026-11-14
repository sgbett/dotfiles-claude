# frozen_string_literal: true

require_relative '../../lib/copilot_check/promote_check'

module CopilotCheck
  module Testing
    # The calls `promote-check check` makes, in order, and their answers.
    # The defaults pass every condition, on sgbett/dotfiles-claude#18 as
    # recorded where it can (Copilot's reviews and the files), as a draft
    # otherwise; a spec overrides only what its case changes:
    #
    #   expect_gate(checks: { entries: [check_entry('lint', 'pending')] })
    module GateCalls
      HERE = 'sgbett/dotfiles-claude'
      NUMBER = 18
      # #18's head, the commit Copilot's latest recorded review is of.
      HEAD = '0203427ffa8add0c145fa78cdc2415511ffbdaa1'
      OTHER_COMMIT = '56b92d3c76c8d5f09feb05ca05af160e8838d8cf'
      # The two recorded Copilot reviews of #18, which no comment marks
      # answered and in which the run found no finding.
      REVIEWS = [5_881_418_347, 5_881_467_821].freeze
      COPILOT = 'BOT_kgDOCnlnWA'
      GRAPHQL = %w[gh api graphql --hostname github.com --input -].freeze
      REPO_VIEW = %w[gh repo view --json nameWithOwner,url].freeze
      LOCAL_HEAD = %w[git rev-parse --verify HEAD].freeze
      CHECKS = ['gh', 'pr', 'checks', NUMBER.to_s, '-R', "github.com/#{HERE}", '--json', 'name,bucket,link'].freeze
      JOB_LINK = "https://github.com/#{HERE}/actions/runs/7/job/%<job>d".freeze
      STEPS = %i[repository pull_request threads local_head files checks mergeable].freeze

      def graphql_request(query, variables)
        JSON.generate('query' => query, 'variables' => variables)
      end

      def as_json(response)
        response.is_a?(String) ? response : JSON.generate(response)
      end

      # A pull request query answer: an open draft that passes, with
      # +fields+ changed.
      def pull_request_response(viewer: 'sgbett', **fields)
        node = { 'state' => 'OPEN', 'isDraft' => true, 'isCrossRepository' => false, 'headRefOid' => HEAD,
                 'mergeable' => 'MERGEABLE', 'changedFiles' => 2, 'author' => { 'login' => 'sgbett' },
                 'autoMergeRequest' => nil }.merge(fields)
        { 'data' => { 'viewer' => { 'login' => viewer }, 'repository' => { 'pullRequest' => node } } }
      end

      # A recorded thread fetch, parsed for a spec to change.
      def threads_response(name = 'threads-18')
        JSON.parse(fixture("graphql/#{name}.json"))
      end

      def threads_pull_request(response)
        response.dig('data', 'repository', 'pullRequest')
      end

      def check_entry(name, bucket, link = format(JOB_LINK, job: 11))
        { 'bucket' => bucket, 'link' => link, 'name' => name }
      end

      def annotations_call(job, page: 1)
        ['gh', 'api', '--hostname', 'github.com', '-X', 'GET', "repos/#{HERE}/check-runs/#{job}/annotations", '-f',
         'per_page=100', '-f', "page=#{page}"]
      end

      def files_call(page: 1)
        ['gh', 'api', '--hostname', 'github.com', '-X', 'GET', "repos/#{HERE}/pulls/#{NUMBER}/files", '-f',
         'per_page=100', '-f', "page=#{page}"]
      end

      # Expects every step's calls up to and including +through+; +steps+
      # holds each step's overrides by name.
      def expect_gate(through: :mergeable, **steps)
        STEPS.take(STEPS.index(through) + 1).each { |step| send(:"expect_#{step}_step", **steps.fetch(step, {})) }
      end

      def expect_repository_step(stdout: fixture('repo-view/checkout.json'), **result)
        fake_runner.expect_call(REPO_VIEW, stdout: stdout, **result)
      end

      def expect_pull_request_step(response: pull_request_response, **result)
        fake_runner.expect_call(GRAPHQL, stdin: graphql_request(CopilotCheck::PullRequestQuery::QUERY,
                                                                CopilotCheck::PullRequestQuery.variables(HERE, NUMBER)),
                                         stdout: as_json(response), **result)
      end

      def expect_threads_step(response: threads_response, **result)
        fake_runner.expect_call(GRAPHQL, stdin: graphql_request(CopilotCheck::Threads::QUERY,
                                                                CopilotCheck::Threads.variables(HERE, NUMBER)),
                                         stdout: as_json(response), **result)
      end

      def expect_local_head_step(sha: HEAD)
        fake_runner.expect_call(LOCAL_HEAD, stdout: "#{sha}\n")
      end

      # +pages+ are the files list's pages, each a recorded answer or a list.
      def expect_files_step(pages: [fixture('rest/files-18.json')])
        pages.each.with_index(1) do |page, number|
          fake_runner.expect_call(files_call(page: number), stdout: as_json(page))
        end
      end

      # +entries+ are what gh pr checks lists, nil when no check has run;
      # +annotations+ each failed check's job id and its annotation texts,
      # for those whose annotations are read.
      def expect_checks_step(entries: [check_entry('test', 'pass')], annotations: {})
        if entries
          fake_runner.expect_call(CHECKS, stdout: as_json(entries))
        else
          fake_runner.expect_call(CHECKS, exit_status: 1, stderr: fixture('pr-checks/no-checks-18.stderr'))
        end
        annotations.each do |job, texts|
          fake_runner.expect_call(annotations_call(job), stdout: as_json(texts.map { |text| annotation(text) }))
        end
      end

      # +reread+ is the pull request query's answer when mergeable was
      # UNKNOWN and is read again; nil when it isn't.
      def expect_mergeable_step(reread: nil)
        expect_pull_request_step(response: reread) if reread
      end

      def annotation(message)
        { 'path' => '.github', 'start_line' => 1, 'end_line' => 1, 'annotation_level' => 'failure', 'title' => '',
          'message' => message, 'raw_details' => '' }
      end

      # The rules file, as the lead writes it: the rules say PRs open as
      # drafts and merging is the owner's, unless +rules+ say otherwise.
      def rules_file(**rules)
        rules = { draft_flow: true, merge_is_owners_step: true, expected_failures: [] }.merge(rules)
        sandbox.path('promotion-rules.json').tap { |path| File.write(path, JSON.generate(rules)) }
      end

      # Phase 0's pr0.json for #18, a draft when the run began unless
      # +draft+ is false.
      def start_file(draft: true, number: NUMBER)
        state = { 'baseRefName' => 'master', 'isCrossRepository' => false, 'isDraft' => draft, 'number' => number }
        sandbox.path('pr0.json').tap { |path| File.write(path, JSON.generate(state)) }
      end

      def gate_arguments(outcome: 'converged', reviews: REVIEWS, rules: rules_file, start: start_file)
        ['check', '--pr', NUMBER.to_s, '--rules-file', rules, '--start-file', start, '--outcome', outcome,
         *(['--reviews-without-findings', reviews.join(',')] unless reviews.empty?)]
      end

      # Runs `promote-check` on +arguments+ in process, returning the exit
      # code and the output as parsed JSON.
      def run_promote_check(arguments)
        outcome = CopilotCheck::PromoteCheck.call(arguments, runner: fake_runner)
        [outcome.exit_code, JSON.parse(outcome.to_json)]
      end
    end
  end
end
