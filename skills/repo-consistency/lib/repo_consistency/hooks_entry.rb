# frozen_string_literal: true

require 'json'
require_relative 'vendored_paths'

module RepoConsistency
  # Whether a repository's .claude/settings.json runs the vendored
  # push-guard: some PreToolUse entry whose hooks include a command naming
  # .claude/hooks/push-guard. A subset check, since a collaborator's settings
  # may hold other hooks beside the template's entry.
  module HooksEntry
    MISSING = :missing
    UNREADABLE = :unreadable
    ABSENT = :absent
    PRESENT = :present
    HOOK = VendoredPaths::HOOK_FILES.first

    module_function

    # +text+ is the settings file, or nil when the repository has none.
    def of_text(text)
      text.nil? ? MISSING : of_settings(JSON.parse(text))
    rescue JSON::ParserError
      UNREADABLE
    end

    # +settings+ is the parsed settings file, or the template's hooks.json.
    def of_settings(settings)
      commands(settings).any? { |command| command.include?(HOOK) } ? PRESENT : ABSENT
    end

    def commands(settings)
      hooks = settings['hooks'] if settings.is_a?(Hash)
      entries = hooks['PreToolUse'] if hooks.is_a?(Hash)
      Array(entries).flat_map { |entry| entry.is_a?(Hash) ? Array(entry['hooks']) : [] }
                    .filter_map { |hook| hook['command'] if hook.is_a?(Hash) }
                    .grep(String)
    end

    private_class_method :commands
  end
end
