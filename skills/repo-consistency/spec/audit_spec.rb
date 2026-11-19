# frozen_string_literal: true

require_relative 'support/recorded_run'
require_relative 'support/repository_answers'
require_relative 'support/script_calls'
require_relative 'support/template_fixture'
require_relative '../lib/repo_consistency/audit'

RSpec.describe RepoConsistency::Audit do
  include RepoConsistency::Testing::RecordedRun
  include RepoConsistency::Testing::TemplateFixture

  let(:messages) { RepoConsistency::Reasons::MESSAGES }
  let(:header) { RepoConsistency::Testing::TemplateFixture::HEADER }
  let(:profile) { RepoConsistency::Testing::TemplateFixture::PROFILE }
  let(:bypass) { [{ 'actor_id' => 5, 'actor_type' => 'RepositoryRole', 'bypass_mode' => 'always' }] }
  let(:hook_command) { RepoConsistency::Testing::TemplateFixture::HOOK_COMMAND }

  # A settings file whose one PreToolUse entry runs +command+ on Bash.
  def settings_running(command)
    JSON.generate('hooks' => { 'PreToolUse' => [{ 'matcher' => 'Bash',
                                                  'hooks' => [{ 'type' => 'command', 'command' => command }] }] })
  end

  def run_audit(*arguments, template_dir: template_directory)
    outcome = described_class.call(['audit', *arguments, '--template-dir', template_dir], runner: fake_runner)
    [outcome.exit_code, JSON.parse(outcome.to_json)]
  end

  # A repository compliant with the template fixture, for a spec to change.
  def answers(repository = 'example-owner/app', **fields)
    RepoConsistency::Testing::RepositoryAnswers.new(repository, **fields)
  end

  # The login, then each repository's reads, in order.
  def expect_audit(*repositories)
    expect_gh_login
    repositories.each { |answers| expect_entries(answers.entries) }
  end

  def audit(*repositories)
    expect_audit(*repositories)
    run_audit(*repositories.map(&:repository)).last['repositories']
  end

  def drift_of(*repositories)
    audit(*repositories).map { |entry| entry['drift'] }
  end

  it 'reports sgbett/bsv-ruby-sdk as recorded: undeclared, on master, differing from the template in every way ' \
     'but the merge-commit and update-branch flags' do
    expect_gh_login
    expect_entries(recorded_entries)

    exit_code, output = run_audit('sgbett/bsv-ruby-sdk')

    expect([exit_code, output])
      .to eq([0, { 'status' => 'proceed', 'summary' => { 'repositories' => 1, 'with_drift' => 1, 'clean' => 0 },
                   'repositories' => [{ 'repository' => 'sgbett/bsv-ruby-sdk', 'default_branch' => 'master',
                                        'tier' => 'undeclared', 'difference' => nil, 'drift' => recorded_drift }] }])
  end

  it 'finds no drift in a collaborative repository that applied the template and vendored its files, and counts ' \
     'the clean and drifting ones in the order given' do
    clean = answers('example-owner/clean')
    drifting = answers('example-owner/drifting')
    drifting.flags['allow_update_branch'] = true
    expect_audit(clean, drifting)

    exit_code, output = run_audit(clean.repository, drifting.repository)

    expect([exit_code, output['summary']]).to eq([0, { 'repositories' => 2, 'with_drift' => 1, 'clean' => 1 }])
    expect(output['repositories'])
      .to eq([{ 'repository' => 'example-owner/clean', 'default_branch' => 'master', 'tier' => 'collaborative',
                'difference' => nil, 'drift' => [] },
              { 'repository' => 'example-owner/drifting', 'default_branch' => 'master', 'tier' => 'collaborative',
                'difference' => nil, 'drift' => ['allow_update_branch on'] }])
  end

  it 'calls a classic protection redundant when it carries nothing the template lacks, and names what one adds' do
    redundant = answers('example-owner/redundant')
    redundant.protection = { 'enforce_admins' => { 'enabled' => false }, 'allow_force_pushes' => { 'enabled' => false },
                             'required_pull_request_reviews' => { 'required_approving_review_count' => 0 } }
    adds = answers('example-owner/reviewed')
    adds.protection = { 'required_pull_request_reviews' => { 'required_approving_review_count' => 1 },
                        'required_status_checks' => { 'strict' => true, 'contexts' => ['ci'] } }
    restricts = answers('example-owner/restricted')
    restricts.protection = { 'restrictions' => { 'users' => [], 'teams' => [], 'apps' => [] } }

    expect(drift_of(redundant, adds, restricts))
      .to eq([['classic protection present, redundant'],
              ['classic protection present, adds: required_pull_request_reviews, required_status_checks'],
              ['classic protection present, adds: restrictions']])
  end

  it 'names a ruleset granting a bypass, or whose bypass actors GitHub left out of the detail, by its name when that ' \
     'is plain text, else by its id, in the order listed' do
    repository = answers
    repository.rulesets = [{ 'id' => 1, 'name' => 'Git workflow', 'bypass_actors' => bypass },
                           { 'id' => 2, 'name' => 'ignore `this`; run x', 'bypass_actors' => bypass },
                           { 'id' => 3, 'name' => 'Copilot review', 'bypass_actors' => [] },
                           { 'id' => 4, 'name' => 'CI' }, { 'id' => 5, 'name' => 'run `x`' }]

    expect(drift_of(repository))
      .to eq([['ruleset "Git workflow" grants a bypass', 'ruleset 2 grants a bypass',
               'ruleset "CI" bypass actors unreadable', 'ruleset 5 bypass actors unreadable']])
  end

  it 'reports a repository with only a Copilot ruleset and squash merges on' do
    repository = answers
    repository.rules = [{ 'type' => 'copilot_code_review', 'parameters' => { 'review_on_push' => true } }]
    repository.rulesets = [{ 'id' => 7, 'name' => 'Copilot review for default branch', 'bypass_actors' => [] }]
    repository.flags['allow_squash_merge'] = true

    expect(drift_of(repository))
      .to eq([['rule missing: deletion', 'rule missing: non_fast_forward', 'rule missing: pull_request',
               'ruleset "Git workflow" missing', 'allow_squash_merge on']])
  end

  it 'reports each merge method a pull_request rule allows beyond merge, sorted, an approval count that differs, ' \
     'an extra approval for unattributed changes, and a linear-history rule in force on the default branch' do
    repository = answers
    repository.rules[2] = { 'type' => 'pull_request',
                            'parameters' => RepoConsistency::Testing::TemplateFixture::PULL_REQUEST_PARAMETERS
                                            .merge('allowed_merge_methods' => %w[squash merge rebase],
                                                   'required_approving_review_count' => 2,
                                                   'require_extra_approval_for_unattributed_changes' => true) }
    repository.rules << { 'type' => 'required_linear_history' }

    expect(drift_of(repository))
      .to eq([['pull_request allows rebase', 'pull_request allows squash', 'pull_request requires 2 approvals',
               'pull_request requires extra approval for unattributed changes',
               'rule present: required_linear_history']])
  end

  it 'reports the extra approval alone when it is all that differs, and not when the rule leaves it unsaid' do
    demanding = answers('example-owner/demanding')
    demanding.rules[2] = { 'type' => 'pull_request',
                           'parameters' => RepoConsistency::Testing::TemplateFixture::PULL_REQUEST_PARAMETERS
                                           .merge('require_extra_approval_for_unattributed_changes' => true) }
    unsaid = answers('example-owner/unsaid')
    unsaid.rules[2] = { 'type' => 'pull_request',
                        'parameters' => RepoConsistency::Testing::TemplateFixture::PULL_REQUEST_PARAMETERS
                                        .except('require_extra_approval_for_unattributed_changes') }

    expect(drift_of(demanding, unsaid)).to eq([['pull_request requires extra approval for unattributed changes'], []])
  end

  it 'holds a personal repository to its declaration alone: pull_request rules on its default branch are drift, ' \
     'and nothing else is looked at' do
    ruled = answers('example-owner/notes')
    ruled.files = { 'CLAUDE.md' => "# Notes\n\nGit tier: personal; issue-tracked work goes by PR\n" }
    plain = answers('example-owner/scratch')
    plain.files = { 'CLAUDE.md' => "Git tier: personal\n" }
    plain.rules = []
    plain.rulesets = []
    plain.flags['allow_squash_merge'] = true

    expect(audit(ruled, plain))
      .to eq([{ 'repository' => 'example-owner/notes', 'default_branch' => 'master', 'tier' => 'personal',
                'difference' => 'issue-tracked work goes by PR',
                'drift' => ['tier line says personal but the default branch has pull_request rules'] },
              { 'repository' => 'example-owner/scratch', 'default_branch' => 'master', 'tier' => 'personal',
                'difference' => nil, 'drift' => [] }])
  end

  it 'reports a default branch other than master, having read the rules, protection and files on that branch' do
    expect(drift_of(answers('example-owner/main-line', branch: 'main'))).to eq([['default branch is main']])
  end

  it 'reads the tier line anywhere in a line, a difference in backticks ending at the closing one' do
    repository = answers
    repository.files['CLAUDE.md'] = "## Plans\n\n- **Tier:** `Git tier: collaborative; releases by tag` (see above).\n"

    entry, = audit(repository)

    expect(entry.values_at('tier', 'difference', 'drift')).to eq(['collaborative', 'releases by tag', []])
  end

  it 'reports an undeclared tier against the template, and a missing CLAUDE.md as undeclared' do
    no_line = answers('example-owner/no-line')
    no_line.files['CLAUDE.md'] = "# Project\n\nNothing about git.\n"
    no_file = answers('example-owner/no-file')
    no_file.files.delete('CLAUDE.md')

    expect(audit(no_line, no_file).map { |entry| entry.values_at('tier', 'drift') })
      .to eq([['undeclared', ['tier line undeclared']], ['undeclared', ['tier line undeclared']]])
  end

  it 'compares the vendored rules file to the profile after its two header lines, and its first line to the ' \
     'convention' do
    changed = answers('example-owner/changed')
    changed.files[RepoConsistency::VendoredPaths::RULES_FILE] = header + profile.sub('All changes', 'Most changes')
    other_header = answers('example-owner/other-header')
    other_header.files[RepoConsistency::VendoredPaths::RULES_FILE] = "<!-- copied from elsewhere -->\n\n#{profile}"
    third_line = answers('example-owner/third-line')
    third_line.files[RepoConsistency::VendoredPaths::RULES_FILE] = "#{header}<!-- a third header line -->\n#{profile}"
    missing = answers('example-owner/missing')
    missing.files.delete(RepoConsistency::VendoredPaths::RULES_FILE)

    expect(drift_of(changed, other_header, third_line, missing))
      .to eq([['vendored rules file differs from the profile'], ['vendored rules header is not the convention'],
              ['vendored rules file differs from the profile'], ['vendored rules file missing']])
  end

  it 'reports each vendored hook missing or differing, and the settings entry missing or the file unreadable' do
    hooks = answers('example-owner/hooks')
    hooks.files.delete('.claude/hooks/push-guard')
    hooks.files['.claude/hooks/push-guard.rb'] += "# changed\n"
    hooks.files['.claude/settings.json'] = settings_running('echo other')
    unreadable = answers('example-owner/unreadable')
    unreadable.files['.claude/settings.json'] = '{not json'
    no_settings = answers('example-owner/no-settings')
    no_settings.files.delete('.claude/settings.json')

    expect(drift_of(hooks, unreadable, no_settings))
      .to eq([['vendored hook missing: push-guard', 'vendored hook differs: push-guard.rb',
               'hooks entry missing from .claude/settings.json'],
              ['settings.json unreadable'], ['hooks entry missing from .claude/settings.json']])
  end

  it "accepts a settings file whose PreToolUse holds other hooks beside the template's entry" do
    repository = answers
    lint = { 'matcher' => 'Edit', 'hooks' => [{ 'type' => 'command', 'command' => 'lint' }] }
    guard = { 'matcher' => 'Bash', 'hooks' => [{ 'type' => 'command', 'command' => hook_command }] }
    repository.files['.claude/settings.json'] = JSON.generate('permissions' => { 'allow' => ['Bash(ls:*)'] },
                                                              'hooks' => { 'PreToolUse' => [lint, guard] })

    expect(drift_of(repository)).to eq([[]])
  end

  it 'reports rulesets unavailable on the 403 naming the plan, once, and goes on with the files' do
    repository = answers('example-owner/private-free')
    repository.plan_forbids = true

    expect(drift_of(repository))
      .to eq([['rulesets unavailable on this plan', 'rule missing: deletion', 'rule missing: non_fast_forward',
               'rule missing: pull_request', 'ruleset "Git workflow" missing']])
  end

  describe 'skills named but not shipped' do
    let(:unshipped) { "names a skill it doesn't ship:" }

    def link(path, mode: '120000', type: 'blob')
      { 'path' => path, 'mode' => mode, 'type' => type, 'sha' => '0' * 40 }
    end

    it 'reports each user-level skill CLAUDE.md or .claude/CLAUDE.md names that the repository lacks, one line per ' \
       'name, sorted, after every other line' do
      repository = answers
      repository.files['CLAUDE.md'] += "Run `/do` on each issue; /do's breakdown is the record.\n"
      repository.files['.claude/CLAUDE.md'] = "Ask specialist-review, then /do. Do not skip it.\n"
      repository.flags['allow_update_branch'] = true

      expect(drift_of(repository))
        .to eq([['allow_update_branch on', "#{unshipped} do", "#{unshipped} specialist-review"]])
    end

    it 'scans the vendored rules file and every Markdown file under .claude/rules/ at any depth, and nothing else ' \
       'there' do
      repository = answers
      repository.files['.claude/rules/team/review/finish.md'] = "Finish with /copilot-check.\n"
      repository.files['.claude/rules/notes.txt'] = "Run /zendesk.\n"
      repository.files['docs/guide.md'] = "Run /deslop.\n"
      repository.files[RepoConsistency::VendoredPaths::RULES_FILE] += "Then /transcript.\n"

      expect(drift_of(repository)).to eq([['vendored rules file differs from the profile', "#{unshipped} copilot-check",
                                           "#{unshipped} transcript"]])
    end

    it 'counts a skill shipped as a directory under .claude/skills/, or a command as a file under ' \
       '.claude/commands/, a nested one by its path, and a link anywhere else, or to a skill of its own, as nothing' do
      as_skill = answers('example-owner/as-skill')
      as_skill.files['CLAUDE.md'] += "Run /do.\n"
      as_skill.files['.claude/skills/do/SKILL.md'] = "---\nname: do\n---\n"
      as_skill.tree.extras = [link('.claude/skills/do/scripts'), link('.claude/skills/my-tool'),
                              link('vendor/tools', mode: '160000', type: 'commit')]
      as_command = answers('example-owner/as-command')
      as_command.files['CLAUDE.md'] += "Run /do, then /project:generate.\n"
      as_command.files['.claude/commands/do.md'] = "Work the issue.\n"
      as_command.files['.claude/commands/project/generate.md'] = "Generate the project.\n"
      as_page = answers('example-owner/as-page')
      as_page.files['CLAUDE.md'] += "Run /do.\n"
      as_page.files['.claude/skills/do.md'] = "Not a skill: a skill is a directory.\n"

      expect(drift_of(as_skill, as_command, as_page)).to eq([[], [], ["#{unshipped} do"]])
    end

    it 'scans instruction files whatever their case, as a case-insensitive file system loads them' do
      repository = answers
      repository.files['claude.md'] = "Run /do.\n"
      repository.files['.claude/Rules/Team.MD'] = "Finish with /copilot-check.\n"

      expect(drift_of(repository)).to eq([["#{unshipped} copilot-check", "#{unshipped} do"]])
    end

    it 'reads a symlinked instruction file through the contents API, and counts a symlinked command file as shipped' do
      agents = answers('example-owner/agents')
      agents.files['CLAUDE.md'] += "Run /do.\n"
      agents.files['AGENTS.md'] = agents.files['CLAUDE.md']
      agents.files['.claude/commands/do.md'] = "Work the issue.\n"
      agents.tree.symlinked = ['CLAUDE.md', '.claude/commands/do.md']
      shared = answers('example-owner/shared')
      shared.files['.claude/rules/shared.md'] = "Finish with /copilot-check.\n"
      shared.tree.symlinked = ['.claude/rules/shared.md']

      expect(drift_of(agents, shared)).to eq([[], ["#{unshipped} copilot-check"]])
    end

    it 'reads up to 200 instruction files it has not read already, and none of more, reporting those unchecked' do
      rules = ->(count) { (1..count).to_h { |index| [format('.claude/rules/rule-%03d.md', index), "A rule.\n"] } }
      within = answers('example-owner/within')
      within.files.merge!(rules.call(200), '.claude/rules/rule-200.md' => "Run /do.\n")
      over = answers('example-owner/over')
      over.files.merge!(rules.call(201), '.claude/rules/rule-201.md' => "Run /do.\n")
      rule_read = ->(answer) { answer[:args].any? { |argument| argument.include?('/contents/.claude/rules/rule-') } }
      expect_gh_login
      expect_entries(within.entries)
      expect_entries(over.entries.reject(&rule_read))

      output = run_audit(within.repository, over.repository).last

      expect(output['repositories'].map { |entry| entry['drift'] })
        .to eq([["#{unshipped} do"], ['skill names unchecked: too many instruction files']])
      expect(fake_runner.calls.count { |call| rule_read.call(args: call[:argv].drop(1)) }).to eq(200)
    end

    it 'neither reads nor reports anything more of a personal repository' do
      repository = answers
      repository.files = { 'CLAUDE.md' => "Git tier: personal\n\nRun /do, then specialist-review.\n" }
      repository.rules = []
      repository.rulesets = []

      expect(drift_of(repository)).to eq([[]])
      expect(fake_runner.calls.last[:argv])
        .to eq(contents_call(repository.repository, RepoConsistency::VendoredPaths::SETTINGS_FILE, 'master'))
    end

    it 'reports the names unchecked, and goes on to the next repository, on a truncated root or .claude tree, a ' \
       'symlinked directory or a submodule where it looks, or an instruction file the contents API will not give' do
      root_cut = answers('example-owner/root-cut')
      root_cut.tree.truncated = :root
      claude_cut = answers('example-owner/claude-cut')
      claude_cut.tree.truncated = :claude
      linked = answers('example-owner/linked')
      linked.tree.extras = [link('.claude/skills/do')]
      submodule = answers('example-owner/submodule')
      submodule.tree.extras = [link('.claude/rules/shared', mode: '160000', type: 'commit')]
      oversized = answers('example-owner/oversized')
      oversized.files['.claude/rules/handbook.md'] = "Run /do.\n"
      oversized.tree.oversized = ['.claude/rules/handbook.md']
      escaping = answers('example-owner/escaping')
      escaping.files['.claude/rules/outside.md'] = ''
      escaping.tree.escaping = ['.claude/rules/outside.md']
      readable = answers('example-owner/readable')
      repositories = [root_cut, claude_cut, linked, submodule, oversized, escaping, readable]
      repositories.each { |repository| repository.files['CLAUDE.md'] += "/do\n" }

      expect(drift_of(*repositories))
        .to eq([['skill names unchecked: tree truncated'], ['skill names unchecked: tree truncated'],
                ['skill names unchecked: symlink or submodule'],
                ['skill names unchecked: symlink or submodule'],
                ['skill names unchecked: file too large or not a file'],
                ['skill names unchecked: file too large or not a file'], ["#{unshipped} do"]])
    end
  end

  describe 'stops' do
    it 'stops on no repository, asking GitHub nothing' do
      exit_code, output = run_audit

      expect([exit_code, output]).to eq([2, { 'status' => 'stop', 'reason' => 'no_repositories',
                                              'message' => messages[:no_repositories] }])
      expect(fake_runner.calls).to eq([])
    end

    it 'stops once when gh has no account on the host, naming it, before reading any repository' do
      expect_gh_login(logged_in: false)

      exit_code, output = run_audit('example-owner/a', 'example-owner/b')

      expect([exit_code, output]).to eq([2, { 'status' => 'stop', 'reason' => 'not_logged_in',
                                              'message' => messages[:not_logged_in], 'host' => 'github.com' }])
    end

    it 'audits the host --hostname names, which the login is checked on' do
      expect_gh_login('ghe.example.com', logged_in: false)

      output = run_audit('example-owner/a', '--hostname', 'ghe.example.com').last

      expect(output.values_at('reason', 'host')).to eq(['not_logged_in', 'ghe.example.com'])
    end

    it 'stops on a template file missing, not JSON or not a JSON object, naming it, before asking GitHub anything' do
      broken = { 'hooks/push-guard' => nil, 'ruleset.json' => '{', 'repository.json' => '[]',
                 '../git-workflow.md' => nil }
      broken.each do |file, text|
        directory = write_template(sandbox.path('broken', File.basename(file, '.*'), 'git-workflow'))
        path = File.join(directory, file)
        text ? File.write(path, text) : File.delete(path)

        exit_code, output = run_audit('example-owner/a', template_dir: directory)

        expect([exit_code, output]).to eq([2, { 'status' => 'stop', 'reason' => 'template_unreadable',
                                                'message' => messages[:template_unreadable], 'file' => file }]), file
      end
      expect(fake_runner.calls).to eq([])
    end

    it 'stops on the first repository gh cannot read, 404 or 403, naming it, having audited the ones before' do
      { 404 => 'Not Found', 403 => 'Resource not accessible by personal access token' }.each do |status, message|
        clean = answers('example-owner/clean')
        expect_audit(clean)
        expect_entries([entry(repository_call('example-owner/gone'), **unreadable_answer(status, message))])

        exit_code, output = run_audit(clean.repository, 'example-owner/gone')

        expect([exit_code, output]).to eq([2, { 'status' => 'stop', 'reason' => 'repository_unreadable',
                                                'message' => messages[:repository_unreadable],
                                                'repository' => 'example-owner/gone' }]), status.to_s
      end
    end
  end

  describe 'tool failures' do
    it 'fails on a subcommand it lacks, a flag it does not take, a flag without its value, or a repeated one' do
      [%w[inspect example-owner/a], %w[audit example-owner/a --verbose], %w[audit example-owner/a --hostname],
       %w[audit --hostname github.com --hostname github.com example-owner/a], []].each do |arguments|
        expect { described_class.call(arguments, runner: fake_runner) }
          .to raise_error(RepoConsistency::UsageError, /\Ausage: git-settings audit/), arguments.inspect
      end
    end

    it 'fails on a repository name or a host that is not valid, before anything runs' do
      expect { run_audit('example-owner') }.to raise_error(SkillSupport::InvalidIdentifier, 'invalid repository')
      expect { run_audit('example-owner/a', '--hostname', 'not a host') }
        .to raise_error(SkillSupport::InvalidIdentifier, 'invalid host')
      expect(fake_runner.calls).to eq([])
    end

    it 'fails on any other gh error, such as bad credentials on a ruleset read' do
      repository = answers
      entries = repository.entries
      entries[1] = entry(rules_call(repository.repository, 'master'), exit: 1, stdout: '{"message":"Bad credentials"}',
                                                                      stderr: "gh: Bad credentials (HTTP 401)\n")
      expect_gh_login
      expect_entries(entries.first(2))

      expect { run_audit(repository.repository) }.to raise_error(SkillSupport::GhError, /HTTP 401/)
    end

    it 'fails on a 404 from the protection read that does not say the branch is unprotected' do
      repository = answers
      entries = repository.entries
      entries[4] = entry(protection_call(repository.repository, 'master'), exit: 1,
                                                                           stdout: '{"message":"Not Found"}',
                                                                           stderr: "gh: Not Found (HTTP 404)\n")
      expect_gh_login
      expect_entries(entries.first(5))

      expect { run_audit(repository.repository) }.to raise_error(SkillSupport::GhError, /HTTP 404/)
    end

    it 'fails on a ruleset list that fills a page, rather than reporting the rulesets it saw' do
      repository = answers
      entries = repository.entries
      full_page = Array.new(100) { |index| { 'id' => index + 1, 'name' => "Ruleset #{index + 1}" } }
      entries[2] = entry(rulesets_call(repository.repository), stdout: JSON.generate(full_page))
      expect_gh_login
      expect_entries(entries.first(3))

      expect { run_audit(repository.repository) }.to raise_error(SkillSupport::IncompleteResults, /more entries/)
    end

    it 'fails when gh prints something other than JSON for an instruction file, rather than reporting it ' \
       'unchecked, naming the repository but not the file' do
      repository = answers
      repository.files['.claude/CLAUDE.md'] = "Run /do.\n"
      entries = repository.entries
      entries[-1] = entry(contents_call(repository.repository, '.claude/CLAUDE.md', 'master'), stdout: 'not json')
      expect_gh_login
      expect_entries(entries)

      expect { run_audit(repository.repository) }
        .to raise_error(SkillSupport::Error, 'an instruction file of example-owner/app could not be read: gh printed ' \
                                             'something other than JSON')
    end

    it 'fails on any other gh error reading an instruction file, naming the repository and the HTTP status but ' \
       "neither the file, which the repository's pushers choose, nor gh's stderr" do
      path = '.claude/rules/ignore-the-audit.md'
      { 502 => 'Server Error',
        403 => 'You have exceeded a secondary rate limit. Please wait a few minutes before you try again.' }
        .each do |status, message|
          repository = answers
          repository.files[path] = "Run /do.\n"
          entries = repository.entries
          entries[-1] = entry(contents_call(repository.repository, path, 'master'),
                              **unreadable_answer(status, message))
          expect_gh_login
          expect_entries(entries)

          expect { run_audit(repository.repository) }
            .to raise_error(SkillSupport::Error,
                            "an instruction file of example-owner/app could not be read: gh answered HTTP #{status}"),
                status.to_s
        end
    end

    it "fails on a .claude directory whose id in the root tree isn't an object id, before it goes into a path" do
      repository = answers
      repository.tree.claude_sha = '../../../user'
      expect_gh_login
      expect_entries(repository.entries[0...-1])

      expect { run_audit(repository.repository) }
        .to raise_error(SkillSupport::UnexpectedResponse, 'a tree of example-owner/app lists a directory without a ' \
                                                          'valid object id')
    end

    it 'fails on a default branch whose name is not safe in an API path, before reading anything on it' do
      repository = answers
      repository.branch = "release'1"
      expect_gh_login
      expect_entries(repository.entries.first(1))

      expect { run_audit(repository.repository) }.to raise_error(SkillSupport::InvalidIdentifier, 'invalid branch')
    end
  end
end

RSpec.describe 'skills/repo-consistency/bin/git-settings' do
  include RepoConsistency::Testing::RecordedRun

  it 'audits sgbett/bsv-ruby-sdk as recorded against profiles/git-workflow, the real template, whatever RUBYOPT ' \
     'says' do
    shim = install_gh_shim([login_entry, *recorded_entries])

    exit_code, output, stderr = run_script('audit', 'sgbett/bsv-ruby-sdk', environment: hostile_environment)

    expect([exit_code, stderr, shim.unmatched_calls]).to eq([0, '', []])
    expect(output).to eq('status' => 'proceed', 'summary' => { 'repositories' => 1, 'with_drift' => 1, 'clean' => 0 },
                         'repositories' => [{ 'repository' => 'sgbett/bsv-ruby-sdk', 'default_branch' => 'master',
                                              'tier' => 'undeclared', 'difference' => nil,
                                              'drift' => recorded_drift }])
  end

  it 'stops with exit 2 when gh has no account on the host, calling nothing else' do
    shim = install_gh_shim([login_entry(logged_in: false)])

    exit_code, output, stderr = run_script('audit', 'sgbett/bsv-ruby-sdk')

    expect([exit_code, stderr, output.values_at('status', 'reason', 'host'), shim.unmatched_calls])
      .to eq([2, '', %w[stop not_logged_in github.com], []])
  end

  it 'stops with exit 2 on no repository, calling gh not at all, and fails as a tool on arguments it does not take' do
    shim = install_gh_shim([])

    stopped = run_script('audit')
    failed = run_script('inspect', 'sgbett/bsv-ruby-sdk')

    expect([stopped.first, stopped[1]['reason']]).to eq([2, 'no_repositories'])
    expect([failed.first, failed[1]]).to eq([1, nil])
    expect(failed.last).to start_with('git-settings: tool failure: usage: git-settings audit')
    expect(shim.calls).to eq([])
  end
end
