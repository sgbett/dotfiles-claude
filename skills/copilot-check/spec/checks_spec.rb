# frozen_string_literal: true

require_relative 'support/gate_calls'

RSpec.describe CopilotCheck::Checks do
  include CopilotCheck::Testing::GateCalls

  let(:github) { SkillSupport::Gh.new(host: 'github.com', runner: fake_runner) }
  let(:documented_failures) { instance_double(CopilotCheck::DocumentedFailures) }
  let(:checks_call) { CopilotCheck::Testing::GateCalls::CHECKS }

  def list(repository = CopilotCheck::Testing::GateCalls::HERE, number = 18)
    described_class.new(github, documented_failures).list(repository, number)
  end

  it 'lists the checks as recorded on a twbs/bootstrap pull request, by bucket, with none failed' do
    fake_runner.expect_call(['gh', 'pr', 'checks', '43381', '-R', 'github.com/twbs/bootstrap', '--json',
                             'name,bucket,link'], stdout: fixture('pr-checks/bootstrap-43381.json'))

    checks = list('twbs/bootstrap', 43_381)

    expect(checks.map(&:bucket).tally).to eq('pass' => 12, 'skipping' => 3, 'cancel' => 1)
    expect(checks.find { |check| check.bucket == 'cancel' }.to_h)
      .to eq(name: 'browserstack', bucket: 'cancel', documented: nil,
             link: 'https://github.com/twbs/bootstrap/actions/runs/43618987493/job/132520164386')
  end

  it 'lists none when gh reports that no check has run, as recorded on #18' do
    fake_runner.expect_call(checks_call, exit_status: 1, stderr: fixture('pr-checks/no-checks-18.stderr'))

    expect(list).to eq([])
  end

  it 'fails on any other failure of gh' do
    [[1, "HTTP 502: Bad Gateway\n"], [4, "To get started with GitHub CLI, please run:  gh auth login\n"]]
      .each do |exit_status, stderr|
      fake_runner.expect_call(checks_call, exit_status: exit_status, stderr: stderr)
      expect { list }.to raise_error(SkillSupport::GhError), stderr
    end
  end

  it 'fails on a check without a name or in a bucket gh never gives' do
    [[{ 'bucket' => 'pass', 'link' => '' }], [check_entry('test', 'unknown')], {}].each do |entries|
      fake_runner.expect_call(checks_call, stdout: as_json(entries))
      expect { list }.to raise_error(SkillSupport::UnexpectedResponse), entries.inspect
    end
  end

  it 'asks of each failure, and only of failures, whether the rules document it' do
    fake_runner.expect_call(checks_call, stdout: as_json([check_entry('ci', 'fail'), check_entry('lint', 'fail'),
                                                          check_entry('test', 'pass')]))
    allow(documented_failures).to receive(:documented?) { |check| check.name == 'ci' }

    expect(list.map { |check| [check.name, check.documented] }).to eq([['ci', true], ['lint', false], ['test', nil]])
  end
end
