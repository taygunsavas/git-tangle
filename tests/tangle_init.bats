#!/usr/bin/env bats

setup() {
  TMPDIR="$(mktemp -d)"
  cd "$TMPDIR"
  git init >/dev/null
}

teardown() {
  cd /
  rm -rf "$TMPDIR"
}

@test "init writes config and leaves tagPrefix empty by default" {
  run git tangle init
  [ "$status" -eq 0 ]

  run git config --get tangle.defaultBranch
  [ "$status" -eq 0 ]

  run git config --get tangle.tagPrefix
  [ "$status" -ne 0 ]

  run git config --get tangle.prefix.feature
  [ "$status" -eq 0 ]
}