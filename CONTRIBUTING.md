# Contributing to dotfiles-claude

Thanks for your interest in contributing! This document outlines how to get involved.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone git@github.com:YOUR-USERNAME/dotfiles-claude.git ~/.claude
   ```
3. **Create a branch** for your changes:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Making Changes

### Code Style

- Use British English spelling (behaviour, colour, organisation)
- Follow existing patterns in the codebase
- Keep commits atomic and focused

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` — New feature
- `fix:` — Bug fix
- `docs:` — Documentation only
- `refactor:` — Code change that neither fixes nor adds
- `chore:` — Maintenance tasks

Example:
```
feat: add new-project-phoenix skill

Automates Phoenix/Elixir project creation with personal conventions.
```

### Testing Your Changes

Before submitting:
- Ensure skills work as expected by invoking them
- Check that documentation is accurate
- Verify no sensitive data is included

## Submitting Changes

1. **Push your branch** to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Open a Pull Request** against the `master` branch

3. **Describe your changes** clearly:
   - What does this PR do?
   - Why is this change needed?
   - Any breaking changes?

## Reporting Issues

Found a bug or have a suggestion? [Open an issue](https://github.com/sgbett/dotfiles-claude/issues/new) with:

- Clear description of the problem or suggestion
- Steps to reproduce (for bugs)
- Expected vs actual behaviour
- Your environment (OS, Claude Code version)

## What to Contribute

Ideas for contributions:

- **New skills** — Automate common workflows
- **Bug fixes** — Fix issues in existing skills/commands
- **Documentation** — Improve clarity, fix typos, add examples
- **Playbooks** — Document useful procedures

## Questions?

Open an issue for discussion before starting large changes. This helps ensure your contribution aligns with the project direction.
