<p align="center">
  <img src="docs/hindimitra-tile.png" alt="HindiMitra app icon" width="220" />
</p>

<h1 align="center">HindiMitra</h1>

<p align="center">
  <b>Your friend for learning to read and write Hindi.</b><br/>
  हिन्दी पढ़ना और लिखना सीखो — trace letters, read stories, earn rewards.
</p>

<p align="center">
  Flutter · Dart 3.4+ · Android · iOS · Web
</p>

---

HindiMitra (*mitra* = friend) is a Flutter app that teaches the Devanagari script through guided letter
tracing, quizzes, flashcards, story reading and games. It is a Flutter port of the React Native (Expo) app
*Hindi Sikho* and keeps the same "Little Hindi" design: cream `#FCF9EE`, marigold `#EE9A4C`, violet `#6E4EDF`,
solid offset "toy" shadows, and Baloo 2 / Nunito / Tiro Devanagari Hindi fonts. There are five tabs:
Home · Learn (Write + Read) · Practice · Test · Upcoming. Profile and Rewards open from the Home header.

Every launch opens on an India intro (tricolour, Ashoka Chakra, "Made in India · for the world", a few facts about
Hindi). Settings has nine themes (Sunny Day, Starry Night, Tiranga, Web Hero, Night Guardian, Ocean, Jungle, Space,
Candy; defined in `lib/theme/themes.dart`), the app language (English and Hindi, more listed as coming soon), and the
user's name in Hindi with a ⓘ to correct the automatic spelling. All levels are open (`unlockAll` in
`lib/data/models.dart`).

## Features

- **Write**: a letter canvas with 4 stages and stroke grading, Matra practice and quiz, word writing, speed
  challenge, dictation, letter comparison, random drill, conjunct practice.
- **Read**: flashcards, matching quiz, word reading, sentence building, story reading, pronunciation coach,
  picture match, word builder, fill in the blank, Hindi numbers, letter sound quiz, letter pairs, word speed
  reading, rhyming words, odd one out, dialogue reading, vocabulary categories.
- **Progress**: a daily-goal ring, streaks, stars and points, 14 badges with a reveal animation and confetti,
  and a leaderboard.
- **Extras**: reminders and streak alerts, Help & FAQ, parent dashboard, paywall, contact sales.
- **Content**: all JSON data and 245 audio clips from the original project.

## Getting started

```bash
flutter pub get
flutter run                    # device / emulator
flutter run -d chrome          # web
```

Requires Flutter 3.22+ (Dart 3.4+).

### App icon

The icon lives in `assets/images/icon.png` (adaptive foreground: `assets/images/adaptive-icon.png`). After
replacing it, regenerate the platform icons:

```bash
dart run flutter_launcher_icons
```

The web icons and favicon are in `web/icons/` and `web/favicon.png`. The README image is
`docs/hindimitra-tile.png`.

### Run locally as a web app

`flutter run -d web-server` needs the Dart Debug Chrome extension and otherwise stays on a blank page, so for a
quick local run build once and serve the output:

```bash
flutter build web --release
python -m http.server 8765 --directory build/web --bind 127.0.0.1   # open http://127.0.0.1:8765
```

After rebuilding, hard-refresh the page (Ctrl+Shift+R) so the browser doesn't keep the old `main.dart.js`.

### Production web build

```bash
flutter build web --release    # output: build/web (Cloudflare Pages: _headers + _redirects are in web/)
```

### Android extras
`flutter_local_notifications` needs, in `android/app/src/main/AndroidManifest.xml`:
`INTERNET`, `VIBRATE`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM`
plus the plugin's receivers, and in `android/app/build.gradle(.kts)`: `isCoreLibraryDesugaringEnabled = true`
with `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")`. See the plugin README.

### Fonts
Baloo 2, Nunito and Tiro Devanagari Hindi are bundled in `assets/google_fonts/` and preloaded before the first
frame (`Fonts.preload()`), so the app works offline and text never jumps from a fallback font.

### Tests
`flutter test` runs the stroke-grading tests plus `test/layout_overflow_test.dart`, which opens every screen at
320×568, 360×690 and 412×915 with a 1.2× system font and fails on any overflow, and `test/layout_wide_test.dart`,
which does the same at 800×900 and 1280×900.

## Project layout

```
lib/
  main.dart            app + theme switching
  routes.dart          route-name → screen registry, openScreen()
  theme/               palette, spacing/radius, fonts, toy shadows
  store/app_store.dart app state (shared_preferences)
  data/                models + generated reading data
  services/            speech (flutter_tts + audioplayers), haptics, stroke evaluator, notifications, billing catalogue
  widgets/             ToyButton, HeaderBar, StarRating, Confetti, DrawCanvas, quiz widgets, BadgeReveal …
  screens/             onboarding, shell, home, rewards, profile, settings, help, paywall, …
  screens/writing/     Write-tab activities
  screens/reading/     Read-tab activities
web/                   index.html, manifest, icons, Cloudflare _headers/_redirects
assets/                data/*.json, audio/*.mp3, images/*
docs/                  README images
```

## Cloud (Firebase)

The app is local-first: it runs fully offline, and `lib/services/cloud.dart` connects to Firebase when it is
configured (it logs `Cloud: offline (…)` otherwise). To connect a Firebase project:

1. In the [Firebase console](https://console.firebase.google.com), create a project and a Cloud Firestore
   database in **asia-south1 (Mumbai)**, production mode.
2. Sign in and link the project (needs the Firebase CLI, `npm i -g firebase-tools`, and the FlutterFire CLI,
   `dart pub global activate flutterfire_cli`):
   ```bash
   firebase login
   flutterfire configure --project=<your-project-id> --platforms=android,ios,web
   firebase use <your-project-id>
   ```
   `flutterfire configure` replaces the placeholder `lib/firebase_options.dart` with the project's keys.
3. Deploy the security rules (everything is locked until the account rules land):
   `firebase deploy --only firestore:rules`

To try sign-in and backup without a real project, run the local emulators with the demo project, then the
app with `USE_FIREBASE_EMULATOR` (the `flutter-web-emulator` entry in `.claude/launch.json` does the second step):

```bash
firebase emulators:start --project demo-hindimitra --only auth,firestore
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATOR=true
```

The emulators enforce `firestore.rules`; the Emulator UI is at http://127.0.0.1:4000.

## Not included yet

The original app ran on a live Firebase project. HindiMitra currently reproduces its **offline mode** (straight
to Onboarding → student app, the same as "Continue as Guest"). Not included:

* Auth screens (login, sign-up, phone, code login, verify e-mail), Firestore sync, school codes.
* Teacher flow (dashboard, students, assignments, reports, code management, unlock requests) and parent flow
  (add child, family dashboard).
* Consent and data-deletion screens.
* Real billing (RevenueCat / Stripe): the Paywall UI is complete, but "Start subscription" uses a **local mock**
  that just sets `isPremium = true`.
* PostHog analytics, Sentry crash reporting, ML Kit handwriting recognition.
* Contact sales opens a pre-filled e-mail instead of calling a backend.
* Reminder notifications repeat at the chosen time of day in **UTC** terms (no timezone plugin), so the hour
  can drift by one across DST changes.

## Known quirks (kept to match the original)

* Fill-in-the-blank reports the *previous* score on the final result.
* Hindi Numbers quiz re-shuffles its options on every state change and cannot advance past question 10.
* Sentence Build shuffles its tiles once per sentence.
* Story reading's "Back to Stories" returns to the reading view rather than the list.
* Pronunciation Coach scores are simulated.
* Activity-level unlock (`completeActivityLevel`) is never triggered by any screen.
* The Parent Dashboard premium-gate "Upgrade to Premium" button has no action.
* Vocabulary category grid collapses to one column on screens narrower than ~400 px.

## Notes on naming

The Dart package is `hindi_mitra` and the Android/iOS bundle id is `com.hindimitra.app`. Progress is saved
under the storage key `hindi-mitra-store`; data saved under the old key `hindi-sikho-store` is still read on
first launch so it carries over.
