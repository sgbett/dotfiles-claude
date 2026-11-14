# frozen_string_literal: true

RSpec.describe SkillSupport::Outcome do
  let(:question) { { reason: :local_branch_ahead, message: 'Build on the local branch?' } }

  it 'maps proceed to exit 0, stop to 2 and ask to 3, leaving 1 for a tool failure' do
    expect([described_class.proceed, described_class.stop(:missing_base, 'The base branch is missing.'),
            described_class.ask([question])].map(&:exit_code)).to eq([0, 2, 3])
    expect(described_class::TOOL_FAILURE_EXIT_CODE).to eq(1)
  end

  it 'puts status first, then a stop reason and message, then the fields in order' do
    outcome = described_class.stop(:missing_base, 'The base branch is missing.',
                                   read: ['references/plan.md'], session_only: {})

    expect(JSON.parse(outcome.to_json).keys).to eq(%w[status reason message read session_only])
  end

  it 'carries asks as a list, each with its reason, message and whatever the answer needs' do
    outcome = described_class.ask(
      [question.merge(accept: '--accept-local-branch 1a2b3c4'),
       { 'reason' => 'untrusted_author', 'message' => 'Adopt?' }],
      summary: { 'issue' => 'example-owner/example-repo#1' }
    )

    expect(outcome.to_h).to eq(
      'status' => 'ask',
      'asks' => [{ 'reason' => 'local_branch_ahead', 'message' => 'Build on the local branch?',
                   'accept' => '--accept-local-branch 1a2b3c4' },
                 { 'reason' => 'untrusted_author', 'message' => 'Adopt?' }],
      'summary' => { 'issue' => 'example-owner/example-repo#1' }
    )
    expect(outcome.reasons).to eq(%w[local_branch_ahead untrusted_author])
  end

  it 'renders as a single line of JSON' do
    expect(described_class.proceed(summary: { 'lines' => "a\nb" }).to_json).not_to include("\n")
  end

  it 'refuses a reason that is not a snake_case enum value' do
    ['Missing base', 'missing-base', '1x', '', nil].each do |reason|
      expect { described_class.stop(reason, 'Message.') }
        .to raise_error(ArgumentError, /reason/), "took #{reason.inspect}"
    end
  end

  it 'refuses an empty message' do
    ['', '  ', nil].each do |message|
      expect { described_class.stop(:missing_base, message) }.to raise_error(ArgumentError, /message/)
    end
  end

  it 'refuses an ask without questions, or with one lacking a reason or message' do
    [[], nil, ['Build?'], [{ reason: :x }], [{ message: 'Build?' }]].each do |asks|
      expect { described_class.ask(asks) }.to raise_error(ArgumentError), "took #{asks.inspect}"
    end
  end

  it "keeps the contract's own keys out of a script's fields" do
    expect { described_class.proceed(status: 'stop') }.to raise_error(ArgumentError, /status/)
    expect { described_class.stop(:x, 'y', reason: 'z') }.to raise_error(ArgumentError, /reason/)
    expect { described_class.proceed(asks: []) }.to raise_error(ArgumentError, /asks/)
    expect { described_class.proceed('message' => 'x') }.to raise_error(ArgumentError, /message/)
  end

  it 'is built only through proceed, stop and ask' do
    expect { described_class.new('proceed', {}, {}) }.to raise_error(NoMethodError)
  end
end
