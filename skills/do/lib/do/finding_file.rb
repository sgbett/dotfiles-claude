# frozen_string_literal: true

module Do
  # The file `gate add` was given can't be the finding: missing, empty, a
  # symlink, or not a regular file.
  class UnusableFindingFile < SkillSupport::UnusableFile; end

  # The finding `gate add` files: the white-hat's report, which the lead
  # wrote to a file with the Write tool. Never printed.
  module FindingFile
    module_function

    def read(path)
      text = SkillSupport::WrittenFile.read(path, error: UnusableFindingFile)
      raise UnusableFindingFile, "#{path} is empty" if text.strip.empty?

      text
    end
  end
end
