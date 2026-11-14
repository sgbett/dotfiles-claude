# frozen_string_literal: true

module CopilotCheck
  # The checks on a pull request's head as `gh pr checks` lists them, each
  # judged by its bucket, never gh's exit code; and, for each failure,
  # whether the rules document it (DocumentedFailures).
  class Checks
    FIELDS = 'name,bucket,link'
    FAILED = 'fail'
    BUCKETS = ['pass', FAILED, 'pending', 'skipping', 'cancel'].freeze
    # With --json, gh exits 0 whatever the checks' state, and 1 with this on
    # stderr and nothing on stdout when no check has run on the head.
    NO_CHECKS = /\Ano checks reported on the /

    # +name+ is GitHub text; +link+ the check's details URL, possibly empty;
    # +documented+, for a failure only, whether the rules document it.
    Check = Struct.new(:name, :bucket, :link, :documented, keyword_init: true) do
      def failed?
        bucket == FAILED
      end
    end

    # +github+ is the SkillSupport::Gh for the repository's host;
    # +documented_failures+ a DocumentedFailures for the same repository.
    def initialize(github, documented_failures)
      @github = github
      @documented_failures = documented_failures
    end

    # Pull request +number+'s checks in +repository+ ("owner/repo"), empty
    # when none has run on its head.
    def list(repository, number)
      listed(repository, number).map do |entry|
        check = Check.new(name: entry['name'], bucket: entry['bucket'], link: entry['link'])
        check.documented = @documented_failures.documented?(check) if check.failed?
        check
      end
    end

    private

    def listed(repository, number)
      arguments = ['pr', 'checks', SkillSupport::Identifiers.issue_number!(number).to_s, '-R',
                   "#{@github.host}/#{SkillSupport::Identifiers.repository!(repository)}", '--json', FIELDS]
      checked(@github.json(arguments))
    rescue SkillSupport::GhError => e
      raise unless e.exit_status == 1 && e.stdout.strip.empty? && NO_CHECKS.match?(e.stderr)

      []
    end

    def checked(entries)
      return entries if entries.is_a?(Array) && entries.all? { |entry| entry?(entry) }

      raise SkillSupport::UnexpectedResponse, 'gh pr checks listed a check without its name or a known bucket'
    end

    def entry?(entry)
      entry.is_a?(Hash) && entry['name'].is_a?(String) && BUCKETS.include?(entry['bucket']) &&
        (entry['link'].nil? || entry['link'].is_a?(String))
    end
  end
end
