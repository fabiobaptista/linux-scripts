# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a collection of Linux utility scripts organized by category. Currently contains Git utility scripts for repository management tasks.

## Repository Structure

```
linux-scripts/
└── git/                    # Git-related utilities
    └── git-delete-branches/
        └── git-delete-branches.sh
```

Scripts are organized by category (e.g., `git/`, potentially `system/`, `network/`, etc. in the future). Each utility lives in its own subdirectory within the category folder.

## Script Architecture

### Git Branch Delete Script

Located at `git/git-delete-branches/git-delete-branches.sh`, this is an interactive Git branch deletion utility.

**Key Design Patterns:**
- Uses `fzf` for interactive multi-selection with live git log preview
- Protected branches list: `main`, `master`, `development` (hardcoded in `PROTECTED` array)
- Accepts CLI arguments as additional exclusion patterns
- Two-stage safety: interactive selection + confirmation prompt
- Uses `git branch -D` for force deletion (assumes user knows what they're doing after confirmation)

**Dependencies:**
- `fzf` (fuzzy finder) - required for interactive selection
- `git` - standard Git CLI
- Bash shell environment

**Usage Pattern:**
```bash
# Basic usage - shows all non-protected branches
./git-delete-branches.sh

# With exclusion patterns (e.g., keep branches matching "1234" or "hot")
./git-delete-branches.sh 1234 hot
```

## Development Guidelines

When adding new scripts to this repository:

1. **Organization:** Place scripts in category directories (e.g., `git/`, `system/`, `docker/`)
2. **Script Structure:** Each utility should have its own subdirectory with the same name as the script
3. **Language:** Bash scripts are preferred for system utilities; use `#!/usr/bin/env bash` shebang
4. **Safety:** For destructive operations, implement confirmation prompts and protected resource lists
5. **Interactivity:** Consider using `fzf` or similar tools for user selection when dealing with multiple items
6. **Comments:** Use the repository's comment language (Portuguese comments are used in existing scripts)
