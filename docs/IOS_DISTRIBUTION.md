# iOS distribution (client demo)

**Recommendation: TestFlight.** Do not use AltStore for clients.

Apple does not allow sharing an IPA like an Android APK. You need a paid **Apple Developer Program** membership (~$99/year) and a Mac with Xcode for signing and upload.

---

## Options (decision)

| Method | Client experience | Needs | Limit | Use for clients? |
|--------|-------------------|-------|-------|------------------|
| **TestFlight** (recommended) | Install TestFlight app → accept invite → install RoundsAI | Apple Developer + App Store Connect | Internal: team members. External: first build needs Beta App Review | **Yes** |
| **Ad Hoc** | Install IPA via link/MDM on **registered** devices only | Same paid account + each device **UDID** | ~100 devices / year; new phone = re-register + re-sign | Only if TestFlight blocked |
| **AltStore / free sideload** | Fragile; 7-day re-sign on free accounts | Dev machine nearby | Expires often; support nightmare | **No** |

**Open decision:** who owns the Apple Developer / App Store Connect account (org vs individual). Until that exists, ship **web + Android** only; iOS stays “invite coming.”

---

## Prerequisites (once)

1. Enroll in [Apple Developer Program](https://developer.apple.com/programs/).
2. Mac with latest stable **Xcode** + command-line tools.
3. Change the Flutter iOS bundle id from the template default:
   - Today: `com.example.roundAi` in `ios/Runner.xcodeproj`
   - Prefer something you control, e.g. `ai.roundsai.app` (must be unique in App Store Connect).
4. In Xcode → **Signing & Capabilities**: select your **Team**, enable **Automatically manage signing** for Debug; for Release use Distribution cert + App Store (TestFlight) or Ad Hoc profile.
5. Create the app record in [App Store Connect](https://appstoreconnect.apple.com/) with the same bundle id (name can stay “RoundsAI”). Privacy: demo uses fictional data; camera/mic usage strings must match `Info.plist`.

---

## Build IPA (production API)

Run on a Mac (Windows cannot produce a signed IPA):

```bash
cd round_ai
flutter pub get
flutter build ipa --release \
  --dart-define=API_BASE_URL=https://round-ai-backend.fly.dev \
  --dart-define=APP_ENV=production \
  --dart-define=DEMO_HINTS=true
```

Typical output:

- Archive / IPA under `build/ios/ipa/`
- Or open `build/ios/archive/*.xcarchive` in Xcode Organizer → **Distribute App**

Same dart-defines as Android/web so the demo hits Fly production.

---

## Path A — TestFlight (preferred)

1. Upload the build (Xcode Organizer → **App Store Connect**, or `xcrun altool` / Transporter).
2. Wait for processing (email / App Store Connect → TestFlight).
3. **Internal testing:** add App Store Connect users on your team → they install via TestFlight (no Beta App Review).
4. **External testing (clients):** create an External group → add emails → submit for **Beta App Review** the first time → after approval, clients get an invite email.
5. Client steps (3 lines):
   1. Install **TestFlight** from the App Store.
   2. Open the invite email → **Accept** → install **RoundsAI**.
   3. Sign in: `resident@rounds.test` / `ChangeMe-12345` (fictional demo only).

Smoke the build with [`RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md) before inviting anyone.

---

## Path B — Ad Hoc (fallback)

1. Collect each tester’s **UDID** (Settings → General → About, or Xcode → Devices, or a config profile).
2. Apple Developer → **Devices** → register UDIDs → create **Ad Hoc** provisioning profile for the bundle id.
3. Archive with that profile (or export Ad Hoc from Organizer).
4. Share the IPA via a trusted link (e.g. Diawi / MDM). Client must trust the developer profile if prompted.
5. New phone = new UDID + new profile + rebuild. Prefer TestFlight when possible.

---

## What we will not do for clients

- AltStore / Sideloadly / free 7-day certificates
- Unsigned IPA email dumps
- Asking clients to install Xcode

---

## Checklist before first iOS invite

- [ ] Apple Developer account owner decided and enrolled
- [ ] Bundle id no longer `com.example.*`
- [ ] `flutter build ipa` with production dart-defines succeeds
- [ ] Build visible in TestFlight (Internal or External)
- [ ] [`RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md) iOS row marked Pass
- [ ] Client guide section C matches the invite you send

## Related

- Android file share: [`ANDROID_APK.md`](ANDROID_APK.md)
- Client walkthrough: [`CLIENT_TEST_GUIDE.md`](CLIENT_TEST_GUIDE.md)
