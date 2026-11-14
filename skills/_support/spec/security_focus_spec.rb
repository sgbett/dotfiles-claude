# frozen_string_literal: true

RSpec.describe SkillSupport::SecurityFocus do
  subject(:focus) do
    described_class.new(SkillSupport::RepositoryFiles.new(SkillSupport::Gh.new(host: 'github.com',
                                                                               runner: fake_runner)))
  end

  let(:sha) { '6b9895d961416bbb7561778aff4e651822796e9e' }
  let(:repository) { 'sgbett/dotfiles-claude' }

  def read
    focus.read(repository, sha)
  end

  def contents_call(path, ref)
    ['gh', 'api', '--hostname', 'github.com', '-X', 'GET', "repos/#{repository}/contents/#{path}", '-f',
     "ref=#{ref}"]
  end

  # A contents API call answered with +body+, or with the recorded 404 for
  # nil.
  def expect_contents(path, ref, body)
    return fake_runner.expect_call(contents_call(path, ref), stdout: JSON.generate(body)) if body

    fake_runner.expect_call(contents_call(path, ref), exit_status: 1, stdout: fixture('contents/not-found.json'),
                                                      stderr: fixture('contents/not-found.stderr'))
  end

  # CLAUDE.md holding +text+, or none for nil, and no .claude/rules/.
  def expect_claude_md_without_rules(text)
    expect_contents('CLAUDE.md', sha, text && contents_file('CLAUDE.md', text))
    expect_contents('.claude/rules', sha, nil)
  end

  # The contents API's answer for a file holding +text+.
  def contents_file(path, text)
    { 'name' => File.basename(path), 'path' => path, 'type' => 'file', 'encoding' => 'base64',
      'content' => [text].pack('m') }
  end

  def listing(*entries)
    entries.map { |path, type| { 'name' => File.basename(path), 'path' => path, 'type' => type } }
  end

  it "reads CLAUDE.md's section at the commit given, when .claude/rules/ is absent" do
    expect_claude_md_without_rules("# Project\n\n## Security focus\n\nSecrets.\n\n## Code Style\n")
    result = read

    expect([result.found?, result.sources, result.text]).to eq([true, ['CLAUDE.md'], "## Security focus\n\nSecrets."])
  end

  it 'reads every file under .claude/rules/ one by one, subdirectories included, in path order' do
    expect_contents('CLAUDE.md', sha, nil)
    expect_contents('.claude/rules', sha, listing(['.claude/rules/z.md', 'file'], ['.claude/rules/area', 'dir'],
                                                  ['.claude/rules/a.md', 'file']))
    expect_contents('.claude/rules/a.md', sha, contents_file('.claude/rules/a.md', "# Style\n"))
    expect_contents('.claude/rules/area', sha, listing(['.claude/rules/area/web.md', 'file']))
    expect_contents('.claude/rules/area/web.md', sha,
                    contents_file('.claude/rules/area/web.md', "## Security focus\nWeb.\n"))
    expect_contents('.claude/rules/z.md', sha, contents_file('.claude/rules/z.md', "## Security focus\nLast.\n"))
    result = read

    expect([result.sources, result.text])
      .to eq([['.claude/rules/area/web.md', '.claude/rules/z.md'],
              "## Security focus\nWeb.\n\n## Security focus\nLast."])
  end

  it 'finds no focus when neither has a section, or neither exists' do
    expect_claude_md_without_rules("# Example\n\n## Code Style\n\nPlain.\n")
    expect_claude_md_without_rules(nil)

    expect([read, read].map { |result| [result.found?, result.sources, result.text] }).to eq([[false, [], '']] * 2)
  end

  it 'fails as a tool on any answer but 404 Not Found' do
    fake_runner.expect_call(contents_call('CLAUDE.md', sha), exit_status: 1, stdout: '{"message":"Bad credentials"}',
                                                             stderr: "gh: Bad credentials (HTTP 401)\n")

    expect { read }.to raise_error(SkillSupport::GhError, /HTTP 401/)
  end

  it 'fails as a tool on a CLAUDE.md that is a directory, or a .claude/rules that is a file' do
    expect_contents('CLAUDE.md', sha, listing(['CLAUDE.md/x', 'file']))
    expect { read }.to raise_error(SkillSupport::UnexpectedResponse, /CLAUDE.md is a directory/)

    expect_contents('CLAUDE.md', sha, nil)
    expect_contents('.claude/rules', sha, contents_file('.claude/rules', 'text'))
    expect { read }.to raise_error(SkillSupport::UnexpectedResponse, %r{\.claude/rules is a file})
  end

  it 'fails as a tool on a submodule, or a listing entry outside its directory or unreadable' do
    [listing(['.claude/rules/vendor', 'submodule']), listing(['.claude/other.md', 'file']),
     [{ 'path' => ".claude/rules/a\nb.md", 'type' => 'file' }], ['.claude/rules/a.md']].each do |entries|
      expect_contents('CLAUDE.md', sha, nil)
      expect_contents('.claude/rules', sha, entries)

      expect { read }.to raise_error(SkillSupport::UnexpectedResponse), entries.inspect
    end
  end
end
