# frozen_string_literal: true

require_relative 'local_records'
require_relative 'private_file'

module Do
  # Another record call on the same issue held its lock for longer than
  # record waits.
  class LockTimeout < SkillSupport::Error; end

  # One record call at a time on an issue: an exclusive flock on
  # <git common dir>/do/<issue node id>.lock, held while the call reads and
  # writes the issue's records, so that two calls never both read the gate
  # file before either writes it. A body on GitHub needs no lock: BodyEdit
  # writes only over the body it read. Closing the file releases the lock,
  # as does the end of the process however it ends.
  module RecordLock
    SUFFIX = '.lock'
    WAIT_SECONDS = 30
    POLL_SECONDS = 0.1
    # NOFOLLOW refuses a symlink as the file itself; NONBLOCK stops a FIFO
    # from hanging the open.
    OPEN_FLAGS = File::RDWR | File::CREAT | File::NOFOLLOW | File::NONBLOCK

    module_function

    def path(common_directory, node_id)
      LocalRecords.path(common_directory, node_id, SUFFIX)
    end

    # Yields with the lock at +path+ held, waiting up to +wait+ seconds for
    # it, and returns what the block returns. Raises LockTimeout once the
    # wait is over. The lock file is created 0600 in a directory only its
    # owner can enter, and never opened through a symlink: one put there
    # after the check still fails the open.
    def hold(path, wait: WAIT_SECONDS)
      PrivateFile.secure_directory(File.dirname(path))
      raise UnsafeGateFile, "#{path} is a symlink; refusing to follow it" if File.symlink?(path)

      File.open(path, OPEN_FLAGS, PrivateFile::FILE_MODE) do |file|
        raise UnsafeGateFile, "#{path} is not a regular file" unless file.stat.file?

        acquire(file, path, wait)
        yield
      end
    end

    def acquire(file, path, wait)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + wait
      until file.flock(File::LOCK_EX | File::LOCK_NB)
        if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
          raise LockTimeout, "another record call held #{path} for over #{wait} seconds; run one record call at a time"
        end

        sleep(POLL_SECONDS)
      end
    end

    private_class_method :acquire
  end
end
