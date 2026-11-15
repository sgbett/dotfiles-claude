# frozen_string_literal: true

require 'base64'
require_relative '../lib/do/check_query'
require_relative 'support/scripts_clone'

RSpec.describe 'skills/do/bin/preflight' do
  include Do::Testing::ScriptsClone

  let(:preflight) { File.join(repository_root, 'skills', 'do', 'bin', 'preflight') }
  let(:graphql) { %w[api graphql --hostname github.com --input -] }
  let(:login) { { args: %w[auth status --active --hostname github.com] } }
  let(:origin) { 'https://github.com/sgbett/dotfiles-claude.git' }
  let(:ssh_push_url) { 'git@github.com:sgbett/dotfiles-claude.git' }
  let(:branch) { 'feat/24-hlr-do-and-copilot-check-move' }
  let(:base_sha) { '6b9895d961416bbb7561778aff4e651822796e9e' }

  # The request exactly as recorded, which the shim matches byte for byte.
  def recorded_request(name)
    JSON.generate(JSON.parse(fixture("graphql/#{name}.request.json")))
  end

  # The file the lead writes the user's argument to with the Write tool,
  # which `facts` reads, here with the trailing newline a file often has.
  def argument_file(text)
    sandbox.path('argument.txt').tap { |path| File.write(path, "#{text}\n") }
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

  # origin fetches from +fetch_from+, a bare repository in the sandbox, and
  # pushes to +push_url+, about which gh alone is asked. Nothing here pushes
  # through origin.
  def checkout_with_origin(push_url, fetch_from: bare_repository('remote.git'))
    system('git', 'commit', '--quiet', '--allow-empty', '-m', 'First', exception: true)
    system('git', 'push', '--quiet', fetch_from, 'master', exception: true)
    system('git', 'remote', 'add', 'origin', fetch_from, exception: true)
    system('git', 'config', 'remote.origin.pushurl', push_url, exception: true)
    system('git', 'fetch', '--quiet', 'origin', exception: true)
  end

  def bare_repository(name)
    sandbox.path(name).tap do |path|
      system('git', 'init', '--quiet', '--bare', '--initial-branch=master', path, exception: true)
    end
  end

  # What git needs to reach ssh_push_url without a network: an ssh that
  # serves +github+, a bare repository standing for GitHub's copy, whatever
  # host and path git asks for.
  def ssh_environment(github)
    ssh = sandbox.path('ssh')
    File.write(ssh, "#!/bin/sh\nexec git upload-pack '#{github}'\n")
    File.chmod(0o755, ssh)
    { 'GIT_SSH_COMMAND' => "'#{ssh}'", 'GIT_SSH_VARIANT' => 'simple' }
  end

  # A commit of its own on +branch+ in the bare repository +bare+, which this
  # checkout doesn't have.
  def branch_in(bare)
    clone = "#{bare}-clone"
    system('git', 'clone', '--quiet', bare, clone, exception: true)
    system('git', '-C', clone, 'commit', '--quiet', '--allow-empty', '-m', "On #{File.basename(bare)}",
           exception: true)
    system('git', '-C', clone, 'push', '--quiet', 'origin', "HEAD:refs/heads/#{branch}", exception: true)
    Open3.capture2('git', '-C', clone, 'rev-parse', 'HEAD').first.chomp
  end

  # check's calls to gh up to its proceeding on the recorded issue, the push
  # remote pushing to +push_url+.
  def check_shim(push_url)
    install_gh_shim([login, recorded_graphql('check-issue-24'),
                     { args: ['repo', 'view', push_url, '--json', 'nameWithOwner,parent,viewerPermission'],
                       stdout_file: fixture_path('repo-view/push-origin.json') },
                     recorded_graphql('base-master'), recorded_graphql('pull-requests-24'), *no_security_focus,
                     *no_copilot_signal])
  end

  def recorded_graphql(name)
    { args: graphql, stdin: recorded_request(name), stdout_file: fixture_path("graphql/#{name}.json") }
  end

  # A CLAUDE.md with no security focus, and no .claude/rules/.
  def no_security_focus
    claude_md = { 'type' => 'file', 'encoding' => 'base64', 'content' => Base64.encode64("# Example\n") }
    [{ args: contents_call('CLAUDE.md'), stdout: JSON.generate(claude_md) },
     { args: contents_call('.claude/rules'), exit: 1, stdout_file: fixture_path('contents/rules-not-found.json'),
       stderr: fixture('contents/rules-not-found.stderr') }]
  end

  # No rules for the base, whose path segment is +base_segment+, as
  # recorded, and no .github/copilot-instructions.md.
  def no_copilot_signal(base_segment = 'master')
    [{ args: ['api', '--hostname', 'github.com', '-X', 'GET',
              "repos/sgbett/dotfiles-claude/rules/branches/#{base_segment}", '-f', 'per_page=100'],
       stdout_file: fixture_path('rest/branch-rules-none.json') },
     { args: contents_call('.github/copilot-instructions.md'), exit: 1,
       stdout_file: fixture_path('contents/rules-not-found.json'), stderr: fixture('contents/rules-not-found.stderr') }]
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
      [login, { args: ['repo', 'view', origin, '--json', 'nameWithOwner,url'],
                stdout_file: fixture_path('repo-view/origin.json') },
       { args: graphql, stdin: recorded_request('issue-24'), stdout_file: fixture_path('graphql/issue-24.json') },
       { args: %w[api --hostname github.com -X GET repos/sgbett/dotfiles-claude/issues/24],
         stdout_file: fixture_path('rest/issue-24.json') }]
    )

    exit_code, stdout, stderr = preflight_run('facts', '--argument-file', argument_file('24'),
                                              environment: hostile_environment)
    output = JSON.parse(stdout)

    expect([exit_code, stderr, shim.unmatched_calls]).to eq([0, '', []])
    expect(output.keys.first).to eq('status')
    expect(output.values_at('status', 'reference', 'default_branch', 'read'))
      .to eq(['proceed', 'sgbett/dotfiles-claude#24', branch, ['references/resume.md']])
    expect(output['ledger']['items'].map { |item| item['id'] }).to eq((1..11).map { |n| "L#{n}" })
    expect(output['issue']['boxes'].map { |box| box.values_at('position', 'checked') })
      .to eq((1..11).map { |n| [n, false] })
    expect(output['session_only']['gate_file'])
      .to eq(File.join(sandbox.work_directory, '.git', 'do', 'I_kwDOQzoXSs8AAAABfBUanQ-gate.md'))
  end

  it 'stops on a pull request number' do
    shim = install_gh_shim([login, { args: graphql, stdin: recorded_request('pull-request-25'),
                                     stdout_file: fixture_path('graphql/pull-request-25.json') }])

    exit_code, stdout, _stderr = preflight_run('facts', '--argument-file', argument_file('sgbett/dotfiles-claude#25'))

    expect([exit_code, shim.unmatched_calls]).to eq([2, []])
    expect(JSON.parse(stdout)).to include('status' => 'stop', 'reason' => 'not_an_issue')
  end

  it 'asks for the repository when a bare number has no origin, calling gh not at all' do
    shim = install_gh_shim([])

    exit_code, stdout, _stderr = preflight_run('facts', '--argument-file', argument_file('24'))

    expect([exit_code, shim.calls]).to eq([3, []])
    expect(JSON.parse(stdout)).to include('status' => 'ask', 'asks' => [include('reason' => 'no_origin')])
  end

  it 'checks the conventions for the recorded issue and proceeds on a new branch, whatever RUBYOPT says' do
    github = bare_repository('github.git')
    checkout_with_origin(ssh_push_url, fetch_from: github)
    shim = check_shim(ssh_push_url)

    environment = hostile_environment.merge(ssh_environment(github))
    exit_code, stdout, stderr = preflight_run(*check_arguments, command: scripts_clone, environment: environment)
    output = JSON.parse(stdout)

    expect([exit_code, stderr, shim.unmatched_calls]).to eq([0, '', []])
    expect(output.values_at('status', 'push_remote_is_fork', 'scripts_in_work_tree', 'working_tree_clean'))
      .to eq(['proceed', false, false, false])
    expect([output['branch']['state'], output['security_focus']['found'], output['copilot_review']['signal']])
      .to eq(['new', false, false])
    expect(output['session_only']).to include('push_urls' => [ssh_push_url], 'changed_paths' => ['?? Gemfile'])
  end

  it "never resumes from another repository that the push remote's fetch URL names, which holds the branch" do
    github = bare_repository('github.git')
    elsewhere = bare_repository('elsewhere.git')
    checkout_with_origin(ssh_push_url, fetch_from: elsewhere)
    elsewhere_tip = branch_in(elsewhere)
    shim = check_shim(ssh_push_url)

    exit_code, stdout, stderr = preflight_run(*check_arguments, command: scripts_clone,
                                                                environment: ssh_environment(github))
    output = JSON.parse(stdout)

    expect([exit_code, stderr, shim.unmatched_calls]).to eq([0, '', []])
    expect(output['branch']).to include('state' => 'new')
    expect(stdout).not_to include(elsewhere_tip)
  end

  it "resumes from the push URL's copy of the branch, fetched for the lead to check out" do
    github = bare_repository('github.git')
    elsewhere = bare_repository('elsewhere.git')
    checkout_with_origin(ssh_push_url, fetch_from: elsewhere)
    system('git', 'push', '--quiet', github, 'master', exception: true)
    github_tip = branch_in(github)
    elsewhere_tip = branch_in(elsewhere)
    check_shim(ssh_push_url)

    exit_code, stdout, _stderr = preflight_run(*check_arguments, command: scripts_clone,
                                                                 environment: ssh_environment(github))

    expect([exit_code, JSON.parse(stdout)['branch'].values_at('state', 'remote_tip')])
      .to eq([0, ['resume_push_remote', github_tip]])
    expect(stdout).not_to include(elsewhere_tip)
    expect(system('git', 'cat-file', '-e', "#{github_tip}^{commit}")).to be(true)
  end

  it 'takes a hierarchical base and branch holding "#", as the lead single-quotes them, to GitHub whole' do
    base = 'project/#7_skills/master'
    work = 'project/#7_skills/feat/24-scripts'
    github = bare_repository('github.git')
    checkout_with_origin(ssh_push_url, fetch_from: github)
    request = lambda do |query, variables|
      JSON.generate('query' => query, 'variables' => { 'owner' => 'sgbett', 'name' => 'dotfiles-claude', **variables })
    end
    base_ref = { 'ref' => { 'name' => base, 'target' => { 'oid' => base_sha } } }
    page = { 'hasNextPage' => false, 'hasPreviousPage' => false }
    none_open = { 'pullRequests' => { 'pageInfo' => page, 'nodes' => [] } }
    shim = install_gh_shim(
      [login, recorded_graphql('check-issue-24'),
       { args: ['repo', 'view', ssh_push_url, '--json', 'nameWithOwner,parent,viewerPermission'],
         stdout_file: fixture_path('repo-view/push-origin.json') },
       { args: graphql, stdin: request.call(Do::CheckQuery::BASE_QUERY, 'qualifiedName' => "refs/heads/#{base}"),
         stdout: JSON.generate('data' => { 'repository' => base_ref }) },
       { args: graphql, stdin: request.call(Do::CheckQuery::PULL_REQUESTS_QUERY, 'branch' => work),
         stdout: JSON.generate('data' => { 'repository' => none_open }) },
       *no_security_focus, *no_copilot_signal('project%2F%237_skills%2Fmaster')]
    )
    arguments = ['check', 'sgbett/dotfiles-claude#24', '--push-remote', 'origin', '--pr-target',
                 'sgbett/dotfiles-claude', '--base', base, '--branch', work]

    exit_code, stdout, stderr = preflight_run(*arguments, command: scripts_clone, environment: ssh_environment(github))

    expect([exit_code, stderr, shim.unmatched_calls]).to eq([0, '', []])
    expect(JSON.parse(stdout).values_at('base', 'branch')).to match([base, include('name' => work, 'state' => 'new')])
  end

  it 'stops a checkout of another repository at its push remote, asking gh nothing more' do
    unrelated = 'https://github.com/example-owner/unrelated.git'
    checkout_with_origin(unrelated)
    shim = install_gh_shim(
      [login, { args: graphql, stdin: recorded_request('check-issue-24'),
                stdout_file: fixture_path('graphql/check-issue-24.json') },
       { args: ['repo', 'view', unrelated, '--json', 'nameWithOwner,parent,viewerPermission'],
         stdout: '{"nameWithOwner":"example-owner/unrelated","parent":null,"viewerPermission":"READ"}' }]
    )

    exit_code, stdout, _stderr = preflight_run(*check_arguments, command: scripts_clone)

    expect([exit_code, JSON.parse(stdout)['reason'], shim.unmatched_calls])
      .to eq([2, 'push_remote_not_this_repository', []])
    expect(shim.calls.length).to eq(3)
  end

  it "takes one trailing newline as the argument file's, not the reference's, and stops on more before calling gh" do
    shim = install_gh_shim([])

    exit_code, stdout, _stderr = preflight_run('facts', '--argument-file', argument_file("24\n"))

    expect([exit_code, JSON.parse(stdout)['reason'], shim.calls]).to eq([2, 'not_an_issue', []])
  end

  it 'fails as a tool on an argument file that is missing or a symlink, before calling gh' do
    shim = install_gh_shim([])
    File.symlink(argument_file('24'), sandbox.path('link.txt'))

    [[sandbox.path('missing.txt'), "doesn't exist"], [sandbox.path('link.txt'), 'is a symlink']].each do |path, problem|
      exit_code, stdout, stderr = preflight_run('facts', '--argument-file', path)

      expect([exit_code, stdout, stderr]).to match([1, '', include(problem)]), path
    end
    expect(shim.calls).to eq([])
  end

  it 'fails as a tool on any arguments it does not take, printing its usage' do
    install_gh_shim([])

    [%w[check 24], [], %w[facts], %w[facts 24], %w[facts --argument-file], %w[facts --issue x], %w[--help]]
      .each do |arguments|
      exit_code, stdout, stderr = preflight_run(*arguments)

      expect([exit_code, stdout]).to eq([1, '']), arguments.inspect
      expect(stderr).to start_with('preflight: tool failure: usage: preflight facts --argument-file <path>'),
                        arguments.inspect
    end
  end
end
