# round_ai

RoundsAI clinical workspace for resident doctors on inpatient rounds.
Same Flutter architecture as Nexo. The phone never calls an AI model
directly and holds no API keys. All AI goes through the Node.js backend.

## Structure

```
lib/
  app/                 # bootstrap + root MaterialApp
  core/
    config/            # env, feature flags, shell tabs
    constants/
    di/                # manual InjectionContainer + BlocObserver
    errors/            # Exception / Failure / Result
    media/             # capture, limits, temp-file cleanup (PHI)
    network/           # Dio ApiClient + interceptors + endpoints
    router/            # go_router routes
    storage/           # SharedPreferences + secure token store
    theme/             # colors, spacing, theme
    usecases/
    utils/             # AppLog, ScreenUtils
  features/            # auth, team, census, patient, chat, scribe, notes,
                       # evidence, problems, rounds, learning, tasks,
                       # signout, profile, today
  shared/widgets/
config/env/            # API_BASE_URL per environment
```

## Running against the backend

1. Start the backend (separate Node.js service) with its seed data:

   ```bash
   npm run seed && npm start
   ```

2. Point the app at that API. The default development URL is
   `http://localhost:8080` in `config/env/development.json`. Change it
   if the backend listens elsewhere (for a physical device use your
   machine's LAN IP, not `localhost`).

3. Run the app on the real backend (this is the default):

   ```bash
   flutter pub get
   flutter run --dart-define-from-file=config/env/development.json
   ```

4. Sign in with the backend's seeded clinician account (see the backend
   README for the email and password). After sign-in, pick a team and
   the census loads from `GET /patients`.

### Demo mode (UI work only)

Local fictional data, no network:

```bash
flutter run --dart-define-from-file=config/env/development.json --dart-define=USE_DEMO=true
```

Use this for layout and theming. Screens without a backend contract stay
marked **Demo content**.

### Optional network logs

Debug builds only. Values are never printed (field names and sizes only):

```bash
flutter run --dart-define-from-file=config/env/development.json --dart-define=ENABLE_NETWORK_LOGS=true
```

### Other environments

```bash
flutter run --dart-define-from-file=config/env/staging.json
flutter run --dart-define-from-file=config/env/production.json
```

Production requires HTTPS.

## Release gate (before client send)

- Smoke checklist: [`docs/RELEASE_CHECKLIST.md`](docs/RELEASE_CHECKLIST.md)
- Client one-pager: [`docs/CLIENT_TEST_GUIDE.md`](docs/CLIENT_TEST_GUIDE.md)
- Client release notes: [`docs/RELEASE_NOTES.md`](docs/RELEASE_NOTES.md)
- Demo seed (backend): `npm run seed-test-data` in `roundsai-backend` (fictional only)

## Android APK (client share)

See [`docs/ANDROID_APK.md`](docs/ANDROID_APK.md).

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://round-ai-backend.fly.dev \
  --dart-define=APP_ENV=production \
  --dart-define=DEMO_HINTS=true
# → build/app/outputs/flutter-apk/app-release.apk
```

Release signing uses `android/key.properties` when present; otherwise the **debug keystore** (demo only).

## iOS (TestFlight)

IPA cannot be shared like an APK. Prefer **TestFlight**; Ad Hoc only as fallback. AltStore is not for clients.

See [`docs/IOS_DISTRIBUTION.md`](docs/IOS_DISTRIBUTION.md) (needs Apple Developer Program + Mac). Until that account exists, ship web + Android only.

## Web demo (Vercel)

Client-friendly browser link (phone or laptop). See [`docs/WEB_DEPLOY.md`](docs/WEB_DEPLOY.md).

```bash
flutter build web --release --no-wasm-dry-run \
  --dart-define=API_BASE_URL=https://round-ai-backend.fly.dev \
  --dart-define=APP_ENV=production \
  --dart-define=DEMO_HINTS=true
cp vercel.json build/web/
npx vercel build/web --prod
```

On web, `flutter_secure_storage` uses browser storage (weaker than mobile Keychain/Keystore) — acceptable for the fictional demo only. Wide viewports center a ~430px phone column.

## What talks to the backend

| Area | Status |
|---|---|
| Sign-in, session, team pick, census, patient overview | Live |
| Chart facts, plan, summary, Ask, notes, problems, ICD suggest | Live |
| Evidence, Teach (patient MCQ), Tasks, Sign-out | Live |
| **Scribe** — patient intake (voice/photo), field mic `/transcribe`, census intake / confirm / export | Live |
| **Round** — morning brief, Rounds tab cards, oral presentation, reminders, prepare presentations | Live |
| **Teaching** — Learn tab plan, quiz, reads, guideline updates, spaced review, reading list | Live |
| **Team chat** — channels, SSE, threads, mentions, search, patient threads, summarize, push stub | Live |
| Attending question + answer framework | Demo only (no backend) |
| Considerations explorer | Hidden (not in the mobile app) |
| Admin approvals (reminder rules, MCQs, curated reads, guideline updates) | Not in mobile — use the backend admin API / separate admin tool |

## Chat

Team chat for the signed-in clinician’s team (backend M5). Messages may contain PHI.

- **Inbox** — Team / Patients / Groups / Direct messages with unread counts; pull to refresh.
- **Channel** — REST history + optimistic send/retry; edit/delete own messages; day separators; patient-thread composer reminder.
- **Realtime** — SSE over Dio with Bearer auth; connect in foreground, disconnect when backgrounded; `Last-Event-ID` replay, dedupe, backoff.
- **Threads / mentions / search** — reply threads; `@FirstName` mentions from a local people directory (no teammates list API); search debounced and never logged.
- **Patient thread** — “Open team thread” from the patient overview; header label + “View patient” stay in navigation `extra`, not the URL.
- **Summarize thread** — explicit menu + confirm; private AI draft for the requester only (never auto-posted).
- **Push** — soft opt-in on the Chat tab; `POST /chat/devices` (token hash on server); payloads must stay generic (`New message` / `Open RoundsAI`). FCM/APNs SDK is not wired until provider + BAA are confirmed; mute / quiet hours not built.
- **Cache** — memory-only bounded message cache; cleared on sign-out and 401. No encrypted offline store (ask before adding).
- **Privacy** — no message text, patient names, or channel labels in logs, analytics, push, or deep-link paths. `PrivacyShield` + Android release `FLAG_SECURE` hide the app switcher snapshot.

Contract gaps vs backend (client workarounds): no `client_message_id`, no `last_activity`, no leave/archive, no teammates API, no `reply_count` field (client counts from loaded messages).

## Scribe / Round / Teaching

### Scribe

- Patient intake: dictate or photograph chart text → backend extract → review facts.
- Mic on note fields: `/transcribe`, then feed sources into notes via `inputs_from_source_ids`.
- Census photo/voice intake, propose list, confirm, reorder (`sort_order`), export (share / copy).
- ICD-10-CM suggest on confirmed/differential problems; accept writes `code_suggestion`.
- Capture limits match the backend (audio 25 MiB, image 10 MiB). Temp media is always deleted after upload, cancel, or failure (`withTempMediaCleanup`). Paths are never logged with patient ids.

### Round

- Today **Morning Brief** uses deterministic counts from `GET /round/brief` (unreviewed facts, outdated summaries, overdue tasks). No urgency ranking.
- **Rounds** tab walks patients in `sort_order` / room order with what-changed, trends, conflicts, pending items, tasks, missing information, plan, problems, and approved reminders (“Prompt for your consideration”).
- Oral presentation: `POST /patients/:id/present` — word count target 150–220, sentence source chips, regenerate, mark reviewed, copy. No TTS in the app.
- Prepare presentations: `POST /round/brief/prepare` with per-patient success/failure (never silent). Daily AI limit is surfaced.
- Reminder rules must be **approved** on the backend before they appear. Empty state: “No approved reminders for this patient's problems.”

### Teaching

- Learn tab topics from `GET /teaching/plan` — generic topic strings and counts only (**no patient names or links**).
- Quiz from `GET /teaching/questions` (approved bank first). Optional “Include AI-generated drafts” (`allow_generate=true`) labels unreviewed drafts. Report issue → question leaves the learner bank.
- Reads: Recent studies, Older high-design evidence, Guidelines, and **Curated high-yield** (only that section may use “high-yield”). Open PMIDs/URLs externally; save to reading list.
- Guideline updates: approved admin-entered feed with “Verify against the source.”
- Spaced review queue uses 1 / 3 / 7 day intervals.

## Privacy

- Tokens live in secure storage when "Remember me" is on; otherwise in memory.
- Sign-out and a 401 clear the session, chat memory cache, SSE, unread badge,
  people directory, push association, and return to sign-in.
- The app switcher shows a plain cover (`PrivacyShield`). Android release
  builds also set `FLAG_SECURE` so screenshots and recent-apps thumbnails
  do not show patient data.
- Logs never print request or response bodies, tokens, chat message text,
  search queries, or typed text. Release builds log nothing.
- Media and dictated text: platform permission strings tell the clinician not
  to capture or speak names, MRNs, or dates of birth, and to follow hospital
  recording policy. See `ios/Runner/Info.plist` and the Android camera/mic
  permissions in `AndroidManifest.xml`.

## Open policy questions

These were not decided in the mobile build (do not guess in product copy):

1. Push provider and compliance position (BAA) for FCM/APNs; is remote push allowed at launch?
2. Is encrypted offline caching of chat messages allowed, or memory-only (current)?
3. Should patient threads appear inside Round mode on each patient card?
4. Mute / quiet hours / notification preferences at launch?
5. Recording policy / consent notice for in-app audio of patient-related speech.
6. Whether oral presentation should gain text-to-speech read-aloud.
7. Who approves reminder rules, curated reads, and guideline updates (admin tool).
