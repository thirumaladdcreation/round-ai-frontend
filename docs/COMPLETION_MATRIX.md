# RoundsAI client requirements — completion matrix

Date: 2026-11-20. Statuses: PASS / PARTIAL / FAIL / BLOCKED only.

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| 1 | Note generation reliability | PASS | Empty/short dictation blocked FE+BE; generic clinical transcripts accepted; failure keeps draft/transcript; retry reuses idempotency key; placeholders/flags block review; export only after review. FE `NoteCubit` + BE W4 tests. |
| 2 | Today/Census sync | PASS | `markCensusDirty` on intake, facts, problems, tasks, plan, notes, summary; overview listens to CensusSync. |
| 3 | Human-readable clinical UI | PASS | Trends/missing humanized; no `clinician_plan`/raw IDs in resident UI paths touched. |
| 4 | Simplified home | PASS | Patient list with one-liner, key changes, pending facts/tasks, note status. |
| 5 | Patient workspace | PASS | Sticky identity chrome; problem-wise A&P; single Create note; Add update consolidated. |
| 6 | Fact review | PASS | Passages + O2 context; bulk review; intake → Review facts; plan bridge after dictation. |
| 7 | Rosa demo consistency | PASS | Live `roundsai-demo` verified: Rosa has 0 pending identity facts; seed purge deletes John Doe / 2023 visit-date rows and scrubs sources; extract binds `patient_id` to route patient + source; regression tests. |
| 8 | Note draft/review/copy | PASS | Draft/partial/reviewed/outdated labels; regenerate confirm (full + section); compose cache + leave confirm; save retry; problem-wise A&P display/bridge; copy after review. |
| 9 | Learning Elevated Pulse | PASS | Seed answer keys + explanations normalized; miss due immediately then 1/3/7; curated PubMed reads; Learn empty states with next steps; census topics ↔ problems. |
| 10 | ICD toggle in A&P + note | PASS | Inline/full A&P “Include ICD-10” + Review ICD; codes beside diagnoses in plan/note; Elevated Pulse flagged (no invented code); wording preserved. |
| 11 | Mobile Safari E2E | PARTIAL | Code hardened: Safari permission copy, upload cancel, WAV filename, clipboard fallback, local TZ labels, viewport meta. Physical iPhone Safari mic/OCR still required — see `docs/SAFARI_E2E_CHECKLIST.md`. |

## Verification run (2026-11-20)

| Check | Result |
|-------|--------|
| Backend `npm test` | PASS **60/60** |
| Frontend `flutter analyze` | **0 errors** (info-level Material deprecations only) |
| Frontend note unit/widget tests | PASS (`f4_logic_test`, `f4_screens_test` note screen, `w4_scribe_note_test`) |
| `flutter build web --release` | PASS (`√ Built build/web`) |
| Vercel | Prior deploy of `6822ee6` passed compile; this commit must redeploy |
| Backend health | `https://round-ai-backend.fly.dev/health` → ok, `provider: openai` |
| iPhone Safari | PARTIAL — software hardenings done; device checklist open |

## Remaining limitations

- Soft AI validation can still save artifacts as `partial` until the clinician edits; review/export remain blocked while flags/placeholders remain.
- Fly production DB must run seed/ensure path (or restart with seed hook) so Rosa purge + Elevated Pulse bank apply on the live volume.
- Full `flutter test` suite beyond note/learning-focused files may include unrelated flakes; critical note paths above were re-run green.
- Physical iPhone Safari mic/OCR E2E still required for requirement 11 PASS (`docs/SAFARI_E2E_CHECKLIST.md`).

## Manual client demo steps

1. Open production frontend (after this commit deploys) → login `resident@rounds.test`.
2. Census → **Rosa Martinez (fictional)** · 509A.
3. Confirm no John Doe / 2023 identity facts.
4. Add update → review facts with passages → save problem-wise A&P → ICD toggle on/off.
5. Create note from dictation (short sentence+) → edit → mark reviewed → copy.
6. Learn → Elevated Pulse → answer wrong once → open Review queue.
