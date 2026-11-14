# /copilot-check spec fixtures

What these files are, and the policy every fixture follows, is in [`skills/_support/spec/fixtures/README.md`](../../../_support/spec/fixtures/README.md). In short: the raw output of one read-only `gh` call against a public repository, or synthesised by hand.

## Recorded

Each was recorded from the repository root of a checkout of sgbett/dotfiles-claude, after checking that `gh repo view sgbett/dotfiles-claude --json visibility` and `gh repo view twbs/bootstrap --json visibility` both print `PUBLIC`. The GraphQL request files are written from the code's own query and variables, so `threads_spec.rb` and `pull_request_query_spec.rb` fail if a query changes without its fixtures being recorded again.

```sh
F=skills/copilot-check/spec/fixtures
request() {
  ruby -I skills/_support/lib -r skill_support -r ./skills/copilot-check/lib/copilot_check/$1 -r json \
    -e 'puts JSON.pretty_generate("query" => CopilotCheck.const_get(ARGV[0])::QUERY,
                                  "variables" => CopilotCheck.const_get(ARGV[0]).variables(ARGV[1], Integer(ARGV[2])))' \
    "$2" "$3" "$4"
}

request threads Threads sgbett/dotfiles-claude 14 > $F/graphql/threads-14.request.json
gh api graphql --hostname github.com --input $F/graphql/threads-14.request.json > $F/graphql/threads-14.json
request threads Threads sgbett/dotfiles-claude 18 > $F/graphql/threads-18.request.json
gh api graphql --hostname github.com --input $F/graphql/threads-18.request.json > $F/graphql/threads-18.json
request pull_request_query PullRequestQuery sgbett/dotfiles-claude 18 > $F/graphql/pull-request-18.request.json
gh api graphql --hostname github.com --input $F/graphql/pull-request-18.request.json \
  > $F/graphql/pull-request-18.json

gh repo view --json nameWithOwner,url > $F/repo-view/checkout.json
gh api --hostname github.com -X GET repos/sgbett/dotfiles-claude/pulls/18/files -f per_page=100 -f page=1 \
  > $F/rest/files-18.json
gh pr checks 18 -R github.com/sgbett/dotfiles-claude --json name,bucket,link 2> $F/pr-checks/no-checks-18.stderr
gh pr checks 43381 -R github.com/twbs/bootstrap --json name,bucket,link > $F/pr-checks/bootstrap-43381.json
```

`threads-14.json` is a pull request after a converged run: five Copilot reviews, four marked answered by our comments and the last, which had no finding, not; one thread, which we answered last and was resolved. `threads-18.json` is Copilot's two reviews of #18's head, neither marked answered, and no thread. `pull-request-18.json` is #18 merged, so not a draft and its mergeability `UNKNOWN`. `no-checks-18.stderr` is what `gh pr checks` prints, exiting 1 with nothing on stdout, when no check has run; `bootstrap-43381.json` is a list of checks that passed, were skipped or were cancelled, with links of every kind: Actions jobs, a check run, and other services.

## Synthesised

The specs build every other case in Ruby (`spec/support/gate_calls.rb`) and in the specs themselves: an open draft that passes every condition, threads and reviews changed from the recorded ones, more files than a page, failed checks and their annotations, and the rules and start files the lead writes. A repository they add is an `example-` one. No annotation is recorded, as the public ones found carry text naming repositories off the allowlist.
