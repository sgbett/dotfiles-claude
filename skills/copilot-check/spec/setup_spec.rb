# frozen_string_literal: true

require_relative 'support/script_calls'

RSpec.describe CopilotCheck::Setup do
  include CopilotCheck::Testing::ScriptCalls

  let(:head) { CopilotCheck::Testing::GateCalls::HEAD }
  let(:start_file) { sandbox.path('pr0.json') }
  let(:rubric_file) { sandbox.path('rubric.md') }

  # The skill's argument, as the lead writes it.
  def argument_file(text = '18')
    sandbox.path('argument.txt').tap { |path| File.write(path, text) }
  end

  def arguments(argument = '18', *extra)
    ['--argument-file', argument_file(argument), '--start-file', start_file, '--rubric-file', rubric_file, *extra]
  end

  def run_setup(*arguments)
    outcome = described_class.call(arguments, runner: fake_runner)
    [outcome.exit_code, JSON.parse(outcome.to_json)]
  end

  # Every call setup makes on #18 after gh pr view, as recorded unless the
  # case changes the rubric or the latest review.
  def expect_start(rubric: nil, latest: fixture('graphql/latest-review-18.json'))
    fake_runner.expect_call(CopilotCheck::Testing::ScriptCalls::BRANCH_CHECK, stdout: "master\n")
    expect_rubric(rubric)
    expect_latest_review(latest)
  end

  def expect_resolution(number = 18, response: pr_view_response)
    expect_repo_view
    expect_pr_view(number, response: response)
  end

  it "starts on #18 as recorded: its facts, no rubric, and the mark from Copilot's latest review" do
    expect_resolution
    expect_start

    exit_code, output = run_setup(*arguments)

    expect([exit_code, output]).to eq([0, { 'status' => 'proceed',
                                            'repository' => { 'host' => 'github.com',
                                                              'name_with_owner' => 'sgbett/dotfiles-claude' },
                                            'pull_request' => { 'number' => 18, 'base' => 'master', 'is_draft' => false,
                                                                'is_cross_repository' => false },
                                            'rubric_found' => false,
                                            'high_water_mark' => CopilotCheck::Testing::ScriptCalls::REVIEWED_AT }])
    expect(JSON.parse(File.read(start_file)))
      .to eq('number' => 18, 'baseRefName' => 'master', 'isCrossRepository' => false, 'isDraft' => false)
    expect(File.read(rubric_file)).to eq('')
  end

  it 'finds the pull request from the current branch when the argument is empty or only white space' do
    ['', " \n"].each do |argument|
      expect_resolution(nil)
      expect_start
      expect(run_setup(*arguments(argument)).last['pull_request']['number']).to eq(18), argument.inspect
    end
  end

  it "saves the base branch's rubric to the rubric file, never printing it" do
    rubric = "## Do not flag\n\n- British spelling\n"
    expect_resolution
    expect_start(rubric: rubric)

    exit_code, output = run_setup(*arguments)

    expect([exit_code, output['rubric_found'], File.read(rubric_file)]).to eq([0, true, rubric])
    expect(output.to_json).not_to include('Do not flag')
  end

  it 'gives the epoch as the mark when Copilot has made no review, as on #20 recorded' do
    expect_resolution
    expect_start(latest: fixture('graphql/latest-review-20.json'))

    expect(run_setup(*arguments).last['high_water_mark']).to eq('1970-01-01T00:00:00Z')
  end

  it 'stops, without asking GitHub anything, on an argument that is no pull request number' do
    not_numbers = %w[https://github.com/sgbett/dotfiles-claude/pull/18 #18 0 sgbett/dotfiles-claude#18].push('18 19')
    not_numbers.each do |argument|
      exit_code, output = run_setup(*arguments(argument))

      expect([exit_code, output.values_at('status', 'reason')])
        .to eq([2, %w[stop not_a_pull_request_number]]), argument
    end
    expect(fake_runner.calls).to eq([])
  end

  it "stops when Copilot's latest review carries another id, writing nothing" do
    expect_resolution
    expect_start(latest: latest_review_response('2026-11-13T09:00:00Z', author: 'BOT_kgDOOtherId'))

    exit_code, output = run_setup(*arguments)

    expect([exit_code, output.values_at('status', 'reason')]).to eq([2, %w[stop copilot_id_changed]])
    expect(output['pull_request']).to eq('number' => 18)
    expect([start_file, rubric_file].map { |path| File.exist?(path) }).to eq([false, false])
  end

  describe 'on a pull request from a fork' do
    let(:fork) { pr_view_response(isCrossRepository: true) }

    it 'asks before anything else is read or written, with the yes tied to its head' do
      expect_resolution(response: fork)

      exit_code, output = run_setup(*arguments)

      expect([exit_code, output['status'], output['asks'].map { |ask| ask.values_at('reason', 'accept_with') }])
        .to eq([3, 'ask', [['fork_pull_request', ['--accept-fork', head]]]])
      expect(output['pull_request']).to eq('number' => 18, 'head' => head)
      expect(File.exist?(start_file)).to be(false)
    end

    it 'goes on once the user says yes for its head, and asks again once the head has moved' do
      expect_resolution(response: fork)
      expect_start
      expect(run_setup(*arguments('18', '--accept-fork', head)).last['pull_request']['is_cross_repository'])
        .to be(true)

      expect_resolution(response: fork.merge('headRefOid' => CopilotCheck::Testing::GateCalls::OTHER_COMMIT))
      expect(run_setup(*arguments('18', '--accept-fork', head)).first).to eq(3)
    end
  end

  it 'fails as a tool when the rubric read fails for any reason but a 404, as on a missing base' do
    expect_resolution
    fake_runner.expect_call(CopilotCheck::Testing::ScriptCalls::BRANCH_CHECK, stdout: "master\n")
    fake_runner.expect_call(CopilotCheck::Testing::ScriptCalls::RUBRIC,
                            exit_status: 1, stdout: '{"message":"No commit found for the ref master"}',
                            stderr: "gh: No commit found for the ref master (HTTP 404)\n")

    expect { run_setup(*arguments) }.to raise_error(SkillSupport::GhError, /No commit found/)
    expect(File.exist?(start_file)).to be(false)
  end

  it 'fails as a tool on a base branch that is not safe on a command line' do
    expect_resolution(response: pr_view_response(baseRefName: "release'1"))
    fake_runner.expect_call(%w[git check-ref-format --branch release'1], stdout: "release'1\n")

    expect { run_setup(*arguments) }.to raise_error(SkillSupport::InvalidIdentifier, 'invalid branch')
  end
end

RSpec.describe 'skills/copilot-check/bin/setup' do
  include CopilotCheck::Testing::ScriptCalls

  def shim_entries(pr_view_args)
    [repo_view_entry, { args: pr_view_args.drop(1), stdout_file: fixture_path('pr-view/pull-request-18.json') },
     { args: CopilotCheck::Testing::ScriptCalls::RUBRIC.drop(1), exit: 1,
       stdout_file: fixture_path('contents/rubric-not-found.json'),
       stderr: fixture('contents/rubric-not-found.stderr') },
     recorded_graphql_entry('latest-review-18')]
  end

  def arguments(argument_file)
    ['--argument-file', argument_file, '--start-file', sandbox.path('pr0.json'),
     '--rubric-file', sandbox.path('rubric.md')]
  end

  it 'starts on #18 as recorded, whatever RUBYOPT says, writing the start file promote-check reads' do
    shim = install_gh_shim(shim_entries(pr_view_call))
    argument = sandbox.path('argument.txt').tap { |path| File.write(path, "18\n") }

    exit_code, output, stderr = run_script('setup', *arguments(argument), environment: hostile_environment)

    expect([exit_code, stderr, shim.unmatched_calls]).to eq([0, '', []])
    expect(output.values_at('status', 'high_water_mark')).to eq(['proceed', CopilotCheck::Testing::ScriptCalls::REVIEWED_AT])
    expect(CopilotCheck::StartState.draft?(sandbox.path('pr0.json'), 18)).to be(false)
  end

  it 'stops with exit 2 on an argument that is no number, and fails as a tool on arguments it does not take' do
    shim = install_gh_shim([])
    argument = sandbox.path('argument.txt').tap { |path| File.write(path, 'the PR') }

    stopped = run_script('setup', *arguments(argument))
    failed = run_script('setup', '--argument-file', argument)

    expect([stopped.first, stopped[1]['reason']]).to eq([2, 'not_a_pull_request_number'])
    expect([failed.first, failed[1]]).to eq([1, nil])
    expect(failed.last).to start_with('setup: tool failure: usage: setup')
    expect(shim.calls).to eq([])
  end
end
