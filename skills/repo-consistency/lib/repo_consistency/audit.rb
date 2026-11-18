# frozen_string_literal: true

require_relative 'audit_arguments'
require_relative 'drift'
require_relative 'reasons'
require_relative 'report'
require_relative 'repository_projection'
require_relative 'repository_reader'
require_relative 'template'

module RepoConsistency
  # skills/repo-consistency/bin/git-settings audit: reports, for each
  # repository named, how its live git settings and vendored files differ
  # from the profile's template (profiles/git-workflow), writing nothing
  # anywhere. It stops before reading any repository when no repository is
  # named, the template can't be read or gh has no account on the host, and
  # on the first repository gh can't read.
  class Audit
    def self.call(arguments, runner: SkillSupport::CommandRunner.new)
      new(AuditArguments.parse(arguments), runner: runner).call
    end

    # +options+ are AuditArguments' Options.
    def initialize(options, runner:)
      @options = options
      @runner = runner
    end

    def call
      return Reasons.stop(Reasons::NO_REPOSITORIES) if @options.repositories.empty?

      audit(Template.load(@options.template_dir).projection)
    rescue TemplateUnreadable => e
      Reasons.stop(Reasons::TEMPLATE_UNREADABLE, file: e.file)
    rescue RepositoryUnreadable => e
      Reasons.stop(Reasons::REPOSITORY_UNREADABLE, repository: e.repository)
    end

    private

    # The login is checked once, before any repository: no account on the
    # host is one stop, not one error per repository.
    def audit(expected)
      return Reasons.stop(Reasons::NOT_LOGGED_IN, host: github.host) unless github.logged_in?

      report(expected).outcome
    end

    def report(expected)
      @options.repositories.each_with_object(Report.new) do |repository, report|
        state = RepositoryReader.read(github, repository, flags: expected.flags.keys)
        actual = RepositoryProjection.call(state)
        report.add(repository, actual, Drift.lines(expected, actual))
      end
    end

    def github
      @github ||= SkillSupport::Gh.new(host: @options.hostname, runner: @runner)
    end
  end
end
