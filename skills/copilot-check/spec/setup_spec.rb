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
    outcome = described_class.call(arguments, runner: fake_runner, skill_directory: scripts_skill_directory)
    [outcome.exit_code, JSON.parse(outcome.to_json)]
  end

  # Every call setup makes on #18 after gh pr view, as recorded unless the
  # case changes the rubric or the latest review.
  def expect_start(rubric: nil, latest: fixture('graphql/latest-review-18.json'))
    expect_scripts_step
    fake_runner.expect_call(CopilotCheck::Testing::ScriptCalls::BRANCH_CHECK, stdout: "master\n")
    expect_rubric(rubric)
    expect_latest_review(latest)
  end

  def expect_resolution(number = 18, response: open_pr_view_response)
    expect_repo_view
    expect_pr_view(number, response: response)
  end

  it "starts on #18 as recorded, open: its facts, no rubric, the mark from Copilot's latest review, and the " \
     'start file with its repository' do
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
      .to eq('number' => 18, 'repository' => 'github.com/sgbett/dotfiles-claude', 'baseRefName' => 'master',
             'isCrossRepository' => false, 'isDraft' => false)
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

  it 'stops on #18 as recorded, merged, and on a closed pull request, reading and writing nothing more' do
    { pr_view_response => 'MERGED', open_pr_view_response(state: 'CLOSED') => 'CLOSED' }.each do |response, state|
      expect_resolution(response: response)

      exit_code, output = run_setup(*arguments)

      expect([exit_code, output.values_at('status', 'reason', 'message', 'pull_request')])
        .to eq([2, ['stop', 'pull_request_not_open', CopilotCheck::Reasons::MESSAGES[:pull_request_not_open],
                    { 'number' => 18, 'state' => state }]]), state
    end
    expect([start_file, rubric_file].map { |path| File.exist?(path) }).to eq([false, false])
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
    let(:fork) { open_pr_view_response(isCrossRepository: true) }

    it 'asks before anything else is read or written, with the yes tied to its head' do
      expect_resolution(response: fork)
      expect_scripts_step

      exit_code, output = run_setup(*arguments)

      expect([exit_code, output['status'], output['asks'].map { |ask| ask.values_at('reason', 'accept_with') }])
        .to eq([3, 'ask', [['fork_pull_request', ['--accept-fork', head]]]])
      expect(output['pull_request']).to eq('number' => 18, 'head' => head)
      expect(output).not_to include('session_only')
      expect(File.exist?(start_file)).to be(false)
    end

    it 'goes on once the user says yes for its head, and asks again once the head has moved' do
      expect_resolution(response: fork)
      expect_start
      expect(run_setup(*arguments('18', '--accept-fork', head)).last['pull_request']['is_cross_repository'])
        .to be(true)

      expect_resolution(response: fork.merge('headRefOid' => CopilotCheck::Testing::GateCalls::OTHER_COMMIT))
      expect_scripts_step
      expect(run_setup(*arguments('18', '--accept-fork', head)).first).to eq(3)
    end
  end

  it 'fails as a tool when the rubric read fails for any reason but a 404, as on a missing base' do
    expect_resolution
    expect_scripts_step
    fake_runner.expect_call(CopilotCheck::Testing::ScriptCalls::BRANCH_CHECK, stdout: "master\n")
    fake_runner.expect_call(CopilotCheck::Testing::ScriptCalls::RUBRIC,
                            exit_status: 1, stdout: '{"message":"No commit found for the ref master"}',
                            stderr: "gh: No commit found for the ref master (HTTP 404)\n")

    expect { run_setup(*arguments) }.to raise_error(SkillSupport::GhError, /No commit found/)
    expect(File.exist?(start_file)).to be(false)
  end

  it 'fails as a tool on a base branch that is not safe on a command line' do
    expect_resolution(response: open_pr_view_response(baseRefName: "release'1"))
    expect_scripts_step
    fake_runner.expect_call(%w[git check-ref-format --branch release'1], stdout: "release'1\n")

    expect { run_setup(*arguments) }.to raise_error(SkillSupport::InvalidIdentifier, 'invalid branch')
  end
end

RSpec.describe 'skills/copilot-check/bin/setup' do
  include CopilotCheck::Testing::ScriptCalls
  include SkillSupport::Testing::SkillClone

  let(:clone) { skill_clone('copilot-check') }
  let(:argument) { sandbox.path('argument.txt').tap { |path| File.write(path, "18\n") } }

  # #18 open, unless +response+ gives another, then its rubric and mark, as
  # recorded.
  def shim_entries(response = open_pr_view_response)
    [repo_view_entry.merge(repeat: true),
     { args: pr_view_call.drop(1), stdout: as_json(response), repeat: true },
     { args: CopilotCheck::Testing::ScriptCalls::RUBRIC.drop(1), exit: 1,
       stdout_file: fixture_path('contents/rubric-not-found.json'),
       stderr: fixture('contents/rubric-not-found.stderr') },
     recorded_graphql_entry('latest-review-18')]
  end

  def arguments(argument_file, *extra)
    ['--argument-file', argument_file, '--start-file', sandbox.path('pr0.json'),
     '--rubric-file', sandbox.path('rubric.md'), *extra]
  end

  it 'starts on #18, open, from a reviewed copy of its scripts, whatever RUBYOPT says, writing the start file ' \
     'promote-check reads' do
    shim = install_gh_shim(shim_entries)

    exit_code, output, stderr = run_script('setup', *arguments(argument), skill: clone,
                                                                          environment: hostile_environment)
    repository = CopilotCheck::CheckoutRepository::Repository.new(host: 'github.com',
                                                                  name_with_owner: 'sgbett/dotfiles-claude')

    expect([exit_code, stderr, shim.unmatched_calls]).to eq([0, '', []])
    expect(output.values_at('status', 'high_water_mark'))
      .to eq(['proceed', CopilotCheck::Testing::ScriptCalls::REVIEWED_AT])
    expect(CopilotCheck::StartState.read(sandbox.path('pr0.json'), 18).draft?(repository)).to be(false)
  end

  it 'stops on #18 as recorded, merged, before looking at its own scripts' do
    shim = install_gh_shim([repo_view_entry, { args: pr_view_call.drop(1),
                                               stdout_file: fixture_path('pr-view/pull-request-18.json') }])
    File.write(File.join(clone, 'lib', 'unreviewed.rb'), "# not reviewed\n")

    exit_code, output, stderr = run_script('setup', *arguments(argument), skill: clone)

    expect([exit_code, stderr, shim.unmatched_calls, output.values_at('reason', 'pull_request')])
      .to eq([2, '', [], ['pull_request_not_open', { 'number' => 18, 'state' => 'MERGED' }]])
  end

  it 'asks before going on with scripts whose checkout has a change, naming it in the session alone, and goes ' \
     'on with the digest a yes names, as /do does' do
    install_gh_shim(shim_entries)
    File.write(File.join(clone, 'lib', 'unreviewed.rb'), "# not reviewed\n")

    exit_code, output, stderr = run_script('setup', *arguments(argument), skill: clone)
    ask, = output['asks']

    expect([exit_code, stderr, ask.values_at('reason', 'message')])
      .to eq([3, '', ['scripts_unreviewed', CopilotCheck::Reasons::MESSAGES[:scripts_unreviewed]]])
    expect(ask['accept_with']).to match(['--accept-scripts', match(/\A\h{64}\z/)])
    expect(output['session_only']).to eq('scripts_checkout' => File.dirname(clone, 2),
                                         'scripts_changes' => ['?? skills/copilot-check/lib/unreviewed.rb'])
    expect(File.exist?(sandbox.path('pr0.json'))).to be(false)

    accepted = run_script('setup', *arguments(argument, *ask['accept_with']), skill: clone)
    expect(accepted.values_at(0, 2)).to eq([0, ''])
  end

  it "asks about a fork's head and the scripts at once, and asks again about scripts changed since the yes" do
    install_gh_shim(shim_entries(open_pr_view_response(isCrossRepository: true)))
    File.write(File.join(clone, 'lib', 'unreviewed.rb'), "# not reviewed\n")

    first = run_script('setup', *arguments(argument), skill: clone)
    yeses = first[1]['asks'].flat_map { |ask| ask['accept_with'] }
    File.write(File.join(clone, 'lib', 'unreviewed.rb'), "# changed since the yes\n")
    second = run_script('setup', *arguments(argument, *yeses), skill: clone)

    expect([first[0], first[1]['asks'].map { |ask| ask['reason'] }])
      .to eq([3, %w[fork_pull_request scripts_unreviewed]])
    expect([second[0], second[1]['asks'].map { |ask| ask['reason'] }]).to eq([3, %w[scripts_unreviewed]])
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
