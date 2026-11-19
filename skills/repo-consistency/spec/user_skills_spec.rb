# frozen_string_literal: true

require_relative '../lib/repo_consistency/user_skills'

# The lists restate what git tracks, so that a skill or command added or
# removed fails here until the lists follow.
RSpec.describe RepoConsistency::UserSkills do
  symlink_mode = '120000'

  # Each path git tracks under +directory+ of the repository, with its mode.
  def tracked(directory)
    output, status = Open3.capture2('git', '-C', repository_root, 'ls-files', '--stage', '-z', '--', directory)
    raise "git ls-files #{directory} failed" unless status.success?

    output.split("\0").to_h do |line|
      stage, path = line.split("\t", 2)
      [path, stage.split.first]
    end
  end

  it 'lists each skill git tracks under skills/: every directory but _support, and every symlink to a vendored ' \
     "skill's directory, which, unlike the vendored reference pages beside them, has no extension" do
    entries = tracked('skills')
    directories = entries.keys.filter_map { |path| path.split('/')[1] if path.count('/') > 1 }
    links = entries.filter_map do |path, mode|
      File.basename(path) if mode == symlink_mode && path.count('/') == 1 && File.extname(path).empty?
    end

    expect(described_class::SKILLS).to match_array((directories.uniq - ['_support']) + links)
  end

  it 'lists each command git tracks under commands/, a nested one by its path joined with a colon' do
    names = tracked('commands').keys.grep(/\.md\z/)
                               .map { |path| path.delete_prefix('commands/').delete_suffix('.md').tr('/', ':') }

    expect(described_class::COMMANDS).to match_array(names)
  end

  it 'names every skill and command once' do
    expect(described_class::NAMES).to eq(described_class::NAMES.uniq)
    expect(described_class::NAMES).to match_array(described_class::SKILLS + described_class::COMMANDS)
  end
end
