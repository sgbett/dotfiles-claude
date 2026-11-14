# frozen_string_literal: true

require_relative 'support/script_calls'

# setup's, threads' and rereview's arguments, each checked before anything
# runs; promote_check_arguments_spec.rb covers promote-check's.
RSpec.describe 'The arguments of setup, threads and rereview' do
  let(:head) { CopilotCheck::Testing::GateCalls::HEAD }
  let(:setup_flags) do
    %w[--argument-file /scratch/argument.txt --start-file /scratch/pr0.json --rubric-file /scratch/rubric.md]
  end

  describe CopilotCheck::SetupArguments do
    it 'takes its files in any order, and the head a yes to a fork was given for' do
      options = described_class.parse([*setup_flags.drop(2), '--accept-fork', head.upcase, *setup_flags.take(2)])

      expect(options.to_h).to eq(argument_file: '/scratch/argument.txt', start_file: '/scratch/pr0.json',
                                 rubric_file: '/scratch/rubric.md', accept_fork: head)
    end

    it 'refuses a flag it lacks, repeats or does not take, and a subcommand' do
      [setup_flags.take(4), [*setup_flags, '--pr', '18'], [*setup_flags, '--start-file', '/scratch/x.json'],
       ['run', *setup_flags], [*setup_flags, '--dry-run'], [*setup_flags, '--accept-fork']].each do |arguments|
        expect { described_class.parse(arguments) }
          .to raise_error(CopilotCheck::SetupUsageError, /\Ausage: setup --argument-file/), arguments.inspect
      end
    end

    it 'writes only to absolute paths, and takes a yes only for a whole commit' do
      { %w[--start-file pr0.json] => 'start_file', %w[--rubric-file -x] => 'rubric_file',
        %w[--argument-file -x] => 'argument_file' }.each do |(flag, value), kind|
        arguments = setup_flags.each_slice(2).to_h.merge(flag => value).flatten
        expect { described_class.parse(arguments) }
          .to raise_error(SkillSupport::InvalidIdentifier, "invalid #{kind}"), flag
      end
      expect { described_class.parse([*setup_flags, '--accept-fork', head[0, 12]]) }
        .to raise_error(SkillSupport::InvalidIdentifier, 'invalid commit_sha')
    end
  end

  describe CopilotCheck::ThreadsArguments do
    it 'takes fetch with the pull request and the bodies directory, and resolve with or without --dry-run' do
      expect(described_class.parse(%w[fetch --bodies-dir /scratch/round-1 --pr 18]).to_h)
        .to eq(command: 'fetch', pr: 18, bodies_dir: '/scratch/round-1', dry_run: false)
      parsed = [%w[resolve --pr 18], %w[resolve --dry-run --pr 18]].map { |arguments| described_class.parse(arguments) }
      expect(parsed.map(&:to_h))
        .to eq([{ command: 'resolve', pr: 18, bodies_dir: nil, dry_run: false },
                { command: 'resolve', pr: 18, bodies_dir: nil, dry_run: true }])
    end

    it 'refuses an unknown subcommand, a flag it lacks, repeats or does not take, and a second --dry-run' do
      [[], %w[list --pr 18], %w[fetch --pr 18], %w[fetch --pr 18 --bodies-dir /a --dry-run],
       %w[resolve --pr 18 --pr 19], %w[resolve --pr 18 --dry-run --dry-run], %w[resolve --pr]].each do |arguments|
        expect { described_class.parse(arguments) }
          .to raise_error(CopilotCheck::ThreadsUsageError, /\Ausage: threads fetch/), arguments.inspect
      end
    end

    it 'refuses a relative bodies directory, and a pull request that is no number' do
      expect { described_class.parse(%w[fetch --pr 18 --bodies-dir round-1]) }
        .to raise_error(SkillSupport::InvalidIdentifier, 'invalid bodies_dir')
      expect { described_class.parse(%w[resolve --pr #18]) }
        .to raise_error(SkillSupport::InvalidIdentifier, 'invalid issue_number')
    end
  end

  describe CopilotCheck::RereviewArguments do
    it 'takes request with or without --dry-run, and watch with the high-water mark' do
      expect(described_class.parse(%w[request --dry-run --pr 18]).to_h)
        .to eq(command: 'request', pr: 18, since: nil, dry_run: true)
      expect(described_class.parse(%w[watch --since 2026-11-12T20:23:51Z --pr 18]).to_h)
        .to eq(command: 'watch', pr: 18, since: '2026-11-12T20:23:51Z', dry_run: false)
    end

    it 'refuses an unknown subcommand, a flag it lacks or does not take, and a mark that is no UTC timestamp' do
      [%w[watch --pr 18], %w[watch --pr 18 --since 2026-11-12T20:23:51Z --dry-run], %w[request]].each do |arguments|
        expect { described_class.parse(arguments) }
          .to raise_error(CopilotCheck::RereviewUsageError, /\Ausage: rereview request/), arguments.inspect
      end
      %w[2026-11-12 2026-11-12T20:23:51+01:00 2026-13-12T20:23:51Z -1].each do |since|
        expect { described_class.parse(['watch', '--pr', '18', '--since', since]) }
          .to raise_error(SkillSupport::InvalidIdentifier, 'invalid since'), since
      end
    end
  end
end
