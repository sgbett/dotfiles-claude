# frozen_string_literal: true

module Do
  # The Visibility rule of /do's SKILL.md: on GitHub, name, link into or
  # quote another repository only if it's public.
  module Visibility
    PUBLIC = 'PUBLIC'

    module_function

    # Whether GitHub text may name an issue in +repository+ when +home+ is
    # this repository. An unknown visibility is not public.
    def nameable?(repository, home)
      repository.same_as?(home) || repository.visibility == PUBLIC
    end
  end
end
