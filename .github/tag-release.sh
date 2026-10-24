#!/usr/bin/env bash

# tags GITHUB_SHA as v<VERSION> in GITHUB_REPOSITORY, unless that release already exists

set -euo pipefail

version=$(tr -d '[:space:]' < VERSION)
if ! [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "::error::VERSION must be MAJOR.MINOR.PATCH, not '$version'"
    exit 1
fi
tag="v$version"

if gh api "repos/$GITHUB_REPOSITORY/git/ref/tags/$tag" --silent 2>/dev/null; then
    echo "$tag already exists; bump VERSION to make a new release"
    exit 0
fi

latest=$(gh api "repos/$GITHUB_REPOSITORY/git/matching-refs/tags/v" --jq '.[].ref | ltrimstr("refs/tags/v")' \
    | { grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' || true; } | sort -V | tail -n 1)
if [ -n "$latest" ] && [ "$(printf '%s\n' "$latest" "$version" | sort -V | tail -n 1)" != "$version" ]; then
    echo "::error::VERSION $version is older than the latest release v$latest"
    exit 1
fi

gh api "repos/$GITHUB_REPOSITORY/git/refs" -f ref="refs/tags/$tag" -f sha="$GITHUB_SHA" --silent
echo "tagged $GITHUB_SHA as $tag"
