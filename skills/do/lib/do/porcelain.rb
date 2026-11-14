# frozen_string_literal: true

module Do
  # Reads `git status --porcelain=v1 -z`: each entry is "XY PATH", NUL-ended,
  # and a rename or copy is followed by its original path as another field.
  module Porcelain
    Entry = Struct.new(:status, :path, :original, keyword_init: true) do
      def untracked?
        status == '??'
      end

      # The entry as `git status --porcelain` prints it without -z.
      def to_s
        original ? "#{status} #{original} -> #{path}" : "#{status} #{path}"
      end
    end

    RENAMED_OR_COPIED = /[RC]/

    module_function

    def entries(output)
      fields = output.scrub.split("\0")
      entries = []
      until fields.empty?
        field = fields.shift
        status = field[0, 2]
        original = RENAMED_OR_COPIED.match?(status) ? fields.shift : nil
        entries << Entry.new(status: status, path: field[3..], original: original)
      end
      entries
    end
  end
end
