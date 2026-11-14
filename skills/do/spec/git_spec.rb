# frozen_string_literal: true

require_relative '../lib/do/git'

RSpec.describe Do::Git do
  subject(:git) { described_class.new(fake_runner) }

  it 'runs git with the arguments given and returns what it printed' do
    fake_runner.expect_call(%w[git rev-parse --show-toplevel], stdout: "/repo\n")

    expect(git.output('rev-parse', '--show-toplevel')).to eq("/repo\n")
  end

  it 'fails as a tool on an exit status the caller does not allow, saying what git said' do
    fake_runner.expect_call(%w[git ls-remote origin], exit_status: 128, stderr: "fatal: could not read from remote\n")

    expect { git.output('ls-remote', 'origin') }
      .to raise_error(Do::GitError, 'git ls-remote origin exited 128: fatal: could not read from remote')
  end

  it 'masks the credentials of a URL among the arguments it names when it fails as a tool' do
    url = 'https://x-access-token:example-secret@github.com/sgbett/dotfiles-claude.git'
    fake_runner.expect_call(['git', 'ls-remote', url, 'refs/heads/x'], exit_status: 128, stderr: "fatal: denied\n")

    expect { git.output('ls-remote', url, 'refs/heads/x') }
      .to raise_error(Do::GitError,
                      'git ls-remote https://***@github.com/sgbett/dotfiles-claude.git refs/heads/x exited 128: ' \
                      'fatal: denied')
  end

  it 'gives the first line of an answer, or nil when git exits 1 for nothing found' do
    fake_runner.expect_call(%w[git config --get branch.x.remote], stdout: "origin\n")
    fake_runner.expect_call(%w[git config --get branch.x.merge], exit_status: 1)

    expect([git.line_or_nil('config', '--get', 'branch.x.remote'),
            git.line_or_nil('config', '--get', 'branch.x.merge')])
      .to eq(['origin', nil])
  end
end
