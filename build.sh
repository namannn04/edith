#!/usr/bin/env bash
#
#   ./build.sh                # build into build/Build/Products/Debug/Edith.app and launch it
#   ./build.sh --install      # also copy to /Applications and launch from there
#   ./build.sh --no-open      # build only, don't launch (used by CI)
#   ./build.sh --pr 42        # resolve PR #42's branch via gh, build it from the
#                             # worktree it is checked out in (created if
#                             # missing), and install
#   ./build.sh --branch name  # same, for a branch named directly
#
# This drives edth.xcodeproj (EdithMain scheme, Debug config) with xcodebuild.
# Signing is CODE_SIGN_STYLE = Automatic, so it picks up whatever Apple
# Development / Developer ID identity Xcode already trusts on this Mac.
# Release signing and notarization are not wired up here - apps/macos/build.sh
# is still what `make release` uses for that.
set -euo pipefail
cd "$(dirname "$0")"

INSTALL=0 NO_OPEN=0 PR="" BRANCH=""
while [ $# -gt 0 ]; do
  case "$1" in
    --install) INSTALL=1 ;;
    --no-open) NO_OPEN=1 ;;
    --pr) PR="${2:?--pr needs a PR number}"; shift ;;
    --branch) BRANCH="${2:?--branch needs a branch name}"; shift ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

if [ -n "$PR" ]; then
  BRANCH="$(gh pr view "$PR" --json headRefName -q .headRefName)"
  echo "PR #$PR -> branch $BRANCH"
fi

if [ -n "$BRANCH" ]; then
  INSTALL=1
  if [ "$BRANCH" != "$(git branch --show-current)" ]; then
    ROOT="$(git worktree list --porcelain \
      | awk -v b="branch refs/heads/$BRANCH" '/^worktree /{w=substr($0,10)} $0==b{print w; exit}')"
    if [ -z "$ROOT" ]; then
      git fetch origin "$BRANCH" >/dev/null 2>&1 || true
      git rev-parse --verify --quiet "refs/heads/$BRANCH" >/dev/null \
        || git branch --track "$BRANCH" "origin/$BRANCH"
      MAIN="$(git worktree list --porcelain | head -1 | cut -c10-)"
      ROOT="$MAIN/../edith-${BRANCH//\//-}"
      echo "creating worktree $ROOT for $BRANCH"
      git worktree add "$ROOT" "$BRANCH"
    fi
    echo "building from $ROOT"
    exec "$ROOT/build.sh" --install
  fi
fi

DERIVED="build"
xcodebuild -project edth.xcodeproj -scheme EdithMain -configuration Debug \
  -derivedDataPath "$DERIVED" build

APP="$DERIVED/Build/Products/Debug/Edith.app"
test -d "$APP" || { echo "build did not produce $APP" >&2; exit 1; }

killall Edith 2>/dev/null || true
pkill -x EdithHelper 2>/dev/null || true
sleep 1

if [ "$INSTALL" = 1 ]; then
  rm -rf /Applications/Edith.app
  cp -R "$APP" /Applications/
  [ "$NO_OPEN" = 1 ] || open /Applications/Edith.app
else
  [ "$NO_OPEN" = 1 ] || open "$APP"
fi
