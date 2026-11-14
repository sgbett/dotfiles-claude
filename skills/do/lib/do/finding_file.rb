# frozen_string_literal: true

require_relative 'written_file'

module Do
  # The file `gate add` was given can't be the finding: missing, empty, a
  # symlink, or not a regular file.
  class UnusableFindingFile < UnusableFile; end

  # The finding `gate add` files: the white-hat's report, which the lead
  # wrote to a file with the Write tool. Never printed.
  module FindingFile
    module_function

    def read(path)
      text = WrittenFile.read(path, error: UnusableFindingFile)
      raise UnusableFindingFile, "#{path} is empty" if text.strip.empty?

      text
    end
  end
end
