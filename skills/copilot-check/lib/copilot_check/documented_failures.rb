# frozen_string_literal: true

require_relative 'rest_list'

module CopilotCheck
  # Whether a failed check is one the repository's rules document as failing
  # by design, such as a required aggregate that stays red on every draft:
  # its name must match an expected failure's, and its failure annotations,
  # bar one runner exit-code line, must be at least one and each carry a
  # text the rules give for that check, and its job must have exactly one
  # failed step, so that a real failure beside the documented one isn't
  # passed. An exit-code line in the rules documents nothing. The
  # annotations and steps are read only through a GitHub Actions job link
  # in this repository, whose last number is the job's id, which is its
  # check run's; their text is data, compared and never printed.
  class DocumentedFailures
    # An annotations list longer than this is read no further, and leaves
    # the failure undocumented, as an annotation past it could be any.
    MAX_PAGES = 10
    # The levels that don't fail a check; any other counts as a failure.
    NOT_FAILURES = %w[notice warning].freeze
    # The runner adds this line to every failed run: step, so a check that
    # fails by design carries it beside its own text, and the rules needn't
    # quote it. A second copy means a second step failed, so only one is set
    # aside, and the line never documents anything, even where the rules
    # quote it, or quoting it would pass that second step. Its count doesn't
    # stand in for the failed steps', which are read from the job too.
    # Windows exit codes are negative.
    EXIT_CODE_LINE = /\AProcess completed with exit code -?[0-9]+\.\z/
    FAILED_STEP = 'failure'

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
      texts = @expected.select { |failure| failure.name == check.name }.map(&:text).grep_v(EXIT_CODE_LINE)
      job = @job_link.match(check.link.to_s)&.[](1)
      !texts.empty? && !job.nil? && every_failure_documented?(job, texts) && one_failed_step?(job)
    end

    private

    # Whether check run +job+'s failure annotations, all of them read and one
    # runner exit-code line set aside, are at least one and each carries one
    # of +texts+, which hold no exit-code line.
    def every_failure_documented?(job, texts)
      messages = failure_messages(job)
      return false if messages.nil?

      messages = without_one_exit_code_line(messages)
      !messages.empty? && messages.all? { |message| texts.include?(message) }
    end

    def without_one_exit_code_line(messages)
      index = messages.index { |message| EXIT_CODE_LINE.match?(message) }
      index ? messages.reject.with_index { |_, position| position == index } : messages
    end

    # Whether job +job+ has exactly one failed step, the one the documented
    # text is taken to come from. The exit-code lines can't tell: the runner
    # caps a step's annotations at 10 of each type and a job's at 50, so a
    # failed step's line can go missing.
    # Warning: annotations name no step, so a step that adds the documented
    # text and succeeds, beside another that fails, still passes. That takes
    # a base-branch workflow built so, as a pull request changing one is
    # held for its protected paths.
    def one_failed_step?(job)
      answer = @github.api("repos/#{@repository}/actions/jobs/#{job}")
      steps = answer['steps'] if answer.is_a?(Hash) && answer['id'].to_s == job
      unless steps.is_a?(Array) && steps.all?(Hash)
        raise SkillSupport::UnexpectedResponse, "job #{job} came back without its steps"
      end

      steps.one? { |step| step['conclusion'] == FAILED_STEP }
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
