# frozen_string_literal: true

# After compaction, Claude Code (2.1.287) re-attaches an invoked skill cut to
# 5,000 tokens, about 20,000 characters, keeping its start, so a SKILL.md
# loses whatever follows the cut for the rest of the run. The ceiling leaves
# a margin below it. Ruby's character count, not a byte count, matches
# Claude Code's for ordinary text.
RSpec.describe 'The character ceiling on SKILL.md' do
  ceiling = 19_000
  # Skills allowed over the ceiling until a planned cut. Each one's example
  # fails once it is within the ceiling, so its exception goes then.
  # copilot-check: until sgbett/dotfiles-claude#24's L10 moves its inline
  # blocks into scripts.
  exceptions = %w[copilot-check]
  # Vendored skills, reached through symlinks into vendor/, are another
  # project's to cut.
  skill_files = Dir[File.join(SkillSupport::Testing::Helpers::REPOSITORY_ROOT, 'skills', '*', 'SKILL.md')]
                .reject { |path| File.symlink?(File.dirname(path)) }
  sizes = skill_files.sort.to_h do |path|
    [File.basename(File.dirname(path)), File.read(path, encoding: 'UTF-8').length]
  end

  it 'finds the skills, and lists only existing ones as exceptions' do
    expect(sizes).not_to be_empty
    expect(exceptions - sizes.keys).to be_empty
  end

  sizes.each do |skill, characters|
    if exceptions.include?(skill)
      it "is still exceeded by #{skill}, a listed exception (#{characters} characters)" do
        expect(characters).to be > ceiling, "#{skill} is within #{ceiling} characters now: remove its exception"
      end
    else
      it "holds for #{skill} (#{characters} characters)" do
        expect(characters).to be <= ceiling
      end
    end
  end
end
