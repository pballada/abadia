#!/bin/bash
# Publish this source tree to the user-requested repository. Never force-push.
set -euo pipefail
cd "$(dirname "$0")/.."
expected="https://github.com/pballada/abadia.git"
if [ ! -d .git ]; then
    git init -b main
fi
if git remote get-url origin >/dev/null 2>&1; then
    actual="$(git remote get-url origin)"
    if [ "$actual" != "$expected" ] && [ "$actual" != "git@github.com:pballada/abadia.git" ]; then
        echo "Refusing to publish: origin is not pballada/abadia." >&2
        exit 1
    fi
else
    git remote add origin "$expected"
fi
git add .gitignore Makefile README.md LICENSE.md Sources Resources Tests scripts docs .github
if ! git diff --cached --quiet; then
    git commit -m "Add native macOS port of La abadia del crimen"
fi
git push -u origin HEAD:main
