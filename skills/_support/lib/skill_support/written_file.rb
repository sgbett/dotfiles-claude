# frozen_string_literal: true

module SkillSupport
  # A file a script was given can't be read: missing, a symlink, or not a
  # regular file.
  class UnusableFile < Error; end

  # A file the lead wrote, with the Write tool or from a command's output, so
  # that text from the user or from GitHub never passes through a shell. Read
  # as a regular file, never through a symlink.
  module WrittenFile
    # NONBLOCK stops a FIFO from hanging the open.
    OPEN_FLAGS = File::RDONLY | File::NOFOLLOW | File::NONBLOCK
    CONTROL_CHARACTER = /[[:cntrl:]]/

    module_function

    # +value+, the path a flag was given, unchanged. Raises InvalidIdentifier
    # of +kind+ for one that is empty, could be read as an option, or holds a
    # control character.
    def path!(kind, value)
      unless value.is_a?(String) && !value.empty? && !value.start_with?('-') && !CONTROL_CHARACTER.match?(value)
        raise InvalidIdentifier.new(kind, value)
      end

      value
    end

    # The text of the file at +path+ as UTF-8, any invalid byte replaced.
    # Raises +error+, an UnusableFile, when it isn't a regular file.
    def read(path, error: UnusableFile)
      File.open(path, OPEN_FLAGS) do |file|
        raise error, "#{path} is not a regular file" unless file.stat.file?

        file.read.force_encoding(Encoding::UTF_8).scrub
      end
    rescue Errno::ENOENT
      raise error, "#{path} doesn't exist"
    rescue Errno::ELOOP, Errno::EMLINK
      raise error, "#{path} is a symlink; refusing to follow it"
    end
  end
end
