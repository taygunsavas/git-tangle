#!/usr/bin/env bats

@test "--version exits successfully" {
  run git tangle --version
  [ "$status" -eq 0 ]
  [[ "$output" == git-tangle* ]]
}

