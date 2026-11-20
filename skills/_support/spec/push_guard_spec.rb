# frozen_string_literal: true

# The push-guard hook end to end: the sh entry under /bin/sh, a hook event on
# stdin, the example's sandbox as the repository. It lives here because the
# repository's .rspec runs specs under skills/ only.
RSpec.describe 'profiles/git-workflow/hooks/push-guard' do
  let(:profile_directory) { File.join(repository_root, 'profiles', 'git-workflow') }
  let(:hook) { File.join(profile_directory, 'hooks', 'push-guard') }
  let(:decider) { File.join(profile_directory, 'hooks', 'push-guard.rb') }
  let(:hooks_json) { File.join(profile_directory, 'hooks.json') }
  let(:bare_force) do
    'push-guard: a bare force-push rewrites whatever is on the remote; ' \
      'use git push --force-with-lease --force-if-includes on your own branch'
  end
  let(:another_author) { { 'GIT_AUTHOR_NAME' => 'Another Author', 'GIT_AUTHOR_EMAIL' => 'another@example.invalid' } }
  let(:bot_author) do
    { 'GIT_AUTHOR_NAME' => 'dependabot[bot]', 'GIT_AUTHOR_EMAIL' => '1+dependabot[bot]@users.noreply.github.com' }
  end

  def event(command, cwd: Dir.pwd, tool_name: 'Bash')
    JSON.generate('hook_event_name' => 'PreToolUse', 'tool_name' => tool_name, 'session_id' => 'spec', 'cwd' => cwd,
                  'permission_mode' => 'default', 'tool_input' => { 'command' => command, 'description' => 'spec' })
  end

  # The hook's answer to +stdin+: nil for silence, else [decision, reason].
  # Whatever it answers, it exits 0 with nothing on stderr.
  def run_hook(stdin, env = {})
    stdout, stderr, status = Open3.capture3(env, '/bin/sh', hook, stdin_data: stdin)
    expect([stderr, status.exitstatus]).to eq(['', 0])
    return if stdout.empty?

    output = JSON.parse(stdout).fetch('hookSpecificOutput')
    expect(output.fetch('hookEventName')).to eq('PreToolUse')
    [output.fetch('permissionDecision'), output.fetch('permissionDecisionReason')]
  end

  def guard(command, env: {}, **options)
    run_hook(event(command, **options), env)
  end

  def git(*arguments, env: {})
    output, status = Open3.capture2e(env, 'git', *arguments)
    raise "git #{arguments.join(' ')} failed: #{output}" unless status.success?
  end

  def commit(message, env: {})
    git('commit', '--quiet', '--allow-empty', '-m', message, env: env)
  end

  def push_commit(message, author = {})
    commit(message, env: author)
    git('push', '--quiet', '-u', 'origin', 'feat')
  end

  # The pusher's identity as the sandbox commits with, in the repository's
  # configuration, where the hook reads it.
  def declare_pusher
    identity = SkillSupport::Testing::Sandbox::GIT_IDENTITY
    git('config', 'user.email', identity.fetch('GIT_AUTHOR_EMAIL'))
    git('config', 'user.name', identity.fetch('GIT_AUTHOR_NAME'))
  end

  # The sandbox repository on feat, with a bare origin whose default branch is
  # master and the pusher's one commit on origin/feat.
  def repository_with_origin
    git('init', '--bare', '--quiet', '--initial-branch=master', sandbox.path('origin.git'))
    git('remote', 'add', 'origin', sandbox.path('origin.git'))
    declare_pusher
    commit('base')
    git('push', '--quiet', 'origin', 'master')
    git('remote', 'set-head', 'origin', 'master')
    git('checkout', '--quiet', '-b', 'feat')
    push_commit('mine')
  end

  # The repository's configuration tells git log to verify signatures with a
  # gpg that leaves a marker behind, whose path this returns: a git log that
  # obeys that configuration runs it on a signed commit.
  def recording_gpg
    marker = sandbox.path('gpg-ran')
    File.write(sandbox.path('gpg'), "#!/bin/sh\ntouch '#{marker}'\nexit 1\n")
    File.chmod(0o755, sandbox.path('gpg'))
    git('config', 'gpg.program', sandbox.path('gpg'))
    git('config', 'log.showSignature', 'true')
    marker
  end

  # origin/feat's tip gains a PGP signature block.
  def sign_tip
    tip, = Open3.capture2('git', 'cat-file', '-p', 'refs/remotes/origin/feat')
    signature = "\ngpgsig -----BEGIN PGP SIGNATURE-----\n iQEzBAABCAAdFiEE\n -----END PGP SIGNATURE-----\n\n"
    signed, = Open3.capture2('git', 'hash-object', '-t', 'commit', '-w', '--stdin',
                             stdin_data: tip.sub("\n\n", signature))
    git('update-ref', 'refs/remotes/origin/feat', signed.strip)
  end

  # A PATH with what the sh entry itself needs and nothing else, ruby included.
  def path_without_ruby
    bin = sandbox.path('bin')
    FileUtils.mkdir_p(bin)
    %w[cat dirname].each { |tool| File.symlink(tool_path(tool), File.join(bin, tool)) }
    bin
  end

  def tool_path(tool)
    Open3.capture2('/bin/sh', '-c', "command -v #{tool}").first.strip
  end

  describe 'the sh entry' do
    it 'is an executable POSIX sh script headed with its vendoring source' do
      first, second = File.readlines(hook, chomp: true)
      expect([File.executable?(hook), first, second])
        .to eq([true, '#!/bin/sh', '# vendored from sgbett/dotfiles-claude profiles/git-workflow/hooks/push-guard'])
    end

    it 'says nothing for a command without push, before it needs ruby' do
      expect(guard('ls -la', env: { 'PATH' => path_without_ruby })).to be_nil
    end

    it 'asks when a push cannot be checked for want of ruby' do
      expect(guard('git push -f', env: { 'PATH' => path_without_ruby }))
        .to eq(['ask', 'push-guard: ruby is not installed, so the push could not be checked'])
    end

    it 'asks when ruby exits without an answer, as a version manager’s shim with nothing behind it does' do
      bin = path_without_ruby
      File.write(File.join(bin, 'ruby'), "#!/bin/sh\nexit 1\n")
      File.chmod(0o755, File.join(bin, 'ruby'))
      expect(guard('git push -f', env: { 'PATH' => bin }))
        .to eq(['ask', 'push-guard: ruby failed, so the push could not be checked'])
    end
  end

  describe 'the decider' do
    it 'is headed with its vendoring source' do
      expect(File.readlines(decider, chomp: true).first)
        .to eq('# vendored from sgbett/dotfiles-claude profiles/git-workflow/hooks/push-guard.rb')
    end

    it 'requires nothing outside the standard library' do
      requires = File.readlines(decider).grep(/\Arequire/).map { |line| line[/'([^']+)'/, 1] }
      expect(requires).to contain_exactly('json', 'open3', 'shellwords')
    end

    context 'under the ruby macOS ships' do
      before { skip 'no /usr/bin/ruby on this machine' unless File.executable?('/usr/bin/ruby') }

      it 'parses without a warning' do
        output, status = Open3.capture2e('/usr/bin/ruby', '-wc', decider)
        expect([output.strip, status.success?]).to eq(['Syntax OK', true])
      end

      # The system PATH alone: its ruby is Apple's, and the xcrun its rbconfig
      # shells out to is beside it.
      it 'denies a bundled -f end to end' do
        expect(guard('git push -fu origin x', env: { 'PATH' => '/usr/bin:/bin' })).to eq(['deny', bare_force])
      end
    end
  end

  describe 'a plain push' do
    ['git push', 'git push -u origin feat', 'git push --tags', 'git push -n origin x', 'git push origin :feat',
     'git push --delete origin feat'].each do |command|
      it "leaves `#{command}` to the permission rules" do
        expect(guard(command)).to be_nil
      end
    end
  end

  describe 'a bare force' do
    ['git push --force', 'git push -f', 'git push -fu origin x', 'git push -uf origin x',
     'git push origin +HEAD:refs/heads/x', 'git push --mirror origin', 'git push --mirr origin',
     'git push origin x --force', 'cd x && git push -f', 'A=b git push -f', 'sudo git push -f',
     'git push -f origin x 2>&1', '(git push -f)', 'git push -f &', 'if git push -f; then echo pushed; fi',
     'git push --force-with-lease -f origin feat', 'git push --force-with-lease --force origin feat',
     'git push --force-with-lease --no-force-with-lease -f origin feat'].each do |command|
      it "denies `#{command}`" do
        expect(guard(command)).to eq(['deny', bare_force])
      end
    end

    it 'denies first when a lease push shares the command with it' do
      expect(guard('git push --force-with-lease origin feat && git push -f origin x')).to eq(['deny', bare_force])
    end

    it 'denies origin HEAD:master --force as a bare force, which is the first match' do
      expect(guard('git push origin HEAD:master --force')).to eq(['deny', bare_force])
    end
  end

  describe 'a base branch' do
    { 'git push --force-with-lease=master:abc origin master' => 'master',
      'git push --force-with-lease origin releases/1' => 'releases/1',
      'git push --force-with-lease origin releases/v2' => 'releases/v2',
      'git push --force-with-lease origin HEAD:project/x/master' => 'project/x/master',
      'git push --delete origin project/x/master' => 'project/x/master',
      'git push --delete origin master' => 'master',
      'git push -d origin releases/1' => 'releases/1',
      'git push origin :master' => 'master',
      'git push origin :refs/heads/master' => 'master',
      'git push origin :heads/master' => 'master' }.each do |command, branch|
      it "denies `#{command}`" do
        expect(guard(command))
          .to eq(['deny', "push-guard: #{branch} is a base branch; it is never rewritten or deleted"])
      end
    end

    it 'denies a lease push from a checkout of master' do
      expect(guard('git push --force-with-lease'))
        .to eq(['deny', 'push-guard: master is a base branch; it is never rewritten or deleted'])
    end

    it 'leaves project/x/y, project/x and releases/v2/hotfix as work branches, a * being one path segment' do
      commands = ['git push --force-with-lease origin project/x/y', 'git push --force-with-lease origin project/x',
                  'git push --force-with-lease origin releases/v2/hotfix', 'git push --delete origin project/x/y']
      expect(commands.map { |command| guard(command) }).to eq([nil, nil, nil, nil])
    end

    it 'reads --no-force-with-lease after a lease as clearing it, leaving a plain push' do
      expect(guard('git push --force-with-lease --no-force-with-lease')).to be_nil
    end
  end

  describe 'a lease push to another branch' do
    it 'says nothing when the remote has only the pusher’s commits beyond the base' do
      repository_with_origin
      expect([guard('git push --force-with-lease'),
              guard('git push --force-with-lease --force-if-includes origin feat')]).to eq([nil, nil])
    end

    it 'asks when another author has commits there, counting them' do
      repository_with_origin
      push_commit('theirs', another_author)
      expect(guard('git push --force-with-lease'))
        .to eq(['ask', 'push-guard: feat on origin has commits by 1 other author(s); a branch with another active ' \
                       'committer is theirs until they say otherwise. Push anyway?'])
    end

    it 'does not count a bot' do
      repository_with_origin
      push_commit('bump', bot_author)
      expect(guard('git push --force-with-lease origin feat')).to be_nil
    end

    it 'says nothing when the remote has no copy of the branch' do
      expect(guard('git push --force-with-lease origin solo')).to be_nil
    end

    it 'asks the repository that -C names, relative to cwd' do
      repository_with_origin
      push_commit('theirs', another_author)
      expect([guard('git push --force-with-lease', cwd: sandbox.root),
              guard('git -C work push --force-with-lease', cwd: sandbox.root).first])
        .to eq([nil, 'ask'])
    end

    it 'follows a cd earlier in the command' do
      repository_with_origin
      push_commit('theirs', another_author)
      expect(guard('cd work && git push --force-with-lease 2>&1', cwd: sandbox.root).first).to eq('ask')
    end

    it 'asks before --all with a lease, which may rewrite every branch' do
      expect(guard('git push --all --force-with-lease'))
        .to eq(['ask', 'push-guard: --all with a lease may rewrite every branch, base branches included. Push anyway?'])
    end

    it 'runs no program the repository’s configuration names while it reads the log' do
      repository_with_origin
      push_commit('theirs', another_author)
      marker = recording_gpg
      sign_tip
      expect([guard('git push --force-with-lease origin feat').first, File.exist?(marker)]).to eq(['ask', false])

      Open3.capture2e('git', 'log', '-1', 'refs/remotes/origin/feat')
      expect(File.exist?(marker)).to be(true)
    end
  end

  describe 'a command it cannot read' do
    it 'says nothing for a push in the text of another command' do
      expect(guard('echo "git push --force"')).to be_nil
    end

    { "sh -c 'git push -f'" => 'sh -c', "bash -lc 'git push -f'" => 'bash -lc', "zsh -ic 'git push -f'" => 'zsh -ic',
      "dash -c 'git push -f'" => 'dash -c', "ksh -c 'git push -f'" => 'ksh -c', 'echo $(git push -f)' => '$(',
      'echo `git push -f`' => '`', 'echo x | xargs -I{} git push -f {}' => 'xargs',
      'eval "git push -f"' => 'eval' }.each do |command, construct|
      it "asks for `#{command}`, naming #{construct}" do
        expect(guard(command))
          .to eq(['ask', "push-guard: a push behind #{construct} cannot be read; run git push on its own command line"])
      end
    end

    it 'says nothing for an opaque construct that mentions no push' do
      expect(guard('echo $(git status)')).to be_nil
    end

    it 'asks for a push in a segment whose quotes do not balance' do
      expect(guard('git commit -m "x; git push -f"'))
        .to eq(['ask', "push-guard: the command's quotes do not balance, so the push in it could not be read"])
    end

    ['git push $REMOTE feat', 'git push origin $BRANCH', '$GIT push -f'].each do |command|
      it "asks for `#{command}`, whose $ may stand for anything" do
        expect(guard(command))
          .to eq(['ask', 'push-guard: a push with an unexpanded $ cannot be read; write the remote and refspec out'])
      end
    end

    { 'env -i git push -f' => '-i', 'nice -n 10 git push -f' => '-n', 'time -p git push' => '-p',
      'command -p git push' => '-p', 'sudo -u deploy git push -f' => '-u' }.each do |command, option|
      it "asks for `#{command}`, whose wrapper takes an option" do
        reason = "push-guard: the option #{option} before the command is not understood, " \
                 'so the push could not be checked'
        expect(guard(command)).to eq(['ask', reason])
      end
    end

    it 'asks for a git option it does not know before a push' do
      expect(guard('git --weird push -f'))
        .to eq(['ask', 'push-guard: the git option --weird is not understood, so the push could not be checked'])
    end

    { 'git -c alias.st=push st -f' => 'alias.st', 'git -c remote.origin.push=+refs/heads/*:refs/heads/* push' =>
      'remote.origin.push', 'git -c remote.origin.mirror=true push' => 'remote.origin.mirror',
      'git --config-env=alias.st=PUSH_ALIAS st && git push' => 'alias.st' }.each do |command, key|
      it "asks for `#{command}`, whose configuration changes what push does" do
        reason = "push-guard: setting #{key} on the command line changes what push does, " \
                 'so the push could not be checked'
        expect(guard(command)).to eq(['ask', reason])
      end
    end

    ['git push --del origin feat', 'git push --weird origin feat', 'git push --forc origin feat'].each do |command|
      it "asks for `#{command}`, whose push option it does not know" do
        option = command.split[2]
        expect(guard(command))
          .to eq(['ask', "push-guard: the push option #{option} is not understood, so the push could not be checked"])
      end
    end
  end

  describe 'an event that is not a Bash command' do
    it 'asks for stdin that is not JSON' do
      expect(run_hook('git push --force')).to eq(['ask', 'push-guard: the hook input could not be read'])
    end

    it 'asks for JSON that is not a hook event' do
      expect(run_hook('["git push --force"]')).to eq(['ask', 'push-guard: the hook input could not be read'])
    end

    it 'asks for a Bash event without a command' do
      stdin = JSON.generate('tool_name' => 'Bash', 'tool_input' => 'git push --force', 'cwd' => Dir.pwd)
      expect(run_hook(stdin)).to eq(['ask', 'push-guard: the hook input could not be read'])
    end

    it 'says nothing for another tool' do
      expect(guard('git push --force', tool_name: 'Edit')).to be_nil
    end
  end

  describe 'a failure' do
    it 'asks rather than fall open when git cannot run where cwd points' do
      not_a_directory = sandbox.path('not-a-directory')
      File.write(not_a_directory, '')
      expect(guard('git push --force-with-lease origin feat', cwd: not_a_directory))
        .to match(['ask', start_with('push-guard: Errno::ENOTDIR: ')])
    end
  end

  describe 'hooks.json' do
    it 'is the PreToolUse entry on Bash that runs the vendored hook with a timeout, blocking when the hook fails' do
      fragment = JSON.parse(File.read(hooks_json))
      entry = { 'type' => 'command', 'command' => 'sh "$CLAUDE_PROJECT_DIR/.claude/hooks/push-guard"', 'timeout' => 5,
                'onFailure' => 'block' }
      expect(fragment).to eq('hooks' => { 'PreToolUse' => [{ 'matcher' => 'Bash', 'hooks' => [entry] }] })
    end
  end

  describe 'setup.md' do
    let(:runbook) { File.read(File.join(profile_directory, 'setup.md')) }

    it 'names every base-branch pattern the hook protects' do
      expect(['master', 'project/*/master', 'releases/*'].reject { |pattern| runbook.include?("`#{pattern}`") })
        .to eq([])
    end

    it 'quotes the hooks.json entry as it is' do
      expect(runbook).to include(File.read(hooks_json).strip)
    end
  end
end
