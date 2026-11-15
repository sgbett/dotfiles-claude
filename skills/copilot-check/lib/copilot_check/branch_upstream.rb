# frozen_string_literal: true

module CopilotCheck
  # A local branch's upstream, from its configuration, as `git for-each-ref`
  # gives it: the remote's name and the branch's ref there. git gives both
  # only for a remote the repository configures with a fetch refspec that
  # maps the ref, or for "." meaning this repository; a URL, or a remote it
  # doesn't know, gives neither.
  class BranchUpstream
    FORMAT = '--format=%(upstream:remotename)%00%(upstream:remoteref)'

    def initialize(runner)
      @git = SkillSupport::Git.new(runner)
    end

    # [remote, ref] for branch +branch+ in the checkout at +checkout+; both
    # empty, or nil, when it has no upstream.
    def read(checkout, branch)
      @git.output('-C', checkout, 'for-each-ref', FORMAT, "refs/heads/#{branch}").chomp.split("\0", 2)
    end
  end
end
