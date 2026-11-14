# /do spec fixtures

What these files are, and the policy every fixture follows, is in [`skills/_support/spec/fixtures/README.md`](../../../_support/spec/fixtures/README.md). In short: the raw output of one read-only `gh` call against a public repository, or synthesised by hand.

## Recorded

Each was recorded from the repository root, after checking that `gh repo view sgbett/dotfiles-claude --json visibility` prints `PUBLIC`. The GraphQL request files are written from the code's own query and variables, so `issue_query_spec.rb` fails if the query changes without the fixtures being recorded again.

```sh
F=skills/do/spec/fixtures
request() {
  ruby -I skills/_support/lib -r skill_support -r ./skills/do/lib/do/issue_query -r json \
    -e 'puts JSON.pretty_generate("query" => Do::IssueQuery::QUERY, "variables" => Do::IssueQuery.variables(ARGV[0], Integer(ARGV[1])))' \
    "$1" "$2"
}

request sgbett/dotfiles-claude 24 > $F/graphql/issue-24.request.json
gh api graphql --hostname github.com --input $F/graphql/issue-24.request.json > $F/graphql/issue-24.json

request sgbett/dotfiles-claude 25 > $F/graphql/pull-request-25.request.json
gh api graphql --hostname github.com --input $F/graphql/pull-request-25.request.json > $F/graphql/pull-request-25.json

request sgbett/dotfiles-claude 99999 > $F/graphql/missing-issue.request.json
gh api graphql --hostname github.com --input $F/graphql/missing-issue.request.json \
  > $F/graphql/missing-issue.json 2> $F/graphql/missing-issue.stderr

gh repo view https://github.com/sgbett/dotfiles-claude.git --json nameWithOwner,url > $F/repo-view/origin.json
```

`issue-24.json` holds #24 as it stood with its breakdown comment and no branches pushed, `pull-request-25.json` what GitHub answers for a pull request's number, and `missing-issue.json` its `NOT_FOUND` for a number that names nothing.

`preflight check`'s fixtures were recorded the same way, after also checking that `gh repo view bettison-org/ai-software-architect --json visibility` prints `PUBLIC`. Its three queries' requests come from `Do::CheckQuery`, and `check_query_spec.rb` checks them against the code in the same way. The contents call reads at the base commit `base-master.json` records.

```sh
F=skills/do/spec/fixtures
check_request() {
  ruby -I skills/_support/lib -r skill_support -r ./skills/do/lib/do/check_query -r json -e '
    value = ARGV[1] == "issue_variables" ? Integer(ARGV[3]) : ARGV[3]
    puts JSON.pretty_generate("query" => Do::CheckQuery.const_get(ARGV[0]),
                              "variables" => Do::CheckQuery.public_send(ARGV[1], ARGV[2], value))' "$@"
}

check_request ISSUE_QUERY issue_variables sgbett/dotfiles-claude 24 > $F/graphql/check-issue-24.request.json
gh api graphql --hostname github.com --input $F/graphql/check-issue-24.request.json > $F/graphql/check-issue-24.json

check_request BASE_QUERY base_variables sgbett/dotfiles-claude master > $F/graphql/base-master.request.json
gh api graphql --hostname github.com --input $F/graphql/base-master.request.json > $F/graphql/base-master.json

check_request BASE_QUERY base_variables sgbett/dotfiles-claude 'feat/#24+no-such-branch' \
  > $F/graphql/base-missing.request.json
gh api graphql --hostname github.com --input $F/graphql/base-missing.request.json > $F/graphql/base-missing.json

check_request PULL_REQUESTS_QUERY pull_request_variables sgbett/dotfiles-claude feat/24-hlr-do-and-copilot-check-move \
  > $F/graphql/pull-requests-24.request.json
gh api graphql --hostname github.com --input $F/graphql/pull-requests-24.request.json > $F/graphql/pull-requests-24.json

gh repo view https://github.com/sgbett/dotfiles-claude.git --json nameWithOwner,parent,viewerPermission \
  > $F/repo-view/push-origin.json
gh repo view https://github.com/bettison-org/ai-software-architect.git --json nameWithOwner,parent,viewerPermission \
  > $F/repo-view/fork.json

gh api --hostname github.com -X GET repos/sgbett/dotfiles-claude/contents/.claude/rules \
  -f ref=6b9895d961416bbb7561778aff4e651822796e9e \
  > $F/contents/rules-not-found.json 2> $F/contents/rules-not-found.stderr
```

`check-issue-24.json` is #24 as GitHub names its repository, with its default branch, `base-master.json` and `base-missing.json` a base branch that exists and one that doesn't, `pull-requests-24.json` the branch with no pull request open, `push-origin.json` this repository through its push URL, `fork.json` a fork and its parent, each with the viewer's permission on it, and `rules-not-found.json` the 404 for an absent `.claude/rules/`.

`record`'s one recording is #24 through REST, recorded the same way after the same check. `closes` reads the issue body from it; the GraphQL query is pre-flight's, so `record` reuses `issue-24.json`.

```sh
F=skills/do/spec/fixtures
gh api --hostname github.com -X GET repos/sgbett/dotfiles-claude/issues/24 > $F/rest/issue-24.json
```

## Synthesised

The specs build every other case in Ruby (`spec/support/issue_responses.rb`) by changing the recorded #24 answer: untrusted authors, parents and sub-issues, other branches and pull requests, cut-off pages and gate lines. Any repository they add is an `example-` one, as no public repository has the sub-issue links they need.

`check`'s other cases are built in `spec/support/check_responses.rb` and the specs themselves: other remotes and forks, pull requests open on the branch, files with a security focus, and the git answers its unit specs expect. Its git layer is tested against real repositories made in each example's sandbox instead; an end-to-end `check` reaches its push URL, `git@github.com:sgbett/dotfiles-claude.git`, through a `GIT_SSH_COMMAND` that serves one of them, never the network.

`record`'s other cases are built in `spec/support/record_calls.rb` and the specs themselves: other ledgers, issue bodies and sub-issues, and every write, whose answers are synthesised rather than recorded. Its gate file is written in each example's sandbox.
