# frozen_string_literal: true

module Do
  # Branch names GitHub gives `preflight facts`: the lead may take one as a
  # base or branch only if every script would take it as an argument, which
  # SkillSupport::Identifiers::BRANCH_CHARACTERS decides. facts reports the
  # rest under session_only, never as a suggestion.
  module BranchNames
    module_function

    def usable?(name)
      SkillSupport::Identifiers::BRANCH_CHARACTERS.match?(name)
    end

    def usable(names)
      names.select { |name| usable?(name) }
    end

    # The names among +names+, nil for none, that aren't usable.
    def unusable(names)
      names.compact.reject { |name| usable?(name) }
    end
  end
end
