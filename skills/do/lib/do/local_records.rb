# frozen_string_literal: true

require_relative 'private_file'

module Do
  # Where record keeps what only this checkout holds, one file to a purpose
  # for each issue: <git common dir>/do/<issue node id><suffix>, in the git
  # directory every worktree shares, where no commit or push can carry it.
  module LocalRecords
    DIRECTORY = 'do'

    module_function

    # The path of the issue with GraphQL node id +node_id+'s file ending in
    # +suffix+, inside the real path of +common_directory+'s do/.
    def path(common_directory, node_id, suffix)
      directory = File.join(File.realpath(common_directory), DIRECTORY)
      path = File.join(directory, "#{SkillSupport::Identifiers.node_id!(node_id)}#{suffix}")
      raise UnsafeGateFile, "#{path} is outside #{directory}" unless File.dirname(File.expand_path(path)) == directory

      path
    end
  end
end
