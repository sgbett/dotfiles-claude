# frozen_string_literal: true

module RepoConsistency
  # The one line of a repository's CLAUDE.md that states a difference from
  # its tier, `Git tier: <word>; <difference>`, as the profile's "Tier line"
  # rule gives it. The word is read only to check it against the tier the
  # rules file decides (Tier); collaborative, the retired name, is read so
  # that it can be reported.
  module TierLine
    WORDS = %w[protected personal collaborative].freeze
    # The literal anywhere in a line. A closing backtick ends the
    # difference, since a CLAUDE.md that scopes the line to one project
    # quotes it in code and goes on in prose.
    PATTERN = /Git tier: (?<word>#{WORDS.join('|')})(?:[ \t]*;(?<difference>[^`\n]*))?/

    # +word+ is nil when there is no line.
    Declaration = Struct.new(:word, :difference, keyword_init: true)

    module_function

    # The Declaration in +text+, CLAUDE.md or nil for a repository without
    # one: the first line that carries the literal.
    def read(text)
      match = PATTERN.match(text.to_s)
      match ? declaration(match) : Declaration.new(word: nil, difference: nil)
    end

    def declaration(match)
      difference = match[:difference].to_s.strip
      Declaration.new(word: match[:word], difference: difference.empty? ? nil : difference)
    end

    private_class_method :declaration
  end
end
