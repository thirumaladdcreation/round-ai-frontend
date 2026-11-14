# Flutter web demo (Vercel)

Client-friendly link (phone or laptop browser). HTTPS is required for mic/camera.

## One-time

1. Install Flutter on the machine that builds (or use Vercel with a Flutter install script).
2. Backend CORS must allow the Vercel origin **and** the admin origin:

```bash
fly secrets set CORS_ORIGIN="https://round-ai-admin.vercel.app,https://YOUR-APP.vercel.app,http://localhost:5173,http://localhost:8080"
```

No bare `*` when multiple apps are listed. Restart/redeploy the Fly app after secrets change.

## Build locally, then deploy static output

Vercel does not ship Flutter SDK by default — build on a machine with Flutter, then upload `build/web`.

```bash
cd round_ai
flutter pub get
flutter build web --release --no-wasm-dry-run \
  --dart-define=API_BASE_URL=https://round-ai-backend.fly.dev \
  --dart-define=APP_ENV=production \
  --dart-define=DEMO_HINTS=true

# Copy vercel.json into the output (Flutter may not copy root config)
cp vercel.json build/web/

# Deploy the static folder
npx vercel build/web --prod
```

`vercel.json` rewrites SPA routes to `index.html` for go_router.

## Security note (demo only)

`flutter_secure_storage` on web uses browser storage (weaker than mobile Keychain/Keystore). Acceptable for the fictional demo; do not treat as clinical-grade session storage.

## Chat realtime on web

SSE via Dio is attempted. Some browsers buffer or restrict authenticated streams cross-origin; if live chat updates stall, pull-to-refresh the channel. A dedicated polling fallback can be added after client feedback.

## Demo accounts (when `DEMO_HINTS=true`)

- `resident@rounds.test` / `ChangeMe-12345`
- `admin@rounds.test` / `ChangeMe-12345`
