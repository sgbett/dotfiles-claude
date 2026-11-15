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

  describe '.protected?' do
    it 'holds workflows and actions, any CLAUDE.md, and anything under a .claude directory, ignoring case' do
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

    it 'holds any AGENTS.md, GEMINI.md and REVIEW.md, the other files Copilot takes instructions from, at any ' \
       'depth, ignoring case' do
      %w[AGENTS.md GEMINI.md REVIEW.md docs/AGENTS.md skills/x/gemini.md lib/a/b/Review.MD agents.md].each do |path|
        expect(described_class.protected?(path)).to be(true), path
      end
    end

    it 'leaves other paths alone' do
      %w[.github/workflow.yml .github/CODEOWNERS docs/CLAUDE.md.bak .claude skills/.claudex/a.md
         github/workflows/ci.yml README.md CLAUDE.local.md.bak mcp.json .mcp.jsonc docs/mcp.json
         docs/.github/copilot-instructions.md .github/copilot-instructions.md.bak copilot-instructions.md
         .github/instruction/ruby.instructions.md docs/.github/instructions/ruby.instructions.md
         ruby.instructions.md AGENTS.md.bak docs/AGENTS REVIEWS.md GEMINI.mdx agents/README.md].each do |path|
        expect(described_class.protected?(path)).to be(false), path
      end
    end
  end
end
