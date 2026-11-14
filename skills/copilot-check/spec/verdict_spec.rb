# frozen_string_literal: true

require_relative '../lib/copilot_check/promote_check'

# Phase 6's conditions as the verdict judges them, from facts already read.
RSpec.describe CopilotCheck::Verdict do
  let(:head) { '0203427ffa8add0c145fa78cdc2415511ffbdaa1' }
  let(:other) { '56b92d3c76c8d5f09feb05ca05af160e8838d8cf' }

  def rules(draft_flow: true, merge_is_owners_step: true)
    CopilotCheck::PromotionRules.new('draft_flow' => draft_flow, 'merge_is_owners_step' => merge_is_owners_step,
                                     'expected_failures' => [])
  end

  def pull_request(**fields)
    CopilotCheck::PullRequestQuery::PullRequest.new(
      state: 'OPEN', draft: true, cross_repository: false, head: head,
      mergeable: 'MERGEABLE', changed_files: 2, author: 'sgbett', auto_merge: false, viewer: 'sgbett', **fields
    )
  end

  def threads(commit: head, todo_threads: [], todo_reviews: [])
    latest = commit && CopilotCheck::Threads::LatestReview.new(submitted_at: '2026-11-12T20:23:51Z', comments: 0,
                                                               commit: commit)
    CopilotCheck::Threads::Result.new(latest_review: latest, todo_threads: todo_threads,
                                      todo_reviews: todo_reviews.map { |id| review(id) })
  end

  def review(id)
    CopilotCheck::TodoSelection::TodoReview.new(review_id: id, body: 'data')
  end

  def todo_thread
    CopilotCheck::TodoSelection::TodoThread.new(thread_id: 'PRRT_x', outdated: false, comment_id: 1, path: 'a.rb',
                                                line: 1, original_line: 1, original_commit: nil, body: 'data')
  end

  def files(paths: %w[skills/do/SKILL.md], complete: true)
    CopilotCheck::ChangedFiles::Result.new(paths: paths, complete: complete)
  end

  def check(bucket, documented: nil)
    CopilotCheck::Checks::Check.new(name: 'test', bucket: bucket, link: '', documented: documented)
  end

  def facts(**overrides)
    CopilotCheck::Verdict::Facts.new(rules: rules, started_as_draft: true, outcome: 'converged',
                                     pull_request: pull_request, mergeable: 'MERGEABLE', local_head: head,
                                     threads: threads, reviews_without_findings: [], files: files,
                                     checks: [check('pass')], **overrides)
  end

  def verdict(**overrides)
    described_class.new(facts(**overrides))
  end

  # One way each condition fails, alone, by its reason.
  failing_alone = {
    not_open: -> { { pull_request: pull_request(state: 'MERGED') } },
    not_a_draft: -> { { pull_request: pull_request(draft: false) } },
    no_draft_flow: -> { { rules: rules(draft_flow: false) } },
    merge_not_owners_step: -> { { rules: rules(merge_is_owners_step: false) } },
    not_draft_at_start: -> { { started_as_draft: false } },
    not_converged: -> { { outcome: 'halted' } },
    local_head_differs: -> { { local_head: other } },
    copilot_not_on_head: -> { { threads: threads(commit: other) } },
    todo_threads: -> { { threads: threads(todo_threads: [todo_thread]) } },
    unanswered_reviews: -> { { threads: threads(todo_reviews: [7]) } },
    not_viewers_own: -> { { pull_request: pull_request(author: 'example-stranger') } },
    from_fork: -> { { pull_request: pull_request(cross_repository: true) } },
    files_unlisted: -> { { files: files(complete: false) } },
    protected_paths_changed: -> { { files: files(paths: %w[skills/do/SKILL.md CLAUDE.md]) } },
    no_checks: -> { { checks: [] } },
    checks_pending: -> { { checks: [check('pass'), check('pending')] } },
    checks_cancelled: -> { { checks: [check('cancel')] } },
    undocumented_failures: -> { { checks: [check('fail', documented: false)] } },
    not_mergeable: -> { { mergeable: 'UNKNOWN' } },
    auto_merge_on: -> { { pull_request: pull_request(auto_merge: true) } }
  }

  it 'promotes when every condition holds' do
    expect([verdict.verdict, verdict.reasons]).to eq(['PROMOTE', []])
  end

  it 'has a case below for every reason it can hold for' do
    expect(failing_alone.keys).to eq(CopilotCheck::Reasons::HOLD)
  end

  failing_alone.each do |reason, overrides|
    it "holds for #{reason} alone when only that condition fails" do
      expect([verdict(**instance_exec(&overrides)).verdict, verdict(**instance_exec(&overrides)).reasons])
        .to eq(['HOLD', [reason]])
    end
  end

  it 'lists every failing condition, in Phase 6 order, when several fail together' do
    combined = {
      pull_request: pull_request(state: 'MERGED', draft: false, author: 'example-stranger', cross_repository: true,
                                 auto_merge: true),
      rules: rules(draft_flow: false, merge_is_owners_step: false), started_as_draft: false, outcome: 'stop',
      local_head: other, threads: threads(commit: other, todo_threads: [todo_thread], todo_reviews: [7]),
      files: files(paths: %w[.github/workflows/ci.yml], complete: false), mergeable: 'CONFLICTING',
      checks: [check('pending'), check('cancel'), check('fail', documented: false)]
    }

    expect(verdict(**combined).reasons).to eq(CopilotCheck::Reasons::HOLD - [:no_checks])
    expect(verdict(**combined, checks: []).reasons)
      .to eq(CopilotCheck::Reasons::HOLD - %i[checks_pending checks_cancelled undocumented_failures])
  end

  it 'holds for every outcome but converged' do
    %w[halted timeout stop push-failed].each do |outcome|
      expect(verdict(outcome: outcome).reasons).to eq([:not_converged]), outcome
    end
  end

  it "holds when Copilot hasn't reviewed the pull request at all" do
    expect(verdict(threads: threads(commit: nil)).reasons).to eq([:copilot_not_on_head])
  end

  it 'holds for a deleted author, whom nobody is, and for a conflicting merge' do
    expect(verdict(pull_request: pull_request(author: nil)).reasons).to eq([:not_viewers_own])
    expect(verdict(mergeable: 'CONFLICTING').reasons).to eq([:not_mergeable])
  end

  it 'passes the to-do reviews the run found no finding in, and only those' do
    reviewed = threads(todo_reviews: [7, 8])

    expect(verdict(threads: reviewed, reviews_without_findings: [7, 8]).verdict).to eq('PROMOTE')
    expect(verdict(threads: reviewed, reviews_without_findings: [7, 9]).reasons).to eq([:unanswered_reviews])
  end

  it 'passes a failure the rules document, and checks that passed or were skipped' do
    expect(verdict(checks: [check('fail', documented: true), check('skipping'), check('pass')]).verdict)
      .to eq('PROMOTE')
  end
end
