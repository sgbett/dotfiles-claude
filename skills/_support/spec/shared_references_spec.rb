# frozen_string_literal: true

# A reference more than one skill reads lives in _support/references/, and
# each SKILL.md names it from its own directory through
# ${CLAUDE_SKILL_DIR}/../_support/, so the skills share one copy. The
# security gate's triggers and white-hat brief are one: a second list in a
# SKILL.md would drift from it.
RSpec.describe "_support's shared references" do
  skills = File.join(SkillSupport::Testing::Helpers::REPOSITORY_ROOT, 'skills')
  references = Dir[File.join(skills, '_support', 'references', '*')]
  # Vendored skills, reached through symlinks into vendor/, can't name ours.
  skill_files = Dir[File.join(skills, '*', 'SKILL.md')].reject { |path| File.symlink?(File.dirname(path)) }
  named_as = ->(reference) { "${CLAUDE_SKILL_DIR}/../_support/references/#{File.basename(reference)}" }

  it 'are each named by a SKILL.md' do
    texts = skill_files.map { |path| File.read(path) }

    expect(references).not_to be_empty
    expect(references.reject { |reference| texts.any? { |text| text.include?(named_as.call(reference)) } })
      .to be_empty
  end

  it 'use neither substitution, which a reference never gets' do
    expect(references.select { |path| File.read(path).match?(/\$\{CLAUDE_SKILL_DIR\}|\$ARGUMENTS/) }).to be_empty
  end

  describe 'the security gate' do
    gate = File.join(skills, '_support', 'references', 'security-gate.md')
    skill_texts = %w[do copilot-check].to_h { |skill| [skill, File.read(File.join(skills, skill, 'SKILL.md'))] }

    it 'exists' do
      expect(File.file?(gate)).to be(true)
    end

    it 'is named by both /do and /copilot-check' do
      expect(skill_texts.reject { |_skill, text| text.include?(named_as.call(gate)) }.keys).to be_empty
    end

    it 'has its triggers listed in neither SKILL.md' do
      expect(File.read(gate)).to include('deserialisation')
      expect(skill_texts.select { |_skill, text| text.include?('deserialisation') }.keys).to be_empty
    end
  end
end
