#!/usr/bin/env bash
set -euo pipefail

bats --version || true
git --version
uname -a

export GIT_AUTHOR_NAME="Git Tangle CI"
export GIT_AUTHOR_EMAIL="ci@git-tangle.test"
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"

bats -r tests