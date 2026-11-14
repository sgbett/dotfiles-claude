# frozen_string_literal: true

module Do
  # Pre-flight step 3's default branch, feat/<N>-<slug>, with the slug made
  # from the issue title: lower-cased, each run of characters outside
  # [a-z0-9] turned into one "-", trimmed, at most six words, and "issue"
  # if nothing is left.
  module Slug
    MAX_WORDS = 6
    FALLBACK = 'issue'

    module_function

    def from_title(title)
      words = title.to_s.downcase.gsub(/[^a-z0-9]+/, '-').split('-').reject(&:empty?)
      words.empty? ? FALLBACK : words.first(MAX_WORDS).join('-')
    end

    # Every default branch for issue +number+ starts with this.
    def branch_prefix(number)
      "feat/#{number}-"
    end

    # Checked with git check-ref-format --branch through +runner+.
    def default_branch(number, title, runner:)
      SkillSupport::Identifiers.branch!("#{branch_prefix(number)}#{from_title(title)}", runner: runner)
    end
  end
end
