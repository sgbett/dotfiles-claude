# frozen_string_literal: true

require_relative '../lib/do/branch_pull_requests'
require_relative '../lib/do/trust'
require_relative 'support/records'

RSpec.describe Do::BranchPullRequests do
  include Do::Testing::Records

  let(:trust) { Do::Trust.new(viewer: 'example-viewer', home: home) }

  def pull_request(number, author, head: Do::Testing::Records::HOME)
    Do::PullRequest.new(number: number, author: author, head_repository: head)
  end

  def on_branch(pull_requests, push_repositories: [Do::Testing::Records::HOME])
    described_class.new(pull_requests, push_repositories: push_repositories, trust: trust)
  end

  it 'lists those whose head is in a repository the push remote pushes to, ignoring case, with their trust' do
    viewer = pull_request(30, author('example-viewer', viewer: true), head: 'EXAMPLE-OWNER/example-repo')
    member = pull_request(31, author('example-member', association: 'MEMBER'), head: 'example-fork-owner/example-repo')
    pull_requests = on_branch([viewer, member],
                              push_repositories: [Do::Testing::Records::HOME, 'example-fork-owner/example-repo'])

    expect(pull_requests.to_a)
      .to eq([{ number: 30, author: 'example-viewer', trusted: true, trust_reason: :viewer },
              { number: 31, author: 'example-member', trusted: true, trust_reason: :trusted_association }])
    expect(pull_requests).not_to be_untrusted
  end

  it 'ignores one from a branch of that name in a repository the push remote does not push to' do
    pull_requests = on_branch([pull_request(32, author('example-stranger'), head: 'example-stranger/example-repo')])

    expect([pull_requests.to_a, pull_requests.untrusted?]).to eq([[], false])
  end

  it "flags one by an author the Trust rule doesn't trust, a deleted account's included" do
    [author('example-stranger', association: 'CONTRIBUTOR'), author(nil, association: 'OWNER')].each do |writer|
      expect(on_branch([pull_request(33, writer)])).to be_untrusted, writer.inspect
    end
  end

  it 'counts one whose head repository GitHub no longer names, as it may be the branch' do
    expect(on_branch([pull_request(34, author('example-stranger'), head: nil)])).to be_untrusted
  end
end
