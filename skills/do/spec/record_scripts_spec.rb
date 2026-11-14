# frozen_string_literal: true

require_relative 'support/check_finish_calls'
require_relative 'support/record_calls'

# record examines the checkout its scripts run from as `preflight check`
# does, and asks before anything else when they may not be the reviewed
# ones.
RSpec.describe "/do's record and its scripts' checkout" do
  include Do::Testing::CheckFinishCalls
  include Do::Testing::RecordCalls

  # The scripts' checkout with a change under skills/do, as check's specs
  # build it.
  def expect_unreviewed_scripts
    fake_runner.expect_call(['git', '-C', scripts_skill_directory, 'rev-parse', '--show-toplevel'],
                            stdout: "#{scripts_top}\n")
    defaults = Do::Testing::CheckFinishCalls::SCRIPTS_DEFAULTS
    expect_scripts_checkout(scripts_top, defaults.merge(status: " M skills/do/lib/do/tick.rb\0"))
  end

  def tick(*extra)
    record('tick', 'sgbett/dotfiles-claude#24', '--ledger', 'L1', '--dry-run', *extra)
  end

  it 'asks before any other call, naming the changes in the session alone' do
    expect_unreviewed_scripts
    exit_code, output = tick

    expect([exit_code, output['asks'].map { |ask| ask.values_at('reason', 'message') }])
      .to eq([3, [['scripts_unreviewed', Do::Reasons::MESSAGES[:scripts_unreviewed]]]])
    expect(output['asks'].first['accept_with']).to match(['--accept-scripts', match(/\A\h{64}\z/)])
    expect(output['session_only'])
      .to eq('scripts_checkout' => scripts_top, 'scripts_changes' => [' M skills/do/lib/do/tick.rb'])
    expect(fake_runner.calls.map { |call| call[:argv].first }.uniq).to eq(['git'])
  end

  it 'goes on once the user accepts that digest' do
    expect_unreviewed_scripts
    digest = tick.last['asks'].first['accept_with'].last
    expect_unreviewed_scripts
    expect_issue_found(record_response)

    expect(tick('--accept-scripts', digest).last.values_at('status', 'flipped')).to eq(['proceed', ['L1']])
  end
end
