# Lab 4 Requirements

Source: the supplied Lab 4 mobile application assignment (DOCX). Option B, Android only,
Flutter/Dart. Lab 3 used C#. Its source is not reused or translated; the
implementation is written afresh in Dart.

- A new, separate repository. Work in separate branches, merging through PRs.
- MDL/EUR/USD/RON/GBP conversion with an amount, selected date, and currency swapping.
- Separate 7-day and 30-day screens: chart, minimum, maximum, mean, absolute
  and percentage change, and an explicit trend.
- Fetch BNM history by date without waiting a month after installation.
- Persistent cache, offline operation, and restart support; visible data dates.
- Handle network errors and empty/corrupt data without crashing.
- Unit tests for XML, statistics, empty data, and validation, run with one command.
- Run on an Android device/emulator and check behavior without a network connection.
- REPORT.md: topic, language change, source and limitations, IDE/AI/models,
  actual errors/fixes, and a substantive comparison of working with AI in a new
  language. Do not invent the student's personal impressions.

## Stages

1. Android scaffold, new GitHub repository, and initial commit.
2. feature/android-converter: calculations, BNM, cache, UI, and analytics; PR into main.
3. tests/android-converter: tests, Android run, README, and report; PR into main.

## Calculations

Exact BigInt arithmetic; double only for the chart. Value/Nominal gives MDL per
unit, and a pair's rate is source/target. A period includes the end date and the
preceding 6/29 days. Statistics use available points; gaps and coverage are visible.
Change = last value − first value; percentage = change/first value × 100.
One point: zero change. Empty set: no statistics.
The actual publication date is stored separately from the selected date.
Do not fabricate points. A corrupt response must not replace a valid cache.
