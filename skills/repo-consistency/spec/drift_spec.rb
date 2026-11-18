# frozen_string_literal: true

require_relative 'support/template_fixture'
require_relative '../lib/repo_consistency/drift'
require_relative '../lib/repo_consistency/repository_projection'
require_relative '../lib/repo_consistency/repository_state'

# The template projected onto itself has no drift, both as the template
# projects itself and as a repository that applied it projects: a line that
# fired there would be a defect in the comparison, not in a repository.
RSpec.describe RepoConsistency::Drift do
  include RepoConsistency::Testing::TemplateFixture

  let(:real_template) { RepoConsistency::Template.load(File.join(repository_root, 'profiles', 'git-workflow')) }

  # The state of a repository that applied +template+ and vendored its
  # files under the runbook's header, as GitHub would answer for it.
  def applied(template)
    header = "<!-- vendored from sgbett/dotfiles-claude profiles/git-workflow.md -->\n\n"
    files = { 'CLAUDE.md' => "# Project\n\nGit tier: collaborative\n",
              '.claude/rules/git-workflow.md' => header + template.profile,
              '.claude/hooks/push-guard' => template.hooks['push-guard'],
              '.claude/hooks/push-guard.rb' => template.hooks['push-guard.rb'],
              '.claude/settings.json' => JSON.generate(template.hooks_settings) }
    ruleset = { 'id' => 1, 'name' => template.ruleset_name, 'bypass_actors' => [] }
    RepoConsistency::RepositoryState.new(repository: 'example-owner/applied', default_branch: 'master',
                                         flags: template.repository_flags, rules: template.rules, rulesets: [ruleset],
                                         protection: nil, rulesets_available: true, files: files)
  end

  it 'finds none between the template fixture and itself, nor against a repository that applied it' do
    template = RepoConsistency::Template.load(template_directory)

    expect(described_class.lines(template.projection, template.projection)).to eq([])
    expect(described_class.lines(template.projection, RepoConsistency::RepositoryProjection.call(applied(template))))
      .to eq([])
  end

  it 'finds none between profiles/git-workflow, the real template, and itself, nor against a repository that ' \
     'applied it' do
    expect(described_class.lines(real_template.projection, real_template.projection)).to eq([])
    expect(described_class.lines(real_template.projection,
                                 RepoConsistency::RepositoryProjection.call(applied(real_template)))).to eq([])
  end

  it 'reads the real template as the runbook describes it: three rules, merge commits alone, no bypass, no approvals' do
    projection = real_template.projection

    expect(real_template.ruleset_name).to eq('Git workflow')
    expect(projection.rule_types).to eq(%w[deletion non_fast_forward pull_request])
    expect(projection.to_h.values_at(:merge_methods, :approvals, :bypassing_rulesets, :default_branch, :tier))
      .to eq([['merge'], 0, [], 'master', 'collaborative'])
    expect(projection.flags).to eq('allow_squash_merge' => false, 'allow_rebase_merge' => false,
                                   'allow_merge_commit' => true, 'allow_update_branch' => false)
    expect(projection.hooks.keys).to eq(%w[push-guard push-guard.rb])
    expect(projection.hooks_entry).to eq(:present)
  end
end
