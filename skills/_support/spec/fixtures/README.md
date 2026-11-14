# Spec fixtures

Each skill keeps its fixtures in its own `spec/fixtures/`, and its specs read them with `fixture('name')` or `fixture_path('name')`. A fixture is either what a real `gh` call printed, recorded from a **public** repository, or synthesised by hand. This repository is public, so a fixture must never come from a private repository, carry a path from your machine, or hold a credential.

## What a recording is

The raw output of one `gh` call, byte for byte:

- `<name>.json`: what `gh` printed on stdout;
- `<name>.stderr`: what it printed on stderr, recorded only when the call failed;
- `<name>.request.json`: for GraphQL, the request body (`query` and `variables`) the call sent.

The spec states the arguments and exit status it expects, so the unit spec's fake runner, or the end-to-end spec's `gh` shim, can match the call exactly.

## Recording

1. Check that the repository is public: `gh repo view <owner>/<repo> --json visibility` must print `PUBLIC`.
2. Run the exact call the code makes, naming the host, and redirect its output into the fixture files.
3. Record reads only. Never record a write (`-X PATCH`, `POST`, `PUT`, `DELETE`, or a GraphQL `mutation`): synthesise its response instead.
4. Read every file before committing it. `fixture_policy_spec.rb` checks all of them as part of the suite.

The `_support` fixtures were recorded from the repository root with these commands:

```sh
F=skills/_support/spec/fixtures

gh api --hostname github.com -X GET repos/sgbett/dotfiles-claude/contents/LICENSE -f ref=master \
  > $F/contents/license.json
gh api --hostname github.com -X GET repos/sgbett/dotfiles-claude/contents/profiles -f ref=master \
  > $F/contents/profiles.json
gh api --hostname github.com -X GET repos/sgbett/dotfiles-claude/contents/no-such-file.md -f ref=master \
  > $F/contents/not-found.json 2> $F/contents/not-found.stderr
gh api --hostname github.com -X GET repos/sgbett/dotfiles-claude/contents/LICENSE -f 'ref=feat/#24+no-such-branch' \
  > $F/contents/no-commit-for-ref.json 2> $F/contents/no-commit-for-ref.stderr
GH_TOKEN=dummy gh api --hostname github.com -X GET repos/sgbett/dotfiles-claude/contents/LICENSE -f ref=master \
  > $F/contents/bad-credentials.json 2> $F/contents/bad-credentials.stderr

gh api graphql --hostname github.com --input $F/graphql/labels-first-page.request.json \
  > $F/graphql/labels-first-page.json
gh api graphql --hostname github.com --input $F/graphql/partial-data-with-errors.request.json \
  > $F/graphql/partial-data-with-errors.json 2> $F/graphql/partial-data-with-errors.stderr

gh repo view https://github.com/bettison-org/ai-software-architect --json nameWithOwner,parent \
  > $F/repo-view/fork.json
```

For GraphQL, write the request body to a `.request.json` file first and send it with `--input`; values go in `variables`, never into the query text.

## What the policy rejects

`fixture_policy_spec.rb` fails on any fixture file that:

- names a repository outside `PUBLIC_REPOSITORIES` in `spec/support/fixture_policy.rb`, except an obviously synthetic owner such as `example-owner`. It looks for GitHub URLs, `repos/<owner>/<repo>` paths, `nameWithOwner` and `full_name`, GraphQL `owner` and `name` variables, and `<owner>/<repo>#<n>` references. A repository named in another way, such as an `owner` object beside a `name`, gets past it, which is why recording only from public repositories comes first;
- holds a home or temporary directory path;
- holds anything shaped like a GitHub or Anthropic token.

To add a repository to the allowlist, confirm it is public as in step 1 and add it to `PUBLIC_REPOSITORIES`.
