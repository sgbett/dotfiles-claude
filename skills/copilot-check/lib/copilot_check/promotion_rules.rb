# frozen_string_literal: true

require 'json'

module CopilotCheck
  # The rules file isn't one promote-check can take.
  class UnusableRulesFile < SkillSupport::UnusableFile; end

  # What the repository's rules, read from the base branch, say about
  # marking a draft ready. Reading them is judgement, so the lead writes this
  # JSON with the Write tool:
  #
  #   {"draft_flow": true, "merge_is_owners_step": true,
  #    "expected_failures": [{"name": "<check>", "text": "<annotation text>"}]}
  #
  # +draft_flow+: pull requests open as drafts; +merge_is_owners_step+:
  # merging is a later step the owner takes; +expected_failures+: each check
  # the rules document as failing by design, by its name and its
  # annotation's text, which is data and never printed. Every key is
  # required, and no other is taken, so a misspelt one can't pass for false.
  class PromotionRules
    KEYS = %w[draft_flow merge_is_owners_step expected_failures].freeze
    FAILURE_KEYS = %w[name text].freeze

    ExpectedFailure = Struct.new(:name, :text, keyword_init: true)

    attr_reader :expected_failures

    # The rules in the file at +path+. Raises UnusableRulesFile for one that
    # isn't a regular file holding that JSON.
    def self.read(path)
      text = SkillSupport::WrittenFile.read(path, error: UnusableRulesFile)
      new(JSON.parse(text))
    rescue JSON::ParserError
      raise UnusableRulesFile, "#{path} isn't JSON"
    end

    def initialize(rules)
      unless rules.is_a?(Hash) && rules.keys.sort == KEYS.sort
        fail_with('is a JSON object with exactly the keys draft_flow, merge_is_owners_step and expected_failures')
      end

      @draft_flow = boolean(rules, 'draft_flow')
      @merge_is_owners_step = boolean(rules, 'merge_is_owners_step')
      @expected_failures = failures(rules['expected_failures'])
    end

    def draft_flow?
      @draft_flow
    end

    def merge_is_owners_step?
      @merge_is_owners_step
    end

    private

    def boolean(rules, key)
      fail_with("gives #{key} as true or false") unless [true, false].include?(rules[key])

      rules[key]
    end

    def failures(entries)
      fail_with('gives expected_failures as a list') unless entries.is_a?(Array)

      entries.map do |entry|
        unless entry.is_a?(Hash) && entry.keys.sort == FAILURE_KEYS && entry.values.all? { |value| text?(value) }
          fail_with('gives each expected failure as an object with exactly a non-empty name and text')
        end

        ExpectedFailure.new(name: entry['name'], text: entry['text'].strip)
      end
    end

    def text?(value)
      value.is_a?(String) && !value.strip.empty?
    end

    def fail_with(requirement)
      raise UnusableRulesFile, "the rules file #{requirement}"
    end
  end
end
