# frozen_string_literal: true

require_relative '../lib/do/branch_assessment'
require_relative '../lib/do/branch_facts'

RSpec.describe Do::BranchAssessment do
  let(:branch) { 'feat/24-x' }
  let(:local_tip) { 'a' * 40 }
  let(:remote_tip) { 'b' * 40 }
  let(:tracking) { { tracking_remote: 'origin', merge: "refs/heads/#{branch}" } }

  def facts(**fields)
    Do::BranchFacts::Facts.new(more_lacking: false, **fields)
  end

  def assess(accepted_tip: nil, **fields)
    described_class.new(facts(**fields), branch: branch, remote: 'origin', accepted_tip: accepted_tip)
  end

  describe 'with no local branch' do
    it 'starts a new branch when the push remote has none either' do
      expect(assess.state).to eq(:new)
    end

    it "resumes from the push remote's copy" do
      expect(assess(remote_tip: remote_tip).state).to eq(:resume_push_remote)
    end

    it 'ignores branch configuration left behind' do
      expect(assess(tracking_remote: 'https://github.com/example-owner/fork.git').state).to eq(:new)
    end
  end

  describe 'with a local branch' do
    it 'resumes on it when it tracks its copy on the push remote and lacks nothing there' do
      expect(assess(remote_tip: remote_tip, local_tip: local_tip, lacking: [], **tracking).state).to eq(:resume_local)
    end

    it 'resumes on it when it is behind that copy' do
      expect(assess(remote_tip: remote_tip, local_tip: local_tip, lacking: [], push_remote: 'origin', **tracking).state)
        .to eq(:resume_local)
    end

    it 'takes one whose remote or pushRemote is a URL or another remote for a checked-out pull request' do
      [{ tracking_remote: 'https://github.com/example-owner/dotfiles-claude.git', merge: "refs/heads/#{branch}" },
       { tracking_remote: 'upstream', merge: "refs/heads/#{branch}" },
       { **tracking, push_remote: 'git@github.com:example-owner/dotfiles-claude.git' },
       { **tracking, push_remote: 'upstream' }].each do |config|
        expect(assess(local_tip: local_tip, lacking: [], **config).state).to eq(:checked_out_pr), config.inspect
      end
    end

    it 'takes one that merges a refs/pull/ ref for a checked-out pull request, wherever it tracks' do
      expect(assess(local_tip: local_tip, lacking: [], tracking_remote: 'origin', merge: 'refs/pull/31/head').state)
        .to eq(:checked_out_pr)
    end

    it "never resumes on a checked-out pull request, the user's yes notwithstanding" do
      assessment = assess(local_tip: local_tip, lacking: [], accepted_tip: local_tip, tracking_remote: 'upstream')

      expect([assessment.state, assessment.accepted?, assessment.ask, assessment.stop_reason])
        .to eq([:checked_out_pr, false, nil, :checked_out_pr])
    end

    it "resumes beside a checked-out pull request from the push remote's copy, in a fresh worktree" do
      beside = assess(remote_tip: remote_tip, local_tip: local_tip, lacking: [], merge: 'refs/pull/7/head',
                      accepted_tip: local_tip)

      expect([beside.state, beside.fresh_worktree?, beside.accepted?, beside.stop_reason, beside.resuming?])
        .to eq([:resume_push_remote, true, false, nil, true])
      expect(assess(remote_tip: remote_tip).fresh_worktree?).to be(false)
    end

    it 'asks about one never pushed, one ahead, and one whose copy could not be fetched to compare' do
      [{ lacking: ['1234567 Example Author Work'] },
       { remote_tip: remote_tip, lacking: ['1234567 Example Author Ahead'], **tracking },
       { remote_tip: remote_tip, lacking: nil, **tracking }].each do |fields|
        expect(assess(local_tip: local_tip, **fields).state).to eq(:local_branch_unpushed), fields.inspect
      end
    end

    it 'asks about one that tracks nothing, a branch of this repository, or another branch on the push remote' do
      [{}, { tracking_remote: '.', merge: 'refs/heads/master' },
       { tracking_remote: 'origin', merge: 'refs/heads/master' }]
        .each do |config|
          expect(assess(remote_tip: remote_tip, local_tip: local_tip, lacking: [], **config).state)
            .to eq(:local_branch_unpushed), config.inspect
        end
    end

    it "asks with the flag a yes passes back, tied to the local branch's tip" do
      expect(assess(local_tip: local_tip, lacking: []).ask)
        .to eq(reason: :local_branch_unpushed, message: Do::Reasons::MESSAGES[:local_branch_unpushed],
               accept_with: ['--accept-local-branch', local_tip])
    end

    it 'resumes on it once the user accepts its current tip, and asks again for any other' do
      accepted = assess(local_tip: local_tip, lacking: ['1234567 Example Author Work'], accepted_tip: local_tip)
      moved = assess(local_tip: local_tip, lacking: ['1234567 Example Author Work'], accepted_tip: remote_tip)

      expect([accepted.state, accepted.accepted?, accepted.ask]).to eq([:resume_local, true, nil])
      expect([moved.state, moved.accepted?]).to eq([:local_branch_unpushed, false])
    end
  end

  it 'stops when the push URLs differ on the branch, whatever is local' do
    [{ remote_tips: [remote_tip, local_tip] }, { remote_tips: [remote_tip, nil] },
     { remote_tips: [nil, remote_tip], local_tip: local_tip, lacking: [], **tracking }].each do |fields|
      assessment = assess(**fields)

      expect([assessment.state, assessment.stop_reason, assessment.resuming?])
        .to eq([:remote_tips_differ, :remote_tips_differ, false]), fields.inspect
    end
  end

  it 'counts every state but a new branch and a checked-out pull request as resuming' do
    expect([assess, assess(remote_tip: remote_tip), assess(local_tip: local_tip, lacking: []),
            assess(remote_tip: remote_tip, local_tip: local_tip, lacking: [], **tracking),
            assess(local_tip: local_tip, lacking: [], merge: 'refs/pull/1/head')].map(&:resuming?))
      .to eq([false, true, true, true, false])
  end
end
