# frozen_string_literal: true

require_relative '../lib/repo_consistency/skill_mentions'

RSpec.describe RepoConsistency::SkillMentions do
  it 'finds a name written as a command, in code, before a possessive or at the end of a sentence, and a ' \
     'hyphenated one bare' do
    { '`/do`' => ['do'], "/do's breakdown" => ['do'], 'then run /do.' => ['do'], '(/zendesk)' => ['zendesk'],
      '/copilot-check' => ['copilot-check'], 'ask `specialist-review`' => ['specialist-review'],
      'run /project:generate' => ['project:generate'], 'then create-adr.' => ['create-adr'] }.each do |text, names|
      expect(described_class.names_in(text)).to eq(names), text
    end
  end

  it 'finds nothing in a path, a URL, a file name, a longer name, another case or prose' do
    ['skills/do/', '~/.claude/skills/do', 'https://x/do', '/docs', '/docs/', '/do-thing', '/do.md', '/DO',
     'create-adr-template', 'create-adr.md', 'skills/create-adr', 'Do not', 'do it now', 'a zendesk ticket',
     'the transcript', '.claude/commands/project:generate'].each do |text|
      expect(described_class.names_in(text)).to eq([]), text
    end
  end

  it 'lists each name once, sorted, whichever form and however often it appears' do
    text = "Ask /specialist-review, then specialist-review again.\nRun /do, /do and /architecture-review.\n"

    expect(described_class.names_in(text)).to eq(%w[architecture-review do specialist-review])
  end

  it 'reads no file as none, and text that is not UTF-8 without its bad bytes' do
    expect(described_class.names_in(nil)).to eq([])
    expect(described_class.names_in("\xFF run /do".b.force_encoding(Encoding::UTF_8))).to eq(['do'])
  end
end
