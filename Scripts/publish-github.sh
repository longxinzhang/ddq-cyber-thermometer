#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_NAME="${GITHUB_REPO_NAME:-ddq-cyber-thermometer}"
TAG="v0.7.1"
TITLE="DDQ's Cyber Thermometer v0.7.1"
DMG="$ROOT_DIR/dist/DDQs-Cyber-Thermometer-0.7.1.dmg"
DMG_SHA="$DMG.sha256"
ZIP="$ROOT_DIR/dist/DDQs-Cyber-Thermometer-0.7.1.app.zip"
ZIP_SHA="$ZIP.sha256"

cd "$ROOT_DIR"

if ! gh auth status >/dev/null 2>&1; then
  echo "GitHub CLI is not logged in. Run: gh auth login" >&2
  exit 1
fi

if [ ! -f "$DMG" ] || [ ! -f "$DMG_SHA" ] || [ ! -f "$ZIP" ] || [ ! -f "$ZIP_SHA" ]; then
  "$ROOT_DIR/Scripts/package-dmg.sh" >/dev/null
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git init
  git branch -M main
fi

git add .
if ! git diff --cached --quiet; then
  git commit -m "Prepare $TAG release"
fi

if git rev-parse "$TAG" >/dev/null 2>&1; then
  git tag -f "$TAG"
else
  git tag "$TAG"
fi

BRANCH="$(git branch --show-current)"
if [ -z "$BRANCH" ]; then
  BRANCH="main"
  git checkout -B "$BRANCH"
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  if gh repo view "$REPO_NAME" >/dev/null 2>&1; then
    REMOTE_URL="$(gh repo view "$REPO_NAME" --json sshUrl -q .sshUrl)"
    git remote add origin "$REMOTE_URL"
  else
    gh repo create "$REPO_NAME" --public --source "$ROOT_DIR" --remote origin --push
  fi
fi

git push -u origin "$BRANCH"
git push origin "$TAG" --force

if gh release view "$TAG" >/dev/null 2>&1; then
  gh release edit "$TAG" --title "$TITLE" --notes-file RELEASE_NOTES.md
  gh release upload "$TAG" "$DMG" "$DMG_SHA" "$ZIP" "$ZIP_SHA" --clobber
else
  gh release create "$TAG" "$DMG" "$DMG_SHA" "$ZIP" "$ZIP_SHA" --title "$TITLE" --notes-file RELEASE_NOTES.md
fi

REPO_FULL="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
PAGES_PAYLOAD="$(mktemp)"
printf '{"source":{"branch":"%s","path":"/docs"}}' "$BRANCH" > "$PAGES_PAYLOAD"
gh api --method POST "repos/$REPO_FULL/pages" --input "$PAGES_PAYLOAD" >/dev/null 2>&1 \
  || gh api --method PATCH "repos/$REPO_FULL/pages" --input "$PAGES_PAYLOAD" >/dev/null 2>&1 \
  || true
rm -f "$PAGES_PAYLOAD"

echo "Repository: https://github.com/$REPO_FULL"
echo "Release: https://github.com/$REPO_FULL/releases/tag/$TAG"
echo "Pages: https://$(echo "$REPO_FULL" | cut -d/ -f1).github.io/$(echo "$REPO_FULL" | cut -d/ -f2)/"
