# frozen_string_literal: true

require_relative '../lib/copilot_check/promote_check'

RSpec.describe CopilotCheck::PromotionRules do
  let(:path) { sandbox.path('promotion-rules.json') }
  let(:valid) do
    { 'draft_flow' => true, 'merge_is_owners_step' => false,
      'expected_failures' => [{ 'name' => 'CI result', 'text' => "  Waits for ready.\n" }] }
  end

  def read(rules)
    File.write(path, rules.is_a?(String) ? rules : JSON.generate(rules))
    described_class.read(path)
  end

  it 'reads what the lead wrote, the expected texts trimmed' do
    rules = read(valid)

    expect([rules.draft_flow?, rules.merge_is_owners_step?, rules.expected_failures.map(&:to_h)])
      .to eq([true, false, [{ name: 'CI result', text: 'Waits for ready.' }]])
  end

  it 'refuses a file without every key, with another key, or a value of the wrong kind' do
    [valid.except('expected_failures'), valid.merge('draft_flows' => true), valid.merge('draft_flow' => 'yes'),
     valid.merge('merge_is_owners_step' => nil), valid.merge('expected_failures' => {}),
     valid.merge('expected_failures' => [{ 'name' => 'CI result' }]),
     valid.merge('expected_failures' => [{ 'name' => 'CI result', 'text' => ' ' }]),
     valid.merge('expected_failures' => [{ 'name' => 'CI result', 'text' => 'x', 'link' => 'y' }]),
     [], 'not json'].each do |rules|
      expect { read(rules) }.to raise_error(CopilotCheck::UnusableRulesFile, /rules file|isn't JSON/), rules.inspect
    end
  end

  it 'refuses a file that is missing or a symlink' do
    File.write(sandbox.path('real.json'), JSON.generate(valid))
    File.symlink(sandbox.path('real.json'), path)

    expect { described_class.read(path) }.to raise_error(CopilotCheck::UnusableRulesFile, /symlink/)
    expect { described_class.read(sandbox.path('missing.json')) }
      .to raise_error(CopilotCheck::UnusableRulesFile, /doesn't exist/)
  end
end

RSpec.describe CopilotCheck::StartState do
  let(:path) { sandbox.path('pr0.json') }
  let(:here) { 'github.com/sgbett/dotfiles-claude' }
  let(:checkout) do
    CopilotCheck::CheckoutRepository::Repository.new(host: 'github.com', name_with_owner: 'sgbett/dotfiles-claude')
  end
  let(:valid) { { 'number' => 18, 'repository' => here, 'isDraft' => true, 'chained' => false } }

  def read(state, number = 18)
    File.write(path, state.is_a?(String) ? state : JSON.generate(state))
    described_class.read(path, number)
  end

  it "reads whether the pull request was a draft and the run chained from Phase 0's file, which names the " \
     "checkout's repository" do
    state = read(valid.merge('baseRefName' => 'master', 'isCrossRepository' => false))
    state.check_repository!(checkout)
    chained = read(valid.merge('isDraft' => false, 'chained' => true,
                               'repository' => 'GitHub.com/SGBETT/dotfiles-claude'))
    chained.check_repository!(checkout)

    expect([state.draft?, state.chained?, chained.draft?, chained.chained?]).to eq([true, false, false, true])
  end

  it "refuses another pull request's file, one without isDraft, chained or the repository, and one that isn't JSON" do
    [valid.merge('number' => 19), valid.merge('number' => '18'), valid.except('isDraft'),
     valid.merge('isDraft' => 'true'), valid.except('chained'), valid.merge('chained' => 'chained'),
     valid.except('repository'), valid.merge('repository' => ['sgbett/dotfiles-claude']), 'not json'].each do |state|
      expect { read(state) }.to raise_error(CopilotCheck::UnusableStartFile), state.inspect
    end
  end

  it "refuses a file whose repository isn't the checkout's, as one setup wrote in another checkout" do
    ['github.com/example-owner/dotfiles-claude', 'ghe.example.com/sgbett/dotfiles-claude', 'sgbett/dotfiles-claude']
      .each do |repository|
        state = read(valid.merge('repository' => repository))
        expect { state.check_repository!(checkout) }
          .to raise_error(CopilotCheck::UnusableStartFile, /another repository than the checkout's/), repository
      end
  end
end
