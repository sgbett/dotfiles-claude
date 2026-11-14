# A blocking security finding

`/do`'s step 6 from the moment the white-hat reports a Critical or High finding until step 7 marks it, and any resume while one is open. Run the `gate` calls as SKILL.md writes them (step 6; `gate mark` at step 7).

## Record it at once

Record each new block before any fix, even with no PR yet:

1. **File it.** Write the finding as reported to a session-scratchpad file with the Write tool and pass that file to `gate add`. It files the finding in the local gate file under the lowest id neither that file nor the ledger uses, and prints the id as `k` (`G1`, `G2`, …), which the later calls take as `--k`.
2. **Ask the owner, on a public repository only** (`facts`' `repository.visibility`): whether to fix it here or stop so the owner can use a private security advisory (`/do` never opens one), saying whether the flaw predates the branch. Record the answer with `gate answer` (`fix-here` or `advisory`); once it's given, only the owner changes it. On `advisory`, stop the run, pushing nothing.
3. **Publish it.** `gate publish` adds the plain ledger line `Gate G<k>: open`.

A finding is open while the gate file or the ledger says so.

## While it's open

- The Visibility invariant keeps it off GitHub, and step 6 says what it blocks. Brief whoever fixes it to report blockers to you.
- Every security review starts with the white-hat re-checking each open finding in the gate file (`facts`' `session_only.gate_file`) as fixed, open or can't tell, where only fixed clears one; then it reviews as usual.
- If the ledger has an open gate line the gate file lacks, stop and ask the user (reason `gate_record_missing`).

## On resume

For a finding left part-way (`facts`' `gate.partial`), finish the steps above before building, pushing or any rewind.
