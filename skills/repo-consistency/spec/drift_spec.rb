# frozen_string_literal: true

require_relative 'support/script_calls'
require_relative 'support/template_fixture'
require_relative '../lib/repo_consistency/drift'
require_relative '../lib/repo_consistency/repository_projection'
require_relative '../lib/repo_consistency/repository_state'
require_relative '../lib/repo_consistency/skill_scan'

# The template projected onto itself has no drift, both as the template
# projects itself and as a repository that applied it projects: a line that
# fired there would be a defect in the comparison, not in a repository. The
# applied repository's instruction files are its CLAUDE.md and the vendored
# profile, so the real template's case also shows the profile names no
# user-level skill.
RSpec.describe RepoConsistency::Drift do
  include RepoConsistency::Testing::TemplateFixture

  let(:real_template) { RepoConsistency::Template.load(File.join(repository_root, 'profiles', 'git-workflow')) }
  # GitHub's detail of the three real templates as applied to a public
  # scratch repository (spec/fixtures/README.md), in template order.
  let(:scratch_details) do
    [28_033_488, 28_033_490, 28_033_491].map do |id|
      JSON.parse(File.read(File.join(RepoConsistency::Testing::ScriptCalls::FIXTURES, 'rulesets',
                                     "ruleset-scratch-#{id}.json")))
    end
  end

  # The state of a repository that applied +template+ and vendored its
  # profile under the runbook's header, as GitHub would answer for it.
  def applied(template, rulesets: template.rulesets.map.with_index(1) { |ruleset, id| ruleset.merge('id' => id) })
    files = vendored(template)
    scan = RepoConsistency::SkillScan.new(texts: files.values_at('.claude/rules/git-workflow.md', 'CLAUDE.md'),
                                          shipped: [])
    RepoConsistency::RepositoryState.new(repository: 'example-owner/applied', default_branch: 'master',
                                         flags: template.repository_flags, rules: template.rules, rulesets: rulesets,
                                         protection: nil, rulesets_available: true, files: files, skill_scan: scan)
  end

  def vendored(template)
    header = "<!-- vendored from sgbett/dotfiles-claude profiles/git-workflow.md -->\n\n"
    { 'CLAUDE.md' => "# Project\n", '.claude/rules/git-workflow.md' => header + template.profile }
  end

  def drift(state, template = real_template)
    described_class.lines(template.projection, RepoConsistency::RepositoryProjection.call(state))
  end

  it 'finds none between the template fixture and itself, nor against a repository that applied it' do
    template = RepoConsistency::Template.load(template_directory)

    expect(described_class.lines(template.projection, template.projection)).to eq([])
    expect(drift(applied(template), template)).to eq([])
  end

  it 'finds none between profiles/git-workflow, the real template, and itself, nor against a repository that ' \
     'applied it' do
    expect(described_class.lines(real_template.projection, real_template.projection)).to eq([])
    expect(drift(applied(real_template))).to eq([])
  end

  it "reports a ruleset's bypass actors unreadable when GitHub leaves them out of its detail, as it does for a " \
     'caller without admin rights, rather than clean where it cannot see' do
    state = applied(real_template)
    state.rulesets[0] = state.rulesets[0].except('bypass_actors')

    expect(drift(state)).to eq(['ruleset "Git workflow" bypass actors unreadable'])
  end

  it 'reads the real template as the runbook describes it: three rules on the default branch, merge commits alone, ' \
     'no approvals, and no extra approval for unattributed changes' do
    projection = real_template.projection

    expect(projection.rule_types).to eq(%w[deletion non_fast_forward pull_request])
    expect(projection.to_h.values_at(:merge_methods, :approvals, :extra_approval, :ruleset_bypasses, :default_branch,
                                     :tier))
      .to eq([['merge'], 0, false, [], 'master', 'protected'])
    expect(projection.flags).to eq('allow_squash_merge' => false, 'allow_rebase_merge' => false,
                                   'allow_merge_commit' => true, 'allow_update_branch' => false)
  end

  it 'pins the real ruleset templates: project bases and release branches by pattern, tags against deletion and ' \
     'update but not creation, and no bypass actors in any' do
    by_name = real_template.rulesets.to_h { |ruleset| [ruleset['name'], ruleset] }
    shape = ->(name) { RepoConsistency::RulesetShape.of(by_name.fetch(name)).to_h }

    expect(by_name.keys).to eq(['Git workflow', 'Project and release branches', 'Tags'])
    expect(real_template.rulesets.map { |ruleset| ruleset['bypass_actors'] }).to eq([[], [], []])
    expect(shape.call('Git workflow').values_at(:target, :enforcement, :includes, :excludes))
      .to eq(['branch', 'active', ['~DEFAULT_BRANCH'], []])
    expect(shape.call('Project and release branches'))
      .to eq(target: 'branch', enforcement: 'active', includes: %w[refs/heads/project/*/master refs/heads/releases/*],
             excludes: [], rules: { 'deletion' => {}, 'non_fast_forward' => {} })
    expect(shape.call('Tags'))
      .to eq(target: 'tag', enforcement: 'active', includes: ['~ALL'], excludes: [],
             rules: { 'deletion' => {}, 'update' => {} })
  end

  describe 'rulesets compared with the templates' do
    it "finds none in GitHub's detail of the real templates as applied, whatever defaults GitHub adds" do
      expect(drift(applied(real_template, rulesets: scratch_details))).to eq([])
    end

    it 'names, for each template ruleset that differs, the fields it differs in, comparing patterns in either ' \
       'order and only the parameters the template states' do
      default_branch, protected_branches, tags = scratch_details
      default_branch['rules'][2]['parameters']['allowed_merge_methods'] = %w[merge squash]
      default_branch['conditions']['ref_name']['include'] = ['~DEFAULT_BRANCH', 'refs/heads/main']
      protected_branches['conditions']['ref_name']['include'].reverse!
      protected_branches['rules'].pop
      protected_branches['target'] = 'push'
      tags['enforcement'] = 'disabled'
      tags['rules'] << { 'type' => 'creation' }
      tags['conditions']['ref_name']['exclude'] = ['refs/tags/scratch-*']

      expect(drift(applied(real_template, rulesets: [default_branch, protected_branches, tags])))
        .to eq(['ruleset "Git workflow" differs: include, rules',
                'ruleset "Project and release branches" differs: target, rules',
                'ruleset "Tags" differs: enforcement, exclude, rules'])
    end

    it 'reports a template ruleset missing by name, and reads a malformed detail as differing rather than failing' do
      default_branch, protected_branches, = scratch_details
      protected_branches['conditions'] = 'not an object'
      protected_branches['rules'] = [{ 'type' => 'deletion', 'parameters' => [] }, 'non_fast_forward']

      expect(drift(applied(real_template, rulesets: [default_branch, protected_branches])))
        .to eq(['ruleset "Project and release branches" differs: include, rules', 'ruleset "Tags" missing'])
    end
  end
end
