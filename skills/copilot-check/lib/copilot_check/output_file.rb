# frozen_string_literal: true

require 'securerandom'

module CopilotCheck
  # A file a script can't write where the lead named: its directory is
  # missing, or the name is taken by a directory.
  class UnwritableFile < SkillSupport::Error; end

  # Writes what a script hands the lead in a file rather than on stdout, as
  # Copilot's text and the rubric are: at a path the lead named, readable by
  # its owner alone, and never through a symlink. The text goes to a new file
  # beside it, then one rename puts it in place: a rename replaces a symlink
  # rather than following it, and a reader never sees half a file.
  module OutputFile
    MODE = 0o600
    DIRECTORY_MODE = 0o700
    CREATE_FLAGS = File::WRONLY | File::CREAT | File::EXCL | File::NOFOLLOW

    module_function

    # Writes +text+ to +path+, whose directory must exist.
    def write(path, text)
      temporary = File.join(File.dirname(path), ".#{File.basename(path)}.#{SecureRandom.hex(8)}")
      File.open(temporary, CREATE_FLAGS, MODE) { |file| put_in_place(file, text, temporary, path) }
    rescue Errno::ENOENT
      raise UnwritableFile, "#{File.dirname(path)} doesn't exist"
    rescue Errno::EISDIR
      raise UnwritableFile, "#{path} is a directory"
    end

    # Makes +directory+ if it is missing, refusing a symlink or anything but
    # a directory, and returns it.
    def directory(directory)
      Dir.mkdir(directory, DIRECTORY_MODE)
      directory
    rescue Errno::EEXIST
      stat = File.lstat(directory)
      raise UnwritableFile, "#{directory} is a symlink; refusing to follow it" if stat.symlink?
      raise UnwritableFile, "#{directory} is not a directory" unless stat.directory?

      directory
    rescue Errno::ENOENT
      raise UnwritableFile, "#{File.dirname(directory)} doesn't exist"
    end

    # Writes +text+ to +file+, just created at +temporary+, and renames it to
    # +path+; on any failure, deletes it again.
    def put_in_place(file, text, temporary, path)
      file.write(text)
      file.flush
      File.rename(temporary, path)
    rescue StandardError
      File.delete(temporary)
      raise
    end

    private_class_method :put_in_place
  end
end
