# frozen_string_literal: true

require_relative '../lib/do/issue_reference'

RSpec.describe Do::IssueReference do
  def parse(text)
    described_class.parse(text)&.to_h
  end

  it 'reads a bare number, with or without "#", leaving the repository to origin' do
    expect([parse('24'), parse('#24')]).to eq([{ host: nil, repository: nil, number: 24 }] * 2)
  end

  it 'reads owner/repo#N as an issue on github.com' do
    expect(parse('sgbett/dotfiles-claude#24')).to eq(host: 'github.com', repository: 'sgbett/dotfiles-claude',
                                                     number: 24)
  end

  it 'reads an issue URL, taking the host from it' do
    expect(parse('https://github.com/sgbett/dotfiles-claude/issues/24'))
      .to eq(host: 'github.com', repository: 'sgbett/dotfiles-claude', number: 24)
    expect(parse('https://GHE.example.com/example-owner/example-repo/issues/7'))
      .to eq(host: 'ghe.example.com', repository: 'example-owner/example-repo', number: 7)
  end

  it 'reads nothing else, a pull request URL included' do
    url = 'https://github.com/example-owner/example-repo'
    ['', ' 24', '24 ', '0', '024', '12345678901', '#', 'sgbett/dotfiles-claude', 'sgbett/dotfiles-claude#',
     'sgbett/dotfiles-claude#0', 'example-owner/example-repo/x#1', 'example-owner/..#1',
     'sgbett/dotfiles-claude#24 extra', "#{url}/pull/3", "#{url.sub('https', 'http')}/issues/3",
     "#{url}/issues/3/", "#{url}/issues/3#x", "#{url.sub('.com', '.com:443')}/issues/3",
     "#{url.delete_prefix('https://')}/issues/3", nil, 24].each do |text|
      expect(parse(text)).to be_nil, "read #{text.inspect}"
    end
  end

  it 'refuses a reference that starts with "-", which a command would read as an option' do
    %w[-24 --help -R -sgbett/dotfiles-claude#24].each do |text|
      expect(parse(text)).to be_nil, "read #{text.inspect}"
    end
  end
end
