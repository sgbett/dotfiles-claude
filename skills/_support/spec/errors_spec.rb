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
end

RSpec.describe SkillSupport::GraphqlError do
  it 'names every error the response carried' do
    result = SkillSupport::CommandRunner::Result.new(stdout: '', stderr: '', exit_status: 0)
    errors = [{ 'type' => 'NOT_FOUND', 'message' => 'Could not resolve' }, { 'message' => 'Rate limited' }]

    expect(described_class.new(%w[api graphql], result, errors).message)
      .to eq('GraphQL errors: Could not resolve; Rate limited')
  end
end
