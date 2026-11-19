# frozen_string_literal: true

module RepoConsistency
  # An entry of a git trees API listing, a Hash with "path", "mode" and
  # "type". A symlink is a blob of its own mode, whatever its target.
  module TreeEntry
    SYMLINK_MODE = '120000'
    SUBMODULE_TYPE = 'commit'
    DIRECTORY_TYPE = 'tree'
    FILE_TYPE = 'blob'

    module_function

    def valid?(entry)
      entry.is_a?(Hash) && entry.values_at('path', 'mode', 'type').all?(String)
    end

    # A regular file or a symlink; nil, for no entry, is neither.
    def file?(entry)
      !entry.nil? && entry['type'] == FILE_TYPE
    end

    def link?(entry)
      file?(entry) && entry['mode'] == SYMLINK_MODE
    end

    def submodule?(entry)
      entry['type'] == SUBMODULE_TYPE
    end

    def directory?(entry)
      entry['type'] == DIRECTORY_TYPE
    end
  end
end
