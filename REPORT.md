# Lab 4 Report

## Topic and change of language

The selected assignment is option B: a mobile currency converter extended with
weekly and monthly analytics. This makes it possible to compare implementations
of a familiar domain on a different platform and in a different language.

Lab 3 used C# and ASP.NET Core. Lab 4 uses Dart and Flutter, targeting **Android
only**, as chosen by the student. The C# source was not opened for porting,
copied, or translated automatically. The models, parser, arithmetic, storage,
and interface were implemented afresh in Dart. The small Kotlin MainActivity
file is Flutter's generated Android entry point; application logic and screens
are written in Dart.

Repository: [CurrencyConverter-Mobile-Lab4](https://github.com/sam4ch/bnm-currency-converter-android).

## Data source and limitations

The app uses the [official BNM XML feed](https://www.bnm.md/en/official_exchange_rates?get_xml=1&date=28.10.2026).
The National Bank of Moldova provides reference rates rather than guaranteed
exchange prices. No API key is required. `Value / Nominal` gives the number of
MDL per unit of a currency; a currency pair's rate is the ratio of its normalized
rates.

History is fetched from the source for individual dates: 7 or 30 calendar days,
including the end date. The monthly chart is available after the first download,
without collecting a month of data after installation. At most three requests
run concurrently, each with a 10-second timeout. On failure, subsequent request
batches stop and available cached dates are used. BNM availability and the time
needed for the first download depend on the network.

Each point stores its observation date and the publication date returned by BNM.
Missing data is not replaced with zero, random values, or interpolation. The
chart does not draw a line across dates with missing points; coverage, such as
6/7 days, is displayed alongside it. Repeated official values may form horizontal
segments. The range of actual publication dates is shown in the UI.

For conversion when no publication is available, the app searches back up to
31 days. A network failure stops this search immediately. Cached data dated
later than a historical request cannot be used. Cached-data mode is clearly
identified.

## Implementation and statistics

There are three screens: converter, weekly comparison, and monthly comparison.
Supported currencies are MDL, EUR, USD, RON, and GBP. The amount must be positive,
no greater than 10^12, and have at most four decimal places; both a dot and a
comma are accepted. Future dates cannot be selected.

Monetary values are represented as rational numbers backed by BigInt. Rounding
occurs when formatting output, with ties rounded away from zero. Double is used
only for chart coordinates. Converting a currency to itself preserves the
entered precision without querying the source.

Statistics are calculated from the displayed observations, sorted by date:

- Minimum and maximum are the lowest and highest observed values.
- Mean is the sum of values divided by the number of available observations.
- Absolute change is the last value minus the first value.
- Percentage change is absolute change / first value × 100.
- Trend is rising, falling, or unchanged, based on the sign of the change.

A single point has zero change. An empty set has no statistics and displays an
option to retry loading. Zero rates are rejected, so a zero percentage
denominator is not replaced with an artificial value.

The persistent cache uses SharedPreferencesAsync with Android DataStore
Preferences. It stores version 1 JSON, dates, fetch timestamps, and exact
numbers. Up to 120 recent requested dates are retained. A bad response does not
replace validated data; a corrupt cache is treated as unavailable data. A write
failure does not discard a successful result and is reported to the user.

## Tools and use of AI

Code, planning, tests, validation, and documentation were created with Codex in
this chat. The exact selected model name was not recorded in the interface and
is therefore not invented here. Antigravity and Copilot were not used for this
lab. The working environment was Codex desktop and PowerShell; builds used
Flutter SDK 3.47.6, Dart 3.13.5, Android SDK/Gradle, and the JDK bundled with
Android Studio. Device validation used Android SDK ADB and a Pixel 5 emulator
running Android 16 API 36.

AI prompts were refined through concrete requirements: a new language without
porting old code; two periods and explicit statistical formulas; injectable
data source and storage for tests; cached data surviving a restart; and device
validation. Generation was followed by code analysis, unit/widget tests, and
real emulator interactions. The requirements and stages used are recorded in
[docs/REQUIREMENTS.md](docs/REQUIREMENTS.md).

## What worked initially and what needed fixing

The parser, exact arithmetic, statistics, and testable source/storage separation
passed the initial set of 73 unit tests. The first debug APK launched on Android
and fetched a real BNM rate.

| Issue | Observation and fix |
| --- | --- |
| Incorrect history-warning condition | Review found an inverted empty-list check: a warning disappeared when a message was present. The condition was corrected; tests cover partial-coverage and source-failure warnings. |
| Analytics row overflow | A widget test at 390×844 found a 17 px RenderFlex overflow. Row was replaced with a wrapping Wrap, and the test passed on rerun. |
| Scroll position when switching tabs | After viewing statistics, the next screen opened at the previous scroll position. A ScrollController now resets the position on tab changes; a widget test verifies this. |
| Chart axis labels overlapped the line | Reviewing an Android screenshot led to reserving a separate left margin for labels. |
| `flutter analyze` fails on Cyrillic paths | An LSP protocol failure in Flutter 3.47.6 is a [known issue](https://github.com/flutter/flutter/issues/191309). Validation uses `dart analyze` without disabling analysis rules. |
| Gradle rejects the local Cyrillic path | The `android.overridePathCheck=true` setting suggested by Gradle itself was added to gradle.properties; the debug APK built successfully. |
| Release AOT cannot read the Cyrillic path | scripts/build-apk.ps1 copies only the current project source into a temporary ASCII-path directory and returns the APK to artifacts. The original project is neither moved nor deleted. The release build succeeded. |

## Working with AI in a new language

In the observed workflow, the calculation logic in Dart did not require a new
way of framing the task: explicit formulas, Nominal > 1 examples, negative
cases, and expected results made it possible to verify the new code
independently of the language. Exactness required an explicit requirement for
rational arithmetic; using ordinary double values for money would introduce
the risk of binary rounding errors.

The mobile environment and interface required more work. Instead of the
server-side Razor Pages lifecycle, the implementation must account for Flutter
widget state, asynchronous updates, scrolling, and phone width. Working
calculations and a successful build did not expose the row overflow; a separate
widget test found it. Android SDK, Gradle, AOT, and Cyrillic paths introduced
configuration work that was not present in the validated .NET run of the
previous lab.

The practical observation is that AI-assisted development skills transfer to a
new language through verifiable requirements, reading errors, and checking the
result in the target environment. In this lab, Android builds and mobile-state
validation were the most difficult parts, while the mathematical contracts
were verified with the same domain examples. This conclusion reflects actual
actions and results; it does not attribute personal feelings or a measured
productivity gain to the student.

## Tests and demonstration

Run `flutter test` from the project root. The original version passed **78
tests**, with no failures or skips: XML/HTTP parsing, Nominal, rounding and
precision, validation, statistics, empty/partial data, offline/cache restart,
protection of valid data, and five widget scenarios. `dart analyze` reported no
issues.

Android validation and actual screenshots are recorded in
[docs/ANDROID_VALIDATION.md](docs/ANDROID_VALIDATION.md). During the lab defense,
the working app must be opened on a device or emulator; screenshots do not
replace a live demonstration.

## UI update — November 4, 2026

At the student's request, the interface gained a dark gradient, mint accents,
a floating 3D illustration, translucent cards, animated heading changes,
a rotating currency-swap button, and a progressively drawn chart. The PNG was
created with the built-in AI image generator; the [full prompt](docs/ASSETS.md)
is saved. Animations use Flutter, while the calculation logic and rate source
remain unchanged.

The background is separated from the form, receives no taps, and is excluded
from screen-reader output. Disabling animations in system settings stops the
decorative movement. Two new widget tests verify motion while conversion
remains usable and a system-setting change while the app is running. The final
result is **80/80 passing tests**, with no `dart analyze` issues.
[Updated Android UI validation](docs/UI_VALIDATION.md) and
[physical-phone setup instructions](docs/PHONE_SETUP.md) are included in the
repository.

## Git

- `b38daf6`: initial Android scaffold and requirements.
- `feature/android-converter`: new implementation; [PR #1](https://github.com/sam4ch/bnm-currency-converter-android/pull/1).
- `tests/android-converter`: unit/widget tests, fixes, build script, and report; [PR #2](https://github.com/sam4ch/bnm-currency-converter-android/pull/2).
- Changes are merged into main through PRs, preserving the history of each stage.
