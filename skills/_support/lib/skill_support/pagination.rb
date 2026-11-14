# frozen_string_literal: true

module SkillSupport
  # Fails closed on GraphQL connections that came back cut off at one page.
  module Pagination
    PAGE_FLAGS = %w[hasNextPage hasPreviousPage].freeze

    module_function

    # Returns the connection at +path+ inside +data+ (field names or aliases)
    # when it is complete. Raises IncompleteResults when its pageInfo reports
    # another page in either direction (hasNextPage for a first: query,
    # hasPreviousPage for a last: one), and also when the connection, its
    # pageInfo or both flags are missing, since completeness can't then be
    # shown. Query pageInfo for every connection a decision depends on.
    def ensure_complete!(data, *path)
      name = path.join('.')
      connection = dig_hashes(data, path)
      flags = page_flags(connection)
      raise IncompleteResults, "#{name}: no pageInfo to show the list is complete" if flags.empty?
      raise IncompleteResults, "#{name} has more than one page" unless flags.values.all?(false)

      connection
    end

    def dig_hashes(data, path)
      path.reduce(data) { |node, key| node.is_a?(Hash) ? node[key] : nil }
    end

    def page_flags(connection)
      page_info = connection['pageInfo'] if connection.is_a?(Hash)
      page_info.is_a?(Hash) ? page_info.slice(*PAGE_FLAGS) : {}
    end

    private_class_method :dig_hashes, :page_flags
  end
end
