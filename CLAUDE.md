# Personal Preferences

## Git

- Default branch: `master` (not `main`)
- No git submodules

**Commit Messages:** Follow [Conventional Commits](https://www.conventionalcommits.org/):
- `feat:` - new feature (MINOR version)
- `fix:` - bug fix (PATCH version)
- `docs:` - documentation only
- `style:` - formatting, no code change
- `refactor:` - code change that neither fixes nor adds
- `perf:` - performance improvement
- `test:` - adding/updating tests
- `build:` - build system or dependencies
- `ci:` - CI configuration
- `chore:` - maintenance tasks
- Breaking changes: append `!` (e.g., `feat!:` or `fix(api)!:`)
- Scope is optional: `feat(auth): add login`

## Development Environment

- Prefer Docker for development environments over local installation
- Minimal use of Homebrew - keep base OS clean
- Primary OS: macOS

## Code Style

- Prefer simplicity over cleverness
- Avoid over-engineering - solve the problem at hand, not hypothetical future problems
- **British English:** Use British spelling in all generated text (documentation, comments, commit messages)
  - Examples: behaviour, colour, organisation, optimise, summarise, favour, centre

## Languages

- Ruby: primary language
  - **Guard clauses:** Use bare `return` without a value
    - Good: `return unless sequence.present?`
    - Bad: `return false unless sequence.present?`

## Communication

- Be direct and concise
- Skip unnecessary praise or validation
- Focus on facts and problem-solving
