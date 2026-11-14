# frozen_string_literal: true

# SKILL.md's calls of the scripts, as the lead runs them. Claude Code puts
# the user's text in place of $ARGUMENTS as it stands, so no call takes it:
# the lead writes it to a file with the Write tool, which the first call,
# `preflight facts`, reads; every later call takes the canonical reference
# facts gives. A branch, a remote and a repository are single-quoted on each,
# as a "#" in a branch would start a shell comment.
RSpec.describe "/do's calls of its scripts" do
  let(:skill) { File.read(File.expand_path('../SKILL.md', __dir__)) }
  let(:calls) { skill.scan(%r{`("\$\{CLAUDE_SKILL_DIR\}/bin/[^`]+)`}).flatten }
  let(:facts_call) { %("${CLAUDE_SKILL_DIR}/bin/preflight" facts --argument-file '<path>') }

  it 'puts $ARGUMENTS on no call: the first, preflight facts, reads it from the file the lead writes it to' do
    expect(calls.first).to eq(facts_call)
    expect(skill.lines.find { |line| line.include?(facts_call) })
      .to match(/\A1\. Write `\$ARGUMENTS` with the Write tool to a session-scratchpad file /)
    expect(calls.grep(/\$ARGUMENTS/)).to be_empty
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

  it "passes, with the issue body's box positions, the digest of the boxes facts counted" do
    positions = calls.grep(/--(?:verified-boxes|issue-boxes) /)

    expect(positions.length).to eq(2)
    expect(positions).to all(include('--boxes-digest <facts.issue.boxes_digest>'))
  end

  it "pushes the run's HEAD from its worktree, so one detached at the push remote's tip pushes its own work" do
    expect(skill).to include("`git -C '<worktree>' push -u '<R>' 'HEAD:refs/heads/<NAME>'`")
  end
end
