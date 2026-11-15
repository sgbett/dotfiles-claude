# frozen_string_literal: true

require_relative 'support/copilot_signal_calls'

RSpec.describe Do::CopilotSignal do
  include Do::Testing::CopilotSignalCalls

  subject(:signal) { described_class.new(SkillSupport::Gh.new(host: 'github.com', runner: fake_runner)) }

  let(:here) { 'sgbett/dotfiles-claude' }
  let(:sdk) { 'sgbett/bsv-ruby-sdk' }
  let(:instructions) { "# Review\n\nFlag input that reaches a shell.\n" }

  def read(repository = here, branch: 'master', ref: 'master')
    signal.read(repository, branch: branch, ref: ref)
  end

  def rules(*types, source: 'Repository')
    JSON.generate(types.map { |type| { 'type' => type, 'ruleset_source_type' => source, 'ruleset_id' => 1 } })
  end

  # gh's answer when GitHub refuses the call with +status+ and +message+.
  def refusal(status, message)
    { exit_status: 1, stderr: "gh: #{message} (HTTP #{status})\n",
      stdout: JSON.generate('message' => message, 'status' => status.to_s,
                            'documentation_url' => 'https://docs.github.com/rest/repos/rules#get-rules-for-a-branch') }
  end

  describe 'the rules for the base' do
    it 'find a copilot_code_review rule, as recorded from a repository that has one' do
      expect_copilot_signal(repository: sdk, rules: fixture('rest/branch-rules-copilot.json'),
                            instructions: instructions)
      result = read(sdk)

      expect([result.ruleset, result.instructions, result.signal?]).to eq([true, true, true])
      expect(result.to_h).to eq(ruleset: true, instructions: true, signal: true)
    end

    it "find none in this repository's empty list, as recorded" do
      expect_copilot_signal

      expect(read.to_h).to eq(ruleset: false, instructions: false, signal: false)
    end

    it 'count the rule whatever set its ruleset: the repository, its organisation or its enterprise' do
      %w[Repository Organization Enterprise].each do |source|
        expect_copilot_signal(rules: rules('copilot_code_review', source: source))

        expect(read.ruleset).to be(true), source
      end
    end

    it 'find none among rules of other types, however close their names' do
      expect_copilot_signal(rules: rules('deletion', 'pull_request', 'required_status_checks', 'Copilot_Code_Review',
                                         'copilot_code_review_x'))

      expect(read.ruleset).to be(false)
    end

    it 'fail on a full page, which may go on to another, and take a page one short of full' do
      expect_copilot_signal(rules: rules(*Array.new(99, 'deletion')))
      expect_branch_rules(rules(*Array.new(100, 'deletion')), repository: here, branch: 'master')

      expect(read.ruleset).to be(false)
      expect { read }.to raise_error(SkillSupport::IncompleteResults, 'the rules for master may go on to another page')
    end

    it 'fail as a tool on a 404 or a 403, never taking either for no rules' do
      [[404, 'Not Found'], [403, 'Resource not accessible by personal access token']].each do |status, message|
        expect_branch_rules(refusal(status, message), repository: here, branch: 'master')

        expect { read }.to raise_error(SkillSupport::GhError) { |error| expect(error.http_status).to eq(status) }
      end
    end

    it 'fail on an answer that is not a list of rules' do
      ['{"type":"copilot_code_review"}', '["copilot_code_review"]'].each do |answer|
        expect_branch_rules(answer, repository: here, branch: 'master')

        expect { read }.to raise_error(SkillSupport::UnexpectedResponse, /something other than a list/), answer
      end
    end

    it 'are asked for with the base as one percent-encoded path segment, its "/", "#" and "+" included' do
      base = 'feat/#27+copilot'
      fake_runner.expect_call(%w[gh api --hostname github.com -X GET
                                 repos/sgbett/dotfiles-claude/rules/branches/feat%2F%2327%2Bcopilot -f per_page=100],
                              stdout: '[]')
      expect_instructions(nil, repository: here, ref: base)

      expect(read(branch: base, ref: base).to_h).to eq(ruleset: false, instructions: false, signal: false)
    end
  end

  describe 'the instructions' do
    it 'are there when the file is, and absent on the 404 that means so' do
      expect_copilot_signal(instructions: instructions)
      expect_copilot_signal

      expect([read.instructions, read.instructions]).to eq([true, false])
    end

    it 'fail when their path is a directory' do
      expect_copilot_signal(instructions: [{ 'name' => 'review.md', 'type' => 'file',
                                             'path' => '.github/copilot-instructions.md/review.md' }])

      expect { read }
        .to raise_error(SkillSupport::UnexpectedResponse, '.github/copilot-instructions.md is a directory, not a file')
    end
  end
end
