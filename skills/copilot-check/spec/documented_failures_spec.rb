# frozen_string_literal: true

require_relative 'support/gate_calls'

# A failure the rules document is one whose check name matches, whose
# failure annotations, bar one runner exit-code line, are at least one and
# each carry a text the rules give for it other than an exit-code line, and
# whose job has exactly one failed step, its annotations and steps read only
# through an Actions job link here.
RSpec.describe CopilotCheck::DocumentedFailures do
  include CopilotCheck::Testing::GateCalls

  subject(:documented_failures) do
    described_class.new(SkillSupport::Gh.new(host: 'github.com', runner: fake_runner), here, expected)
  end

  let(:here) { CopilotCheck::Testing::GateCalls::HERE }
  let(:text) { 'The suite runs once the pull request is ready.' }
  let(:exit_code) { 'Process completed with exit code 1.' }
  let(:expected) { [CopilotCheck::PromotionRules::ExpectedFailure.new(name: 'CI result', text: text)] }

  def failed(name, link = format(CopilotCheck::Testing::GateCalls::JOB_LINK, job: 41))
    CopilotCheck::Checks::Check.new(name: name, bucket: 'fail', link: link)
  end

  # Each page a list of annotations, given as a message for a failure, or
  # as [message, level].
  def expect_annotations(*pages, job: 41)
    pages.each.with_index(1) do |entries, page|
      annotations = entries.map { |message, level = 'failure'| annotation(message, level: level) }
      fake_runner.expect_call(annotations_call(job, page: page), stdout: as_json(annotations))
    end
  end

  # The job's steps, read once its annotations pass, concluding as
  # +conclusions+ say, or +answer+ in their place.
  def expect_steps(conclusions = CopilotCheck::Testing::JobAnswers::ONE_FAILED_STEP, job: 41,
                   answer: job_response(job, conclusions))
    fake_runner.expect_call(job_call(job), stdout: as_json(answer))
  end

  # The rules give each of +texts+ for the check.
  def document(*texts)
    expected.replace(texts.map do |documented|
      CopilotCheck::PromotionRules::ExpectedFailure.new(name: 'CI result', text: documented)
    end)
  end

  # The rules needn't quote the runner's exit-code line: it is on every
  # failed run: step, not a text of the check's own.
  it "documents a failure whose failure annotations, bar the runner's exit-code line, each carry a text the " \
     'rules give for it, whatever its notices and warnings say' do
    expect_annotations([exit_code, "#{text}\n", ['Node.js 16 actions are deprecated.', 'warning'],
                        ['Tests were skipped.', 'notice']])
    expect_steps

    expect(documented_failures.documented?(failed('CI result'))).to be(true)
  end

  it "holds a failure with any failure annotation the rules don't give, beside one they do" do
    expect_annotations([text, 'Tests failed.'])

    expect(documented_failures.documented?(failed('CI result'))).to be(false)
  end

  it "holds the runner's exit-code line alone, even when the rules give it" do
    expect_annotations([exit_code])
    expect_annotations([exit_code])

    unquoted = documented_failures.documented?(failed('CI result'))
    document(text, exit_code)

    expect([unquoted, documented_failures.documented?(failed('CI result'))]).to eq([false, false])
  end

  it 'sets aside only one exit-code line, as a second means a second step failed' do
    expect_annotations([text, exit_code, exit_code])

    expect(documented_failures.documented?(failed('CI result'))).to be(false)
  end

  it 'never takes an exit-code line the rules quote as documenting anything, as it would pass a second failed step' do
    document(exit_code)
    expect(documented_failures.documented?(failed('CI result'))).to be(false)

    document(text, exit_code)
    expect_annotations([exit_code, exit_code])
    expect_annotations([text, exit_code])
    expect_steps

    expect(Array.new(2) { documented_failures.documented?(failed('CI result')) }).to eq([false, true])
  end

  it 'takes any exit code, a Windows one negative, as the exit-code line, and nothing else like it' do
    ['Process completed with exit code 137.', "Process completed with exit code -1073741819.\n"].each do |line|
      expect_annotations([text, line])
      expect_steps
    end
    ['Process completed with exit code 1', 'Process completed with exit code 1. The suite failed.'].each do |line|
      expect_annotations([text, line])
    end

    expect(Array.new(4) { documented_failures.documented?(failed('CI result')) }).to eq([true, true, false, false])
  end

  it 'holds a failure whose name matches but whose annotations do not' do
    expect_annotations([exit_code, 'Tests failed.'])

    expect(documented_failures.documented?(failed('CI result'))).to be(false)
  end

  it 'holds a failure with no failure annotation, or one without its message' do
    expect_annotations([])
    expect_annotations([[text, 'warning']])
    expect_annotations([text, nil])

    expect(Array.new(3) { documented_failures.documented?(failed('CI result')) }).to eq([false, false, false])
  end

  it "holds a failure whose annotation matches but whose name doesn't, reading no annotations" do
    expect(documented_failures.documented?(failed('CI'))).to be(false)
  end

  it "holds a failure whose link isn't a GitHub Actions job link in this repository, reading no annotations" do
    ["https://github.com/#{here}/runs/41", 'https://github.com/example-owner/other/actions/runs/7/job/41',
     "https://ghe.example.com/#{here}/actions/runs/7/job/41", "https://github.com/#{here}/actions/runs/7/job/41/",
     "https://github.com/#{here}/actions/runs/7/job/41?check_suite_focus=true", '', nil].each do |link|
      expect(documented_failures.documented?(failed('CI result', link))).to be(false), link.inspect
    end
  end

  it 'reads the annotations past their first page' do
    expect_annotations(Array.new(100) { [exit_code, 'notice'] }, [text])
    expect_steps

    expect(documented_failures.documented?(failed('CI result'))).to be(true)
  end

  it 'holds a failure whose annotations run past the pages it reads, as one past them could be any' do
    expect_annotations(*Array.new(described_class::MAX_PAGES) { Array.new(100) { text } })

    expect(documented_failures.documented?(failed('CI result'))).to be(false)
  end

  it 'matches any text the rules document for that check' do
    expected << CopilotCheck::PromotionRules::ExpectedFailure.new(name: 'CI result', text: 'Waiting for ready.')
    expect_annotations(['Waiting for ready.'])
    expect_steps

    expect(documented_failures.documented?(failed('CI result'))).to be(true)
  end

  # Exit-code lines don't count failed steps: the runner caps a job's
  # annotations, and a failed step's line can go missing.
  it 'passes a documented failure only in a job with exactly one failed step' do
    [CopilotCheck::Testing::JobAnswers::ONE_FAILED_STEP, %w[success failure skipped failure success],
     %w[success success success]].each do |conclusions|
      expect_annotations([text, exit_code])
      expect_steps(conclusions)
    end

    expect(Array.new(3) { documented_failures.documented?(failed('CI result')) }).to eq([true, false, false])
  end

  it "fails on a job answer that isn't the job's, or comes without its steps" do
    steps = job_response(41, CopilotCheck::Testing::JobAnswers::ONE_FAILED_STEP)['steps']
    [[], { 'id' => 41 }, { 'id' => 41, 'steps' => {} }, { 'id' => 41, 'steps' => [*steps, nil] },
     { 'id' => 42, 'steps' => steps }, { 'steps' => steps }].each do |answer|
      expect_annotations([text, exit_code])
      expect_steps(answer: answer)

      expect { documented_failures.documented?(failed('CI result')) }
        .to raise_error(SkillSupport::UnexpectedResponse), answer.inspect
    end
  end
end
