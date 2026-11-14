# frozen_string_literal: true

RSpec.describe SkillSupport::Testing::FixturePolicy do
  # Assembled here so that this file does not itself hold a machine-local
  # path or anything shaped like a token.
  let(:local_paths) do
    [%w[Users example notes.md], %w[home example notes.md], %w[private tmp x], %w[tmp x], %w[var folders x]]
      .map { |parts| File.join('', *parts) }
  end
  let(:tokens) { %w[ghp ghs gho ghu ghr github_pat].map { |prefix| "#{prefix}_#{'A' * 36}" } << "sk-ant-#{'A' * 36}" }

  def violations(text)
    described_class.violations(text)
  end

  it 'flags a repository outside the allowlist in every form it looks for' do
    forms = ['https://github.com/not-allowlisted/repository/pull/3', 'git@github.com:not-allowlisted/repository.git',
             '"url":"https://api.github.com/repos/not-allowlisted/repository/issues/1"',
             'https://raw.githubusercontent.com/not-allowlisted/repository/master/x',
             'gh api repos/not-allowlisted/repository', '"nameWithOwner":"not-allowlisted/repository"',
             '"full_name": "not-allowlisted/repository"',
             '"variables": {"owner": "not-allowlisted", "name": "repository"}', 'see not-allowlisted/repository#24']

    forms.each do |text|
      expect(violations(text))
        .to eq(['line 1: repository not-allowlisted/repository is not on the public allowlist']), text
    end
  end

  it 'allows the public allowlist in any case, and synthetic example- owners' do
    text = <<~TEXT
      https://github.com/sgbett/dotfiles-claude/issues/24 and https://github.com/TWBS/Bootstrap.git
      "nameWithOwner":"bettison-org/ai-software-architect" codenamev/ai-software-architect#1
      https://github.com/example-owner/anything example-fork-owner/repo#2
    TEXT

    expect(violations(text)).to be_empty
  end

  it 'ignores GitHub paths that do not name a repository' do
    text = 'https://github.com/apps/copilot-pull-request-reviewer https://api.github.com/users/octocat/repos ' \
           'https://github.com/orgs/example-org/projects/1 application/json .github/workflows docs/x.md#heading'

    expect(violations(text)).to be_empty
  end

  it 'flags home and temporary paths' do
    local_paths.each do |path|
      expect(violations("written to #{path}")).to match([start_with('line 1: machine-local path /')]), path
    end
  end

  it 'flags anything shaped like a token, naming only its prefix' do
    tokens.each do |token|
      expect(violations("token: #{token}"))
        .to match([match(/\Aline 1: token-like string [a-z_-]+\.\.\.\z/)]), token[0, 4]
    end
  end

  it 'reports the line of each violation' do
    expect(violations("fine\nhttps://github.com/not-allowlisted/repository\n#{tokens.first}\n"))
      .to eq(['line 2: repository not-allowlisted/repository is not on the public allowlist',
              'line 3: token-like string ghp_...'])
  end

  it 'passes every committed fixture of every skill' do
    fixtures = Dir.glob(File.join(repository_root, 'skills', '**', 'spec', 'fixtures', '**', '*'), File::FNM_DOTMATCH)
                  .select { |path| File.file?(path) }
    failures = fixtures.flat_map do |path|
      violations(File.binread(path).force_encoding(Encoding::UTF_8).scrub)
        .map { |violation| "#{path.delete_prefix("#{repository_root}/")}: #{violation}" }
    end

    expect(fixtures).not_to be_empty
    expect(failures).to be_empty, failures.join("\n")
  end
end
