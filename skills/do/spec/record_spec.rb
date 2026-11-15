# frozen_string_literal: true

require_relative '../lib/do/checklist'
require_relative 'support/scripts_clone'

# record runs from a copy of the scripts in a checkout of their own, which
# it finds reviewed, whatever state this repository is in.
RSpec.describe 'skills/do/bin/record' do
  include Do::Testing::ScriptsClone

  let(:record) { scripts_clone('record') }
  let(:graphql) { %w[api graphql --hostname github.com --input -] }
  let(:issue) { 'sgbett/dotfiles-claude#24' }
  let(:ledger_path) { 'repos/sgbett/dotfiles-claude/issues/comments/6867069660' }
  let(:ledger) do
    JSON.parse(fixture('graphql/issue-24.json'))
        .dig('data', 'repository', 'issueOrPullRequest', 'comments', 'nodes', 0, 'body')
  end

  # gh auth status, which comes before any request to the issue's host.
  def login
    { args: %w[auth status --active --hostname github.com] }
  end

  # The request exactly as recorded, which the shim matches byte for byte.
  def issue_query
    { args: graphql, stdin: JSON.generate(JSON.parse(fixture('graphql/issue-24.request.json'))),
      stdout_file: fixture_path('graphql/issue-24.json') }
  end

  def rest(method, path, body, stdin: nil)
    { args: ['api', '--hostname', 'github.com', '-X', method, path, *(%w[--input -] if stdin)],
      stdout: JSON.generate('body' => body), **({ stdin: stdin } if stdin) }
  end

  def run_record(*arguments, environment: {})
    stdout, stderr, status = Open3.capture3(environment, record, *arguments)
    [status.exitstatus, stdout, stderr]
  end

  # What a calling directory can hand any Ruby started there: Bundler,
  # loaded against a Gemfile that names a gem which doesn't exist.
  def hostile_environment
    File.write('Gemfile', "source 'https://rubygems.org'\ngem 'skill-support-no-such-gem'\n")
    { 'RUBYOPT' => '-rbundler/setup', 'BUNDLE_GEMFILE' => File.expand_path('Gemfile') }
  end

  it 'holds the recorded issue open on its unverified boxes, a bare number through origin, whatever RUBYOPT says' do
    origin = 'https://github.com/sgbett/dotfiles-claude.git'
    system('git', 'remote', 'add', 'origin', origin, exception: true)
    shim = install_gh_shim(
      [login, { args: ['repo', 'view', origin, '--json', 'nameWithOwner,url'],
                stdout_file: fixture_path('repo-view/origin.json') },
       issue_query,
       { args: %w[api --hostname github.com -X GET repos/sgbett/dotfiles-claude/issues/24],
         stdout_file: fixture_path('rest/issue-24.json') },
       { args: %w[api --hostname github.com -X GET repos/sgbett/dotfiles-claude/rules/branches/master -f per_page=100],
         stdout_file: fixture_path('rest/branch-rules-none.json') },
       { args: %w[api --hostname github.com -X GET repos/sgbett/dotfiles-claude/contents/.github/copilot-instructions.md
                  -f ref=master],
         exit: 1, stdout_file: fixture_path('contents/rules-not-found.json'),
         stderr: fixture('contents/rules-not-found.stderr') }]
    )

    digest = Do::Checklist.scan(JSON.parse(fixture('rest/issue-24.json'))['body'], target: :issue_body).digest
    exit_code, stdout, stderr = run_record('closes', '24', '--base', 'master', '--verified-items', 'L1',
                                           '--verified-boxes', '1', '--boxes-digest', digest,
                                           environment: hostile_environment)
    output = JSON.parse(stdout)

    expect([exit_code, stderr, shim.unmatched_calls]).to eq([0, '', []])
    expect(output.values_at('status', 'criteria', 'closes_lines', 'close_by_hand'))
      .to eq(['proceed', 'issue_boxes', [], []])
    expect(output['held'])
      .to eq([{ 'reference' => '#24', 'reasons' => ['unverified_boxes'], 'unverified' => (2..11).to_a }])
    expect(output['copilot_review']).to eq('ruleset' => false, 'instructions' => false, 'signal' => false)
  end

  it 'reports the box a dry run would tick, asking gh nothing but its login and the issue query' do
    shim = install_gh_shim([login, issue_query])

    exit_code, stdout, _stderr = run_record('tick', issue, '--ledger', 'L1', '--dry-run')

    expect([exit_code, JSON.parse(stdout), shim.calls.length])
      .to eq([0, { 'status' => 'proceed', 'target' => 'ledger', 'flipped' => ['L1'], 'already' => [],
                   'dry_run' => true }, 2])
  end

  it 'ticks the ledger in place: a fresh read, the write, then the read back' do
    after = ledger.sub('- [ ] **L1 ', '- [x] **L1 ')
    shim = install_gh_shim([login, issue_query, rest('GET', ledger_path, ledger),
                            rest('PATCH', ledger_path, after, stdin: JSON.generate('body' => after)),
                            rest('GET', ledger_path, after)])

    exit_code, stdout, _stderr = run_record('tick', issue, '--ledger', 'L1')

    expect([exit_code, JSON.parse(stdout)['flipped'], shim.unmatched_calls]).to eq([0, ['L1'], []])
    expect(shim.calls.map { |call| call['args'][3] == '-X' ? call['args'][4] : call['args'][1] })
      .to eq(%w[status graphql GET PATCH GET])
  end

  it 'stops, writing nothing, when the ledger changed since the read' do
    shim = install_gh_shim([login, issue_query, rest('GET', ledger_path, "#{ledger}\nEdited meanwhile.\n")])

    exit_code, stdout, _stderr = run_record('tick', issue, '--ledger', 'L1')

    expect([exit_code, JSON.parse(stdout)['reason'], shim.unmatched_calls.length]).to eq([2, 'body_changed', 0])
  end

  it "files a gate finding in this checkout's common git directory, 0600, printing only its k" do
    finding = sandbox.path('finding.md')
    File.write(finding, "The unfixed flaw in detail.\n")
    install_gh_shim([login, issue_query])

    exit_code, stdout, _stderr = run_record('gate', 'add', issue, '--finding-file', finding)
    gate_file = File.join(sandbox.work_directory, '.git', 'do', 'I_kwDOQzoXSs8AAAABfBUanQ-gate.md')

    expect([exit_code, JSON.parse(stdout)]).to eq([0, { 'status' => 'proceed', 'k' => 'G1' }])
    expect([File.stat(gate_file).mode & 0o777, File.read(gate_file)])
      .to eq([0o600, "## G1: open\n\n```\nThe unfixed flaw in detail.\n```\n"])
  end

  it 'fails as a tool on any arguments it does not take, printing its usage' do
    install_gh_shim([])

    [[], %w[close 24], %w[closes 24], %w[tick 24 --ledger L1 --issue-boxes 1], %w[--help]].each do |arguments|
      exit_code, stdout, stderr = run_record(*arguments)

      expect([exit_code, stdout]).to eq([1, '']), arguments.inspect
      expect(stderr).to start_with('record: tool failure: usage: record closes <issue>'), arguments.inspect
    end
  end
end
