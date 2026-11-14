# frozen_string_literal: true

module Do
  # preflight was called with arguments it doesn't take.
  class UsageError < SkillSupport::Error
    USAGE = [
      'usage: preflight facts <issue>',
      '       preflight check <issue> --push-remote <remote> --pr-target <owner/repo>',
      '                       --base <branch> --branch <branch>',
      '                       [--accept-local-branch <sha>] [--accept-scripts <digest>]',
      'where <issue> is an issue number, owner/repo#N or https://<host>/<owner>/<repo>/issues/<N>'
    ].join("\n").freeze

    def initialize
      super(USAGE)
    end
  end
end
