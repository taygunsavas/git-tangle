#!/usr/bin/env bats

setup() { TMPDIR="$(mktemp -d)"; cd "$TMPDIR"; git init >/dev/null; }
teardown() { cd /; rm -rf "$TMPDIR"; }

@test "init honors custom prefixes and tag prefix" {
  git tangle init
  git checkout -B main >/dev/null
  git commit --allow-empty -m "chore: seed" >/dev/null

  git tangle config set tangle.prefix.feature feat
  git tangle config set tangle.tagPrefix v

  run git tangle feature start login
  [ "$status" -eq 0 ]

  current="$(git rev-parse --abbrev-ref HEAD)"
  [ "$current" = "feat/login" ]
}