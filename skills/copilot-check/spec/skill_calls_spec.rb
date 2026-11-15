# frozen_string_literal: true

require 'shellwords'
require_relative 'support/script_calls'

# SKILL.md's calls of the scripts, and what it says of their files and
# output, against what the scripts take and give.
RSpec.describe "/copilot-check's calls of its scripts" do
  include CopilotCheck::Testing::ScriptCalls

  let(:skill_directory) { File.expand_path('..', __dir__) }
  let(:skill) { File.read(File.join(skill_directory, 'SKILL.md')) }
  let(:calls) { skill.scan(%r{`"\$\{CLAUDE_SKILL_DIR\}/bin/([\w-]+)" ([^`]+)`}) }
  let(:parsers) do
    { 'setup' => CopilotCheck::SetupArguments, 'threads' => CopilotCheck::ThreadsArguments,
      'rereview' => CopilotCheck::RereviewArguments, 'promote-check' => CopilotCheck::PromoteCheckArguments }
  end
  let(:values) do
    { '{pr}' => '18', '{arg}' => '18', '{scratch}' => '/scratch', '{n}' => '1', '{mark}' => '2026-11-12T20:23:51Z',
      '{outcome}' => 'converged', '{review_ids}' => '5881418347,5881467821',
      '{pull_request.head}' => CopilotCheck::Testing::GateCalls::HEAD }
  end

  # The call's arguments with each placeholder filled in, an optional flag
  # given, as the lead's shell would split them.
  def arguments(call)
    Shellwords.split(values.reduce(call.delete('[]')) { |text, (placeholder, value)| text.gsub(placeholder, value) })
  end

  # Each call of +script+, as its arguments parse.
  def parsed(script)
    calls.select { |name, _call| name == script }.map { |_name, call| parsers.fetch(script).parse(arguments(call)) }
  end

  it 'calls each of its scripts, and no other' do
    expect(calls.map(&:first).uniq).to eq(%w[setup threads rereview promote-check])
    expect(parsers.keys.map { |script| File.executable?(File.join(skill_directory, 'bin', script)) }).to all(be(true))
  end

  it 'calls each subcommand once, in the order the run takes them, as the script takes its arguments' do
    commands = calls.map { |script, call| [script, parsers.fetch(script).parse(arguments(call)).to_h[:command]] }

    expect(commands).to eq([['setup', nil], %w[threads fetch], %w[threads resolve], %w[rereview request],
                            %w[rereview watch], %w[promote-check check], %w[promote-check verify]])
  end

  it 'puts $ARGUMENTS on no call: setup reads it from the file the lead writes it to' do
    expect(skill).to include('Write `$ARGUMENTS` (empty if none) with the Write tool to `{scratch}/argument.txt`')
    expect(parsed('setup').first.argument_file).to eq('/scratch/argument.txt')
    expect(calls.map(&:last).grep(/\$ARGUMENTS/)).to be_empty
  end

  it 'hands promote-check the start file setup writes, and single-quotes every path and the mark' do
    quoted = calls.flat_map { |_script, call| call.delete('[]').scan(/(\S*\{(?:scratch|mark)\}\S*)/).flatten }

    expect(parsed('setup').first.start_file).to eq(parsed('promote-check').first.start_file)
    expect(quoted.length).to be >= 7
    expect(quoted).to all(match(/\A'[^']+'\z/))
  end

  it 'calls check and verify with what the run gives them' do
    check, = parsed('promote-check')

    expect(check.to_h.values_at(:rules_file, :reviews_without_findings, :bodies_dir))
      .to eq(['/scratch/pr-18-rules.json', [5_881_418_347, 5_881_467_821], '/scratch/pr-18-round-1'])
  end

  it "hands threads fetch and check the same round's bodies directory, and puts no thread's path on a command line" do
    fetch, = parsed('threads')
    check, = parsed('promote-check')

    expect(check.bodies_dir).to eq(fetch.bodies_dir)
    expect(skill).not_to match(/git show|\{path\}/)
  end

  it "ends the run at a stop from Phase 6's own call, rather than going by way of Phase 6 again" do
    expect(skill).to include('by way of Phase 6, with outcome `timeout` after reason `copilot_timeout`, else `stop`, ' \
                             "though a stop from Phase 6's own call ends it there.")
  end

  it 'takes the review ids only from the fetch whose body files the lead read, and holds a HOLD for the run' do
    expect(skill).to include("whose body files from the last round's `threads fetch`, round `{n}`, you read and " \
                             'found no finding in, and no others')
    expect(skill).to include('**On `HOLD`**, leave the PR as it is: the verdict is final for the run, so never run ' \
                             '`check` again.')
  end

  it "says in Phase 0 that setup stops on a pull request that isn't open, and asks about its own scripts" do
    expect(skill).to include("stops on a PR that isn't open, and asks before going on with a PR from someone else's " \
                             'fork or with scripts that may not be the reviewed ones.')
  end

  it 'names every outcome check takes, and the rules file by its keys' do
    expect(CopilotCheck::PromoteCheckArguments::OUTCOMES.reject { |outcome| skill.include?("`#{outcome}`") })
      .to be_empty
    expect([*CopilotCheck::PromotionRules::KEYS, *CopilotCheck::PromotionRules::FAILURE_KEYS]
             .reject { |key| skill.include?(%("#{key}":)) }).to be_empty
  end

  it "names in Phase 6 only fields check's output has" do
    expect_gate
    output = run_promote_check(gate_arguments).last
    phase6 = skill[skill.index('## Phase 6')..]
    named = phase6.scan(/\{((?:repository|pull_request)\.\w+)\}|`((?:pull_request)\.\w+)`/).flatten.compact.uniq

    expect(named).to include('repository.host', 'pull_request.head', 'pull_request.is_draft')
    expect(named.reject { |path| output.dig(*path.split('.')) || output.dig(*path.split('.')) == false }).to be_empty
    expect(output).to include('checks', 'reasons', 'verdict')
  end

  describe 'the fields it names of setup, threads and rereview' do
    def run(script, arguments)
      outcome = script.call(arguments, runner: fake_runner)
      JSON.parse(outcome.to_json)
    end

    def named?(field)
      skill.include?("`#{field}`")
    end

    it "are setup's" do
      expect_repo_view
      expect_pr_view
      expect_scripts_step
      expect_checkout_step
      fake_runner.expect_call(CopilotCheck::Testing::ScriptCalls::BRANCH_CHECK, stdout: "master\n")
      expect_rubric
      expect_focus
      expect_latest_review
      argument = sandbox.path('argument.txt').tap { |path| File.write(path, '18') }
      outcome = CopilotCheck::Setup.call(['--argument-file', argument, '--start-file', sandbox.path('pr0.json'),
                                          '--rubric-file', sandbox.path('rubric.md'),
                                          '--focus-file', sandbox.path('security-focus.md')],
                                         runner: fake_runner, skill_directory: scripts_skill_directory)
      output = JSON.parse(outcome.to_json)
      fields = %w[pull_request.number repository.name_with_owner repository.host pull_request.base
                  pull_request.head_branch push_remote session_only.checkout high_water_mark rubric_found]

      expect(fields.reject { |field| named?(field) && !output.dig(*field.split('.')).nil? }).to be_empty
    end

    it "are threads' and rereview's" do
      expect_repo_view
      expect_threads(threads_response('threads-3'), number: 3)
      fetched = run(CopilotCheck::ThreadsCommand, ['fetch', '--pr', '3', '--bodies-dir', sandbox.path('round-1')])
      thread = fetched['todo_threads'].first
      expect_repo_view
      expect_pull_request_id
      requested = run(CopilotCheck::Rereview, %w[request --pr 18 --dry-run])

      expect(%w[thread_id comment_id line original_line original_commit original_file body_file github_text]
               .reject { |field| named?(field) && thread.key?(field) }).to be_empty
      expect([named?('todo_reviews'), fetched['todo_reviews'].first.key?('body_file')]).to eq([true, true])
      expect([named?('copilot_on_head'), fetched.key?('copilot_on_head')]).to eq([true, true])
      expect([named?('review_request'), requested.key?('review_request')]).to eq([true, true])
    end

    it "are resolve's and watch's" do
      expect_repo_view
      expect_threads(threads_response('threads-3'), number: 3)
      resolved = run(CopilotCheck::ThreadsCommand, %w[resolve --pr 3 --dry-run])
      expect_repo_view
      expect_latest_review
      watched = run(CopilotCheck::Rereview, %w[watch --pr 18 --since 2026-11-12T20:00:00Z])

      expect([named?('changed'), resolved.key?('changed')]).to eq([true, true])
      expect([named?('submitted_at'), watched.key?('submitted_at')]).to eq([true, true])
      expect(skill).to include('`review_request` of `underway`')
      expect(CopilotCheck::ReviewRequest::UNDERWAY).to eq('underway')
    end
  end
end
