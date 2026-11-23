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
  let(:another_on_feat) do
    'push-guard: feat on origin has commits by 1 other author(s), another@example.invalid; a branch with another ' \
      'active committer is theirs until they say otherwise, and an address of your own belongs in .mailmap. ' \
      'Push anyway?'
  end
  let(:unknown_directory) do
    'push-guard: the directory the push runs in could not be followed, so the push could not be checked; ' \
      'write it as git -C <path> push'
  end
  let(:another_author) { { 'GIT_AUTHOR_NAME' => 'Another Author', 'GIT_AUTHOR_EMAIL' => 'another@example.invalid' } }
  let(:same_name_stranger) { { 'GIT_AUTHOR_NAME' => 'Skill Spec', 'GIT_AUTHOR_EMAIL' => 'stranger@example.invalid' } }
  let(:aliased_pusher) { { 'GIT_AUTHOR_NAME' => 'S. Spec', 'GIT_AUTHOR_EMAIL' => 'other@example.invalid' } }
  let(:bot_author) do
    { 'GIT_AUTHOR_NAME' => 'dependabot[bot]', 'GIT_AUTHOR_EMAIL' => '1+dependabot[bot]@users.noreply.github.com' }
  end
  let(:system_path) { { 'PATH' => '/usr/bin:/bin' } }
  let(:log_bound) { File.read(decider)[/^\s*MAX_COMMITS = (\d+)/, 1].to_i }

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

  # The ask for one other author's commits on +branch+ at +remote+; the
  # example on origin pins the text in full.
  def other_authors_ask(branch, remote, address = 'another@example.invalid')
    ['ask', "push-guard: #{branch} on #{remote} has commits by 1 other author(s), #{address}; a branch with another " \
            'active committer is theirs until they say otherwise, and an address of your own belongs in .mailmap. ' \
            'Push anyway?']
  end

  def unreadable_history_ask(mend)
    ['ask', 'push-guard: the commits of feat on origin beyond its base could not be read, so the push could not be ' \
            "checked; run #{mend} first"]
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

  # A commit by +author+ on the checkout, pushed to +branch+ on origin while
  # feat stays the current branch.
  def push_branch(branch, author = {})
    commit("on #{branch}", env: author)
    git('push', '--quiet', 'origin', "HEAD:#{branch}")
  end

  def configure(key, value)
    git('config', key, value)
  end

  # The pusher's identity as the sandbox commits with, in the repository's
  # configuration, where the hook reads it.
  def declare_pusher
    identity = SkillSupport::Testing::Sandbox::GIT_IDENTITY
    configure('user.email', identity.fetch('GIT_AUTHOR_EMAIL'))
    configure('user.name', identity.fetch('GIT_AUTHOR_NAME'))
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

  # A second remote at the same bare repository, fetched.
  def add_remote(name)
    git('remote', 'add', name, sandbox.path('origin.git'))
    git('fetch', '--quiet', name)
  end

  # feat tracks origin/+branch+, created on origin from master.
  def track(branch)
    git('push', '--quiet', 'origin', "master:#{branch}")
    git('branch', '--quiet', "--set-upstream-to=origin/#{branch}", 'feat')
  end

  def mailmap(line)
    File.write('.mailmap', "#{line}\n")
  end

  # What a single-branch fetch leaves: the remote's HEAD known, its copy of
  # master not here.
  def forget_base
    git('update-ref', '-d', 'refs/remotes/origin/master')
  end

  def forget_remote_head
    git('remote', 'set-head', 'origin', '--delete')
  end

  # The object behind origin/feat goes missing, so the ref still resolves
  # while a log over it fails.
  def lose_tip
    sha, = Open3.capture2('git', 'rev-parse', 'refs/remotes/origin/feat')
    sha = sha.strip
    File.delete(File.join('.git', 'objects', sha[0, 2], sha[2..]))
  end

  # origin/feat becomes +count+ commits of the pusher's over one of another
  # author's, all beyond the base, written straight into the remote-tracking
  # ref: a history too long to grow by committing.
  def bury_stranger_under(count)
    base, = Open3.capture2('git', 'rev-parse', 'refs/remotes/origin/master')
    entries = [commit_entry(1, 'Another Author <another@example.invalid>', "from #{base.strip}")]
    (2..count + 1).each do |mark|
      entries << commit_entry(mark, 'Skill Spec <skill-spec@example.invalid>', "from :#{mark - 1}")
    end
    output, status = Open3.capture2e('git', 'fast-import', '--quiet', '--force', stdin_data: entries.join)
    raise "fast-import failed: #{output}" unless status.success?
  end

  def commit_entry(mark, identity, parent)
    stamp = "#{1_700_000_000 + mark} +0000"
    "commit refs/remotes/origin/feat\nmark :#{mark}\nauthor #{identity} #{stamp}\ncommitter #{identity} #{stamp}\n" \
      "data 1\n.\n#{parent}\n\n"
  end

  # The repository's configuration tells git log to verify signatures with a
  # gpg that leaves a marker behind, whose path this returns: a git log that
  # obeys that configuration runs it on a signed commit.
  def recording_gpg
    marker = sandbox.path('gpg-ran')
    File.write(sandbox.path('gpg'), "#!/bin/sh\ntouch '#{marker}'\nexit 1\n")
    File.chmod(0o755, sandbox.path('gpg'))
    configure('gpg.program', sandbox.path('gpg'))
    configure('log.showSignature', 'true')
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

    # The system PATH alone: its ruby is Apple's 2.6, and the xcrun its
    # rbconfig shells out to is beside it. A method 2.6 lacks parses and then
    # fails at run time, so the paths that parse git's output run end to end.
    context 'under the ruby macOS ships' do
      before { skip 'no /usr/bin/ruby on this machine' unless File.executable?('/usr/bin/ruby') }

      it 'parses without a warning' do
        output, status = Open3.capture2e('/usr/bin/ruby', '-wc', decider)
        expect([output.strip, status.success?]).to eq(['Syntax OK', true])
      end

      it 'denies a bundled -f end to end' do
        expect(guard('git push -fu origin x', env: system_path)).to eq(['deny', bare_force])
      end

      it 'forbids the git it runs a lazy fetch, which in a partial clone would reach the promisor remote' do
        expect(File.read(decider))
          .to include("ENVIRONMENT = { 'GIT_OPTIONAL_LOCKS' => '0', 'GIT_NO_LAZY_FETCH' => '1' }.freeze")
      end

      it 'resolves the destination through push.default=upstream end to end' do
        repository_with_origin
        track('project/p1/master')
        configure('push.default', 'upstream')
        expect(guard('git push --force-with-lease', env: system_path))
          .to eq(['deny', 'push-guard: project/p1/master is a base branch; it is never rewritten or deleted'])
      end

      it 'reads the authors through .mailmap end to end' do
        repository_with_origin
        mailmap('Skill Spec <skill-spec@example.invalid> <other@example.invalid>')
        push_commit('mine too', aliased_pusher)
        push_commit('theirs', another_author)
        expect(guard('git push --force-with-lease', env: system_path)).to eq(['ask', another_on_feat])
      end
    end
  end

  describe 'a plain push' do
    ['git push', 'git push -u origin feat', 'git push --tags', 'git push -n origin x', 'git push --no-prune origin',
     'git push origin :', 'GIT_DIR=/elsewhere git push', 'cd "$d" && git push', 'pushd work && git push origin feat',
     'git push -ofoo origin feat', 'git push -odeploy origin feat', 'git push -uo opt origin feat'].each do |command|
      it "leaves `#{command}` to the permission rules" do
        expect(guard(command)).to be_nil
      end
    end

    it 'decides nothing for --repo origin --delete x, which has no refspec and git refuses' do
      expect(guard('git push --repo origin --delete x')).to be_nil
    end
  end

  describe 'a bare force' do
    ['git push --force', 'git push -f', 'git push -fu origin x', 'git push -uf origin x', 'git push -fo opt origin x',
     'git push origin +HEAD:refs/heads/x', 'git push --mirror origin', 'git push --mirr origin',
     'git push origin x --force', 'cd x && git push -f', 'A=b git push -f', 'sudo git push -f',
     'git push -f origin x 2>&1', '(git push -f)', 'git push -f &', 'if git push -f; then echo pushed; fi',
     'git push --force-with-lease -f origin feat', 'git push --force-with-lease --force origin feat',
     'git push --force-with-lease --no-force-with-lease -f origin feat',
     'git push origin x 2>&1 --force', '2>&1 git push --force', 'git push --force >&2', 'git push --force &>/dev/null',
     'git push --force |& tee log', 'git push --force-with-lease origin feat 2>&1 && git push -f origin x',
     'cd "$d" && git push --force', 'GIT_DIR=/elsewhere git push --force'].each do |command|
      it "denies `#{command}`" do
        expect(guard(command)).to eq(['deny', bare_force])
      end
    end

    it 'joins a backslash-newline continuation before reading, so a --force on the second line is read' do
      expect(guard("git push origin feat --force-with-lease \\\n  --force")).to eq(['deny', bare_force])
    end

    it 'reads an even number of trailing backslashes as escaped, not as a continuation' do
      expect([guard("echo x\\\\\ngit push --force origin master"),
              guard("echo x\\\\\ngit push --force-with-lease origin master").first]).to eq([['deny', bare_force], 'deny'])
    end

    it 'reads a comment line to its end, backslash and all, so a continuation after it is still read' do
      expect([guard("# see C:\\\ngit push --force origin master"), guard("# C:\\\ngit push \\\n  --force origin master")])
        .to eq([['deny', bare_force]] * 2)
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
      'git push --prune --force-with-lease origin master' => 'master',
      'git push --delete origin master' => 'master',
      'git push --delete origin project/x/master' => 'project/x/master',
      'git push -d origin releases/1' => 'releases/1',
      'git push origin :master' => 'master',
      'git push origin :refs/heads/master' => 'master',
      'git push origin :heads/master' => 'master',
      'cd "$d" && git push --force-with-lease origin master' => 'master' }.each do |command, branch|
      it "denies `#{command}`" do
        expect(guard(command))
          .to eq(['deny', "push-guard: #{branch} is a base branch; it is never rewritten or deleted"])
      end
    end

    it 'denies a lease push from a checkout of master' do
      expect(guard('git push --force-with-lease'))
        .to eq(['deny', 'push-guard: master is a base branch; it is never rewritten or deleted'])
    end

    it 'reads a trailing comment to the end of its line, so its backslash does not join the push after it' do
      denied = ['deny', 'push-guard: master is a base branch; it is never rewritten or deleted']
      expect([guard("git status # C:\\\ngit push --force-with-lease origin master"),
              guard("git status # C:\\\ngit push \\\n  --force-with-lease origin master"),
              guard("git status # C:\\\ngit push \\\n  --delete origin master")]).to eq([denied] * 3)
    end

    it 'starts a comment at a # glued to a shell operator too, as bash and zsh do' do
      denied = ['deny', 'push-guard: master is a base branch; it is never rewritten or deleted']
      expect([guard("true;# C:\\\ngit push --force-with-lease"), guard("true&&# C:\\\ngit push origin --delete HEAD")])
        .to eq([denied] * 2)
    end

    it 'keeps a # inside quotes as text, and denies a base branch a refspec names on a line read apart' do
      expect([guard("git commit -m \"fix #12\" && git push \\\n  --force origin feat"),
              guard("git commit -m \"a \\\n#b\" && git push --force-with-lease origin master")])
        .to eq([['deny', bare_force], ['deny', 'push-guard: master is a base branch; it is never rewritten or deleted']])
    end

    it 'denies --all with a lease from a checkout of master, the strictest answer standing' do
      expect(guard('git push --all --force-with-lease'))
        .to eq(['deny', 'push-guard: master is a base branch; it is never rewritten or deleted'])
    end

    it 'leaves project/x/y, project/x and releases/v2/hotfix as work branches, a * being one path segment' do
      commands = ['git push --force-with-lease origin project/x/y', 'git push --force-with-lease origin project/x',
                  'git push --force-with-lease origin releases/v2/hotfix']
      expect([*commands.map { |command| guard(command) }, guard('git push --delete origin project/x/y').first])
        .to eq([nil, nil, nil, 'ask'])
    end

    it 'judges a lease push to project/x/y, a pull-request branch, by its authors' do
      repository_with_origin
      push_branch('project/x/y', another_author)
      expect(guard('git push --force-with-lease origin project/x/y')).to eq(other_authors_ask('project/x/y', 'origin'))
    end

    it 'reads --no-force-with-lease after a lease as clearing it, leaving a plain push' do
      expect(guard('git push --force-with-lease --no-force-with-lease')).to be_nil
    end
  end

  describe 'a lease push to another branch' do
    it 'says nothing when the remote has only the pusher’s commits beyond the base' do
      repository_with_origin
      expect([guard('git push --force-with-lease'),
              guard('git push --force-with-lease --force-if-includes origin feat'),
              guard('git push --force-with-lease origin feat 2>&1 && echo ok')]).to eq([nil, nil, nil])
    end

    it 'reads nothing from a trailing comment, which bash does not run' do
      repository_with_origin
      commands = ['git push --force-with-lease origin feat # master is protected', 'git push origin feat # --force',
                  'git push origin feat # costs $5']
      expect([*commands.map { |command| guard(command) }, guard('git push origin feat --force # --force')])
        .to eq([nil, nil, nil, ['deny', bare_force]])
    end

    it 'asks when another author has commits there, naming them' do
      repository_with_origin
      push_commit('theirs', another_author)
      expect(guard('git push --force-with-lease')).to eq(['ask', another_on_feat])
    end

    it 'asks about a stranger who shares the pusher’s name, since identity is the email alone' do
      repository_with_origin
      push_commit('theirs', same_name_stranger)
      expect(guard('git push --force-with-lease')).to eq(other_authors_ask('feat', 'origin', 'stranger@example.invalid'))
    end

    it 'names only the printable characters of an address, cut to 64, since the text reaches the prompt' do
      repository_with_origin
      push_commit('long', 'GIT_AUTHOR_EMAIL' => "#{'x' * 290}@example.invalid")
      push_commit('control', 'GIT_AUTHOR_EMAIL' => "a\e[31m\rb@example.invalid")
      expect(guard('git push --force-with-lease'))
        .to eq(['ask', 'push-guard: feat on origin has commits by 2 other author(s), a[31mb@example.invalid, ' \
                       "#{'x' * 64}; a branch with another active committer is theirs until they say otherwise, " \
                       'and an address of your own belongs in .mailmap. Push anyway?'])
    end

    it 'names at most five addresses and counts the rest' do
      repository_with_origin
      (1..6).each { |n| push_commit("theirs #{n}", 'GIT_AUTHOR_EMAIL' => "author#{n}@example.invalid") }
      expect(guard('git push --force-with-lease'))
        .to eq(['ask', 'push-guard: feat on origin has commits by 6 other author(s), author6@example.invalid, ' \
                       'author5@example.invalid, author4@example.invalid, author3@example.invalid, ' \
                       'author2@example.invalid and 1 more; a branch with another active committer is theirs until ' \
                       'they say otherwise, and an address of your own belongs in .mailmap. Push anyway?'])
    end

    it 'asks when the log fills its bound, since older commits may be another author’s' do
      repository_with_origin
      bury_stranger_under(log_bound - 2)
      expect(guard('git push --force-with-lease')).to eq(['ask', another_on_feat])
      bury_stranger_under(log_bound - 1)
      expect(guard('git push --force-with-lease'))
        .to eq(['ask', "push-guard: feat on origin has #{log_bound} or more commits beyond its base, more than the " \
                       'hook reads, so the push could not be checked; git shortlog -sne refs/remotes/origin/feat ' \
                       '--not refs/remotes/origin/master lists their authors'])
    end

    it 'measures a pull-request branch beyond its project base, not beyond master alone' do
      repository_with_origin
      push_branch('project/x/master', another_author)
      push_branch('project/x/y')
      expect(guard('git push --force-with-lease origin project/x/y')).to be_nil
      push_branch('project/x/y', another_author)
      expect(guard('git push --force-with-lease origin project/x/y')).to eq(other_authors_ask('project/x/y', 'origin'))
    end

    it 'does not count a second address of the pusher’s that .mailmap folds onto the first' do
      repository_with_origin
      mailmap('Skill Spec <skill-spec@example.invalid> <other@example.invalid>')
      push_commit('mine too', aliased_pusher)
      expect(guard('git push --force-with-lease')).to be_nil
    end

    it 'reads the pusher’s own user.email through .mailmap too' do
      repository_with_origin
      mailmap('Skill Spec <skill-spec@example.invalid> <other@example.invalid>')
      configure('user.email', 'other@example.invalid')
      expect(guard('git push --force-with-lease')).to be_nil
    end

    it 'asks when user.email is not set' do
      repository_with_origin
      git('config', '--unset', 'user.email')
      expect(guard('git push --force-with-lease'))
        .to eq(['ask', 'push-guard: user.email is not set, so the commits on the remote could not be told from your ' \
                       'own and the push could not be checked; set it with git config user.email <address>'])
    end

    it 'does not count a bot' do
      repository_with_origin
      push_commit('bump', bot_author)
      expect(guard('git push --force-with-lease origin feat')).to be_nil
    end

    it 'says nothing when the remote has no copy of the branch' do
      expect(guard('git push --force-with-lease origin solo')).to be_nil
    end

    it 'asks for a lease with a value in it when the remote’s copy is not here, naming the fetch' do
      expect(guard('git push --force-with-lease=feat:0123abc origin feat'))
        .to eq(unreadable_history_ask('git fetch origin feat'))
      git('checkout', '--quiet', '-b', 'feat')
      expect(guard('git push --force-with-lease=feat:0123abc')).to eq(unreadable_history_ask('git fetch origin feat'))
    end

    it 'reads --force-with-lease=<ref> as an expectation of that ref, not as a push to it' do
      repository_with_origin
      expect(guard('git push origin --force-with-lease=master')).to be_nil
      git('checkout', '--quiet', 'master')
      expect(guard('git push origin --force-with-lease=master'))
        .to eq(['deny', 'push-guard: master is a base branch; it is never rewritten or deleted'])
    end

    it 'asks when the base is not here, naming the fetch' do
      repository_with_origin
      forget_base
      expect(guard('git push --force-with-lease')).to eq(unreadable_history_ask('git fetch origin master'))
    end

    it 'asks when neither the base nor the remote’s HEAD is here, naming set-head' do
      repository_with_origin
      forget_remote_head
      forget_base
      expect(guard('git push --force-with-lease')).to eq(unreadable_history_ask('git remote set-head origin -a'))
    end

    it 'asks when git log fails, naming the fetch' do
      repository_with_origin
      lose_tip
      expect(guard('git push --force-with-lease')).to eq(unreadable_history_ask('git fetch origin feat'))
    end

    it 'asks about a deletion of a branch another author has commits on, as about a lease' do
      repository_with_origin
      push_commit('theirs', another_author)
      expect([guard('git push origin --delete feat'), guard('git push origin :feat'), guard('git push -d origin feat')])
        .to eq([['ask', another_on_feat]] * 3)
    end

    it 'says nothing about a deletion of a branch with only the pusher’s commits' do
      repository_with_origin
      expect(guard('git push origin --delete feat')).to be_nil
    end

    it 'asks about a deletion when the remote’s copy is not here, since git deletes an unfetched branch too' do
      expect([guard('git push origin --delete solo'), guard('git push origin :solo')])
        .to eq([['ask', 'push-guard: the commits of solo on origin beyond its base could not be read, so the push ' \
                        'could not be checked; run git fetch origin solo first']] * 2)
    end

    it 'asks the repository that -C names, relative to cwd' do
      repository_with_origin
      push_commit('theirs', another_author)
      expect([guard('git push --force-with-lease', cwd: sandbox.root),
              guard('git -C work push --force-with-lease', cwd: sandbox.root).first])
        .to eq([nil, 'ask'])
    end

    it 'joins repeated -C paths in order' do
      repository_with_origin
      push_commit('theirs', another_author)
      expect(guard('git -C .. -C work push --force-with-lease')).to eq(['ask', another_on_feat])
    end

    it 'follows a cd earlier in the command' do
      repository_with_origin
      push_commit('theirs', another_author)
      expect(guard('cd work && git push --force-with-lease 2>&1', cwd: sandbox.root).first).to eq('ask')
    end

    it 'follows a cd past a parenthesis inside quotes, which opens no subshell' do
      repository_with_origin
      push_commit('theirs', another_author)
      expect(guard('cd work && git commit -m "fix (typo)" && git push --force-with-lease origin feat', cwd: sandbox.root))
        .to eq(['ask', another_on_feat])
    end

    it 'judges a continued lease push by its joined lines, not by the first line alone from a checkout of master' do
      repository_with_origin
      push_commit('theirs', another_author)
      git('checkout', '--quiet', 'master')
      expect(guard("git push --force-with-lease \\\n  origin feat")).to eq(['ask', another_on_feat])
    end

    it 'says nothing for a continued lease push to the pusher’s own branch from a checkout of master' do
      repository_with_origin
      git('checkout', '--quiet', 'master')
      expect(guard("git push --force-with-lease \\\n  origin feat")).to be_nil
    end

    it 'strips a direction override and a zero-width space from an address, which count as printable' do
      repository_with_origin
      push_commit('bidi', 'GIT_AUTHOR_EMAIL' => "a‮b​c@example.invalid")
      expect(guard('git push --force-with-lease')).to eq(other_authors_ask('feat', 'origin', 'abc@example.invalid'))
    end

    it 'reads a non-ASCII address, and command, as UTF-8 under a C locale' do
      repository_with_origin
      push_commit('theirs', 'GIT_AUTHOR_EMAIL' => 'zoë@example.invalid')
      c_locale = { 'LANG' => 'C', 'LC_ALL' => 'C' }
      expect([guard('git push --force-with-lease', env: c_locale), guard('git commit -m "zoë" && git push -f', env: c_locale)])
        .to eq([other_authors_ask('feat', 'origin', 'zoë@example.invalid'), ['deny', bare_force]])
    end

    it 'recovers the directory from an absolute cd or -C after one it could not follow' do
      repository_with_origin
      push_commit('theirs', another_author)
      expect([guard("cd \"$d\" && cd #{sandbox.work_directory} && git push --force-with-lease", cwd: sandbox.root),
              guard("cd \"$d\" && git -C #{sandbox.work_directory} push --force-with-lease", cwd: sandbox.root)])
        .to eq([['ask', another_on_feat]] * 2)
    end

    it 'reads >& log as a redirection, judging the push on origin and not on a remote named log' do
      repository_with_origin
      push_commit('theirs', another_author)
      expect(guard('git push --force-with-lease >& log')).to eq(['ask', another_on_feat])
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

  describe 'the destination of a push with no refspec' do
    it 'denies through push.default=upstream when the upstream is a project base' do
      repository_with_origin
      track('project/p1/master')
      configure('push.default', 'upstream')
      expect(guard('git push --force-with-lease'))
        .to eq(['deny', 'push-guard: project/p1/master is a base branch; it is never rewritten or deleted'])
    end

    it 'reads remote.pushDefault for the remote' do
      repository_with_origin
      push_commit('theirs', another_author)
      add_remote('upstream')
      configure('remote.pushDefault', 'upstream')
      expect(guard('git push --force-with-lease')).to eq(other_authors_ask('feat', 'upstream'))
    end

    it 'reads branch.feat.pushRemote for the remote' do
      repository_with_origin
      push_commit('theirs', another_author)
      add_remote('upstream')
      configure('branch.feat.pushRemote', 'upstream')
      expect(guard('git push --force-with-lease')).to eq(other_authors_ask('feat', 'upstream'))
    end

    it 'reads the remote the command names over the configuration' do
      repository_with_origin
      push_commit('theirs', another_author)
      configure('remote.pushDefault', 'upstream')
      expect(guard('git push origin --force-with-lease')).to eq(['ask', another_on_feat])
    end

    it 'reads a positional remote over --repo, as git does' do
      repository_with_origin
      push_commit('theirs', another_author)
      add_remote('upstream')
      expect(guard('git push upstream --repo=origin --force-with-lease')).to eq(other_authors_ask('feat', 'upstream'))
    end

    it 'reads --repo when no positional names the remote' do
      repository_with_origin
      push_commit('theirs', another_author)
      add_remote('upstream')
      expect([guard('git push --repo=upstream --force-with-lease'), guard('git push --repo upstream --force-with-lease')])
        .to eq([other_authors_ask('feat', 'upstream')] * 2)
    end

    it 'says nothing with remote.origin.push configured when the command names the refspec' do
      repository_with_origin
      configure('remote.origin.push', 'refs/heads/master:refs/heads/master')
      expect(guard('git push --force-with-lease origin feat')).to be_nil
    end
  end

  describe 'a push whose targets it cannot name' do
    let(:prune) do
      'push-guard: --prune may rewrite or delete any branch on the remote, base branches included, so the targets ' \
        'could not be checked; name them, as git push <remote> --delete <branch>. Push anyway?'
    end

    def cannot_name(form)
      "push-guard: #{form} may rewrite or delete any branch on the remote, base branches included, so the targets " \
        'could not be checked; name them, as git push <remote> <branch>. Push anyway?'
    end

    it 'asks before --prune, whatever else is on the line' do
      expect([guard('git push --prune origin'), guard('git push --prune --force-with-lease origin feat')])
        .to eq([['ask', prune]] * 2)
    end

    it 'asks before --all with a lease, which may rewrite every branch' do
      git('checkout', '--quiet', '-b', 'feat')
      expect(guard('git push --all --force-with-lease')).to eq(['ask', cannot_name('--all with a lease')])
    end

    it 'asks before a wildcard refspec with a lease' do
      expect(guard("git push --force-with-lease origin 'refs/heads/*:refs/heads/*'"))
        .to eq(['ask', cannot_name('the refspec refs/heads/*:refs/heads/*')])
    end

    it 'asks before the matching refspec with a lease' do
      expect(guard('git push --force-with-lease origin :')).to eq(['ask', cannot_name('the refspec :')])
    end

    it 'asks under push.default=matching' do
      repository_with_origin
      configure('push.default', 'matching')
      expect(guard('git push --force-with-lease')).to eq(['ask', cannot_name('push.default=matching')])
    end

    it 'asks when remote.origin.push is configured and the command names no refspec' do
      repository_with_origin
      configure('remote.origin.push', 'refs/heads/master:refs/heads/master')
      expect(guard('git push --force-with-lease'))
        .to eq(['ask', cannot_name('the configured remote.origin.push')])
    end
  end

  describe 'a command it cannot read' do
    it 'says nothing for a push in the text of another command' do
      expect(guard('echo "git push --force"')).to be_nil
    end

    { "sh -c 'git push -f'" => 'sh -c', "bash -lc 'git push -f'" => 'bash -lc', "zsh -ic 'git push -f'" => 'zsh -ic',
      "dash -c 'git push -f'" => 'dash -c', "ksh -c 'git push -f'" => 'ksh -c', 'echo $(git push -f)' => '$(',
      'echo `git push -f`' => '`', 'echo x | xargs -I{} git push -f {}' => 'xargs',
      'eval "git push -f"' => 'eval', 'timeout 60 git push --force' => 'timeout', 'nohup git push -f' => 'nohup',
      'caffeinate -i git push -f' => 'caffeinate' }.each do |command, construct|
      it "asks for `#{command}`, naming #{construct}" do
        expect(guard(command))
          .to eq(['ask', "push-guard: a push behind #{construct} cannot be read; run git push on its own command " \
                         'line with the remote and refspec written out'])
      end
    end

    it 'says nothing for an opaque construct that mentions no push' do
      expect(guard('echo $(git status)')).to be_nil
    end

    it 'says nothing for a command whose words say push but not git, or git only as a path or after push' do
      commands = ['make push', 'grep -rn push git/', 'rg push /opt/git', 'ls ~/.config/git | grep push']
      expect(commands.map { |command| guard(command) }).to eq([nil] * 4)
    end

    it 'asks for a push in a segment whose quotes do not balance' do
      expect(guard('git commit -m "x; git push -f"'))
        .to eq(['ask', "push-guard: the command's quotes do not balance, so the push in it could not be read"])
    end

    it 'splits a redirection glued to a refspec as bash does, so a base branch there is still denied' do
      denied = ['deny', 'push-guard: master is a base branch; it is never rewritten or deleted']
      expect([guard('git push --force-with-lease origin master&>/dev/null'), guard('git push --delete origin master>log'),
              guard('git push --force-with-lease origin master>log'),
              guard('git push --force-with-lease origin master &>/dev/null')]).to eq([denied] * 4)
    end

    it 'splits a redirection glued to a work branch or the remote the same way' do
      repository_with_origin
      push_commit('theirs', another_author)
      expect([guard('git push --force-with-lease origin feat>log'), guard('git push origin>log --delete feat')])
        .to eq([['ask', another_on_feat]] * 2)
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
      'git --config-env=alias.st=PUSH_ALIAS st && git push' => 'alias.st',
      'git -c branch.feat2.remote=origin -c branch.feat2.merge=refs/heads/master push --force-with-lease' =>
      'branch.feat2.remote', 'git -c branch.feat.pushRemote=upstream push --force-with-lease' => 'branch.feat.pushRemote',
      %q(GIT_CONFIG_PARAMETERS="'push.default=matching'" git push --force-with-lease) => 'GIT_CONFIG_PARAMETERS',
      'GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=alias.st GIT_CONFIG_VALUE_0=push git st' => 'GIT_CONFIG_COUNT',
      'HOME=/tmp git push --force-with-lease' => 'HOME',
      'XDG_CONFIG_HOME=/tmp git push --force-with-lease' => 'XDG_CONFIG_HOME' }
      .each do |command, key|
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

  describe 'a directory it cannot follow' do
    ['cd "$d" && git push --force-with-lease', 'cd - && git push --force-with-lease',
     'cd -P x && git push --force-with-lease', 'cd a b && git push --force-with-lease',
     'pushd work && git push --force-with-lease', 'popd && git push --force-with-lease',
     '(cd /tmp); git push --force-with-lease', 'cd "$d" && cd work && git push --force-with-lease',
     'cd "$d" && git -C work push --force-with-lease', 'git --work-tree=/elsewhere push --force-with-lease',
     'git --git-dir /elsewhere/.git push --force-with-lease', 'GIT_DIR=/elsewhere git push --force-with-lease',
     'GIT_WORK_TREE=/elsewhere git push --force-with-lease'].each do |command|
      it "asks for `#{command}`, whose push it cannot place" do
        expect(guard(command)).to eq(['ask', unknown_directory])
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

    it 'reads a byte that is not UTF-8 in the command as text, deciding the push beside it' do
      stdin = event('git commit -m "x" && git push -f').b.sub('"x"', "\"\xFF\"".b)
      expect(run_hook(stdin)).to eq(['deny', bare_force])
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
