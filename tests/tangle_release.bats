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

@test "release start/finish creates plain tag when tagPrefix is empty" {
  git tangle release start 0.1.0
  [ "$(git rev-parse --abbrev-ref HEAD)" = "release/0.1.0" ]
  git commit --allow-empty -m "chore: finalize" >/dev/null
  git tangle release finish 0.1.0
  [ "$(git rev-parse --abbrev-ref HEAD)" = "main" ]

  run git tag --list
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "^0.1.0$"
}

@test "release finish respects tagPrefix when set" {
  git tangle config set tangle.tagPrefix v
  git tangle release start 0.2.0
  git commit --allow-empty -m "chore: finalize" >/dev/null
  git tangle release finish 0.2.0

  run git tag --list
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "^v0.2.0$"
}