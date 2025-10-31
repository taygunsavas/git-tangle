#!/usr/bin/env bats

setup() { TMPDIR="$(mktemp -d)"; cd "$TMPDIR"; }
teardown() { cd /; rm -rf "$TMPDIR"; }

@test "detects master as default when main absent" {
  git init >/dev/null
  git checkout -B master >/dev/null
  git commit --allow-empty -m "seed" >/dev/null

  git tangle init
  run git config --get tangle.defaultBranch
  [ "$status" -eq 0 ]
  [ "$output" = "master" ]
}