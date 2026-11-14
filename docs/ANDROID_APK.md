# Android APK (client share)

## Build (production API)

```bash
cd round_ai
flutter pub get
flutter build apk --release \
  --dart-define=API_BASE_URL=https://round-ai-backend.fly.dev \
  --dart-define=APP_ENV=production \
  --dart-define=DEMO_HINTS=true
```

Output:

`build/app/outputs/flutter-apk/app-release.apk`

Share that file (Drive / WhatsApp / email).

## Client install (3 steps)

1. Download `app-release.apk` on the Android phone.
2. Open the file → allow **Install unknown apps** / **Install from this source** if asked.
3. Open **RoundsAI**, sign in with `resident@rounds.test` / `ChangeMe-12345` (fictional demo data only).

## Signing (what this build uses)

| Mode | When | Notes |
|------|------|--------|
| **Debug keystore** (current default) | No `android/key.properties` | Fine for demo installs. Android may warn “unknown developer”. Reinstalls from a different machine’s debug key can require uninstall first. |
| **Release upload keystore** | `android/key.properties` present | Required before Play Store. See below. |

### Create a real release keystore (optional, not in git)

```bash
mkdir -p android/keystore
keytool -genkey -v -keystore android/keystore/roundsai-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias roundsai
cp android/key.properties.example android/key.properties
# edit passwords + paths
```

- Keep `key.properties` and `*.jks` **out of git** (already gitignored).
- Store the JKS + passwords in a password manager and an encrypted offline backup.
- Losing the upload keystore blocks Play Store updates for that app id.

## Differs from iOS

APK installs like a normal file share. IPA cannot — needs Ad Hoc/TestFlight. See [`IOS_DISTRIBUTION.md`](IOS_DISTRIBUTION.md).
