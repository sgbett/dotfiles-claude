# frozen_string_literal: true

require_relative '../lib/do/slug'

RSpec.describe Do::Slug do
  def slug(title)
    described_class.from_title(title)
  end

  it 'lower-cases, turns each run of other characters into one "-" and keeps at most six words' do
    title = '[HLR] /do and /copilot-check: move deterministic steps into tested scripts, load rare branches ' \
            'on demand, and cap growth'

    expect(slug(title)).to eq('hlr-do-and-copilot-check-move')
  end

  it 'trims leading and trailing separators' do
    expect(slug('  --Fix: the #42 bug!!  ')).to eq('fix-the-42-bug')
  end

  it 'treats letters outside a-z as separators' do
    expect(slug('Café über naïve')).to eq('caf-ber-na-ve')
  end

  it 'keeps a title of six words or fewer whole' do
    expect(slug('One two three four five six')).to eq('one-two-three-four-five-six')
  end

  it 'falls back to "issue" when nothing is left' do
    expect(['', '!!!', '—', nil].map { |title| slug(title) }).to eq(%w[issue issue issue issue])
  end

  it 'makes the default branch feat/<N>-<slug>, checked by git' do
    fake_runner.expect_call(%w[git check-ref-format --branch feat/42-fix-the-bug], stdout: "feat/42-fix-the-bug\n")

    expect(described_class.default_branch(42, 'Fix the bug', runner: fake_runner)).to eq('feat/42-fix-the-bug')
  end
end
