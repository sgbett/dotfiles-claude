# frozen_string_literal: true

module Do
  # A git remote URL as git reports it. Pre-flight reads only its host from
  # it: which repository it is comes from GitHub, as a URL can be an alias
  # or a repository's old name.
  module RemoteUrl
    # scheme://[userinfo@]host[:port]/...; the userinfo runs to the last @
    # before the path, as git reads it.
    SCHEME = %r{\A(?<scheme>[A-Za-z][A-Za-z0-9+.-]*://)(?:[^/]*@)?(?<host>\[[^\]/]*\]|[^/:?#]*)}
    # git's scp-like [user@]host:path, which it recognises only when no slash
    # comes before the first colon.
    SCP = %r{\A(?:[^@/:]*@)?(?<host>[^@/:]+):(?!//)}
    USERINFO = %r{\A(?<scheme>[A-Za-z][A-Za-z0-9+.-]*://)[^/]*@}

    module_function

    # The URL's host, lower-cased, or nil when it has none, as a local path
    # or a file:// URL has none.
    def host(url)
      match = SCHEME.match(url) || SCP.match(url)
      match[:host].downcase if match && !match[:host].empty?
    end

    # The URL with any userinfo of a scheme://user:secret@host/ form masked,
    # as a push URL can carry a token.
    def redacted(url)
      url.sub(USERINFO, '\k<scheme>***@')
    end
  end
end
