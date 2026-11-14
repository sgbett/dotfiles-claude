# frozen_string_literal: true

RSpec.describe SkillSupport::GhError do
  def failure(stdout:, stderr:)
    result = SkillSupport::CommandRunner::Result.new(stdout: stdout, stderr: stderr, exit_status: 1)
    described_class.new(%w[api user], result)
  end

  it 'reads the HTTP status and the API message gh reported' do
    error = failure(stdout: fixture('contents/not-found.json'), stderr: fixture('contents/not-found.stderr'))

    expect([error.http_status, error.api_message]).to eq([404, 'Not Found'])
    expect(error.message).to eq('gh api user exited 1: gh: Not Found (HTTP 404)')
  end

  it 'has neither when gh failed before any HTTP answer' do
    error = failure(stdout: '', stderr: "error connecting to api.github.com\n")

    expect([error.http_status, error.api_message]).to eq([nil, nil])
  end

  it 'has no API message when the body is not a JSON object' do
    expect([failure(stdout: '<html>', stderr: '').api_message, failure(stdout: '[]', stderr: '').api_message])
      .to eq([nil, nil])
  end

  it 'masks the credentials of a URL among the arguments it prints, keeping them for the caller' do
    url = 'https://x-access-token:example-secret@github.com/sgbett/dotfiles-claude.git'
    result = SkillSupport::CommandRunner::Result.new(stdout: '', stderr: "error\n", exit_status: 1)
    error = described_class.new(['repo', 'view', url, '--json', 'nameWithOwner'], result)

    expect(error.message)
      .to eq('gh repo view https://***@github.com/sgbett/dotfiles-claude.git --json nameWithOwner exited 1: error')
    expect(error.arguments).to include(url)
  end
end

RSpec.describe SkillSupport::GraphqlError do
  it 'names every error the response carried' do
    result = SkillSupport::CommandRunner::Result.new(stdout: '', stderr: '', exit_status: 0)
    errors = [{ 'type' => 'NOT_FOUND', 'message' => 'Could not resolve' }, { 'message' => 'Rate limited' }]

    expect(described_class.new(%w[api graphql], result, errors).message)
      .to eq('GraphQL errors: Could not resolve; Rate limited')
  end
end
