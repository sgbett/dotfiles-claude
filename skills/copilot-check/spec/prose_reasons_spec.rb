# frozen_string_literal: true

require_relative '../lib/copilot_check/reasons'

# Where SKILL.md says how to handle a script's stop, it names the stop by its
# reason, as "reason `copilot_timeout`". Each must be a reason the scripts
# give.
RSpec.describe "/copilot-check's prose and the scripts' reasons" do
  let(:skill) { File.read(File.expand_path('../SKILL.md', __dir__)) }

  def named_reasons(text)
    text.scan(/\breasons? ((?:`[a-z_]+`(?:,? (?:and |or )?)?)+)/)
        .flat_map { |(list)| list.scan(/`([a-z_]+)`/).flatten.map(&:to_sym) }
  end

  it 'names only reasons the scripts can stop or ask for' do
    named = named_reasons(skill)

    expect(named).to include(:copilot_timeout)
    expect(named - CopilotCheck::Reasons::ALL).to be_empty
  end
end
