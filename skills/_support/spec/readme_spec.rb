# frozen_string_literal: true

# What skills/README.md commits to where no script can check it.
RSpec.describe 'skills/README.md' do
  let(:evaluation) do
    readme = File.read(File.join(SkillSupport::Testing::Helpers::REPOSITORY_ROOT, 'skills', 'README.md'))
    readme[readme.index('## Evaluation')..]
  end

  it "keeps evaluation not adopted, its trust step needing the owner's assertion of trust by either route" do
    expect(evaluation).to start_with("## Evaluation\n\nNot adopted yet")
    expect(evaluation).to include("needs the owner's assertion of trust: the first-run prompt in a terminal, or " \
                                  "`--trust-plugin` given only on the owner's say-so")
    expect(evaluation).not_to match(/needs the owner in a terminal|trust it, in a terminal/)
  end
end
