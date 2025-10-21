#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."

# 의존성(바뀌었을 때만 빨리 반영)
flutter pub get || true

# 개발용 웹서버: http://localhost:5000
exec flutter run -d web-server \
  --web-hostname 127.0.0.1 \
  --web-port 5000
