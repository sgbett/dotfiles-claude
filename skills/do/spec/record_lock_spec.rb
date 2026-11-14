# frozen_string_literal: true

require_relative '../lib/do/record_lock'

RSpec.describe Do::RecordLock do
  let(:node_id) { 'I_kwDOExample' }
  let(:common_directory) { File.join(sandbox.work_directory, '.git') }
  let(:directory) { File.join(File.realpath(common_directory), 'do') }
  let(:path) { described_class.path(common_directory, node_id) }

  # Holds the lock at +path+ from another open file, as a second process
  # would, until the block returns.
  def held_elsewhere
    FileUtils.mkdir_p(directory)
    File.open(path, File::RDWR | File::CREAT, 0o600) do |file|
      file.flock(File::LOCK_EX)
      yield
    end
  end

  describe '.path' do
    it 'is <git common dir>/do/<issue node id>.lock, refusing a node id that could leave that directory' do
      expect(path).to eq(File.join(directory, "#{node_id}.lock"))
      ['..', 'I_kw/../x', '-I_kw'].each do |unsafe|
        expect { described_class.path(common_directory, unsafe) }.to raise_error(SkillSupport::InvalidIdentifier)
      end
    end
  end

  describe '.hold' do
    it 'runs the block with the lock held, in a file 0600 in a directory 0700, and returns what it returns' do
      result = described_class.hold(path) do
        File.open(path) { |file| expect(file.flock(File::LOCK_EX | File::LOCK_NB)).to be(false) }
        :done
      end

      expect([result, File.stat(directory).mode & 0o777, File.stat(path).mode & 0o777]).to eq([:done, 0o700, 0o600])
      File.open(path) { |file| expect(file.flock(File::LOCK_EX | File::LOCK_NB)).to eq(0) }
    end

    it 'waits for a lock held elsewhere, then fails as a tool once the wait is over, never running the block' do
      ran = false

      held_elsewhere do
        expect { described_class.hold(path, wait: 0.2) { ran = true } }
          .to raise_error(Do::LockTimeout, /run one record call at a time/)
      end
      expect(ran).to be(false)
    end

    it 'releases the lock when the block raises' do
      expect { described_class.hold(path) { raise ArgumentError, 'failed' } }.to raise_error(ArgumentError)

      expect(described_class.hold(path, wait: 0) { :again }).to eq(:again)
    end

    it 'refuses a lock file that is a symlink or not a regular file, and a do directory that is a symlink' do
      FileUtils.mkdir_p(directory)
      File.symlink(sandbox.path('elsewhere'), path)
      expect { described_class.hold(path) { nil } }.to raise_error(Do::UnsafeGateFile, /is a symlink/)

      File.delete(path)
      File.mkfifo(path)
      expect { described_class.hold(path) { nil } }.to raise_error(Do::UnsafeGateFile, /not a regular file/)

      FileUtils.rm_rf(directory)
      File.symlink(sandbox.path('decoy'), directory)
      expect { described_class.hold(path) { nil } }.to raise_error(Do::UnsafeGateFile, /is a symlink/)
      expect(File.exist?(sandbox.path('elsewhere'))).to be(false)
    end
  end
end
