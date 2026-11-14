# UI parity diff (app vs clinical prototype)

Prototype: `rounds-ai-clinical-prototype.ludwingr.chatgpt.site`  
Captured: 2026-11-14. Safety copy ("AI draft · review required", "Not entered", etc.) left unchanged.

## Global tokens

| Area | Prototype | App before | Change |
|------|-----------|------------|--------|
| Background | `#f3f6f8` | `#F4F8FC` | Aligned |
| Ink / navy | `#10232e` | `#102A43` | Aligned |
| Primary blue | `#087cff` | `#2677D9` | Aligned |
| Muted | `#768690` | `#718096` | Aligned |
| Border | `#e4eaee` | `#DFE7EF` | Aligned |
| Success / warn / error | green/amber/red tokens | older greens/rose | Aligned |
| AI surfaces | clinical teal | purple tint | Teal/slate (not purple-on-white) |
| Radii | 4–12px scale | ad-hoc 12/16 | `AppRadii` |
| Type | SF Pro / system | Poppins (bundled) | Keep Poppins — closest licensed bundle; not Inter/Roboto |

## Bottom navigation

| Item | Prototype | App | Decision |
|------|-----------|-----|----------|
| Tab 1 | Today | was **Home** | Renamed **Today** |
| Tab 2 | Census | Census | Icons → outlined groups |
| Tab 3 | Rounds | **Scribe** then Rounds | **Keep Scribe** in bar (product: photo/voice intake). Diff intentional. |
| Tab 4 | Tasks (badge) | Rounds | Tasks stay in drawer / patient chart |
| Tab 5 | Learn | Learn | Book outline icon |

## Screen-by-screen

### Today
- Prototype: date above “Good morning, Dr. X.”; circular soft header buttons; Resident Mode pill; dark slate priority card; “Your day” stats.
- App: greeting + name aligned; circular elevated header icons; attention/brief/census still product-specific (no fake acuity ranking).
- Still open: Resident Mode pill (role chip) if product wants it; “Rounds in Xm” chip.

### Census
- Prototype: “TEAM A · N PATIENTS”, My Census, All/Priority/Discharge chips, patient cards with initials + status rail.
- App: census list + reorder + photo/voice intake. Filter chip styling inherits new `chipTheme`. Priority/Discharge filters not ported (would imply urgency ranking — out of safety scope).

### Rounds
- Prototype: live progress, presentation builder, teaching question card.
- App: deterministic day brief + presentation + reminders. Presentation empty-state copy improved in W4. Visual tokens only this pass.

### Note / Evidence / Presentation / Sign-out / Learn / Chat / Profile
- Screenshots not yet provided by client for all of these. Theme tokens apply globally. Drop files into this folder to continue per-screen polish.

## Safety wording (do not change)

- “AI draft · review required”
- “Prompt for your consideration”
- “Not entered”
- “Synthetic team list…” / demo disclaimers
