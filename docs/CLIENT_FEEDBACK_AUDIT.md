# Client feedback audit — Phase 0

**Date:** 2026-11-24  
**Scope:** Read-only production sanity + code/fixture trace. **No behavior changes in this phase.**  
**Repos audited:** `round_ai` (Flutter), `roundsai-backend`, `round_ai_admin` (path differs from prompt’s `roundsai-admin`).  
**Live API under test:** `https://roundsai-demo.fly.dev` (Flutter `config/env/production.json`).  
**Prototype screenshots:** `docs/prototype/01-today.png`, `02-census.png`, `03-rounds.png` + `PARITY_DIFF.md`.

---

## Production sanity (live)

### `GET /health` (`roundsai-demo`)

```json
{
  "status": "ok",
  "provider": "openai",
  "db_path": "/data/roundsai.db",
  "users": 3,
  "patients": 2
}
```

- **Provider:** `openai` (not mock).
- **Model:** **not on public `/health`**. On `GET /admin/health` and `GET /admin/settings`: **`gpt-4o`** (`prompt_version`: `2026-11-v2`).
- Dictation artifact also reported model string `gpt-4o-2024-08-06`.

### Fly secrets present (`fly secrets list -a roundsai-demo`)

| Secret | Present |
|--------|---------|
| `AI_PROVIDER` | Yes |
| `OPENAI_API_KEY` | Yes |
| `OPENAI_MODEL` | Yes |
| `OPENAI_TRANSCRIBE_MODEL` | Yes |
| `OPENAI_VISION_MODEL` | **No** (vision falls back to `OPENAI_MODEL` in `src/ai/adapter.js`) |
| `ALLOW_MOCK_IN_PRODUCTION` | **N/A — flag not implemented in code** |

### `GET /admin/settings` (admin)

| Field | Value |
|-------|-------|
| `provider` | `openai` |
| `model` | `gpt-4o` |
| `ai_enabled` | `true` |
| `review_intervals_days` | `[1, 3, 7]` |
| `max_calls_per_user_per_day` | `200` |
| CORS | admin Vercel + `round-ai-one.vercel.app` + localhost |

### `GET /admin/icd`

| Field | Value |
|-------|-------|
| `count` | **10** |
| `fy` | **`demo`** |
| `demo_only` | **`true`** |
| Meaning | **Tiny demo subset only — not the real CMS/CDC fiscal-year file** |

### Content counts (admin)

| Content | Count | Notes |
|---------|-------|-------|
| Approved MCQs (`/admin/mcqs?status=approved`) | **3** | 2× Elevated Pulse (`source: human`), 1× acute kidney injury |
| Curated reads (approved) | **2** | Both Elevated Pulse / PubMed-style titles |
| Guideline updates | **0** | |
| Check / reminder rules | **10 draft, 0 approved** | None clinician-approved |

### Transcription / vision (code defaults)

| Capability | Config | Live |
|------------|--------|------|
| Transcribe | `OPENAI_TRANSCRIBE_MODEL` default `whisper-1`; secret set on Fly | Configured |
| Vision / OCR | `OPENAI_VISION_MODEL` or fallback `OPENAI_MODEL` | Secret **missing**; falls back to chat model |

---

## Mock guard (code vs requirement)

| Requirement | Actual |
|-------------|--------|
| Refuse start in production when `AI_PROVIDER=mock` unless `ALLOW_MOCK_IN_PRODUCTION=true` | **Missing.** `src/config.js` defaults `AI_PROVIDER` to `'mock'`. Production only asserts `AUTH_SECRET` + `/data` DB path. |
| `/health` exposes `provider` | **Yes** |
| Apps show persistent **“MOCK AI: demo output only”** when mock | **Missing.** Flutter has `DemoContentBanner` (“Demo content…”) for `USE_DEMO`, not a mock-provider banner. Admin: not audited end-to-end for mock banner. |
| Mock fixtures must never write canned patient text into real data paths | **Partial.** Mock OCR/transcribe return canned clinical lines (`src/ai/mock.js`); identity validators + `purgeIdentityFacts` scrub John Doe / 2023. |

**Prime suspect — “note is the same thing I said”:**  
Confirmed in code: mock `draft_note` **echoes** `inputs.*` for clinician-sourced sections (`roundsai-backend/src/ai/mock.js` ~L52–68). Live demo provider is **openai**, so that echo is **not** what production is running **today**. Historical client pain matches mock/`draft_note` field mode more than current `from-dictation` openai path.

---

## John Doe / 2023 under Rosa — fixture trace

### Live `roundsai-demo` (2026-11-24)

- Rosa id `848c4396-…`, room `509A`, **0 unreviewed facts**, **17 facts**, **3 sources**.
- Scan of facts + sources JSON: **no** `John Doe`, **no** `Visit Date: 2023` / Patient Name contamination.
- Display name still stored as `Rosa Martinez (fictional)` in API (Flutter strips trailing `(fictional)` for UI).

### How contamination happened (root cause — historical)

1. **Not** present in current `ROSA_SOURCES` seed text (`src/seed.js`).
2. Likely path: **photo/OCR or pasted source** (or an older mock/vision path) produced header-like lines (`Patient Name: John Doe`, visit date **2023**) that were extracted into **facts on Rosa’s `patient_id`**.
3. Mitigations now in tree:
   - `validators.js` `isIdentityFact` / identity patterns (John Doe, bare year visit dates).
   - `purgeIdentityFacts()` deletes matching facts and scrubs source text; called from `ensureRosaDemoCase` / existing-DB `seedDemo`.
4. **Flutter `lib/`** has **no** John Doe fixture; only docs/`COMPLETION_MATRIX.md` mention the purge.

**Status today:** live Rosa **clean**. Root cause = identity lines imported into chart facts without hard block at extract time historically; purge + validators are the fix path (still need Phase 4 hardening for mismatch warnings as specified).

---

## Note-from-dictation reproduce (client point 1)

| Case | Result |
|------|--------|
| Usable transcript → `POST /patients/:id/notes/from-dictation` | **HTTP 200**, `provider: openai`, `review_state: draft`, artifact `status: **partial**`, `requires_review: true` |
| Empty transcript | **HTTP 400**, `code: transcript_required` |
| `X-Request-Id` on response | **Absent** (middleware not implemented) |

**Differs from client wording:** generic **“Something went wrong”** was **not** reproduced on live openai today.  
**Still a product risk:** `partial` drafts can feel like failure in the UI; soft-validation / placeholders may block review. FE maps many failures to specific copy (`api_error.dart`) — literal “Something went wrong” is largely banned in `lib/` already (comment only in `failures.dart`).

---

## Request id

- **Backend:** no `X-Request-Id` middleware (`server.js` CORS allows `Idempotency-Key` only).
- **App:** no “Reference: …” support surface for request ids yet.

---

## Core flow tap audit (today vs target)

**Target:** Census → patient → Create note in **2 taps**; Add update in **1 flow**; stay in patient context; no technical text.

| Step | Today (code) | Taps from Census |
|------|--------------|------------------|
| Open patient | Patients tab card → `/patient/:id` | **1** |
| Create note | Sticky footer **Create note** → `/patient/:id/note` | **2** |
| Add update | Sticky footer **Add update** → intake (Dictate/Photo/Paste) | **1** entry from patient |

**Also present (adds noise vs north star):**

| Extra entry | Where |
|-------------|--------|
| Home → Start New Round → Census | `HomeAssistantCard` |
| Home → Recent Patients row | same patient open |
| **Scribe** bottom tab | parallel intake hub |
| Rounds / Learn / drawer Chat & Tasks | secondary |

**Bottom nav (P3 implemented):** Patients, Tasks, Learn, Chat — Home/Scribe/Rounds secondary (drawer / Add update). Profile remains drawer + header avatar.

**Rough screen count Census→copyable note (happy path):**  
Patients → Overview → (optional Add update → fact review) → Create note → edit/review → Copy ≈ **4–6 screens** if update+review included; **3** if note-only (Census, Overview, Note).

---

## Design system gap (section 4)

| Rule | Current |
|------|---------|
| Single type scale (24/18/16/14/12) | `AppTypography` roles: `screenTitle` 24, `sectionHeader` 18, `clinicalBody` 16, `secondaryText` 14, `captionMeta` 12 (P2). Ad-hoc sizes still exist on older screens. |
| Clinical values never &lt;12 / never caption | Improved; caption reserved for meta |
| One primary button / screen | Mostly better on Home/Patient; still dense on some charts |
| Sticky patient header (name+room) on all patient screens | Overview has chrome; not uniformly audited across every sub-route |
| `ClinicalFormatter` name | Implemented as `lib/core/utils/clinical_format.dart` (not class name `ClinicalFormatter`) |
| Banned-token widget test | **Present** (`test/clinical_format_test.dart` + `test/support/banned_tokens.dart`) |

---

## Client points 1–11

Statuses below are **against Prompt 8 acceptance**, not the optimistic `COMPLETION_MATRIX.md` (see “Differs from docs”).

### 1 — Note generation reliability

| | |
|--|--|
| **Current** | FE gate ≥12 chars; BE `transcript_required`; failure keeps text + Retry; live openai from-dictation **200/partial**. Screens: `note_draft_screen.dart`, `note_cubit.dart`; BE `orchestrator.draftNoteFromDictation`. |
| **Root cause (historical “same thing I said”)** | Mock `draft_note` echoes inputs; field-mode scribe. |
| **Root cause (historical 500 / Something went wrong)** | Not reproduced today; likely prior deploy/validator/provider mapping. |
| **Planned** | P1: harden partial UX, backend failure-path test, never lose text, request-id in errors. |
| **Test plan** | BE failure path; widget: failed gen keeps text + Retry; empty cannot submit (partially exists in `f4_*`). |
| **Status** | **Partial → improved in P1** (2026-11-24): BE `ai_unavailable` failure-path test; FE short-gate test; note `_ErrorBox` shows `Reference:`; compose cache already present; `HospitalClock` + `note_date` on dictation. Still Partial until hospital TZ confirmed + soft-`partial` UX polish. |

### 2 — Status / counts consistent

| | |
|--|--|
| **Current** | BE mutations return `patient_status` (facts/review, plan, problems, tasks). FE `PatientStatusStore` applies snapshots; Census + Home Recent Patients overlay counts immediately; `CensusSync` still refetches as fallback. |
| **Root cause** | Was sync-by-invalidate only. |
| **Planned** | P2: `patient_status` on mutation responses + store. |
| **Test plan** | BE fact-review asserts `patient_status`; FE store overlay unit test. |
| **Status** | **Improved (P2, 2026-11-24)** — still Partial until every list surface + summary generation path is confirmed end-to-end on device. |

### 3 — Remove technical information

| | |
|--|--|
| **Current** | `humanizeMissingToken` / `humanizeKey` cover clinician_* keys; trends/conflicts never dump wire keys; banned-token helper + widget test on Patient/Today/Note surfaces. |
| **Root cause** | Was missing a global banned-token gate test. |
| **Planned** | P2: expand formatter + banned-token widget test. |
| **Status** | **Improved (P2)** — Partial until full Rounds/Overview screen pumps are gated the same way. |

### 4 — Simplify home

| | |
|--|--|
| **Current** | Bottom bar: **Patients · Tasks · Learn · Chat**. Post-login lands on Patients. Today overview is drawer-only (date + one counts line + Recent Patients; assistant “Start New Round” removed). Scribe hub reframed as Add update / census capture (not a tab). |
| **Root cause** | Was 5-tab shell with Home/Scribe/Rounds competing. |
| **Planned** | P3: cut duplicate CTAs; merge Home into Patients; fold Scribe into Add update. |
| **Status** | **Improved (P3, 2026-11-24)** — tap audit: Census→patient→Create note = **2 taps** from Patients list. |
| **Before → after** | Before: Home or Patients or Scribe → patient → note (3+ competing entry points). After: Patients → patient → Create note (one primary list). |

### 5 — Patient page reorganization

| | |
|--|--|
| **Current** | Sticky header (name+room) + **More** menu (Tasks, Evidence, Teach, Presentation, Chat, Ask, Sign-out). Body: one-liner → changes → vitals → problems → A&P → facts/summary. Sticky footer: **Add update** + **Create note** (no scroll). |
| **Planned** | P3: More menu; create-note always visible. |
| **Status** | **Improved (P3)** |

### 6 — Fact review

| | |
|--|--|
| **Current** | Compact review: label/value/qualifier chip/time/passage (expand), bulk select, Confirm/Reject, inline Edit. Qualifier must appear in passage (BE validator). Dictation A&P proposals shown on review sheet with accept → structured plan. |
| **Planned** | P4: qualifiers validator, compact sheet, A&P proposals. |
| **Status** | **Improved (P4, 2026-11-24)** |

### 7 — Demo data integrity

| | |
|--|--|
| **Current** | Extract binds `source.patient_id === route patient` (`patient_mismatch`). Identity mismatch warning when imported “Patient Name:” ≠ chart. Implausible / before-admission date warnings on facts. Purge + `isIdentityFact` retained. |
| **Planned** | P4: mismatch/date warnings, stronger tests. |
| **Status** | **Improved (P4)** — tests in `p4_fact_integrity.test.js` + API extract bind. |

### 8 — Note usability / A&P by problem

| | |
|--|--|
| **Current** | Problem-wise A&P blocks (`source`/`status`/`manually_edited`); plain text migrates to General; rewrite dialog Keep mine / Use new; note **History** + restore (marks manually_edited, clears review). |
| **Planned** | P5. |
| **Status** | **Improved (P5, 2026-11-24)** |

### 9 — Learning

| | |
|--|--|
| **Current** | ≥5 approved human MCQs per Rosa topic (Elevated Pulse, CAP, AKI); curated reads 2; pneumonia+AKI check-rules demo-approved; Learn topics filter + `bank_count`; `DEMO_MODE`/`DEMO_CLOCK_ISO` for scripted demos. |
| **Planned** | P6. |
| **Status** | **Improved (P6, 2026-11-24)** |

### 10 — ICD toggle

| | |
|--|--|
| **Current** | Toggle + accepted-only codes in render/copy; **Needs more detail** when specificity missing; **production ICD is demo_only (10 codes)** — cannot honestly claim CMS table. |
| **Planned** | P5 UX done; real ICD import still needs your file (§10). |
| **Status** | **Improved (P5 UX)** / **Fail** (prod table prerequisite) |

### 11 — Mobile Safari

| | |
|--|--|
| **Current** | Code hardenings + `SAFARI_E2E_CHECKLIST.md`; physical iPhone E2E not done here. |
| **Planned** | P7 + Playwright WebKit + your device checklist. |
| **Status** | **Partial** |

---

## Differs from existing docs / prompt

1. Prompt says `roundsai-admin` — disk path is **`round_ai_admin`**.
2. Prompt production host examples vs this app’s **`roundsai-demo.fly.dev`** (also older `round-ai-backend.fly.dev` in matrix).
3. `docs/COMPLETION_MATRIX.md` marks 1–10 as **PASS** — **too strong** vs Prompt 8 acceptance (patient_status store, mock guard, MOCK banner, banned-token test, real ICD file, full A&P blocks, learning demo depth, Safari device). This audit supersedes those PASS marks for Prompt 8.
4. Class name `ClinicalFormatter` vs file `clinical_format.dart`.
5. Live dictation does **not** currently return the client’s “Something went wrong” string.
6. `(fictional)` still in API `display_name`; FE strips for display (local change; may not be on Vercel yet).

---

## Phase 0 exit criteria (before P1)

1. Implement **mock production guard** + `ALLOW_MOCK_IN_PRODUCTION`. → **Done (2026-11-24)**
2. Add **`X-Request-Id`** middleware (no PHI) and surface “Reference: …” in app errors. → **Done**
3. Expose `model` on `/health`. → **Done**
4. Persistent **MOCK AI: demo output only** banner (Flutter + admin) when provider is mock. → **Done**

---

## Phase 2 exit (2026-11-24)

1. BE `patient_status` on fact review / plan / problem decide / task mutations → **Done** (live `roundsai-demo` verified on plan save).
2. FE `PatientStatusStore` + Census/Home overlay → **Done**.
3. Clinical humanize + banned-token widget test → **Done**.
4. Typography role aliases (24/18/16/14/12) → **Done** (adoption across all screens still incremental).
5. Deploy → **Done** (`roundsai-demo`).

---

## Phase 3 exit (2026-11-24)

1. Bottom nav Patients · Tasks · Learn · Chat; Home/Scribe/Rounds secondary → **Done**.
2. Patients list rows: room, one-liner, ≤2 changes, fact/task badges, status chip → **Done**.
3. Patient More menu + sticky Add update / Create note → **Done**.
4. Post-login landing = Patients (`/census`) → **Done**.
5. Tests: `test/p3_nav_patient_test.dart` + updated shell/chat tests → **Done**.
6. FE web deploy (Vercel) → not in this phase unless requested.

---

## Phase 4 exit (2026-11-24)

1. Qualifier field + passage validator + FE chip/display → **Done**.
2. Identity mismatch + date warnings → **Done**.
3. Cross-patient extract blocked (`patient_mismatch`) → **Done**.
4. A&P proposals from extract + accept into structured plan → **Done**.
5. Inline fact edit (`PATCH /facts/:id`) → **Done**.
6. Tests: `test/p4_fact_integrity.test.js`, `test/p4_fact_review_test.dart`, API P4 cases → **Done**.
7. Deploy → **roundsai-demo** (this phase).

---

## Phase 5 exit (2026-11-24)

1. A&P problem blocks + plain-text → General migration (`plan.js`) → **Done**.
2. Regenerate rewrite dialog: **Keep mine** / **Use new** → **Done**.
3. Note version history + restore API/UI (`History` on draft note) → **Done**.
4. ICD: accepted codes only in render/copy; **Needs more detail** chip → **Done**.
5. Tests: `test/p5_plan_blocks.test.js`, `test/p5_version_restore.test.js`, `test/p5_plan_and_history_test.dart` → **Done**.
6. Deploy → **roundsai-demo** (this phase).
7. Real CMS/CDC ICD file still **open** (§10) — prod remains `demo_only` (10 codes).

---

## Phase 6 exit (2026-11-24)

1. Demo bank ≥5 approved Q/topic (Elevated Pulse, CAP, AKI) + ensure backfill → **Done**.
2. Learn topics filter + `bank_count` on plan → **Done**.
3. `DEMO_MODE` + `DEMO_CLOCK_ISO` (BE `today`/`nowIso` + FE `HospitalClock`) → **Done**.
4. Demo-approve pneumonia + AKI check-rules (disable with `DEMO_APPROVE_CHECK_RULES=false`) → **Done**.
5. Tests: `test/p6_learning_demo.test.js`, `test/p6_learning_test.dart` → **Done**.
6. Deploy → **roundsai-demo** (this phase).
7. Optional: set Fly secrets `DEMO_MODE` / `DEMO_CLOCK_ISO` only when scripting a fixed demo day.

---

## Questions (do not guess — section 10)

1. Which **model** and **vision/transcription** providers are approved for production? (Live today: chat `gpt-4o`, transcribe secret set, vision falls back to chat model.)
2. **Hospital timezone** for the demo?
3. Who is the **demo physician reviewer** for questions/rules?
4. Is **short-lived on-device persistence** of unsent drafts acceptable?
5. Is the **real ICD-10-CM fiscal-year file** available to import on production?
6. Bottom-nav — **implemented in P3** as Patients · Tasks · Learn · Chat (Profile stays drawer/avatar; Rounds/Today secondary in drawer).
