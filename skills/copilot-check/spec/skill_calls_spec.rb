# frozen_string_literal: true

require 'shellwords'
require_relative 'support/gate_calls'

# SKILL.md's calls of promote-check, and what it says of the rules file and
# the output, against what the script takes and gives.
RSpec.describe "/copilot-check's calls of its scripts" do
  include CopilotCheck::Testing::GateCalls

  let(:skill_directory) { File.expand_path('..', __dir__) }
  let(:skill) { File.read(File.join(skill_directory, 'SKILL.md')) }
  let(:calls) { skill.scan(%r{`"\$\{CLAUDE_SKILL_DIR\}/bin/([\w-]+)" ([^`]+)`}) }
  let(:values) do
    { '{pr}' => '18', '{scratch}' => '/scratch', '{outcome}' => 'converged', '{review_ids}' => '5881418347,5881467821',
      '{pull_request.head}' => CopilotCheck::Testing::GateCalls::HEAD }
  end

  # The call's arguments with each placeholder filled in, an optional flag
  # given, as the lead's shell would split them.
  def arguments(call)
    Shellwords.split(values.reduce(call.delete('[]')) { |text, (placeholder, value)| text.gsub(placeholder, value) })
  end

  it 'calls only scripts the skill has' do
    expect(calls.map(&:first).uniq).to eq(['promote-check'])
    expect(File.executable?(File.join(skill_directory, 'bin', 'promote-check'))).to be(true)
  end

  it 'calls check and verify as the script takes them, quoting the paths' do
    parsed = calls.map { |_script, call| CopilotCheck::PromoteCheckArguments.parse(arguments(call)) }

    expect(parsed.map(&:command)).to eq(%w[check verify])
    expect(parsed.first.to_h.values_at(:rules_file, :start_file, :reviews_without_findings))
      .to eq(['/scratch/promotion-rules.json', '/scratch/pr0.json', [5_881_418_347, 5_881_467_821]])
    expect(calls.first.last)
      .to include("--rules-file '{scratch}/promotion-rules.json' --start-file '{scratch}/pr0.json'")
  end

  it 'names every outcome check takes, and the rules file by its keys' do
    expect(CopilotCheck::PromoteCheckArguments::OUTCOMES.reject { |outcome| skill.include?("`#{outcome}`") })
      .to be_empty
    expect([*CopilotCheck::PromotionRules::KEYS, *CopilotCheck::PromotionRules::FAILURE_KEYS]
             .reject { |key| skill.include?(%("#{key}":)) }).to be_empty
  end

  it "names only fields check's output has" do
    expect_gate
    output = run_promote_check(gate_arguments).last
    named = skill.scan(/\{((?:repository|pull_request)\.\w+)\}|`((?:pull_request)\.\w+)`/).flatten.compact.uniq

    expect(named).to include('repository.host', 'pull_request.head', 'pull_request.is_draft')
    expect(named.reject { |path| output.dig(*path.split('.')) || output.dig(*path.split('.')) == false }).to be_empty
    expect(output).to include('checks', 'reasons', 'verdict')
  end
end
