# frozen_string_literal: true

require 'securerandom'

module Do
  # A path the scripts won't read or write: through a symlink, or where a
  # directory or regular file should be and isn't.
  class UnsafeGateFile < SkillSupport::Error; end

  # Writes a file only its owner can read, in a directory only its owner
  # can enter, never through a symlink. The text goes to a new file beside
  # it, then one rename puts it in place: a rename replaces a symlink rather
  # than following it, and a failure leaves the old file as it was.
  module PrivateFile
    DIRECTORY_MODE = 0o700
    FILE_MODE = 0o600
    CREATE_FLAGS = File::WRONLY | File::CREAT | File::EXCL | File::NOFOLLOW

    module_function

    # Writes +text+ to +path+, making its directory if it is missing.
    def write(path, text)
      directory = File.dirname(path)
      secure_directory(directory)
      temporary = File.join(directory, ".#{File.basename(path)}.#{SecureRandom.hex(8)}")
      File.open(temporary, CREATE_FLAGS, FILE_MODE) { |file| put_in_place(file, text, temporary, path) }
    end

    # Writes +text+ to +file+, just created at +temporary+, and renames it to
    # +path+; on any failure, deletes it again.
    def put_in_place(file, text, temporary, path)
      file.write(text)
      file.fsync
      File.rename(temporary, path)
    rescue StandardError
      File.delete(temporary)
      raise
    end

    # Makes +directory+ if it is missing, or tightens it, refusing a symlink
    # or anything but a directory.
    def secure_directory(directory)
      Dir.mkdir(directory, DIRECTORY_MODE)
    rescue Errno::EEXIST
      stat = File.lstat(directory)
      raise UnsafeGateFile, "#{directory} is a symlink; refusing to follow it" if stat.symlink?
      raise UnsafeGateFile, "#{directory} is not a directory" unless stat.directory?

      File.chmod(DIRECTORY_MODE, directory)
    end

    private_class_method :put_in_place
  end
end
