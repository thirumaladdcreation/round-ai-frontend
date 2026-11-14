# Release checklist (smoke test)

**Rule:** Nothing goes to the client until every item below passes on a **clean install** of the build you intend to ship.

Use **fictional demo data only**. Do not type real names, MRNs, or dates of birth.

**Demo accounts:** `resident@rounds.test` / `ChangeMe-12345`  
Second chat user: `other@rounds.test` / `ChangeMe-12345` (Team B — cannot see Team A patients)  
Admin (reminders approval): `admin@rounds.test` / `ChangeMe-12345` → [Admin](https://round-ai-admin.vercel.app)

**API:** `https://round-ai-backend.fly.dev`

Mark each box after you verify it yourself.

---

## Platforms

Run the same list on each platform you ship:

| Platform | Build under test | Tester | Date | Pass? |
|----------|------------------|--------|------|-------|
| Web (HTTPS) | | | | ☐ |
| Android APK | | | | ☐ |
| iOS TestFlight (see [`IOS_DISTRIBUTION.md`](IOS_DISTRIBUTION.md)) | | | | ☐ |

---

## Smoke steps (every platform)

### Auth
- [ ] **Login** with `resident@rounds.test` / `ChangeMe-12345`
- [ ] **Remember me** on → force-close app/browser → reopen → still signed in (or email prefilled per platform behavior)
- [ ] Wrong password shows a clear error (no stack traces)

### Census & chart
- [ ] **Census** opens; at least one fictional patient visible
- [ ] **Add patient** (or confirm from photo/voice intake) → patient appears on census
- [ ] Open patient → **confirm facts** (pending → confirmed)
- [ ] **Save Today's plan** (typed by clinician; AI does not invent it)

### AI drafts (always labeled for review)
- [ ] **Summary** generates → shows “AI draft · review required” (or equivalent)
- [ ] **Write note from dictation** → cleaned sections; empty plan stays not entered if not dictated
- [ ] **Presentation** generates; if chart/plan incomplete, clear message (e.g. confirm facts / save plan) — not a broken stub
- [ ] **Photo intake** on a chart-like image → source + pending facts (or a plain error: too large / unreadable / busy) — never a silent fail

### Teach / reminders / chat
- [ ] **Learn / Teach** opens; topics or empty state is clear (no patient names in Learn)
- [ ] **Reminders:** after admin **approves** an example check-rule, patient reminders show “Prompt for your consideration”
- [ ] **Chat** between `resident@rounds.test` and a teammate on the **same** team (use admin to add a second Team A user if needed); `other@rounds.test` cannot see Team A patients
- [ ] **Sign-out** → returns to login; protected screens require login again

### Hygiene
- [ ] No PHI or clinical text in device logs you checked
- [ ] Backend `fly logs -a round-ai-backend` shows status codes only on failures (no pasted chart text)

---

## Gate

| Question | Answer |
|----------|--------|
| All platforms in scope marked Pass? | ☐ Yes |
| Known issues filed **internally** (not in client notes)? | ☐ Yes |
| Client test guide + release notes ready? | ☐ Yes |

**Ship only if every answer is Yes.**
