# frozen_string_literal: true

module RepoConsistency
  # What SkillScanReader read of a repository: the text of each instruction
  # file SkillPaths names, in path order, and which of UserSkills' names the
  # repository ships. Or, in unchecked, why it couldn't read them all:
  # :truncated, a tree came back cut off; :linked, a submodule, or a
  # symlink that could stand for a directory, is where SkillPaths looks;
  # :unreadable, the contents API refused an instruction file as too large
  # or not a file; :too_many, more than SkillScanReader::MAX_FILE_READS
  # files would need reading.
  SkillScan = Struct.new(:texts, :shipped, :unchecked, keyword_init: true)
end
