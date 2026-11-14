# frozen_string_literal: true

RSpec.describe SkillSupport::Cli do
  let(:stdout) { StringIO.new }
  let(:stderr) { StringIO.new }

  def run_cli(&body)
    described_class.run('preflight', reasons: %i[missing_base local_branch_ahead],
                                     stdout: stdout, stderr: stderr, &body)
  end

  it "prints the outcome as one line of JSON and returns the outcome's exit code" do
    expect(run_cli { SkillSupport::Outcome.stop(:missing_base, 'The base branch is missing.') }).to eq(2)
    expect(stdout.string).to eq(%({"status":"stop","reason":"missing_base","message":"The base branch is missing."}\n))
    expect(stderr.string).to be_empty
  end

  it 'reports a failure the library anticipates as a tool failure: exit 1, a diagnostic, an empty stdout' do
    expect(run_cli { raise SkillSupport::IncompleteResults, 'repository.labels has more than one page' }).to eq(1)
    expect(stdout.string).to be_empty
    expect(stderr.string).to eq("preflight: tool failure: repository.labels has more than one page\n")
  end

  it 'reports any other error as a tool failure, with its class and backtrace' do
    expect(run_cli { raise KeyError, 'key not found: "data"' }).to eq(1)
    expect(stdout.string).to be_empty
    expect(stderr.string.lines.first).to eq(%(preflight: tool failure: KeyError: key not found: "data"\n))
    expect(stderr.string.lines.length).to be > 1
  end

  it "fails when an outcome carries a reason outside the script's enum" do
    expect(run_cli { SkillSupport::Outcome.ask([{ reason: :not_listed, message: 'Go on?' }]) }).to eq(1)
    expect(stdout.string).to be_empty
    expect(stderr.string).to include('preflight has no reason not_listed')
  end

  it 'fails when the body returns anything but an Outcome' do
    expect(run_cli { { 'status' => 'proceed' } }).to eq(1)
    expect(stdout.string).to be_empty
  end
end
