# frozen_string_literal: true

module SkillSupport
  module Testing
    # What a committed fixture must never contain: a repository outside the
    # public allowlist, a machine-local path, or something shaped like a
    # token. It looks for the forms in which gh output and recording commands
    # name a repository; recording only from public repositories
    # (spec/fixtures/README.md) is the first line of defence.
    module FixturePolicy
      PUBLIC_REPOSITORIES = %w[
        sgbett/dotfiles-claude
        sgbett/bsv-ruby-sdk
        sgbett/ruleset-scratch
        bettison-org/ai-software-architect
        codenamev/ai-software-architect
        twbs/bootstrap
      ].freeze
      SYNTHETIC_OWNER = /\Aexample(?:-[a-z0-9]+)+\z/i
      OWNER = /[A-Za-z0-9][A-Za-z0-9_-]*/
      NAME = /[A-Za-z0-9._-]+/
      # First path segments on github.com that name a GitHub feature, not an owner.
      NON_OWNERS = %w[
        apps enterprises features login marketplace notifications organizations orgs search settings sponsors
        topics users
      ].freeze
      REPOSITORY_REFERENCES = [
        %r{(?<![\w.-])github\.com[/:](?<owner>#{OWNER})/(?<name>#{NAME})},
        %r{api\.github\.com/repos/(?<owner>#{OWNER})/(?<name>#{NAME})},
        %r{raw\.githubusercontent\.com/(?<owner>#{OWNER})/(?<name>#{NAME})},
        %r{(?<![\w./-])repos/(?<owner>#{OWNER})/(?<name>#{NAME})},
        %r{"(?:nameWithOwner|full_name)"\s*:\s*"(?<owner>#{OWNER})/(?<name>#{NAME})"},
        /"owner"\s*:\s*"(?<owner>#{OWNER})"\s*,\s*"name"\s*:\s*"(?<name>#{NAME})"/,
        %r{(?<![\w./@-])(?<owner>#{OWNER})/(?<name>#{NAME})#\d}
      ].freeze
      MACHINE_LOCAL_PATH = %r{/Users/|/home/|/private/(?:tmp|var)\b|/var/folders/|/tmp/}
      TOKEN = /(?:gh[pousr]_|github_pat_|sk-ant-)[A-Za-z0-9]/

      module_function

      # Each violation in +text+, as "line N: what". A token is reported by its
      # prefix alone, so the report never repeats it.
      def violations(text)
        text.each_line.with_index(1).flat_map do |line, number|
          line_violations(line).map { |violation| "line #{number}: #{violation}" }
        end
      end

      def line_violations(line)
        repositories(line).reject { |repository| allowed?(repository) }
                          .map { |repository| "repository #{repository} is not on the public allowlist" } +
          line.scan(MACHINE_LOCAL_PATH).map { |path| "machine-local path #{path}" } +
          line.scan(TOKEN).map { |token| "token-like string #{token.chop}..." }
      end

      def repositories(line)
        REPOSITORY_REFERENCES.flat_map do |pattern|
          line.to_enum(:scan, pattern).filter_map { repository(Regexp.last_match) }
        end.uniq
      end

      def repository(match)
        return if NON_OWNERS.include?(match[:owner].downcase)

        "#{match[:owner]}/#{match[:name].delete_suffix('.git').sub(/\.+\z/, '')}"
      end

      def allowed?(repository)
        PUBLIC_REPOSITORIES.any? { |public| public.casecmp?(repository) } ||
          SYNTHETIC_OWNER.match?(repository.split('/').first)
      end

      private_class_method :line_violations, :repositories, :repository, :allowed?
    end
  end
end
