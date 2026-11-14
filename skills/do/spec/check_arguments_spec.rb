# frozen_string_literal: true

require_relative '../lib/do/check_arguments'

RSpec.describe Do::CheckArguments do
  let(:required) do
    ['--push-remote', 'origin', '--pr-target', 'sgbett/dotfiles-claude', '--base', 'master', '--branch', 'feat/#24+x']
  end

  def parse(*arguments)
    described_class.parse(arguments, runner: SkillSupport::CommandRunner.new)
  end

  it 'reads the issue, then the four conventions in any order, with no yes by default' do
    options = parse('24', *required.each_slice(2).to_a.reverse.flatten)

    expect(options.to_h).to eq(reference: '24', push_remote: 'origin', pr_target: 'sgbett/dotfiles-claude',
                               base: 'master', branch: 'feat/#24+x', accept_local_branch: nil, accept_scripts: nil)
  end

  it 'reads each yes, a commit lower-cased' do
    digest = 'c' * 64
    options = parse('24', *required, '--accept-local-branch', 'A' * 40, '--accept-scripts', digest)

    expect(options.to_h.values_at(:accept_local_branch, :accept_scripts)).to eq(['a' * 40, digest])
  end

  it 'takes a remote name with a slash, as git allows' do
    expect(parse('24', *required.drop(2), '--push-remote', 'team/fork').push_remote).to eq('team/fork')
  end

  it 'refuses a flag that is missing, unknown, repeated or without its value, and no issue' do
    [required.drop(2), [*required, '--force', 'yes'], [*required, '--base', 'main'], [*required, '--accept-scripts'],
     [*required.drop(2), '--push-remote=origin']].each do |flags|
      expect { parse('24', *flags) }.to raise_error(Do::UsageError, /usage: preflight facts/), flags.inspect
    end
    expect { parse }.to raise_error(Do::UsageError)
  end

  it 'refuses any value that is not valid, or could be read as an option' do
    { '--push-remote' => ['-x', '', "origin\n"], '--pr-target' => ['sgbett', '-o/r', 'o/r/x'],
      '--base' => ['-master', 'a..b', ''], '--branch' => ['--help', 'feat x', '@{-1}'] }.each do |flag, values|
      values.each do |value|
        flags = required.each_slice(2).to_h.merge(flag => value).flatten

        expect { parse('24', *flags) }.to raise_error(SkillSupport::InvalidIdentifier), "#{flag} #{value.inspect}"
      end
    end
  end

  it 'refuses a yes that is not a whole commit name or a digest' do
    [['--accept-local-branch', '5c766e2'], ['--accept-local-branch', 'HEAD'], ['--accept-scripts', 'C' * 64],
     ['--accept-scripts', 'c' * 63]].each do |flag, value|
      expect { parse('24', *required, flag, value) }.to raise_error(SkillSupport::InvalidIdentifier), value
    end
  end
end
