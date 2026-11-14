# frozen_string_literal: true

RSpec.describe SkillSupport::RepositoryFiles do
  subject(:files) { described_class.new(SkillSupport::Gh.new(host: 'github.com', runner: fake_runner)) }

  def contents_call(path, ref)
    ['gh', 'api', '--hostname', 'github.com', '-X', 'GET', "repos/sgbett/dotfiles-claude/contents/#{path}", '-f',
     "ref=#{ref}"]
  end

  def answer(path, ref, body)
    fake_runner.expect_call(contents_call(path, ref), stdout: JSON.generate(body))
  end

  it 'returns a file decoded from base64 as UTF-8' do
    fake_runner.expect_call(contents_call('LICENSE', 'master'), stdout: fixture('contents/license.json'))

    license = files.read('sgbett/dotfiles-claude', 'LICENSE', ref: 'master')

    expect(license).to start_with("MIT License\n").and include('Permission is hereby granted')
    expect(license.encoding).to eq(Encoding::UTF_8)
  end

  it 'returns a directory listing to read file by file' do
    fake_runner.expect_call(contents_call('profiles', 'master'), stdout: fixture('contents/profiles.json'))

    listing = files.read('sgbett/dotfiles-claude', 'profiles', ref: 'master')

    expect(listing.map { |entry| entry.values_at('path', 'type') })
      .to eq([%w[profiles/git-workflow.md file], %w[profiles/work-organisation.md file]])
  end

  it 'returns nil for 404 Not Found, the only answer that means absent' do
    fake_runner.expect_call(contents_call('no-such-file.md', 'master'), exit_status: 1,
                                                                        stdout: fixture('contents/not-found.json'),
                                                                        stderr: fixture('contents/not-found.stderr'))

    expect(files.read('sgbett/dotfiles-claude', 'no-such-file.md', ref: 'master')).to be_nil
  end

  it 'sends a ref with # and + whole, and raises for the 404 a missing ref gets' do
    ref = 'feat/#24+no-such-branch'
    fake_runner.expect_call(contents_call('LICENSE', ref), exit_status: 1,
                                                           stdout: fixture('contents/no-commit-for-ref.json'),
                                                           stderr: fixture('contents/no-commit-for-ref.stderr'))

    expect { files.read('sgbett/dotfiles-claude', 'LICENSE', ref: ref) }
      .to raise_error(SkillSupport::GhError, %r{No commit found for the ref feat/#24\+no-such-branch \(HTTP 404\)})
  end

  it 'raises for any other failure' do
    fake_runner.expect_call(contents_call('LICENSE', 'master'), exit_status: 1,
                                                                stdout: fixture('contents/bad-credentials.json'),
                                                                stderr: fixture('contents/bad-credentials.stderr'))

    expect { files.read('sgbett/dotfiles-claude', 'LICENSE', ref: 'master') }
      .to raise_error(SkillSupport::GhError) { |error| expect(error.http_status).to eq(401) }
  end

  it 'raises when gh fails before GitHub answers, rather than reading the file as absent' do
    fake_runner.expect_call(contents_call('CLAUDE.md', 'master'), exit_status: 1,
                                                                  stderr: "error connecting to api.github.com\n")

    expect { files.read('sgbett/dotfiles-claude', 'CLAUDE.md', ref: 'master') }
      .to raise_error(SkillSupport::GhError, /error connecting/)
  end

  it 'percent-encodes each path segment and keeps the slashes between them' do
    fake_runner.expect_call(contents_call('.claude/rules/r%C3%A8gles%20%231%3F.md', 'master'),
                            stdout: fixture('contents/license.json'))

    expect(files.read('sgbett/dotfiles-claude', '.claude/rules/règles #1?.md', ref: 'master')).to start_with('MIT')
  end

  it 'refuses an empty path or one with an empty, dot or dot-dot segment, before calling gh' do
    ['', '/CLAUDE.md', 'a//b', 'a/', '../x', 'a/./b', '..', nil].each do |path|
      expect { files.read('sgbett/dotfiles-claude', path, ref: 'master') }
        .to raise_error(SkillSupport::InvalidIdentifier, 'invalid file_path'), "accepted #{path.inspect}"
    end
  end

  it 'refuses an empty ref, which would read the default branch, and control characters' do
    ['', nil, "master\nx"].each do |ref|
      expect { files.read('sgbett/dotfiles-claude', 'CLAUDE.md', ref: ref) }
        .to raise_error(SkillSupport::InvalidIdentifier, 'invalid ref'), "accepted #{ref.inspect}"
    end
  end

  it 'refuses an invalid repository before calling gh' do
    expect { files.read('sgbett dotfiles-claude', 'CLAUDE.md', ref: 'master') }
      .to raise_error(SkillSupport::InvalidIdentifier, 'invalid repository')
  end

  it 'raises for a symlink, a submodule, or a file too large for the API to return' do
    { 'link' => { 'type' => 'symlink', 'target' => 'elsewhere' },
      'module' => { 'type' => 'submodule' },
      'big.bin' => { 'type' => 'file', 'encoding' => 'none', 'content' => '' } }.each do |path, body|
      answer(path, 'master', body)

      expect { files.read('sgbett/dotfiles-claude', path, ref: 'master') }
        .to raise_error(SkillSupport::UnexpectedResponse, /\A#{Regexp.escape(path)} /)
    end
  end

  it 'raises for a listing at the API limit, which may be truncated' do
    answer('many', 'master', Array.new(described_class::LISTING_LIMIT) { |index| { 'name' => "f#{index}" } })

    expect { files.read('sgbett/dotfiles-claude', 'many', ref: 'master') }
      .to raise_error(SkillSupport::UnexpectedResponse, /may have more entries/)
  end
end
