#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

if [ $# -lt 1 ]; then
    echo "Usage: ./release.sh <version> [commit_message]"
    echo "Example: ./release.sh 1.2.6 \"Add numeric keybindings 1-4 for reward choices\""
    exit 1
fi

# Accept both "1.2.6" and "v1.2.6"
VERSION="${1#v}"
TAG="v${VERSION}"
COMMIT_MSG="${2:-Release ${TAG}}"
TOC_FILE="ForeverQuestKey.toc"

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Version must follow semantic versioning (X.Y.Z), got '${VERSION}'."
    exit 1
fi

if [ ! -f "$TOC_FILE" ] || [ ! -f "Core.lua" ]; then
    echo "Error: Must be run from the ForeverQuestKey root containing ${TOC_FILE} and Core.lua."
    exit 1
fi

if ! grep -qE "^## X-Curse-Project-ID:[[:space:]]*[1-9][0-9]*" "$TOC_FILE"; then
    echo "Error: Valid numeric '## X-Curse-Project-ID:' is missing in ${TOC_FILE}."
    exit 1
fi

# 1. Fail fast if the tag already exists locally or on origin
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "Error: Local tag '${TAG}' already exists. Bump the version number first."
    exit 1
fi

if git ls-remote --exit-code --tags origin "refs/tags/${TAG}" >/dev/null 2>&1; then
    echo "Error: Remote tag '${TAG}' already exists on origin. Bump the version number first."
    exit 1
fi

# 2. Normalize line endings for Linux/SteamOS and update .toc version
sed -i 's/\r$//' *.lua *.toc *.sh *.md 2>/dev/null || true
sed -i -E "s/^## Version:.*/## Version: ${VERSION}/" "$TOC_FILE"

# 3. Stage and commit any modified or new files
git add -A
if ! git rev-parse --verify HEAD >/dev/null 2>&1 || ! git diff-index --quiet HEAD --; then
    git commit -m "$COMMIT_MSG"
else
    echo "No file changes to commit; tagging current HEAD."
fi

# 4. Push main BEFORE creating any local tag so a rejected push leaves no orphan tag
echo "Pushing main to origin..."
git push origin main

# 5. Create annotated tag and push to trigger GitHub Actions + CurseForge sync
echo "Creating and pushing tag ${TAG}..."
git tag -a "$TAG" -m "Release ${TAG}"
git push origin "$TAG"

echo ""
echo "Released ${TAG} successfully!"
echo "Monitor workflow: https://github.com/foxfair/forever-quest-key/actions"
if command -v gh >/dev/null 2>&1; then
    echo "Waiting for GitHub Actions run to register..."
    sleep 5
    RUN_ID=$(gh run list --repo foxfair/forever-quest-key --limit 1 --json databaseId --jq '.[0].databaseId')
    if [ -n "$RUN_ID" ] && [ "$RUN_ID" != "null" ]; then
        gh run watch "$RUN_ID" --repo foxfair/forever-quest-key
    fi
fi
