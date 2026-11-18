# frozen_string_literal: true

require_relative '../lib/repo_consistency/audit_arguments'

RSpec.describe RepoConsistency::AuditArguments do
  it 'takes repositories and flags in any order, with github.com and the profile directory as the defaults' do
    options = described_class.parse(%w[audit sgbett/dotfiles-claude --hostname GitHub.com example-owner/app])

    expect(options.to_h).to eq(repositories: %w[sgbett/dotfiles-claude example-owner/app],
                               template_dir: File.join(repository_root, 'profiles', 'git-workflow'),
                               hostname: 'github.com')
  end

  it 'takes another template directory and host, and no repository at all, which Audit stops on' do
    options = described_class.parse(['audit', '--template-dir', 'copy/git-workflow', '--hostname', 'ghe.example.com'])

    expect(options.to_h).to eq(repositories: [], template_dir: 'copy/git-workflow', hostname: 'ghe.example.com')
  end

  it 'refuses anything but audit, a flag it does not take, one without its value, and one given twice' do
    [[], %w[inspect a/b], %w[audit a/b --dry-run], %w[audit a/b --template-dir],
     %w[audit --hostname x.example.com --hostname y.example.com a/b]].each do |arguments|
      expect { described_class.parse(arguments) }.to raise_error(RepoConsistency::UsageError), arguments.inspect
    end
  end

  it 'refuses a repository, host or template directory that is not a valid identifier' do
    expect { described_class.parse(%w[audit example-owner]) }
      .to raise_error(SkillSupport::InvalidIdentifier, 'invalid repository')
    expect { described_class.parse(%w[audit a/b --hostname github]) }
      .to raise_error(SkillSupport::InvalidIdentifier, 'invalid host')
    expect { described_class.parse(['audit', 'a/b', '--template-dir', "dir\n"]) }
      .to raise_error(SkillSupport::InvalidIdentifier, 'invalid template_dir')
  end
end
