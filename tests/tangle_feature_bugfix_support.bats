#!/usr/bin/env bats

setup() {
  TMPDIR="$(mktemp -d)"
  cd "$TMPDIR"
  git init >/dev/null
  git tangle init
  git checkout -B main >/dev/null
  git commit --allow-empty -m "chore: seed" >/dev/null
}

teardown() { cd /; rm -rf "$TMPDIR"; }

@test "feature start/finish merges back to default and deletes topic" {
  git tangle feature start demo
  [ "$(git rev-parse --abbrev-ref HEAD)" = "feature/demo" ]

  echo hi > hi.txt
  git add hi.txt
  git commit -m "feat: add hi" >/dev/null

  run git tangle feature finish demo
  [ "$status" -eq 0 ]
  [ "$(git rev-parse --abbrev-ref HEAD)" = "main" ]

  run git show-ref --verify --quiet refs/heads/feature/demo
  [ "$status" -ne 0 ]
}

@test "bugfix and support behave the same" {
  git tangle bugfix start hot
  [ "$(git rev-parse --abbrev-ref HEAD)" = "bugfix/hot" ]
  git commit --allow-empty -m "fix: empty" >/dev/null
  git tangle bugfix finish hot
  [ "$(git rev-parse --abbrev-ref HEAD)" = "main" ]

  git tangle support start lts-1
  [ "$(git rev-parse --abbrev-ref HEAD)" = "support/lts-1" ]
  git commit --allow-empty -m "chore: support" >/dev/null
  git tangle support finish lts-1
  [ "$(git rev-parse --abbrev-ref HEAD)" = "main" ]
}