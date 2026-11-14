# frozen_string_literal: true

require_relative '../lib/do/remote_url'

RSpec.describe Do::RemoteUrl do
  let(:path) { 'example-owner/example-repo' }

  describe '.host' do
    it 'reads the host of each URL form git pushes to, lower-cased, without user or port' do
      { 'https://github.com/sgbett/dotfiles-claude.git' => 'github.com',
        'https://GitHub.COM/SGBETT/Dotfiles-Claude' => 'github.com',
        "http://ghe.example.com/#{path}" => 'ghe.example.com',
        "https://x-access-token:secret@github.com/#{path}.git" => 'github.com',
        "https://user:p@ss@github.com/#{path}.git" => 'github.com',
        "ssh://git@github.com:22/#{path}.git" => 'github.com',
        "git://github.com/#{path}" => 'github.com',
        "git+ssh://git@github.com/#{path}" => 'github.com',
        "git@github.com:#{path}.git" => 'github.com',
        "github.com:#{path}.git" => 'github.com',
        "deploy@github.com:#{path}.git" => 'github.com' }.each do |url, host|
        expect(described_class.host(url)).to eq(host), url
      end
    end

    it 'takes an SSH host alias for the host it names, which is not the one it stands for' do
      expect(described_class.host('git@github-work:sgbett/dotfiles-claude.git')).to eq('github-work')
    end

    it 'finds no host in a local path or a file URL' do
      ['/srv/git/repo.git', './repo', '../repo.git', 'repo', 'file:///srv/git/repo.git', "https:///#{path}", '']
        .each do |url|
          expect(described_class.host(url)).to be_nil, url
        end
    end
  end

  describe '.redacted' do
    it 'masks the userinfo of a scheme URL, which can carry a token' do
      { "https://x-access-token:ghs-example@github.com/#{path}.git" => "https://***@github.com/#{path}.git",
        "https://token-as-user@github.com/#{path}" => "https://***@github.com/#{path}",
        "ssh://git@github.com/#{path}.git" => "ssh://***@github.com/#{path}.git" }.each do |url, redacted|
        expect(described_class.redacted(url)).to eq(redacted)
      end
    end

    it 'leaves a URL without userinfo, and the scp-like form, as they are' do
      ["https://github.com/#{path}.git", "git@github.com:#{path}.git", '/srv/git/repo.git'].each do |url|
        expect(described_class.redacted(url)).to eq(url)
      end
    end
  end
end
