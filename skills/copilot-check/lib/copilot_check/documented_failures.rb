# frozen_string_literal: true

require_relative 'rest_list'

module CopilotCheck
  # Whether a failed check is one the repository's rules document as failing
  # by design, such as a required aggregate that stays red on every draft:
  # its name must match an expected failure's, and every one of its failure
  # annotations must carry a text the rules give for that check, so that a
  # real failure beside the documented one isn't passed. The annotations are
  # read only through a GitHub Actions job link in this repository, whose
  # last number is the check run's id; their text is data, compared and
  # never printed.
  class DocumentedFailures
    # An annotations list longer than this is read no further, and leaves
    # the failure undocumented, as an annotation past it could be any.
    MAX_PAGES = 10
    # The levels that don't fail a check; any other counts as a failure.
    NOT_FAILURES = %w[notice warning].freeze

    # +github+ is the SkillSupport::Gh for the repository's host;
    # +repository+ its "owner/repo"; +expected+ the PromotionRules'
    # expected failures.
    def initialize(github, repository, expected)
      @github = github
      @repository = SkillSupport::Identifiers.repository!(repository)
      @expected = expected
      @job_link = %r{\Ahttps://#{Regexp.escape(github.host)}/#{Regexp.escape(@repository)}/actions/runs/[0-9]+/job/([0-9]+)\z}
    end

    # +check+ is a failed Checks::Check.
    def documented?(check)
      texts = @expected.select { |failure| failure.name == check.name }.map(&:text)
      job = @job_link.match(check.link.to_s)&.[](1)
      !texts.empty? && !job.nil? && every_failure_documented?(job, texts)
    end

    private

    # Whether check run +job+ has failure annotations, all of them read, and
    # each carries one of +texts+.
    def every_failure_documented?(job, texts)
      messages = failure_messages(job)
      !messages.nil? && !messages.empty? && messages.all? { |message| texts.include?(message) }
    end

    # The text of each of the check run's failure annotations, nil for one
    # without, or nil for them all when the list may run past what was read.
    def failure_messages(job)
      annotations, whole = RestList.read(@github, "repos/#{@repository}/check-runs/#{job}/annotations",
                                         max_pages: MAX_PAGES)
      return unless whole

      annotations.reject { |annotation| not_failure?(annotation) }.map { |annotation| message(annotation) }
    end

    def not_failure?(annotation)
      annotation.is_a?(Hash) && NOT_FAILURES.include?(annotation['annotation_level'])
    end

    def message(annotation)
      text = annotation['message'] if annotation.is_a?(Hash)
      text.strip if text.is_a?(String)
    end
  end
end
