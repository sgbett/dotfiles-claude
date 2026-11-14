# frozen_string_literal: true

RSpec.describe 'skills/do/bin/preflight' do
  let(:preflight) { File.join(repository_root, 'skills', 'do', 'bin', 'preflight') }
  let(:graphql) { %w[api graphql --hostname github.com --input -] }
  let(:origin) { 'https://github.com/sgbett/dotfiles-claude.git' }

  # The request exactly as recorded, which the shim matches byte for byte.
  def recorded_request(name)
    JSON.generate(JSON.parse(fixture("graphql/#{name}.request.json")))
  end

  def preflight_run(*arguments, environment: {})
    stdout, stderr, status = Open3.capture3(environment, preflight, *arguments)
    [status.exitstatus, stdout, stderr]
  end

  # What a calling directory can hand any Ruby started there: Bundler,
  # loaded against a Gemfile that names a gem which doesn't exist.
  def hostile_environment
    File.write('Gemfile', "source 'https://rubygems.org'\ngem 'skill-support-no-such-gem'\n")
    { 'RUBYOPT' => '-rbundler/setup', 'BUNDLE_GEMFILE' => File.expand_path('Gemfile') }
  end

  it 'proceeds on the recorded issue, a bare number resolved through origin, whatever RUBYOPT says' do
    system('git', 'remote', 'add', 'origin', origin, exception: true)
    shim = install_gh_shim(
      [{ args: ['repo', 'view', origin, '--json', 'nameWithOwner,url'],
         stdout_file: fixture_path('repo-view/origin.json') },
       { args: graphql, stdin: recorded_request('issue-24'), stdout_file: fixture_path('graphql/issue-24.json') }]
    )

    exit_code, stdout, stderr = preflight_run('facts', '24', environment: hostile_environment)
    output = JSON.parse(stdout)

    expect([exit_code, stderr, shim.unmatched_calls]).to eq([0, '', []])
    expect(output.keys.first).to eq('status')
    expect(output.values_at('status', 'default_branch', 'read'))
      .to eq(['proceed', 'feat/24-hlr-do-and-copilot-check-move', ['references/resume.md']])
    expect(output['ledger']['items'].map { |item| item['id'] }).to eq((1..11).map { |n| "L#{n}" })
    expect(output['session_only']['gate_file'])
      .to eq(File.join(sandbox.work_directory, '.git', 'do', 'I_kwDOQzoXSs8AAAABfBUanQ-gate.md'))
  end

  it 'stops on a pull request number' do
    shim = install_gh_shim([{ args: graphql, stdin: recorded_request('pull-request-25'),
                              stdout_file: fixture_path('graphql/pull-request-25.json') }])

    exit_code, stdout, _stderr = preflight_run('facts', 'sgbett/dotfiles-claude#25')

    expect([exit_code, shim.unmatched_calls]).to eq([2, []])
    expect(JSON.parse(stdout)).to include('status' => 'stop', 'reason' => 'not_an_issue')
  end

  it 'asks for the repository when a bare number has no origin, calling gh not at all' do
    shim = install_gh_shim([])

    exit_code, stdout, _stderr = preflight_run('facts', '24')

    expect([exit_code, shim.calls]).to eq([3, []])
    expect(JSON.parse(stdout)).to include('status' => 'ask', 'asks' => [include('reason' => 'no_origin')])
  end

  it 'fails as a tool on check, which is still to be built, and on any other arguments' do
    install_gh_shim([])

    [%w[check 24], [], %w[facts], %w[facts 24 25], %w[--help]].each do |arguments|
      exit_code, stdout, stderr = preflight_run(*arguments)

      expect([exit_code, stdout]).to eq([1, '']), arguments.inspect
      expect(stderr).to start_with('preflight: tool failure: '), arguments.inspect
    end
  end
end
