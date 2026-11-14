# frozen_string_literal: true

require_relative 'rest_list'

module CopilotCheck
  # Whether a failed check is one the repository's rules document as failing
  # by design, such as a required aggregate that stays red on every draft:
  # its name and the text of one of its annotations must both match one
  # expected failure. The annotations are read only through a GitHub Actions
  # job link in this repository, whose last number is the check run's id;
  # their text is data, compared and never printed.
  class DocumentedFailures
    # An annotations list longer than this is read no further, which can
    # only leave a failure undocumented.
    MAX_PAGES = 10

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
      return false if texts.empty? || job.nil?

      annotation_texts(job).any? { |text| texts.include?(text) }
    end

    private

    def annotation_texts(job)
      annotations, _whole = RestList.read(@github, "repos/#{@repository}/check-runs/#{job}/annotations",
                                          max_pages: MAX_PAGES)
      annotations.map { |annotation| annotation['message'] if annotation.is_a?(Hash) }.grep(String).map(&:strip)
    end
  end
end
