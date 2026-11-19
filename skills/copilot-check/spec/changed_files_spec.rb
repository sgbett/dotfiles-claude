# frozen_string_literal: true

require_relative 'support/gate_calls'

RSpec.describe CopilotCheck::ChangedFiles do
  include CopilotCheck::Testing::GateCalls

  subject(:files) { described_class.new(SkillSupport::Gh.new(host: 'github.com', runner: fake_runner)) }

  let(:here) { CopilotCheck::Testing::GateCalls::HERE }

  def entries(count, prefix: 'lib/file')
    Array.new(count) { |index| { 'filename' => "#{prefix}-#{index}.rb" } }
  end

  it 'lists #18 as recorded, all its files' do
    expect_files_step

    expect(files.list(here, 18, changed_files: 2).to_h)
      .to eq(paths: %w[profiles/work-organisation.md skills/do/SKILL.md], complete: true)
  end

  it "reads every page, and a renamed file's previous path" do
    renamed = { 'filename' => 'docs/rules.md', 'previous_filename' => '.claude/rules/x.md' }
    expect_files_step(pages: [entries(100), [renamed]])

    result = files.list(here, 18, changed_files: 101)

    expect([result.paths.length, result.complete, result.protected_paths]).to eq([102, true, ['.claude/rules/x.md']])
  end

  it "holds a rules file renamed into a .claude directory's plans through its previous path" do
    expect_files_step(pages: [[{ 'filename' => '.claude/plans/x.md', 'previous_filename' => '.claude/rules/x.md' }]])

    expect(files.list(here, 18, changed_files: 1).protected_paths).to eq(['.claude/rules/x.md'])
  end

  it 'calls the list incomplete when it holds fewer files than GitHub counts' do
    expect_files_step(pages: [entries(2)])

    expect(files.list(here, 18, changed_files: 3).complete).to be(false)
  end

  it 'stops at the 3,000 files GitHub lists, calling the list incomplete' do
    expect_files_step(pages: Array.new(30) { |page| entries(100, prefix: "page-#{page}") })

    expect(files.list(here, 18, changed_files: 3001).complete).to be(false)
  end

  it 'fails on a file without its path' do
    expect_files_step(pages: [[{ 'status' => 'modified' }]])

    expect { files.list(here, 18, changed_files: 1) }.to raise_error(SkillSupport::UnexpectedResponse)
  end

  it "fails on a path that isn't UTF-8, which it can't compare as a file system would open it" do
    expect_files_step(pages: [%([{"filename":"a\xFF.md"}])])

    expect { files.list(here, 18, changed_files: 1) }.to raise_error(SkillSupport::UnexpectedResponse)
  end

  describe '.protected?' do
    it 'holds workflows and actions, any CLAUDE.md, and anything else under a .claude directory, ignoring case' do
      %w[.github/workflows/ci.yml .github/actions/setup/action.yml CLAUDE.md docs/claude.md .claude/rules/a.md
         vendor/tool/.claude/skills/x/SKILL.md .GitHub/Workflows/ci.yml .Claude/settings.json].each do |path|
        expect(described_class.protected?(path)).to be(true), path
      end
    end

    it 'holds any CLAUDE.local.md and any .mcp.json, at any depth, ignoring case' do
      %w[CLAUDE.local.md docs/CLAUDE.local.md skills/x/claude.LOCAL.md .mcp.json tools/server/.mcp.json
         .MCP.JSON].each do |path|
        expect(described_class.protected?(path)).to be(true), path
      end
    end

    it "holds Copilot's rubric, where Copilot reads it, ignoring case" do
      %w[.github/copilot-instructions.md .GitHub/Copilot-Instructions.MD].each do |path|
        expect(described_class.protected?(path)).to be(true), path
      end
    end

    it "holds anything under .github/instructions/, where Copilot's path-specific instructions are, ignoring case" do
      %w[.github/instructions/ruby.instructions.md .github/instructions/backend/api.instructions.md
         .github/instructions/README.md .GitHub/Instructions/Ruby.Instructions.MD].each do |path|
        expect(described_class.protected?(path)).to be(true), path
      end
    end

    it "holds anything under .github/skills/, where Copilot's agent skills are, ignoring case" do
      %w[.github/skills/code-review/SKILL.md .github/skills/code-review/scripts/check.sh .github/skills/README.md
         .GitHub/Skills/Code-Review/SKILL.MD].each do |path|
        expect(described_class.protected?(path)).to be(true), path
      end
    end

    it "holds anything under .agents/skills/, where a project can also keep Copilot's agent skills, ignoring case" do
      %w[.agents/skills/x/SKILL.md .agents/skills/x/scripts/check.sh .Agents/Skills/X/SKILL.MD].each do |path|
        expect(described_class.protected?(path)).to be(true), path
      end
    end

    it 'holds any AGENTS.md, GEMINI.md and REVIEW.md, the other files Copilot takes instructions from, at any ' \
       'depth, ignoring case' do
      %w[AGENTS.md GEMINI.md REVIEW.md docs/AGENTS.md skills/x/gemini.md lib/a/b/Review.MD agents.md].each do |path|
        expect(described_class.protected?(path)).to be(true), path
      end
    end

    it "leaves a plan under a .claude directory's plans/ alone, at any depth, ignoring case, as Claude Code " \
       "doesn't load one" do
      %w[.claude/plans/a.md apps/x/.claude/plans/2026/a.md .Claude/Plans/a.md].each do |path|
        expect(described_class.protected?(path)).to be(false), path
      end
    end

    it "holds a path the plans exemption doesn't fit: plans itself, a look-alike, another .claude directory in " \
       'the path, or an empty, . or .. segment' do
      %w[.claude/plans .claude/plans/.claude/settings.json .claude/rules/.claude/plans/x.md .claude/plans-old/x.md
         .claude/plans/../rules/x.md .claude/plans/./x.md .claude/plans//x.md].each do |path|
        expect(described_class.protected?(path)).to be(true), path
      end
    end

    it "holds a plan that a name or directory protects regardless, as the plans exemption is only the .claude rule's" do
      %w[.claude/plans/CLAUDE.md .claude/plans/x/.mcp.json .github/skills/x/.claude/plans/y.md].each do |path|
        expect(described_class.protected?(path)).to be(true), path
      end
    end

    it 'holds a path that HFS+ or NTFS opens as a protected one, without default-ignorable code points or ' \
       'trailing dots and spaces' do
      [".claude\u200C/rules/x.md", 'CLAUDE.md.', 'CLAUDE.md ', '.claude./settings.json',
       ".github/workflows\u200B/ci.yml", "AGENTS.md\u00AD", '.github./copilot-instructions.md'].each do |path|
        expect(described_class.protected?(path)).to be(true), path.inspect
      end
    end

    it 'holds a .claude or plans segment that only normalises to its name, rather than widen the exemption' do
      expect(described_class.protected?('.claude/plans/x.md')).to be(false)
      [".claude/plans\u200C/.claude/x", '.claude/plans./x', ".claude/plans\u200C/x.md", ".claude\u200C/plans/x.md",
       '.claude/plans/ /x.md', '.claude/plans/.../x.md'].each do |path|
        expect(described_class.protected?(path)).to be(true), path.inspect
      end
    end

    it 'holds a file named .claude, at any depth, as a symlink or submodule in place of the directory, ignoring case' do
      %w[.claude sub/.claude vendor/tool/.Claude].each do |path|
        expect(described_class.protected?(path)).to be(true), path
      end
    end

    it "holds a file at a protected directory's own path, as a symlink or submodule in its place, ignoring case" do
      %w[.github/workflows .github/actions .github/instructions .github/skills .agents/skills
         .GitHub/Workflows].each do |path|
        expect(described_class.protected?(path)).to be(true), path
      end
    end

    it 'leaves other paths alone' do
      %w[.github/workflow.yml .github/CODEOWNERS docs/CLAUDE.md.bak skills/.claudex/a.md sub/.claudex
         github/workflows/ci.yml README.md CLAUDE.local.md.bak mcp.json .mcp.jsonc docs/mcp.json
         docs/.github/copilot-instructions.md .github/copilot-instructions.md.bak copilot-instructions.md
         .github/instruction/ruby.instructions.md docs/.github/instructions/ruby.instructions.md
         ruby.instructions.md AGENTS.md.bak docs/AGENTS REVIEWS.md GEMINI.mdx agents/README.md
         .github/skill/code-review/SKILL.md docs/.github/skills/code-review/SKILL.md
         skills/code-review/SKILL.md agents/skills/x docs/.agents/skills/x/SKILL.md .github/workflowsx
         docs/.github/workflows].each do |path|
        expect(described_class.protected?(path)).to be(false), path
      end
    end
  end
end
