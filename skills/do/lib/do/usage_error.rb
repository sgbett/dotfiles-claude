# frozen_string_literal: true

module Do
  # preflight was called with arguments it doesn't take.
  class UsageError < SkillSupport::Error
    USAGE = [
      'usage: preflight facts --argument-file <path>',
      '       preflight check <issue> --push-remote <remote> --pr-target <owner/repo>',
      '                       --base <branch> --branch <branch>',
      '                       [--accept-local-branch <sha>] [--accept-scripts <digest>]',
      'where the file at <path>, and <issue>, name the issue as an issue number, owner/repo#N or',
      'https://<host>/<owner>/<repo>/issues/<N>'
    ].join("\n").freeze

    def initialize
      super(self.class::USAGE)
    end
  end

  # record was called with arguments it doesn't take.
  class RecordUsageError < UsageError
    USAGE = [
      'usage: record closes <issue> --base <branch> [--verified-items <ids>]',
      '                     [--verified-boxes <positions> --boxes-digest <digest>]',
      '       record tick <issue> (--ledger <ids> | --issue-boxes <positions> --boxes-digest <digest>) [--dry-run]',
      '       record gate add <issue> --finding-file <path>',
      '       record gate answer <issue> --k G<k> --answer fix-here|advisory',
      '       record gate publish <issue> --k G<k> [--dry-run]',
      '       record gate mark <issue> --k G<k> --state fixed|user-decided [--dry-run]',
      '       record sub-issue <issue> --item <L<n>|P<n>> --number <M> [--dry-run]',
      'each taking [--accept-scripts <digest>], where <issue> is an issue number, owner/repo#N or',
      'https://<host>/<owner>/<repo>/issues/<N>, <ids> are ledger ids (L<n>, P<n>, #M or owner/repo#M)',
      "and <positions> the places of the issue body's boxes, at any depth, counting from 1, each list",
      "comma-separated, and --boxes-digest takes preflight facts' issue.boxes_digest"
    ].join("\n").freeze
  end
end
