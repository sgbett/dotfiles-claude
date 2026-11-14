# frozen_string_literal: true

module SkillSupport
  module Testing
    # Puts the gh shim (support/shim/gh) first on PATH for an end-to-end spec.
    # Each entry is a hash:
    #
    #   args:        the exact arguments after "gh" (required)
    #   stdin:       the exact stdin to require; omit to accept any
    #   stdout:      what to print, or stdout_file: a recorded file to print
    #   stderr:      what to print on stderr (default "")
    #   exit:        the exit status (default 0)
    #   repeat:      true to answer more than once (default: once only)
    #
    # The first unused entry that matches answers. Any other call exits 97
    # naming itself on stderr.
    class GhShim
      DIRECTORY = File.expand_path('shim', __dir__)

      def self.install(sandbox, entries)
        table = sandbox.path('gh-shim-fixtures.json')
        log = sandbox.path('gh-shim-calls.jsonl')
        File.write(table, JSON.generate(entries.map { |entry| entry.transform_keys(&:to_s) }))
        # The Ruby running the specs goes on PATH too, for the shim's own shebang.
        search_path = [DIRECTORY, File.dirname(RbConfig.ruby), ENV.fetch('PATH', '')].join(File::PATH_SEPARATOR)
        ENV.update('GH_SHIM_FIXTURES' => table, 'GH_SHIM_LOG' => log, 'PATH' => search_path)
        new(log)
      end

      def initialize(log)
        @log = log
      end

      # Each call the shim received, in order, as "args", "stdin" and
      # "fixture" (the index of the entry that answered, nil for none).
      def calls
        File.exist?(@log) ? File.readlines(@log).map { |line| JSON.parse(line) } : []
      end

      def unmatched_calls
        calls.select { |call| call['fixture'].nil? }
      end
    end
  end
end
