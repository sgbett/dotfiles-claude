# frozen_string_literal: true

RSpec.describe SkillSupport::CommandRunner do
  subject(:runner) { described_class.new }

  def child_environment
    runner.run(%w[env -0]).stdout.split("\0").to_h { |pair| pair.split('=', 2) }
  end

  it 'returns stdout, stderr and the exit status' do
    result = runner.run(['sh', '-c', 'printf out; printf err >&2; exit 3'])

    expect(result.to_h).to eq(stdout: 'out', stderr: 'err', exit_status: 3)
    expect(result).not_to be_success
  end

  it 'hands each argument to the child verbatim, with no shell to expand it' do
    arguments = ['$HOME', 'a;b', '*', "it's", 'two words', '', '#24', '--flag']

    expect(runner.run(['printf', '%s\n', *arguments]).stdout.lines(chomp: true)).to eq(arguments)
  end

  it 'never hands a one-element command to a shell' do
    marker = sandbox.path('shell-ran')

    expect { runner.run(["touch #{marker}; true"]) }.to raise_error(SkillSupport::CommandNotFound)
    expect { runner.run(["touch #{marker}"]) }.to raise_error(SkillSupport::CommandNotFound)
    expect(File).not_to exist(marker)
  end

  it 'refuses a shell string' do
    expect { runner.run('gh api user') }.to raise_error(ArgumentError, /never a shell string/)
  end

  it 'refuses an empty command, an empty program and arguments that are not strings' do
    [nil, [], [''], ['gh', 1], ['gh', nil], [:gh]].each do |argv|
      expect { runner.run(argv) }.to raise_error(ArgumentError), "accepted #{argv.inspect}"
    end
  end

  it 'raises CommandNotFound naming a program that is not installed' do
    expect { runner.run(['skill-support-no-such-command']) }
      .to raise_error(SkillSupport::CommandNotFound, 'skill-support-no-such-command is not installed or not on PATH')
  end

  it "removes the variables that retarget, page or colour gh, and pins its and git's quiet settings" do
    described_class::REMOVED_VARIABLES.each { |name| ENV[name] = 'set-by-spec' }
    ENV.update('GH_PROMPT_DISABLED' => '0', 'NO_COLOR' => '', 'GIT_TERMINAL_PROMPT' => '1')

    environment = child_environment

    expect(environment.keys & described_class::REMOVED_VARIABLES).to be_empty
    expect(environment).to include('GH_PROMPT_DISABLED' => '1', 'GH_NO_UPDATE_NOTIFIER' => '1', 'NO_COLOR' => '1',
                                   'GIT_TERMINAL_PROMPT' => '0')
  end

  it 'passes the rest of the environment through' do
    ENV['SKILL_SUPPORT_SPEC'] = 'kept'

    expect(child_environment).to include('SKILL_SUPPORT_SPEC' => 'kept', 'GH_TOKEN' => 'dummy')
  end

  it 'writes stdin to the child' do
    expect(runner.run(['cat'], stdin: 'piped').stdout).to eq('piped')
  end

  it 'gives the child an empty stdin when there is none to send' do
    expect(runner.run(['cat']).stdout).to eq('')
  end

  it 'reports death by a signal as 128 plus the signal number' do
    expect(runner.run(['sh', '-c', 'kill -TERM $$']).exit_status).to eq(128 + Signal.list.fetch('TERM'))
  end

  it 'returns output as UTF-8' do
    result = runner.run(%w[printf %s café])

    expect(result.stdout).to eq('café')
    expect(result.stdout.encoding).to eq(Encoding::UTF_8)
  end
end
