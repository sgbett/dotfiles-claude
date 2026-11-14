# frozen_string_literal: true

require_relative 'scripts_checkout'
require_relative 'usage_error'

module Do
  # The arguments of `preflight check`, every one validated before anything
  # else runs: the issue as the user gave it (IssueLocator's to judge), then
  # the conventions the lead resolved and any yes, each as a flag and value.
  module CheckArguments
    FLAGS = {
      '--push-remote' => :push_remote, '--pr-target' => :pr_target, '--base' => :base, '--branch' => :branch,
      '--accept-local-branch' => :accept_local_branch, '--accept-scripts' => :accept_scripts
    }.freeze
    REQUIRED = %i[push_remote pr_target base branch].freeze

    Options = Struct.new(:reference, *FLAGS.values, keyword_init: true)

    module_function

    # The Options in +arguments+. Raises UsageError for an unknown, repeated
    # or missing flag, and InvalidIdentifier for a value that isn't valid;
    # whether the push remote exists is the remote check's to say.
    def parse(arguments, runner:)
      reference, *flags = arguments
      values = values(flags)
      raise UsageError unless reference && (REQUIRED - values.keys).empty?

      Options.new(reference: reference, **conventions(values, runner), **answers(values))
    end

    def values(flags)
      raise UsageError if flags.length.odd?

      flags.each_slice(2).with_object({}) do |(flag, value), values|
        key = FLAGS[flag]
        raise UsageError if key.nil? || values.key?(key)

        values[key] = value
      end
    end

    def conventions(values, runner)
      { push_remote: SkillSupport::Identifiers.remote!(values[:push_remote]),
        pr_target: SkillSupport::Identifiers.repository!(values[:pr_target]),
        base: SkillSupport::Identifiers.branch!(values[:base], runner: runner),
        branch: SkillSupport::Identifiers.branch!(values[:branch], runner: runner) }
    end

    # The yeses given, each tied to the state it answered.
    def answers(values)
      { accept_local_branch: values[:accept_local_branch]&.then { |sha| SkillSupport::Identifiers.commit_sha!(sha) },
        accept_scripts: values[:accept_scripts]&.then { |digest| ScriptsCheckout.token!(digest) } }
    end

    private_class_method :values, :conventions, :answers
  end
end
