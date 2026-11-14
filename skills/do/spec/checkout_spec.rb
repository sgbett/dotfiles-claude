# frozen_string_literal: true

require_relative '../lib/do/checkout'

RSpec.describe Do::Checkout do
  subject(:checkout) { described_class.new(SkillSupport::CommandRunner.new) }

  it "gives origin's URL, or nil when there is no origin" do
    expect(checkout.origin_url).to be_nil

    system('git', 'remote', 'add', 'origin', 'https://github.com/sgbett/dotfiles-claude.git', exception: true)
    expect(checkout.origin_url).to eq('https://github.com/sgbett/dotfiles-claude.git')
  end

  it 'gives the git directory every worktree shares, as an absolute path' do
    system('git', 'commit', '--quiet', '--allow-empty', '-m', 'first', exception: true)
    worktree = sandbox.path('worktree')
    system('git', 'worktree', 'add', '--quiet', worktree, exception: true)

    Dir.chdir(worktree) do
      expect(checkout.common_directory).to eq(File.join(sandbox.work_directory, '.git'))
    end
  end

  it 'raises NotACheckout outside a git repository' do
    outside = sandbox.path('outside')
    FileUtils.mkdir_p(outside)
    ENV['GIT_CEILING_DIRECTORIES'] = sandbox.root

    Dir.chdir(outside) do
      expect(checkout.origin_url).to be_nil
      expect { checkout.common_directory }.to raise_error(Do::NotACheckout, /from a checkout/)
    end
  end
end
