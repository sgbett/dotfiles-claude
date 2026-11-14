# frozen_string_literal: true

require 'json'

module CopilotCheck
  # The repository whose pull request the run is on: what `gh repo view`
  # resolves from the checkout's remotes in the working directory, as Phase
  # 0 found the pull request. Every later call names it, with its host.
  module CheckoutRepository
    ARGUMENTS = %w[repo view --json nameWithOwner,url].freeze
    URL = %r{\Ahttps://(?<host>[^/]+)/(?<path>[^/]+/[^/]+)\z}

    Repository = Struct.new(:host, :name_with_owner, keyword_init: true) do
      # The repository as gh's -R takes it, host included.
      def argument
        "#{host}/#{name_with_owner}"
      end
    end

    module_function

    # Raises GhError when gh can't resolve one, and UnexpectedResponse when
    # its URL isn't the https URL of the repository it names.
    def resolve(runner)
      result = runner.run(['gh', *ARGUMENTS])
      raise SkillSupport::GhError.new(ARGUMENTS, result) unless result.success?

      repository(parse(result.stdout))
    end

    def parse(output)
      view = JSON.parse(output)
      raise SkillSupport::UnexpectedResponse, 'gh repo view printed no repository' unless view.is_a?(Hash)

      view
    rescue JSON::ParserError
      raise SkillSupport::UnexpectedResponse, 'gh repo view printed something other than JSON'
    end

    def repository(view)
      name = SkillSupport::Identifiers.repository!(view['nameWithOwner'])
      match = URL.match(view['url'].to_s)
      unless match && match[:path].casecmp?(name)
        raise SkillSupport::UnexpectedResponse, "gh repo view's URL isn't the repository it names"
      end

      Repository.new(host: SkillSupport::Identifiers.host!(match[:host]), name_with_owner: name)
    end

    private_class_method :parse, :repository
  end
end
