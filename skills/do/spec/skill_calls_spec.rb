# frozen_string_literal: true

# SKILL.md's calls of the scripts, as the lead runs them. Claude Code puts
# the user's text in place of $ARGUMENTS as it stands, so only the first
# call, `preflight facts`, takes it, once the lead has checked its form;
# every later call takes the canonical reference facts gives. A branch, a
# remote and a repository are single-quoted on each, as a "#" in a branch
# would start a shell comment.
RSpec.describe "/do's calls of its scripts" do
  let(:skill) { File.read(File.expand_path('../SKILL.md', __dir__)) }
  let(:calls) { skill.scan(%r{`("\$\{CLAUDE_SKILL_DIR\}/bin/[^`]+)`}).flatten }
  let(:facts_call) { %("${CLAUDE_SKILL_DIR}/bin/preflight" facts '$ARGUMENTS') }

  it 'gives $ARGUMENTS to the first call, preflight facts, alone, once the lead has checked its form' do
    expect(calls.first).to eq(facts_call)
    expect(skill.lines.find { |line| line.include?(facts_call) }).to match(/\A1\. Stop unless `\$ARGUMENTS` is /)
    expect(calls.drop(1).grep(/\$ARGUMENTS/)).to be_empty
  end

  it "gives every later call facts' reference" do
    expect(calls.length).to be > 1
    expect(calls.drop(1).reject { |call| call.include?(" '<facts.reference>' ") }).to be_empty
  end

  it 'single-quotes every branch, remote and repository a call names' do
    values = calls.flat_map { |call| call.scan(/--(?:base|branch|push-remote|pr-target) (\S+)/).flatten }

    expect(values).to include("'<B>'", "'<NAME>'", "'<R>'", "'<owner/repo>'")
    expect(values).to all(match(/\A'[^']+'\z/))
  end
end
