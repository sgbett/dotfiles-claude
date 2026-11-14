# frozen_string_literal: true

require_relative '../lib/copilot_check/promote_check'

RSpec.describe CopilotCheck::PromoteCheckArguments do
  let(:head) { '0203427ffa8add0c145fa78cdc2415511ffbdaa1' }
  let(:flags) do
    %w[--pr 18 --rules-file /scratch/promotion-rules.json --start-file /scratch/pr0.json --outcome converged]
  end
  let(:check) { ['check', *flags] }

  def parse(arguments)
    described_class.parse(arguments)
  end

  it 'takes check with its flags in any order, and the reviews the run found no finding in' do
    options = parse(['check', *flags.drop(2), '--reviews-without-findings', '5881418347,5881467821,5881418347',
                     *flags.take(2)])

    expect(options.to_h.compact)
      .to eq(command: 'check', pr: 18, rules_file: '/scratch/promotion-rules.json', start_file: '/scratch/pr0.json',
             outcome: 'converged', reviews_without_findings: [5_881_418_347, 5_881_467_821])
    expect(parse(check).reviews_without_findings).to eq([])
  end

  it 'takes verify with the pull request and its head' do
    expect(parse(['verify', '--head', head.upcase, '--pr', '18']).to_h.compact)
      .to eq(command: 'verify', pr: 18, head: head, reviews_without_findings: [])
  end

  it 'refuses an unknown subcommand, or a flag the subcommand lacks, repeats or does not take' do
    [[], %w[ready --pr 18], check.first(5), [*check, '--pr', '19'], [*check, '--head', head], [*check, '--dry-run'],
     ['verify', '--pr', '18'], ['verify', '--pr', '18', '--head', head, '--outcome', 'converged']].each do |arguments|
      expect { parse(arguments) }.to raise_error(CopilotCheck::UsageError, /\Ausage: promote-check check/),
                                     arguments.inspect
    end
  end

  it 'refuses a value that is not valid, or could be read as an option' do
    { %w[--pr 0] => 'issue_number', %w[--pr -18] => 'issue_number', %w[--outcome done] => 'outcome',
      %w[--rules-file -x] => 'rules_file', %w[--reviews-without-findings 1,,2] => 'review_ids',
      %w[--reviews-without-findings x] => 'review_ids' }.each do |(flag, value), kind|
      arguments = ['check', *flags.each_slice(2).to_h.merge(flag => value).flatten]
      expect { parse(arguments) }
        .to raise_error(SkillSupport::InvalidIdentifier, "invalid #{kind}"), [flag, value].inspect
    end
    expect { parse(['verify', '--pr', '18', '--head', head[0, 12]]) }
      .to raise_error(SkillSupport::InvalidIdentifier, 'invalid commit_sha')
  end
end
