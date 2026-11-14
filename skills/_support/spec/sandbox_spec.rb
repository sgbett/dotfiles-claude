# frozen_string_literal: true

RSpec.describe SkillSupport::Testing::Sandbox do
  def git(*arguments)
    output, status = Open3.capture2e('git', *arguments)
    [output.strip, status.success?]
  end

  it 'gives gh an empty configuration directory and a dummy token' do
    expect(ENV.fetch('GH_CONFIG_DIR')).to eq(sandbox.gh_config_directory)
    expect(Dir.empty?(sandbox.gh_config_directory)).to be(true)
    expect(ENV.fetch('GH_TOKEN')).to eq('dummy')
  end

  it 'clears every other GitHub credential and routing variable' do
    expect(ENV.keys & described_class::CLEARED_VARIABLES).to be_empty
  end

  it 'works in a fresh git repository of its own, outside this one' do
    expect(Dir.pwd).to eq(sandbox.work_directory)
    expect(git('rev-parse', '--show-toplevel')).to eq([sandbox.work_directory, true])
    expect(git('rev-parse', '--verify', '--quiet', 'HEAD')).to eq(['', false])
    expect(Dir.pwd).not_to start_with(repository_root)
  end

  it 'keeps the git configuration of the machine away from the repository' do
    expect(ENV.fetch('GIT_CONFIG_GLOBAL')).to eq(sandbox.git_config_file)
    expect(ENV.fetch('GIT_CONFIG_NOSYSTEM')).to eq('1')
    expect(git('config', '--global', '--list')).to eq(['', true])
  end

  it 'restores the environment it changed' do
    saved = ENV.to_h
    described_class.open { ENV['SKILL_SUPPORT_SPEC'] = 'leaked' }

    expect(ENV.to_h).to eq(saved)
  end
end
