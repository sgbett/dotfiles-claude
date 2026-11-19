# frozen_string_literal: true

require_relative 'user_skills'

module RepoConsistency
  # Which of UserSkills' names a text invokes, case-sensitively. Every name
  # counts written as a command, /name; a hyphenated one counts bare too, as
  # in "run specialist-review", but a single word never does, since "do" is
  # prose. Neither form counts inside a path, a URL, an anchor, a file name
  # or a longer word in any script, so skills/do/, ~/.claude/skills/do,
  # https://x/do, x:/do, adr.md#create-adr, /docs, /doé, /do-thing,
  # create-adr.md and create-adr-template name nothing.
  module SkillMentions
    BEFORE = '(?<![\p{Word}./~#:-])'
    AFTER = '(?![\p{Word}/-]|\.\p{Word})'
    PATTERNS = UserSkills::NAMES.to_h do |name|
      quoted = Regexp.escape(name)
      slash = name.include?('-') ? '/?' : '/'
      [name, Regexp.new("#{BEFORE}#{slash}#{quoted}#{AFTER}")]
    end.freeze

    module_function

    # The names +text+ invokes, sorted. +text+ is a file's text, nil for
    # none; bytes that aren't UTF-8 can't be part of a name.
    def names_in(text)
      words = text.to_s.scrub
      PATTERNS.filter_map { |name, pattern| name if pattern.match?(words) }.sort
    end
  end
end
