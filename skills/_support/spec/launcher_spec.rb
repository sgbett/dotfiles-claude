# frozen_string_literal: true

RSpec.describe 'skills/_support/bin/ruby-launch' do
  let(:launcher) { File.join(repository_root, 'skills', '_support', 'bin', 'ruby-launch') }
  let(:templates) { SkillSupport::Testing::LaunchProbe::TEMPLATES }
  let(:repository_ruby_version) { File.read(File.join(repository_root, '.ruby-version')).strip.delete_prefix('ruby-') }

  def probe(with_support: true)
    SkillSupport::Testing::LaunchProbe.new(sandbox, with_support: with_support)
  end

  def report(stdout, stderr, status)
    expect(status.exitstatus).to eq(0), "exit #{status.exitstatus}: #{stderr}"
    JSON.parse(stdout)
  end

  # RUBYOPT loads Bundler against a Gemfile naming a gem that doesn't exist,
  # RUBYLIB shadows the standard library's json, and the gem paths are empty.
  def hostile_environment
    poison = sandbox.path('poison')
    gems = sandbox.path('gems')
    FileUtils.mkdir_p([poison, gems])
    File.write(File.join(poison, 'json.rb'), "raise 'RUBYLIB reached the script'\n")
    File.write('Gemfile', "source 'https://rubygems.org'\ngem 'skill-support-no-such-gem'\n")
    { 'RUBYOPT' => '-rbundler/setup', 'BUNDLE_GEMFILE' => File.expand_path('Gemfile'), 'RUBYLIB' => poison,
      'GEM_HOME' => gems, 'GEM_PATH' => gems }
  end

  def on_path?(program)
    ENV.fetch('PATH').split(File::PATH_SEPARATOR).any? { |directory| File.executable?(File.join(directory, program)) }
  end

  # PATH with a ruby first that fails, as the launcher's fallback would.
  def path_with_failing_ruby
    fake_ruby = sandbox.path('fake-bin', 'ruby')
    FileUtils.mkdir_p(File.dirname(fake_ruby))
    File.write(fake_ruby, "#!/bin/sh\necho 'the Ruby on PATH ran' >&2\nexit 42\n")
    File.chmod(0o755, fake_ruby)
    [File.dirname(fake_ruby), ENV.fetch('PATH')].join(File::PATH_SEPARATOR)
  end

  def old_ruby
    candidates = mise_rubies + ['/usr/bin/ruby']
    candidates.find { |ruby| File.executable?(ruby) && older_than_supported?(ruby) }
  end

  def mise_rubies
    output, _stderr, status = Open3.capture3('mise', 'ls', '--installed', '--json', 'ruby')
    status.success? ? JSON.parse(output).map { |install| File.join(install['install_path'], 'bin', 'ruby') } : []
  rescue Errno::ENOENT
    []
  end

  def older_than_supported?(ruby)
    version, _stderr, status = Open3.capture3(ruby, '-e', 'print RUBY_VERSION')
    status.success? && Gem::Version.new(version) < Gem::Version.new('3.1')
  end

  it 'faces an environment that does break a plain ruby' do
    environment = hostile_environment

    _stdout, bundler_error, bundler_status = Open3.capture3(environment.slice('RUBYOPT', 'BUNDLE_GEMFILE'),
                                                            RbConfig.ruby, '-e', 'exit')
    _stdout, rubylib_error, rubylib_status = Open3.capture3(environment.slice('RUBYLIB'),
                                                            RbConfig.ruby, '-e', 'require "json"')

    expect([bundler_status.success?, rubylib_status.success?]).to eq([false, false])
    expect(bundler_error).to include('skill-support-no-such-gem')
    expect(rubylib_error).to include('RUBYLIB reached the script')
  end

  it "runs the entry on the repository's Ruby whatever RUBYOPT, RUBYLIB, the gem paths and the Gemfile say" do
    result = report(*Open3.capture3(hostile_environment, probe.command))

    expect(result).to include('status' => 'proceed', 'ruby_version' => repository_ruby_version,
                              'bundler_loaded' => false, 'environment' => {})
  end

  it "ignores the Ruby first on PATH and the calling directory's .ruby-version" do
    skip "mise isn't installed, so the launcher falls back to the Ruby on PATH" unless on_path?('mise')
    # Installed or not, an old pin consulted by mistake ends in a failure.
    File.write('.ruby-version', "2.7.4\n")

    result = report(*Open3.capture3({ 'PATH' => path_with_failing_ruby }, probe.command))

    expect(result['ruby_version']).to eq(repository_ruby_version)
  end

  it "lets mise read no config file but those /do's scripts digest covers, nor an environment's or platform's" do
    skip "mise isn't installed, so the launcher falls back to the Ruby on PATH" unless on_path?('mise')
    copy = sandbox.path('tree', 'skills', '_support', 'bin', 'ruby-launch')
    FileUtils.mkdir_p(File.dirname(copy))
    FileUtils.cp(launcher, copy, preserve: true)
    FileUtils.cp(File.join(repository_root, '.ruby-version'), sandbox.path('tree'))
    %w[.rtx.toml .config/mise/mise.toml mise.local.toml mise.ci.toml mise.unix.toml].each do |name|
      FileUtils.mkdir_p(File.dirname(File.join(File.dirname(copy), name)))
      File.write(File.join(File.dirname(copy), name), "[tools]\nruby = '2.7.4'\n")
    end
    File.write('version.rb', 'print RUBY_VERSION')
    # Trusted, so that mise would read each of them were it not kept from it.
    environment = { 'PATH' => path_with_failing_ruby, 'MISE_TRUSTED_CONFIG_PATHS' => sandbox.path('tree'),
                    'MISE_STATE_DIR' => sandbox.path('mise-state'), 'MISE_ENV' => 'ci', 'MISE_AUTO_ENV' => 'true' }

    stdout, _stderr, status = Open3.capture3(environment, copy, File.expand_path('version.rb'))

    expect([status.exitstatus, stdout]).to eq([0, repository_ruby_version])
  end

  it 'hands the arguments over verbatim' do
    arguments = ['two words', '--flag', '', '#24', '$HOME', 'a;b']

    expect(report(*Open3.capture3(probe.command, *arguments))['arguments']).to eq(arguments)
  end

  it 'finds skills/_support through a skill directory reached by a symlink' do
    launched = probe

    expect(File.symlink?(File.dirname(launched.command, 2))).to be(true)
    expect(report(*Open3.capture3(launched.command))['status']).to eq('proceed')
  end

  it 'reports a missing skills/_support as a tool failure, not a shell error' do
    stdout, stderr, status = Open3.capture3(probe(with_support: false).command)

    expect([status.exitstatus, stdout]).to eq([1, ''])
    expect(stderr)
      .to match(%r{\Aprobe: tool failure: skills/_support is missing beside \S+; install skills/ as one unit\n\z})
  end

  it 'reports a missing library from the entry itself, not as a LoadError' do
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, '--disable=rubyopt', probe(with_support: false).entry)

    expect([status.exitstatus, stdout]).to eq([1, ''])
    expect(stderr.lines.length).to eq(1)
    expect(stderr).to match(%r{\Aprobe: tool failure: \S+/_support/lib/skill_support\.rb is missing; install skills/})
  end

  it 'stops a Ruby older than 3.1 at the version check, before any newer syntax' do
    ruby = old_ruby || skip('no Ruby older than 3.1 is installed')

    stdout, stderr, status = Open3.capture3(ruby, '--disable=rubyopt', probe.entry)

    expect([status.exitstatus, stdout]).to eq([1, ''])
    expect(stderr)
      .to match(/\Aprobe: tool failure: Ruby 2\.\d+\.\d+ is too old, 3\.1 or later is needed; run mise install/)
  end

  it 'refuses an entry that looks like an option, and a missing one' do
    option = Open3.capture3(launcher, '-e', 'print 1')
    missing = Open3.capture3(launcher)

    expect([option, missing].map { |stdout, _stderr, status| [status.exitstatus, stdout] }).to eq([[1, ''], [1, '']])
    expect(option[1]).to include('the entry file must be a path')
    expect(missing[1]).to include('no entry file given')
  end

  describe 'the skills that launch through it' do
    let(:stubs) do
      Dir.glob(File.join(repository_root, 'skills', '*', 'bin', '*'))
         .reject { |file| file.include?('/_support/') }
         .select { |file| File.file?(file) && File.read(file).include?('ruby-launch') }
    end

    it 'run it from an unchanged, executable copy of templates/bin_stub' do
      template = File.read(File.join(templates, 'bin_stub'))

      stubs.each do |stub|
        expect(File.read(stub)).to eq(template), "#{stub} differs from templates/bin_stub"
        expect(File).to be_executable(stub)
      end
    end

    it 'begin each entry with an unchanged copy of templates/entry_preamble.rb' do
      preamble = File.read(File.join(templates, 'entry_preamble.rb'))

      stubs.each do |stub|
        entry = File.join(File.dirname(stub, 2), 'lib', "#{File.basename(stub)}.rb")
        expect(File.read(entry)).to start_with(preamble), "#{entry} does not begin with templates/entry_preamble.rb"
      end
    end
  end
end
