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

  it 'gives the first line of an answer, or nil when git exits 1 for nothing found' do
    fake_runner.expect_call(%w[git config --get branch.x.remote], stdout: "origin\n")
    fake_runner.expect_call(%w[git config --get branch.x.merge], exit_status: 1)

    expect([git.line_or_nil('config', '--get', 'branch.x.remote'),
            git.line_or_nil('config', '--get', 'branch.x.merge')])
      .to eq(['origin', nil])
  end
end
