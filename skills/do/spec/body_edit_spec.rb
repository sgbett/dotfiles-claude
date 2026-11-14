# frozen_string_literal: true

require_relative '../lib/do/body_edit'

RSpec.describe Do::BodyEdit do
  subject(:edit) { described_class.comment(SkillSupport::Gh.new(host: 'github.com', runner: fake_runner), here, 7) }

  let(:here) { 'example-owner/example-repo' }
  let(:get) { %w[gh api --hostname github.com -X GET repos/example-owner/example-repo/issues/comments/7] }
  let(:patch) { %w[gh api --hostname github.com -X PATCH repos/example-owner/example-repo/issues/comments/7 --input -] }

  def answer(body)
    JSON.generate('id' => 7, 'body' => body)
  end

  it 'reads the body, and an empty one as ""' do
    fake_runner.expect_call(get, stdout: answer('Text'))
    fake_runner.expect_call(get, stdout: answer(nil))

    expect([edit.read, edit.read]).to eq(['Text', ''])
  end

  it 'fails as a tool on an answer without a body' do
    fake_runner.expect_call(get, stdout: '{"id":7}')

    expect { edit.read }.to raise_error(SkillSupport::UnexpectedResponse, /without a body/)
  end

  it 'writes only once a fresh read matches the body the change was made from, then reads it back' do
    fake_runner.expect_call(get, stdout: answer('- [ ] One'))
    fake_runner.expect_call(patch, stdin: '{"body":"- [x] One"}', stdout: answer('- [x] One'))
    fake_runner.expect_call(get, stdout: answer('- [x] One'))

    expect { edit.write('- [ ] One', '- [x] One') }.not_to raise_error
  end

  it 'raises BodyChanged, writing nothing, when the body changed since it was read' do
    fake_runner.expect_call(get, stdout: answer('- [ ] One, edited'))

    expect { edit.write('- [ ] One', '- [x] One') }.to raise_error(Do::BodyChanged)
  end

  it 'fails as a tool when what it wrote does not read back' do
    fake_runner.expect_call(get, stdout: answer('- [ ] One'))
    fake_runner.expect_call(patch, stdin: '{"body":"- [x] One"}', stdout: answer('- [x] One'))
    fake_runner.expect_call(get, stdout: answer('- [ ] One'))

    expect { edit.write('- [ ] One', '- [x] One') }
      .to raise_error(SkillSupport::UnexpectedResponse, /doesn't read back as written/)
  end

  it "addresses the issue's own body by its number" do
    issue = described_class.issue(SkillSupport::Gh.new(host: 'github.com', runner: fake_runner), here, 24)
    fake_runner.expect_call(%w[gh api --hostname github.com -X GET repos/example-owner/example-repo/issues/24],
                            stdout: answer('Body'))

    expect(issue.read).to eq('Body')
  end
end
