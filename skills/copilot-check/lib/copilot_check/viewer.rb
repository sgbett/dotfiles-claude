# frozen_string_literal: true

module CopilotCheck
  # The authenticated user, whose login `gh api user` gives.
  class Viewer
    # +github+ is the SkillSupport::Gh for the repository's host.
    def initialize(github)
      @github = github
    end

    # Whether they own +pull_request+'s head repository, comparing logins
    # without case, as GitHub does. A head owner gh doesn't name is nobody's,
    # so GitHub isn't asked. Raises UnexpectedResponse when GitHub gives no
    # login.
    def owns_head?(pull_request)
      owner = pull_request.head_owner
      !owner.nil? && owner.casecmp?(login)
    end

    private

    def login
      user = @github.api('user')
      login = user['login'] if user.is_a?(Hash)
      return login if login.is_a?(String) && !login.empty?

      raise SkillSupport::UnexpectedResponse, 'gh api user gave no login'
    end
  end
end
