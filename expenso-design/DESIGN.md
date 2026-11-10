# Expenso — design handoff for Flutter

The `screens/` folder holds the approved mockups as HTML source (one file per screen).
Read them for layout, copy, sizes and colours. They are a reference, not code to port line by line.
Build in Flutter (Android + iOS), fully offline. The PRD (`PRD.md`) has the rules for every number.

## Screens (file → Flutter screen)
| File | Screen |
|---|---|
| Main.dc.html | Splash: "Expenso" centred on a black→#282828 gradient, "Get started" white pill |
| Welcome.dc.html | First-time setup: salary, Daily expenses (locked), other items, totals, "Save and continue" |
| Home.dc.html | Today card (remaining, limit, spent, progress), This month card, entry list, + FAB |
| AddEntry.dc.html | Amount + in-app keypad, Debit/Credit toggle, category chips, date, note, Save (disabled at 0) |
| Calendar.dc.html | Month grid, green/red day tints with +/− amount, tap a day → detail panel |
| Stats.dc.html | Saved this month, credit vs debit, salary used, category bars, daily trend with limit line |
| Budget.dc.html | Salary, item list (Daily expenses pinned), summary, Save → "This month / Next month" sheet → toast |
| Settings.dc.html | Export / import, app lock switch, light/dark toggle |

Bottom nav on Home, Calendar, Stats, Budget, Settings. Home opens by default after setup.

## Design tokens
- Font: Inter (400 body, 500 buttons/labels, 700 numbers and titles). Letter-spacing 0.
- Colours: primary #000000 · text secondary #545454 · muted #757575 · placeholder #AFAFAF
  · surface #FFFFFF / #F6F6F6 / #EEEEEE · border #E2E2E2
  · success #276B45 (tint #E3EFE7) · error #C62828 (tint #FBE6E6)
- Green/red only mean within/over limit or saved/overspent. Always pair with + / − or ✓ / !.
- Radius: buttons, chips, toggles 999 (pill) · cards 16 · calendar cells 12 · inputs 0 (square).
- Spacing: 4, 6, 8, 12, 16, 20, 24, 32. Screen side padding 20.
- Cards are flat (no shadow). Only the FAB and toasts get `0 2px 8px rgba(0,0,0,.16)`.
- Money: ₹ with Indian grouping (₹1,12,739). Paise only for the daily limit (₹333.33).
- Touch targets ≥ 44 px. Phone frame reference: 390 × 844.
- Dark theme: not drawn yet — invert surfaces (#000000 / #1A1A1A / #282828), keep semantics.
