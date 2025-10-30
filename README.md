# Git Tangle 🧶

A lightweight branching workflow tool for Git that helps teams keep repositories tidy and predictable.
Create short‑lived branches, finish them cleanly, and tag releases with a simple set of commands.

> Untangle your workflow.

## Features

- Simple **start** and **finish** commands for **feature**, **bugfix**, **support**, and **release** branches
- Clean merge back to the default branch with optional rebase before merge
- Optional annotated release tagging on finish for release branches
- Configurable branch prefixes, tag prefix, merge style, and auto‑push behavior
- Works locally with or without a remote and respects your existing Git setup
- No PR requirement baked in; teams can still use PRs outside the tool if they prefer

## Install

Global package managers will be added. For now you can run it directly from the repo.

```bash
git clone https://github.com/taygunsavas/git-tangle
cd git-tangle
chmod +x bin/git-tangle libexec/tangle/*.sh
export PATH="$PWD/bin:$PATH"
```

To install system‑wide on macOS or Linux:

```bash
# Apple Silicon default prefix
sudo PREFIX=/opt/homebrew ./scripts/install.sh

# Common Linux or Intel macOS prefix
# sudo PREFIX=/usr/local ./scripts/install.sh
```

## Quick start

Inside any Git repository:

```bash
git tangle init
git tangle feature start login
# do work, commit
git tangle feature finish login
```

Release example:

```bash
git tangle release start 1.0.0
# final fixes
git tangle release finish 1.0.0
```

## Commands

```text
git tangle init
git tangle config get <key>
git tangle config set <key> <value>

git tangle feature start <name> [--from <branch>]
git tangle feature finish <name>

git tangle bugfix start <name> [--from <branch>]
git tangle bugfix finish <name>

git tangle support start <name> [--from <branch>]
git tangle support finish <name>

git tangle release start <version> [--from <branch>]
git tangle release finish <version>
```

## Configuration

Repository‑local Git config keys used by Git Tangle:

- `tangle.defaultBranch` default branch name, auto‑detected if empty
- `tangle.tagPrefix` tag prefix for `release finish` (default **empty**)
- `tangle.mergeStyle` `no-ff` or `ff` (default `no-ff`)
- `tangle.autoPush` `true` or `false` (default `true`)
- `tangle.rebaseOnFinish` `true` or `false` (default `false`)
- `tangle.prefix.feature` (default `feature`)
- `tangle.prefix.bugfix` (default `bugfix`)
- `tangle.prefix.support` (default `support`)
- `tangle.prefix.release` (default `release`)

You can set values with:

```bash
git tangle config set tangle.autoPush false
git tangle config set tangle.mergeStyle ff
git tangle config set tangle.tagPrefix ""     # keep empty, or e.g. 'v'
```

## Notes

- Git Tangle is a workflow helper that sits on top of Git
- It does not replace Git commands and it does not change Git’s data model
- Release tagging behavior is configurable and can be enabled or disabled per repository

## Roadmap

- Homebrew and Winget packages
- Optional finish with PR creation for hosted platforms
- Changelog generation for releases
- CI templates for common providers

## License

This project is licensed under the MIT License.  
See the [LICENSE](./LICENSE) file for details.