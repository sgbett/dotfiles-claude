# frozen_string_literal: true

module Do
  # The file `gate add` was given can't be the finding: missing, empty, a
  # symlink, or not a regular file.
  class UnusableFindingFile < SkillSupport::Error; end

  # The finding `gate add` files: the white-hat's report, which the lead
  # wrote to a file with the Write tool so that it never passes through a
  # shell. Read as a regular file, never through a symlink, and never
  # printed.
  module FindingFile
    # NONBLOCK stops a FIFO from hanging the open.
    OPEN_FLAGS = File::RDONLY | File::NOFOLLOW | File::NONBLOCK

    module_function

    def read(path)
      text = File.open(path, OPEN_FLAGS) do |file|
        raise UnusableFindingFile, "#{path} is not a regular file" unless file.stat.file?

        file.read.force_encoding(Encoding::UTF_8).scrub
      end
      raise UnusableFindingFile, "#{path} is empty" if text.strip.empty?

      text
    rescue Errno::ENOENT
      raise UnusableFindingFile, "#{path} doesn't exist"
    rescue Errno::ELOOP, Errno::EMLINK
      raise UnusableFindingFile, "#{path} is a symlink; refusing to follow it"
    end
  end
end
