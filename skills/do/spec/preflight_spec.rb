# frozen_string_literal: true

require 'base64'
require_relative 'support/scripts_clone'

RSpec.describe 'skills/do/bin/preflight' do
  include Do::Testing::ScriptsClone

  let(:preflight) { File.join(repository_root, 'skills', 'do', 'bin', 'preflight') }
  let(:graphql) { %w[api graphql --hostname github.com --input -] }
  let(:origin) { 'https://github.com/sgbett/dotfiles-claude.git' }
  let(:branch) { 'feat/24-hlr-do-and-copilot-check-move' }
  let(:base_sha) { '6b9895d961416bbb7561778aff4e651822796e9e' }

  # The request exactly as recorded, which the shim matches byte for byte.
  def recorded_request(name)
    JSON.generate(JSON.parse(fixture("graphql/#{name}.request.json")))
  end

  def preflight_run(*arguments, environment: {}, command: preflight)
    stdout, stderr, status = Open3.capture3(environment, command, *arguments)
    [status.exitstatus, stdout, stderr]
  end

  # What a calling directory can hand any Ruby started there: Bundler,
  # loaded against a Gemfile that names a gem which doesn't exist.
  def hostile_environment
    File.write('Gemfile', "source 'https://rubygems.org'\ngem 'skill-support-no-such-gem'\n")
    { 'RUBYOPT' => '-rbundler/setup', 'BUNDLE_GEMFILE' => File.expand_path('Gemfile') }
  end

  # origin fetches from a bare repository in the sandbox and pushes to
  # GitHub, so git reads branches locally while gh is asked about the push
  # URL. Nothing here pushes through origin.
  def checkout_with_origin(push_url)
    remote = sandbox.path('remote.git')
    system('git', 'commit', '--quiet', '--allow-empty', '-m', 'First', exception: true)
    system('git', 'init', '--quiet', '--bare', '--initial-branch=master', remote, exception: true)
    system('git', 'push', '--quiet', remote, 'master', exception: true)
    system('git', 'remote', 'add', 'origin', remote, exception: true)
    system('git', 'config', 'remote.origin.pushurl', push_url, exception: true)
    system('git', 'fetch', '--quiet', 'origin', exception: true)
  end

  def contents_call(path)
    ['api', '--hostname', 'github.com', '-X', 'GET', "repos/sgbett/dotfiles-claude/contents/#{path}", '-f',
     "ref=#{base_sha}"]
  end

  def check_arguments
    ['check', 'sgbett/dotfiles-claude#24', '--push-remote', 'origin', '--pr-target', 'sgbett/dotfiles-claude',
     '--base', 'master', '--branch', branch]
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
      .to eq(['proceed', branch, ['references/resume.md']])
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

  it 'checks the conventions for the recorded issue and proceeds on a new branch, whatever RUBYOPT says' do
    checkout_with_origin(origin)
    claude_md = { 'type' => 'file', 'encoding' => 'base64', 'content' => Base64.encode64("# Example\n") }
    shim = install_gh_shim(
      [{ args: graphql, stdin: recorded_request('check-issue-24'),
         stdout_file: fixture_path('graphql/check-issue-24.json') },
       { args: ['repo', 'view', origin, '--json', 'nameWithOwner,parent'],
         stdout_file: fixture_path('repo-view/push-origin.json') },
       { args: graphql, stdin: recorded_request('base-master'), stdout_file: fixture_path('graphql/base-master.json') },
       { args: graphql, stdin: recorded_request('pull-requests-24'),
         stdout_file: fixture_path('graphql/pull-requests-24.json') },
       { args: contents_call('CLAUDE.md'), stdout: JSON.generate(claude_md) },
       { args: contents_call('.claude/rules'), exit: 1, stdout_file: fixture_path('contents/rules-not-found.json'),
         stderr: fixture('contents/rules-not-found.stderr') }]
    )

    exit_code, stdout, stderr = preflight_run(*check_arguments, environment: hostile_environment,
                                                                command: scripts_clone)
    output = JSON.parse(stdout)

    expect([exit_code, stderr, shim.unmatched_calls]).to eq([0, '', []])
    expect(output.values_at('status', 'push_remote_is_fork', 'scripts_in_work_tree', 'working_tree_clean'))
      .to eq(['proceed', false, false, false])
    expect([output['branch']['state'], output['security_focus']['found']]).to eq(['new', false])
    expect(output['session_only']).to include('push_urls' => [origin], 'changed_paths' => ['?? Gemfile'])
  end

  it 'stops a checkout of another repository at its push remote, asking gh nothing more' do
    unrelated = 'https://github.com/example-owner/unrelated.git'
    checkout_with_origin(unrelated)
    shim = install_gh_shim(
      [{ args: graphql, stdin: recorded_request('check-issue-24'),
         stdout_file: fixture_path('graphql/check-issue-24.json') },
       { args: ['repo', 'view', unrelated, '--json', 'nameWithOwner,parent'],
         stdout: '{"nameWithOwner":"example-owner/unrelated","parent":null}' }]
    )

    exit_code, stdout, _stderr = preflight_run(*check_arguments, command: scripts_clone)

    expect([exit_code, JSON.parse(stdout)['reason'], shim.unmatched_calls])
      .to eq([2, 'push_remote_not_this_repository', []])
    expect(shim.calls.length).to eq(2)
  end

  it 'fails as a tool on any arguments it does not take, printing its usage' do
    install_gh_shim([])

    [%w[check 24], [], %w[facts], %w[facts 24 25], %w[--help]].each do |arguments|
      exit_code, stdout, stderr = preflight_run(*arguments)

      expect([exit_code, stdout]).to eq([1, '']), arguments.inspect
      expect(stderr).to start_with('preflight: tool failure: usage: preflight facts <issue>'), arguments.inspect
    end
  end
end
