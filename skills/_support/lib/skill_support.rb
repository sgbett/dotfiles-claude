# frozen_string_literal: true

# Shared by the skills' scripts (sgbett/dotfiles-claude#24). An entry file
# loads this only after its version guard, so the library may use Ruby 3.1
# syntax; it must not use anything newer, as the guard admits 3.1.
require_relative 'skill_support/remote_url'
require_relative 'skill_support/errors'
require_relative 'skill_support/command_runner'
require_relative 'skill_support/identifiers'
require_relative 'skill_support/gh'
require_relative 'skill_support/pagination'
require_relative 'skill_support/repository_files'
require_relative 'skill_support/written_file'
require_relative 'skill_support/git'
require_relative 'skill_support/porcelain'
require_relative 'skill_support/scripts_checkout'
require_relative 'skill_support/markdown'
require_relative 'skill_support/focus_sections'
require_relative 'skill_support/security_focus'
require_relative 'skill_support/outcome'
require_relative 'skill_support/cli'
