# Expenso

Offline expense tracking for Android and iOS. Know every day if you're on track.

Built in Flutter from the approved mockups in [`expenso-design/screens/`](expenso-design/screens).
All data lives on the phone in Hive — there is no network code anywhere in the app.

## Run it

```bash
flutter pub get
flutter run                      # attached device
flutter run -d linux             # desktop preview, sized to the 390x844 phone frame
```

## Build an APK

```bash
flutter build apk --release --split-per-abi
```

`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (~19 MB) is the one
for a modern phone. It is signed with debug keys: fine for sideloading, not
for the Play Store.

## Screens

| Screen | Mockup |
|---|---|
| Splash | `Main.dc.html` |
| First-time setup | `Welcome.dc.html` |
| Home — today, this month, entries | `Home.dc.html` |
| Add entry — in-app keypad | `AddEntry.dc.html` |
| Calendar — day tints, day detail | `Calendar.dc.html` |
| Stats — categories, daily trend | `Stats.dc.html` |
| Budget — apply from this/next month | `Budget.dc.html` |
| Settings — export, app lock, theme | `Settings.dc.html` |

The lock screen has no mockup; it is built from the splash.

## How the numbers work

`PRD.md` was never delivered with the designs, so every rule was recovered from
the mockups' own logic and pinned by tests in
[`test/mockup_parity_test.dart`](test/mockup_parity_test.dart).

| Quantity | Rule |
|---|---|
| Daily limit | `dailyExpensesBudget / daysInMonth` → ₹333.33 in a 30-day month |
| Remaining today | `limit − today's Daily-expenses debits` |
| Saved | `salary − debits` — credits are **not** added back, matching the mockups |
| Day tint | green within limit, red over, outlined when nothing is logged |
| Planned savings | `salary − sum(budget items)` |

Money is stored as integer paise throughout; rupees are a display concern only.

Each month keeps its own budget snapshot, so editing the budget never changes a
past month's colours or stats.

## Layout

```
lib/
  core/      design tokens, typography, money and date formatting
  data/      Hive models, hand-written adapters, repositories, services
  domain/    month summary, keypad input, backup format
  state/     AppState (ChangeNotifier)
  ui/        widgets/ and screens/
```

## Tests

```bash
flutter test                                  # 103 tests
flutter test test/golden --update-goldens     # refresh the screen images
```

Golden images render each screen at the mockups' own dimensions with real
Inter, and live in `test/golden/images/`.
