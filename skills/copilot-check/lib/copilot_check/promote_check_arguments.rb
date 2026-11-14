# frozen_string_literal: true

require_relative 'arguments'
require_relative 'usage_error'

module CopilotCheck
  # The arguments of promote-check, every one validated before anything else
  # runs: the subcommand, then its flags, each with its value, in any order.
  module PromoteCheckArguments
    SUBCOMMANDS = {
      'check' => { required: %w[--pr --rules-file --start-file --outcome], optional: %w[--reviews-without-findings] },
      'verify' => { required: %w[--pr --head] }
    }.freeze
    OUTCOMES = %w[converged halted timeout stop push-failed].freeze
    REVIEW_ID = /\A[1-9][0-9]{0,19}\z/
    LIST_SEPARATOR = ','

    Options = Struct.new(:command, :pr, :rules_file, :start_file, :outcome, :reviews_without_findings, :head,
                         keyword_init: true)

    module_function

    # The Options in +arguments+. Raises UsageError for an unknown
    # subcommand, or a flag it doesn't take, repeats or lacks, and
    # InvalidIdentifier for a value that isn't valid.
    def parse(arguments)
      command, values, = Arguments.parse(arguments, SUBCOMMANDS, error: UsageError)
      Options.new(command: command, reviews_without_findings: [],
                  **values.to_h { |flag, value| [Arguments.option(flag), convert(flag, value)] })
    end

    def convert(flag, value)
      case flag
      when '--pr' then SkillSupport::Identifiers.issue_number!(value)
      when '--rules-file', '--start-file' then SkillSupport::WrittenFile.path!(Arguments.option(flag), value)
      when '--outcome' then outcome!(value)
      when '--reviews-without-findings' then review_ids!(value)
      when '--head' then SkillSupport::Identifiers.commit_sha!(value)
      end
    end

    def outcome!(value)
      raise SkillSupport::InvalidIdentifier.new(:outcome, value) unless OUTCOMES.include?(value)

      value
    end

    def review_ids!(value)
      ids = value.split(LIST_SEPARATOR, -1)
      raise SkillSupport::InvalidIdentifier.new(:review_ids, value) if ids.empty? || !ids.all?(REVIEW_ID)

      ids.map { |id| Integer(id, 10) }.uniq
    end

    private_class_method :convert, :outcome!, :review_ids!
  end
end
