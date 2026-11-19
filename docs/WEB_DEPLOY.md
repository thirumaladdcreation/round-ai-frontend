# Flutter web demo (Vercel)

Client-friendly link (phone or laptop browser). HTTPS is required for mic/camera.

## One-time

1. Install Flutter on the machine that builds (or use Vercel with a Flutter install script).
2. Backend CORS must allow the Vercel origin **and** the admin origin:

```bash
fly secrets set CORS_ORIGIN="https://round-ai-admin.vercel.app,https://YOUR-APP.vercel.app,http://localhost:5173,http://localhost:8080"
```

No bare `*` when multiple apps are listed. Restart/redeploy the Fly app after secrets change.

## Preferred: Git-connected Vercel project

Root `vercel.json` must match the Vercel project settings:

| Setting | Value |
|---|---|
| Build Command | `bash scripts/vercel-build.sh` |
| Output Directory | `build/web` |
| Install Command | skipped (Flutter deps install inside the build script) |
| Framework | Other / none |

`scripts/vercel-build.sh` installs Flutter on the builder, runs `flutter build web`, and copies `vercel.json` into `build/web` for SPA rewrites.

Redeploy from `main` after push. Confirm https://round-ai-one.vercel.app loads `index.html` (not a bare 404).

## Alternate: build locally, then deploy static output

```bash
cd round-ai-frontend
bash scripts/vercel-build.sh
# or: flutter build web … then cp vercel.json build/web/
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
