# The plan

`/do`'s pre-flight finds the plan at step 3 and commits it first at step 6.

## Which file is the plan

- The plan is a file trusted text on the issue links to — a repository-relative path to a tracked file, or an untracked one in the conventions' plan location — confirmed as this issue's own by a back-link: a header line such as `Tracking:` or `Issue:` naming this issue, not a passing mention or "Part of".
- A linked plan without a back-link is context: ask the user before treating it as the plan.
- With no linked plan, look for one with such a back-link; if there are several, ask which.
- With none, the breakdown comment carries the design.

## The plan-first commit

If the plan is untracked or modified, commit it first: `docs(plans): #<N> — <issue title>`, the message passed in a file as SKILL.md's shell-text rule says, since the title is issue text. If the plan breaks the Visibility rule — another repository not shown to be public, or a machine-local path — stop and ask; never edit the owner's file silently.
