# frozen_string_literal: true

module Do
  # Whether a repository asks for Copilot's review of pull requests into a
  # base branch: a ruleset's copilot_code_review rule applies to the branch,
  # whether the repository, its organisation or its enterprise set it, and
  # .github/copilot-instructions.md is on the base. Either alone is half a
  # signal, which is no signal.
  class CopilotSignal
    RULE_TYPE = 'copilot_code_review'
    INSTRUCTIONS = '.github/copilot-instructions.md'
    # The most rules a page asks for; a page that comes back full may go on
    # to another.
    PAGE_SIZE = 100

    Result = Struct.new(:ruleset, :instructions, keyword_init: true) do
      def signal?
        ruleset && instructions
      end

      def to_h
        { ruleset: ruleset, instructions: instructions, signal: signal? }
      end
    end

    # +github+ is the SkillSupport::Gh to read through, which fixes the host.
    def initialize(github)
      @github = github
      @files = SkillSupport::RepositoryFiles.new(github)
    end

    # The Result for +repository+ ("owner/repo"), from the rules that apply
    # to +branch+ and the instructions as they stand at +ref+.
    def read(repository, branch:, ref:)
      Result.new(ruleset: ruleset?(repository, branch), instructions: instructions?(repository, ref))
    end

    private

    # Any failure raises, a 404 included: the owner's ordinary private
    # repositories answer 200 with no rules, and only a security advisory's
    # temporary fork, which /do can't target, answered 404.
    def ruleset?(repository, branch)
      rules = @github.api(rules_path(repository, branch), fields: { 'per_page' => PAGE_SIZE.to_s })
      unless rules.is_a?(Array) && rules.all?(Hash)
        raise SkillSupport::UnexpectedResponse, "the rules for #{branch} came back as something other than a list"
      end
      if rules.length >= PAGE_SIZE
        raise SkillSupport::IncompleteResults, "the rules for #{branch} may go on to another page"
      end

      rules.any? { |rule| rule['type'] == RULE_TYPE }
    end

    def rules_path(repository, branch)
      "repos/#{SkillSupport::Identifiers.repository!(repository)}/rules/branches/" \
        "#{SkillSupport::Gh.path_segment(branch)}"
    end

    def instructions?(repository, ref)
      content = @files.read(repository, INSTRUCTIONS, ref: ref)
      raise SkillSupport::UnexpectedResponse, "#{INSTRUCTIONS} is a directory, not a file" if content.is_a?(Array)

      !content.nil?
    end
  end
end
