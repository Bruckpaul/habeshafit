# HabeshaFit 💪

A personal workout tracker built with Flutter for the Habesha community. Plan your split, open the app, and it tells you what to train today.

## ✨ Features (phase 1)

- **Today's workout**: the Home screen works out today's session from your active routine.
  - *Fixed weekdays*: each day is pinned to weekdays (Mon = Upper A, Tue = Lower A…).
  - *Rotation*: days run in a cycle with optional rest slots; a missed day waits for you.
  - Skip today or swap to another day.
- **Routine builder**: days, exercises, sets, rep ranges, rest time, target weight and notes, with drag-to-reorder. Starter templates: Upper/Lower, Push/Pull/Legs, Full body.
- **Exercise library**: 876 exercises with demo images, muscles, equipment and step-by-step instructions, plus your own custom exercises.
- **Live workout**: each set shows what you lifted last time; ticking an empty set copies it. Includes a rest timer (−15/+15/skip), warm-up/drop/failure sets, a progression hint, and personal-record detection.
- **Empty workout**: start immediately, add exercises as you go, save it as a routine afterwards.
- **Progress**: workouts per week vs target, sets per muscle, per-exercise estimated 1RM charts, body weight and measurements.
- **History**: every workout, editable afterwards.
- **Offline-first**: all data is stored on the device (sembast: a file on mobile, IndexedDB on web). A workout in progress survives the app closing.
- **Notifications** (Android/iOS): rest-timer alert even with the app closed, an optional daily "today's workout" reminder on training days, and your coach's reminders scheduled on the phone.
- **Coaching** (premium, local for now): approved training centers, coach profiles and directory, client programs, goal board, meal plans, reminders and workout feedback.
- **Backup**: export and restore all data, including coaching, as JSON.
- Light, dark and system themes; kg or lb.

## 🚀 Tech stack

- **Flutter** (Dart 3)
- **Provider** for state (`lib/state/app_state.dart`)
- **go_router** for navigation
- **sembast / sembast_web** for local storage (`lib/data/repository.dart`)
- **fl_chart** for charts
- **cached_network_image** for exercise images

## 🗂️ Project layout

```
lib/
  data/        local database + repository (JSON documents)
  logic/       pure logic: today's plan (schedule.dart), stats/PRs, templates
  models/      Exercise, Routine, WorkoutSession, UserProfile, Measurement
  state/       AppState (ChangeNotifier)
  screens/     UI screens
  widgets/     shared widgets, workout editor
assets/exercises.json   exercise library (free-exercise-db, public domain)
test/          unit tests for schedule, stats and state
```

## 🛠️ How to run

```bash
flutter pub get
flutter run            # Android/iOS device or emulator
flutter run -d chrome  # web
flutter test
```

## Group members

1. Bersabeh Dawit
2. Biruk Takele
3. Bruck Paulos
4. Filimon Assesfa
5. Girum Tadesse

## Credits

Exercise data and images: [free-exercise-db](https://github.com/yuhonas/free-exercise-db) by yuhonas, released under The Unlicense.
