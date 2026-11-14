# frozen_string_literal: true

require_relative 'support/gate_calls'

# A failure the rules document is one whose check name and annotation text
# both match, its annotations read only through an Actions job link here.
RSpec.describe CopilotCheck::DocumentedFailures do
  include CopilotCheck::Testing::GateCalls

  subject(:documented_failures) do
    described_class.new(SkillSupport::Gh.new(host: 'github.com', runner: fake_runner), here, expected)
  end

  let(:here) { CopilotCheck::Testing::GateCalls::HERE }
  let(:text) { 'The suite runs once the pull request is ready.' }
  let(:expected) { [CopilotCheck::PromotionRules::ExpectedFailure.new(name: 'CI result', text: text)] }

  def failed(name, link = format(CopilotCheck::Testing::GateCalls::JOB_LINK, job: 41))
    CopilotCheck::Checks::Check.new(name: name, bucket: 'fail', link: link)
  end

  def expect_annotations(*pages, job: 41)
    pages.each.with_index(1) do |messages, page|
      fake_runner.expect_call(annotations_call(job, page: page),
                              stdout: as_json(messages.map { |message| annotation(message) }))
    end
  end

  it 'documents a failure whose name and annotation text both match, beside the run\'s other annotations' do
    expect_annotations(['Process completed with exit code 1.', "#{text}\n"])

    expect(documented_failures.documented?(failed('CI result'))).to be(true)
  end

  it 'holds a failure whose name matches but whose annotations do not' do
    expect_annotations(['Process completed with exit code 1.', 'Tests failed.'])

    expect(documented_failures.documented?(failed('CI result'))).to be(false)
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
    expect_annotations(Array.new(100) { 'Process completed with exit code 1.' }, [text])

    expect(documented_failures.documented?(failed('CI result'))).to be(true)
  end

  it 'matches any text the rules document for that check' do
    expected << CopilotCheck::PromotionRules::ExpectedFailure.new(name: 'CI result', text: 'Waiting for ready.')
    expect_annotations(['Waiting for ready.'])

    expect(documented_failures.documented?(failed('CI result'))).to be(true)
  end
end
