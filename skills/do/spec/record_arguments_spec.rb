# frozen_string_literal: true

require_relative '../lib/do/record_arguments'

RSpec.describe Do::RecordArguments do
  def parse(*arguments)
    described_class.parse(arguments, runner: SkillSupport::CommandRunner.new)
  end

  def options(*arguments)
    parse(*arguments).to_h.compact
  end

  it 'reads each subcommand, the issue, then its flags in any order' do
    expect(options('closes', '24', '--verified-boxes', '2,1,2', '--base', 'feat/#24+x', '--verified-items',
                   'L1,#31,example-owner/upstream#5,P4'))
      .to eq(command: 'closes', reference: '24', base: 'feat/#24+x', verified_boxes: [2, 1],
             verified_items: %w[L1 #31 example-owner/upstream#5 P4], dry_run: false)
    expect([options('tick', '24', '--dry-run', '--ledger', 'L2'), options('tick', '24', '--issue-boxes', '3')])
      .to eq([{ command: 'tick', reference: '24', ledger: ['L2'], dry_run: true },
              { command: 'tick', reference: '24', issue_boxes: [3], dry_run: false }])
  end

  it 'reads the gate actions, with answers and states as the gate file and the ledger write them' do
    parsed = [options('gate', 'add', '24', '--finding-file', '/scratch/finding.md'),
              options('gate', 'answer', '24', '--k', 'G2', '--answer', 'fix-here'),
              options('gate', 'publish', '24', '--k', 'G2', '--dry-run'),
              options('gate', 'mark', '24', '--state', 'user-decided', '--k', 'G2')]

    expect(parsed.map { |option| option.except(:reference) })
      .to eq([{ command: 'gate add', finding_file: '/scratch/finding.md', dry_run: false },
              { command: 'gate answer', k: 'G2', answer: 'fix here', dry_run: false },
              { command: 'gate publish', k: 'G2', dry_run: true },
              { command: 'gate mark', k: 'G2', state: 'user decided', dry_run: false }])
  end

  it 'reads sub-issue' do
    expect(options('sub-issue', '24', '--item', 'L3', '--number', '31'))
      .to eq(command: 'sub-issue', reference: '24', item: 'L3', number: 31, dry_run: false)
  end

  it 'refuses an unknown subcommand, a missing issue, and a flag that is missing, unknown, repeated or unpaired' do
    [[], %w[close 24 --base master], %w[gate 24], %w[gate open 24 --k G1], %w[closes --base master],
     %w[closes 24], %w[closes 24 --base master --base main], %w[closes 24 --base master --dry-run],
     %w[closes 24 --base], %w[tick 24], %w[tick 24 --ledger L1 --issue-boxes 1],
     %w[tick 24 --ledger L1 --dry-run --dry-run], %w[gate add 24 --k G1],
     %w[gate answer 24 --k G1 --dry-run --answer advisory], %w[sub-issue 24 --item L1],
     %w[closes 24 --base=master]].each do |arguments|
      expect { parse(*arguments) }.to raise_error(Do::RecordUsageError, /usage: record closes/), arguments.inspect
    end
  end

  it 'refuses any value that is not valid, or could be read as an option' do
    { %w[closes --base] => ['-master', 'a..b'],
      %w[closes --base master --verified-items] => ['', 'L1,', 'L0', 'X1', '#0', 'a b#1', '-L1', 'Gate G1'],
      %w[closes --base master --verified-boxes] => ['0', '1,,2', 'one', '-1'],
      %w[gate-answer --k G1 --answer] => ['fix here', 'yes'],
      %w[gate-mark --k G1 --state] => ['user decided', 'open'],
      %w[gate-publish --k] => %w[1 G0 g1 G1x],
      %w[gate-add --finding-file] => ['-f', "a\nb"],
      %w[sub-issue --number 31 --item] => %w[#31 L1a G1], %w[sub-issue --item L1 --number] => %w[0 -3 x] }
      .each do |(command, *flags), values|
        values.each do |value|
          arguments = [*command.sub(/\Agate-/, 'gate ').split, '24', *flags, value]
          expect { parse(*arguments) }.to raise_error(SkillSupport::InvalidIdentifier), arguments.inspect
        end
      end
  end
end
