# frozen_string_literal: true

require_relative '../lib/do/reference_files'

# /do's rarer branches live in references/, which the lead reads only when
# they apply: SKILL.md names each with the event that calls for it, and the
# scripts' `read` lists them by the same paths. Claude Code substitutes
# ${CLAUDE_SKILL_DIR} and $ARGUMENTS in SKILL.md alone. A reference another
# skill reads too lives in _support/references/, named from this directory
# through ../_support/.
RSpec.describe "/do's reference files" do
  let(:skill_directory) { File.expand_path('..', __dir__) }
  let(:skill) { File.read(File.join(skill_directory, 'SKILL.md')) }
  let(:references) { Dir[File.join(skill_directory, 'references', '*')].sort }

  def relative(path)
    path.delete_prefix("#{skill_directory}/")
  end

  def missing(paths)
    paths.reject { |path| File.file?(File.join(skill_directory, path)) }
  end

  it 'are each named in SKILL.md' do
    expect(references).not_to be_empty
    expect(references.map { |path| relative(path) }.reject { |path| skill.include?(path) }).to be_empty
  end

  it 'are the only ones SKILL.md and the references name' do
    named = [skill, *references.map { |path| File.read(path) }].flat_map do |text|
      text.scan(%r{(?:\.\./_support/)?references/[\w-]+(?:\.[\w-]+)*})
    end

    expect(missing(named.uniq)).to be_empty
  end

  it "include every one the scripts' read can list" do
    paths = Do::ReferenceFiles.constants.map { |name| Do::ReferenceFiles.const_get(name) }

    expect(paths).not_to be_empty
    expect(missing(paths)).to be_empty
  end

  it 'use neither substitution, which a reference never gets' do
    substituting = references.select { |path| File.read(path).match?(/\$\{CLAUDE_SKILL_DIR\}|\$ARGUMENTS/) }

    expect(substituting.map { |path| relative(path) }).to be_empty
  end

  it 'open with a contents list when longer than 100 lines' do
    long = references.map { |path| [relative(path), File.readlines(path, chomp: true)] }.select do |_path, lines|
      lines.length > 100
    end

    expect(long.reject { |_path, lines| lines.find { |line| line.start_with?('## ') } == '## Contents' }.map(&:first))
      .to be_empty
  end
end
