#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."

REMOTE=origin
BRANCH=main
INTERVAL=2   # 초

# 로컬이 없을 수 있으므로 안전하게 시작
git fetch --quiet "$REMOTE" "$BRANCH" || true
git checkout -B "$BRANCH" || true

while true; do
  git fetch --quiet "$REMOTE" "$BRANCH" || true
  LOCAL=$(git rev-parse "$BRANCH" 2>/dev/null || echo "")
  REMOTE_HASH=$(git rev-parse "$REMOTE/$BRANCH" 2>/dev/null || echo "")

  if [ -n "$REMOTE_HASH" ] && [ "$LOCAL" != "$REMOTE_HASH" ]; then
    echo "[autopull] updating to $REMOTE_HASH"
    git reset --hard "$REMOTE/$BRANCH"
    flutter pub get || true   # pubspec 변경 대응
    # 파일이 바뀌면 preview_dev의 flutter run이 자동 감지해 hot-reload/HMR
  fi

  sleep "$INTERVAL"
done
