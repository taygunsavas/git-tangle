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

@test "no-ff creates a merge commit" {
  git tangle config set tangle.mergeStyle no-ff

  git tangle feature start m1
  echo a > a.txt && git add a.txt && git commit -m "feat: A" >/dev/null
  git tangle feature finish m1

  merges="$(git log --oneline --merges | wc -l | tr -d ' ')"
  [ "$merges" -ge 1 ]
}

@test "ff avoids merge commit when possible" {
  git tangle config set tangle.mergeStyle ff

  git tangle feature start m2
  echo b > b.txt && git add b.txt && git commit -m "feat: B" >/dev/null
  git tangle feature finish m2

  merges="$(git log --oneline --merges | wc -l | tr -d ' ')"
  [ "$merges" -eq 0 ]
}

@test "rebaseOnFinish=true performs rebase before merge" {
  git tangle config set tangle.mergeStyle no-ff
  git tangle config set tangle.rebaseOnFinish true

  git tangle feature start linear
  echo c > c.txt && git add c.txt && git commit -m "feat: C" >/dev/null
  git tangle feature finish linear

  run git log -1 --oneline
  [ "$status" -eq 0 ]
}