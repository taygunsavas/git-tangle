#!/usr/bin/env bash
set -euo pipefail

bats --version || true
git --version
uname -a

bats -r tests