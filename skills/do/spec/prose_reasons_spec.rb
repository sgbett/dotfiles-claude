# frozen_string_literal: true

require_relative '../lib/do/reasons'

# Where SKILL.md or a reference says how to handle a script's stop or ask,
# it names the stop or ask by its reason, as "(reason `gate_advisory`)" or
# "reasons `a` and `b`". Each must be a reason the scripts give, and each
# reason they give comes with a message for the lead to pass on.
RSpec.describe "/do's prose and the scripts' reasons" do
  let(:skill_directory) { File.expand_path('..', __dir__) }
  let(:prose) do
    [File.join(skill_directory, 'SKILL.md'), *Dir[File.join(skill_directory, 'references', '*')]]
      .to_h { |path| [path.delete_prefix("#{skill_directory}/"), File.read(path)] }
  end

  def named_reasons(text)
    text.scan(/\breasons? ((?:`[a-z_]+`(?:,? (?:and |or )?)?)+)/)
        .flat_map { |(list)| list.scan(/`([a-z_]+)`/).flatten.map(&:to_sym) }
  end

  def messages(reason)
    return Do::Reasons::NOT_AN_ISSUE_MESSAGES.values if reason == Do::Reasons::NOT_AN_ISSUE

    [Do::Reasons::MESSAGES[reason]]
  end

  it 'names only reasons the scripts can stop or ask for' do
    named = prose.transform_values { |text| named_reasons(text) }

    expect(named.values.flatten).not_to be_empty
    expect(named.transform_values { |reasons| reasons - Do::Reasons::ALL }.reject { |_path, unknown| unknown.empty? })
      .to be_empty
  end

  it 'reads a list of reasons whole' do
    expect(named_reasons('reasons `a_b`, `c` and `d`; reason `e` or the `f` field'))
      .to eq(%i[a_b c d e])
  end

  it 'has every reason the scripts can give come with a message' do
    unmessaged = Do::Reasons::ALL.reject do |reason|
      messages(reason).all? { |message| message.is_a?(String) && !message.empty? }
    end

    expect(unmessaged).to be_empty
  end
end
