# RoundsAI client requirements — completion matrix

Date: 2026-11-19. Status values: PASS / PARTIAL / FAIL / BLOCKED only.

| # | Requirement | Status | Notes |
|---|-------------|--------|-------|
| 1 | Note generation reliability | PARTIAL | Empty advanced generate disabled; empty dictation still 400. Soft AI validation can still save `partial` artifacts. |
| 2 | Today/Census sync | PASS | `markCensusDirty` on intake confirm, problem decisions, task complete/accept/dismiss, plan save, notes/summary. Overview listens to CensusSync. |
| 3 | Human-readable clinical UI | PASS | Trends/missing tokens humanized; census one-liner + key changes from chart (no AI ranking). |
| 4 | Simplified home | PASS | Home rows show one-liner, overnight/key changes, pending facts/tasks, note status. |
| 5 | Patient workspace | PASS | Problem-wise A&P editor; structured plan API; single primary Create note (header duplicate + Draft Note tile removed). |
| 6 | Fact review | PASS | Add update → intake → Review facts deep-link; plan bridge after dictation note remains. |
| 7 | Rosa demo consistency | PASS | `ensureRosaDemoCase` + Elevated Pulse bank (5 options) idempotent without wiping users. |
| 8 | Note draft/review/copy | PASS | Prefill/export use saved plan with ICD preference; regenerate confirm dialog kept; copy after review via server export. |
| 9 | Learning Elevated Pulse | PASS | Seed + backfill guarantee 5 options; spaced-review miss path covered by backend test; empty queue has practice CTA. |
| 10 | ICD toggle in A&P + note | PASS | Toggle persists via structured plan; note prefill respects `include_icd`; codes only from accepted suggestions. |
| 11 | Mobile Safari | BLOCKED | Layout shell exists; no physical iPhone Safari mic/camera E2E this pass. |

## Verification

| Check | Result |
|-------|--------|
| Backend `npm test` | PASS (59/59) |
| Frontend `flutter analyze` / `flutter test` | BLOCKED (Flutter SDK not on this machine PATH) |
| Frontend `flutter build web` | BLOCKED locally; Vercel uses `scripts/vercel-build.sh` |
| https://round-ai-one.vercel.app | PARTIAL / FAIL until redeploy — currently 404 (no `build/web` from prior Git deploy). Settings documented in `docs/WEB_DEPLOY.md`. |
| Backend health | PASS — `https://round-ai-backend.fly.dev/health` → `provider: openai`, status ok |

## Explicitly out of this slice

- Full design-token redesign of every screen
- Physical iPhone Safari E2E
- Admin panel deep redesign
