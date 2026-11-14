# frozen_string_literal: true

RSpec.describe SkillSupport::Identifiers do
  def expect_rejected(kind, values, &check)
    values.each do |value|
      expect { check.call(value) }
        .to raise_error(SkillSupport::InvalidIdentifier, "invalid #{kind}"), "accepted #{value.inspect}"
    end
  end

  describe '.repository!' do
    it 'accepts owner/repo as GitHub names them' do
      %w[sgbett/dotfiles-claude twbs/bootstrap example-owner/.github example_shortcode/repo.name a/b].each do |value|
        expect(described_class.repository!(value)).to eq(value)
      end
    end

    it 'rejects anything else' do
      values = ['', 'sgbett', 'sgbett/', '/repo', 'a/b/c', '-owner/repo', 'owner/..', 'owner/.', 'owner/re po',
                "owner/repo\n", 'owner/repo#24', 'https://github.com/owner/repo', 'owner\\repo', nil, 42]
      expect_rejected(:repository, values) { |value| described_class.repository!(value) }
    end

    it 'names only the kind in its message, keeping the value for diagnostics' do
      expect { described_class.repository!("x/y\nmalicious") }
        .to raise_error(SkillSupport::InvalidIdentifier) { |error|
          expect([error.message, error.kind, error.value]).to eq(['invalid repository', :repository, "x/y\nmalicious"])
        }
    end
  end

  describe '.issue_number!' do
    it 'returns the number as an Integer' do
      expect(['24', 24, '9999999999'].map { |value| described_class.issue_number!(value) })
        .to eq([24, 24, 9_999_999_999])
    end

    it 'rejects anything but a positive decimal number without leading zeros' do
      values = ['', '0', '024', '-1', '+1', '1e3', '#24', "24\n", ' 24', '12345678901', 0, -3, 24.0, nil]
      expect_rejected(:issue_number, values) { |value| described_class.issue_number!(value) }
    end
  end

  describe '.node_id!' do
    it 'accepts current and legacy node ids' do
      %w[I_kwDOQOLWRc7Tq9Ex R_kgDOOu5lLA MDQ6VXNlcjEwOTEzNQ== IC_kwDO-_x=].each do |value|
        expect(described_class.node_id!(value)).to eq(value)
      end
    end

    it 'rejects anything that is not safe in a file name' do
      values = ['', '-I_kw', 'I/kw', 'I+kw', 'I.kw', '../gate', "I_kw\n", 'I kw', 'a' * 101, nil]
      expect_rejected(:node_id, values) { |value| described_class.node_id!(value) }
    end
  end

  describe '.comment_id!' do
    it 'returns the id as an Integer' do
      expect(['6867069660', 6_867_069_660].map { |value| described_class.comment_id!(value) })
        .to eq([6_867_069_660, 6_867_069_660])
    end

    it 'rejects anything but a positive decimal number' do
      values = ['', '0', '01', '-1', 'IC_kwDO', "1\n", '1' * 21, nil]
      expect_rejected(:comment_id, values) { |value| described_class.comment_id!(value) }
    end
  end

  describe '.commit_sha!' do
    it 'accepts a whole SHA-1 or SHA-256 object name, lower-cased' do
      sha1 = '5c766e2986ce31d0f4fd8a1391da1098c217dcac'
      sha256 = 'a' * 64

      expect([sha1, sha1.upcase, sha256].map { |value| described_class.commit_sha!(value) }).to eq([sha1, sha1, sha256])
    end

    it 'rejects an abbreviation, a ref, other lengths and anything not hexadecimal' do
      values = ['', '5c766e2', 'HEAD', 'master', "#{'a' * 40}\n", 'g' * 40, 'a' * 41, 'a' * 63, "-#{'a' * 39}", nil]
      expect_rejected(:commit_sha, values) { |value| described_class.commit_sha!(value) }
    end
  end

  describe '.host!' do
    it 'accepts a host name and lower-cases it' do
      expect(%w[github.com GitHub.COM octocorp.ghe.com].map { |value| described_class.host!(value) })
        .to eq(%w[github.com github.com octocorp.ghe.com])
    end

    it 'rejects a scheme, port, path, bare label or malformed name' do
      values = ['', '-github.com', 'github', 'github.com/', 'github.com:443', 'https://github.com', 'github..com',
                '.github.com', 'github.com.', 'git hub.com', "github.com\n", "#{'a' * 64}.com",
                "#{(['a' * 63] * 4).join('.')}.com", nil]
      expect_rejected(:host, values) { |value| described_class.host!(value) }
    end
  end

  describe '.branch!' do
    def switch_away_from_a_second_branch
      system('git', 'commit', '--quiet', '--allow-empty', '-m', 'first', exception: true)
      system('git', 'switch', '--quiet', '-c', 'previous', exception: true)
      system('git', 'switch', '--quiet', 'master', exception: true)
    end

    it 'accepts a name git accepts, # and + included' do
      %w[feat/24-hlr-do-and-copilot-check-move feat/#24+x master].each do |value|
        expect(described_class.branch!(value)).to eq(value)
      end
    end

    it 'rejects a name git refuses, an option, or a control character' do
      values = ['', '-x', '--help', 'a..b', 'a b', 'foo.lock', 'HEAD', 'x/', 'a~b', "a\tb", "feat\nx", "a\0b", nil]
      expect_rejected(:branch, values) { |value| described_class.branch!(value) }
    end

    it 'rejects a name git would rewrite, such as @{-1} for the previous branch' do
      switch_away_from_a_second_branch

      expect_rejected(:branch, ['@{-1}']) { |value| described_class.branch!(value) }
    end

    it 'asks git through the runner it is given' do
      fake_runner.expect_call(['git', 'check-ref-format', '--branch', 'feat/#24'], stdout: "feat/#24\n")
      fake_runner.expect_call(['git', 'check-ref-format', '--branch', '@{-1}'], stdout: "previous\n")

      expect(described_class.branch!('feat/#24', runner: fake_runner)).to eq('feat/#24')
      expect_rejected(:branch, ['@{-1}']) { |value| described_class.branch!(value, runner: fake_runner) }
    end
  end
end
