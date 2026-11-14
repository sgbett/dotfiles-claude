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

## Synthesised

The specs build every other case in Ruby (`spec/support/issue_responses.rb`) by changing the recorded #24 answer: untrusted authors, parents and sub-issues, other branches and pull requests, cut-off pages and gate lines. Any repository they add is an `example-` one, as no public repository has the sub-issue links they need.
