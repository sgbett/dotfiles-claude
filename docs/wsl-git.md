# Using Fork (Windows) with WSL Repositories

## Dubious Ownership Error

When pointing Fork at a WSL path, Git may report:

```
fatal: detected dubious ownership in repository at '//wsl.localhost/Ubuntu/home/simon/.claude'
```

This is a Git security feature (added in Git 2.35.2). Windows Git can't verify Unix ownership across the filesystem boundary.

**Fix:** Mark the directory as safe (run in Windows PowerShell, not WSL):

```powershell
git config --global --add safe.directory '%(prefix)///wsl.localhost/Ubuntu/home/simon/.claude'
```

Or trust all WSL paths (less secure):

```powershell
git config --global --add safe.directory '*'
```

## Permission Issues (Executable Bit Stripped)

Windows Git can't properly write Unix permissions to the WSL filesystem. This causes `.sh` and other executable files to lose their `+x` permission when Fork modifies them.

**Fix:** Disable file mode tracking globally in WSL:

```bash
git config --global core.fileMode false
```

This tells Git to ignore permission changes. Stored in `~/.gitconfig`, affects all repos for this user on this WSL instance only.

**Downside:** Git won't track any permission changes. When adding new scripts that need to be executable, explicitly mark them:

```bash
git update-index --chmod=+x script.sh
```

## Line Ending Issues (CRLF Instead of LF)

Windows Git may convert LF to CRLF via `core.autocrlf`. Files should always use LF in WSL.

**Fix in WSL Git:**

```bash
git config --global core.autocrlf input
```

This converts CRLF→LF on commit but never introduces CRLF.

**Fix per-repo (overrides user config):**

Add a `.gitattributes` file to the repository root:

```
* text=auto eol=lf
```

This forces LF for all text files regardless of user settings. Recommended for repos shared between Windows and Linux users.
