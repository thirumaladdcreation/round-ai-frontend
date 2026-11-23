# iPhone Safari E2E checklist (requirement #11)

Physical device pass is still required for matrix **PASS**. Softenings below are already in code for denied permissions, cancel/upload, timezone labels, and viewport.

**Environment:** production HTTPS frontend · `resident@rounds.test` · backend `roundsai-demo.fly.dev`

## A. Shell / keyboard / scroll

- [ ] Open site in **Safari** (not Chrome iOS).
- [ ] Login; Home/Census scroll without horizontal jank.
- [ ] Open Rosa → type in a field; keyboard does not cover Save; dismiss on drag/tap outside.
- [ ] Long patient page + note draft: scroll while keyboard open.

## B. Notes — save / copy / interrupt

- [ ] Create note from short dictation or typed field → edit section → Save.
- [ ] Mark reviewed → **Copy note text** (if Safari blocks clipboard, snackbar explains manual copy).
- [ ] Start regenerate → **Cancel** mid-request → draft/dictation still present.
- [ ] Leave compose before generate → confirm dialog; return later → typed text restored.

## C. Microphone → transcription

- [ ] Patient → Add update / Dictate → allow mic → record → Stop & save → pending facts.
- [ ] Deny mic → clear Safari Website Settings message; typed chart text unchanged.
- [ ] Cancel upload mid-flight → chart unchanged; can retry.

## D. Photo → OCR

- [ ] Take photo / Choose from gallery → upload → pending facts or readable error.
- [ ] Deny camera → Safari Website Settings guidance.
- [ ] HEIC-only failure → JPEG/PNG / screenshot guidance.
- [ ] Cancel upload → no partial source.

## E. Timestamps

- [ ] Fact event times and “Made …” labels show **local** clock with zone (e.g. `IST` / `GMT+5:30`).
- [ ] Same instant looks consistent across facts list, source drawer, and note chrome.

## F. Sign-off

| Check | Pass? | Tester | Date |
|-------|-------|--------|------|
| A Shell/keyboard | | | |
| B Notes copy/interrupt | | | |
| C Mic E2E | | | |
| D Photo OCR E2E | | | |
| E Timezone labels | | | |

When all rows pass, set `COMPLETION_MATRIX.md` #11 to **PASS** and attach this filled checklist.
