#!/usr/bin/env bash
# Install Flutter on the Vercel builder and produce build/web.
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-stable}"
API_BASE_URL="${API_BASE_URL:-https://round-ai-backend.fly.dev}"
APP_ENV="${APP_ENV:-production}"
DEMO_HINTS="${DEMO_HINTS:-true}"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Installing Flutter ($FLUTTER_VERSION)..."
  git clone https://github.com/flutter/flutter.git --depth 1 -b "$FLUTTER_VERSION" "$HOME/flutter"
  export PATH="$HOME/flutter/bin:$PATH"
fi

flutter config --no-analytics --enable-web
flutter --version
flutter pub get
flutter build web --release --no-wasm-dry-run \
  --dart-define="API_BASE_URL=$API_BASE_URL" \
  --dart-define="APP_ENV=$APP_ENV" \
  --dart-define="DEMO_HINTS=$DEMO_HINTS"

# SPA rewrites must live next to the static output for some deploy modes.
cp vercel.json build/web/vercel.json
echo "Built build/web successfully."
