# frozen_string_literal: true

require_relative '../lib/repo_consistency/reasons'

# Where SKILL.md says how to handle the audit's stop, it names the stop by
# its reason, as "reason `not_logged_in`". Each must be a reason the script
# gives, and the skill must stay within the character ceiling the shared
# skill_size_spec.rb holds every skill to.
RSpec.describe "/repo-consistency's prose and git-settings' reasons" do
  let(:skill) { File.read(File.expand_path('../SKILL.md', __dir__)) }

  def named_reasons(text)
    text.scan(/\breasons? ((?:`[a-z_]+`(?:,? (?:and |or )?)?)+)/)
        .flat_map { |(list)| list.scan(/`([a-z_]+)`/).flatten.map(&:to_sym) }
  end

  it 'names every reason the script can stop for, and no other' do
    expect(named_reasons(skill)).to match_array(RepoConsistency::Reasons::ALL)
  end

  it 'writes the call out in full, quoting the repositories, and never names a quarter' do
    expect(skill).to include(%("${CLAUDE_SKILL_DIR}/bin/git-settings" audit 'owner/repo'))
    expect(skill).not_to match(/quarterly/i)
  end

  it 'stays within 19,000 characters' do
    expect(skill.length).to be <= 19_000
  end
end
