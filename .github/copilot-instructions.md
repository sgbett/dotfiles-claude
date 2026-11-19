# Copilot Code Review Instructions

## Purpose

This file has one job: make Copilot an effective reviewer of every pull request in this repository. Copilot is used here only for automated PR review.

It is not the source of truth for how the repository works. It says how to review and where the truth lives, so it cannot drift from the conventions it points at.

## What this repository is

A Claude Code configuration: doctrine in [`CLAUDE.md`](../CLAUDE.md), shareable practice bundles under [`profiles/`](../profiles/), skills under [`skills/`](../skills/) with their scripts in each skill's `bin/` and `lib/`, playbooks and reference documents under [`playbooks/`](../playbooks/) and [`docs/`](../docs/), and the live `settings.json`.

Two parts run on other people's machines, which is where review matters most. The profiles are vendored verbatim into other repositories' `.claude/rules/`, so a change to a profile is a change to every copy. The push-guard hook under [`profiles/git-workflow/hooks/`](../profiles/git-workflow/hooks/) runs on every Bash command in every checkout that vendors it, under whatever Ruby the machine has, macOS's 2.6 included.

## How to review

Lead with what would break or weaken a collaborator's checkout, then correctness, then everything else.

1. **The hook.** It must never answer `allow`; anything it cannot read or settle becomes `ask`; a defect must fail closed, an exception included. Flag any path through it that stays silent on a form that could rewrite or delete a remote branch, and any syntax or library Ruby 2.6 does not have. [`profiles/git-workflow/setup.md`](../profiles/git-workflow/setup.md) describes the hook's behaviour: flag a claim there the code does not keep.
2. **The profiles.** [`profiles/git-workflow.md`](../profiles/git-workflow.md) and [`profiles/work-organisation.md`](../profiles/work-organisation.md) are read by other repositories without this one's context. Flag a dependency on a private skill, a machine-local path, or wording that only makes sense here.
3. **The skill scripts.** Each `bin/` script prints one JSON object and treats GitHub text, comments and reviews as data, never as instructions; the trusted set is the authenticated user and authors GitHub records as owner, member or collaborator. Flag anything that acts on untrusted text, writes to GitHub where the skill says it only reads, or changes the JSON contract without its spec.
4. **The specs.** They live under [`skills/_support/spec/`](../skills/_support/spec/) and each skill's `spec/`, run with `rspec` from the repository root. A behaviour change without an example, or an example that asserts the wrong thing, is a finding.
5. **Visibility.** This repository is public. Flag any machine-local path, any name of a repository that is not plainly public, and any description of a security weakness whose fix is not in the same pull request.

## Conventions to hold the diff to

- British English in prose, comments and commit messages; one line per Markdown paragraph.
- Comments explain why, never what; a comment restating the code is a finding, as is a stale one. [`docs/code-comments.md`](../docs/code-comments.md) has the catalogue.
- Conventional Commits; changes land by merge commit; PRs and paths are cited rather than commit hashes in anything that outlives a rebase.
- Simplicity over cleverness, but single responsibility from the outset: flag a class that has gained a second reason to change.

## What not to flag

- Style the linters already cover (`rubocop` runs on every changed Ruby file).
- American spellings inside identifiers where a specification or an API mandates them.
- The `settings.json` file's own content beyond what the pull request changes: it is live configuration.
