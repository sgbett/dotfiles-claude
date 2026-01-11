# Terminal Basics for Claude Code

## What is Terminal?

Terminal is a text-based way to interact with your computer. Instead of clicking folders, you type commands. It's simpler than it looks.

## Opening Terminal

**Mac:** Press `Cmd + Space`, type "Terminal", press Enter.

**Windows:** Press `Win + R`, type "cmd" or use Windows Terminal.

**Linux:** Press `Ctrl + Alt + T`.

## The Prompt

When Terminal opens, you'll see something like:

```
simon@macbook ~ %
```

The `~` means you're in your "home" folder. This is your starting point.

## Essential Commands

### Where am I?

```bash
pwd
```

**P**rint **W**orking **D**irectory. Shows your current location.

```
/Users/simon
```

### What's here?

```bash
ls
```

**L**i**s**t. Shows files and folders in your current location.

```
Desktop    Documents    Downloads    Projects
```

### Go somewhere

```bash
cd foldername
```

**C**hange **D**irectory. Moves you into a folder.

```bash
cd Documents
cd Projects
cd my-app
```

### Go back up

```bash
cd ..
```

The `..` means "parent folder" (one level up).

### Go home

```bash
cd ~
```

Returns to your home folder from anywhere.

### Go to a specific path

```bash
cd /Users/simon/Projects/my-app
```

You can jump directly to any location using the full path.

## Putting It Together

A typical workflow to navigate to a project:

```bash
pwd                        # Check where you are
ls                         # See what folders exist
cd Projects                # Enter Projects folder
ls                         # See your projects
cd my-app                  # Enter your project
```

## Tips

- **Tab completion:** Type the first few letters of a folder name, then press `Tab`. Terminal will autocomplete it.
- **Case matters:** `Documents` and `documents` are different on some systems.
- **Spaces in names:** Use quotes: `cd "My Project"` or escape with backslash: `cd My\ Project`
- **Up arrow:** Press ↑ to recall previous commands.

## Running Claude Code

Once you're in your project folder:

```bash
claude
```

That's it. Claude Code will start in that directory.

---

You now know enough to navigate anywhere on your computer. Everything else you'll pick up as you go.
