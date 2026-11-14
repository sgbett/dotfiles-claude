# frozen_string_literal: true

module CopilotCheck
  # A paginated REST list, read a full page at a time by page number.
  module RestList
    PER_PAGE = 100

    module_function

    # The entries of the list at +path+, at most +max_pages+ pages of them,
    # and whether that was all: false when every page read was full.
    def read(github, path, max_pages:)
      entries = []
      (1..max_pages).each do |page|
        batch = github.api(path, fields: { 'per_page' => PER_PAGE.to_s, 'page' => page.to_s })
        raise SkillSupport::UnexpectedResponse, "#{path} returned something other than a list" unless batch.is_a?(Array)

        entries.concat(batch)
        return [entries, true] if batch.length < PER_PAGE
      end
      [entries, false]
    end
  end
end
