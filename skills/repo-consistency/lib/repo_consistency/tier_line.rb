# frozen_string_literal: true

module RepoConsistency
  # The one line of a repository's CLAUDE.md that declares its git tier,
  # `Git tier: collaborative` or `Git tier: personal`, with any difference
  # after a semicolon, as the profile's "Tier line" rule gives it.
  module TierLine
    COLLABORATIVE = 'collaborative'
    PERSONAL = 'personal'
    UNDECLARED = 'undeclared'
    # The literal anywhere in a line. A closing backtick ends the
    # difference, since a CLAUDE.md that scopes the line to one project
    # quotes it in code and goes on in prose.
    PATTERN = /Git tier: (?<tier>collaborative|personal)(?:[ \t]*;(?<difference>[^`\n]*))?/

    Declaration = Struct.new(:tier, :difference, keyword_init: true)

    module_function

    # The Declaration in +text+, CLAUDE.md or nil for a repository without
    # one: the first line that carries the literal, or undeclared.
    def read(text)
      match = PATTERN.match(text.to_s)
      match ? declaration(match) : Declaration.new(tier: UNDECLARED, difference: nil)
    end

    def declaration(match)
      difference = match[:difference].to_s.strip
      Declaration.new(tier: match[:tier], difference: difference.empty? ? nil : difference)
    end

    private_class_method :declaration
  end
end
