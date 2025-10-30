#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/utils.sh"

cmd="$1"; name="${2:-}"; shift || true

case "$cmd" in
  start)
    if [[ -z "$name" ]]; then echo "[tangle] ERROR: support name required."; exit 1; fi
    local base branch from def
    def="$(tangle::default_branch)"
    from="$def"
    # parse optional --from
    for ((i=1; i<=$#; i++)); do
      if [[ "${!i}" == "--from" ]]; then
        j=$((i+1)); from="${!j}"
      fi
    done
    branch="$(tangle::prefix tangle.prefix.support support)/$name"
    tangle::fetch_origin_if_possible
    tangle::create_branch_from "$branch" "$from"
    if [[ "$(tangle::auto_push)" == "true" ]] && [[ "$(tangle::remote_available)" == "true" ]]; then
      git push -u origin "$branch" || echo "[tangle] WARNING: push failed."
    fi
    echo "[tangle] Created $branch from $from."
    ;;
  finish)
    if [[ -z "$name" ]]; then echo "[tangle] ERROR: support name required."; exit 1; fi
    local def branch
    def="$(tangle::default_branch)"
    branch="$(tangle::prefix tangle.prefix.support support)/$name"
    tangle::ensure_branch_exists "$branch"
    tangle::ensure_clean_worktree
    tangle::fetch_origin_if_possible
    tangle::finish_merge "$def" "$branch"
    tangle::maybe_push "$branch"
    echo "[tangle] Merged $branch -> $def."
    ;;
  *)
    echo "[tangle] Unknown support subcommand: $cmd"; exit 1;;
esac