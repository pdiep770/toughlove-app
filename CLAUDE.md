# Chalked In — Project Context & Handoff

*Persistent context for Claude Code. This file is duplicated (identical content) at the root of both repos so either one loads full project context automatically. Last verified against actual repo state: 2026-08-31.*

---

## 1. What This Is

**Chalked In** (working name; originally pitched as "Tough Love") is a solo-built fitness coaching + social app. The core hypothesis being tested: **does an adaptive workout plan combined with visible small-group accountability actually keep people training consistently?** Everything is built around testing that with a small group of friends before any wider launch.

Two core mechanics:
1. **Adaptive plan generation** — a rules-based engine builds a personalized workout split, then adjusts weights/reps over time based on logged performance.
2. **Social accountability** — friend connections and real-time chat, so consistency is visible to people who matter to the user, not just tracked privately.

---

## 2. Repos, Branches, and Local Environment — READ THIS FIRST

**Two separate repos, not a monorepo:**
- **Frontend (Flutter):** `github.com/pdiep770/toughlove-app`
- **Backend (Spring Boot):** `github.com/pdiep770/chalked-in-backend`

**⚠️ Critical gotcha: the frontend repo's real branch is `mainline`, not `main`.** GitHub's default branch shows `main`, which contains almost nothing (a stray early commit). All real work lives on `mainline`. If you clone this repo fresh and things look empty, check the branch before assuming something is broken:
```bash
git fetch origin
git checkout mainline
```
This should be cleaned up at some point (`git branch -M main && git push -u origin main`), but hasn't been yet as of this writing. The backend repo's default branch is already `mainline` correctly (no `main` confusion there).

**Local folder naming is inconsistent between machines** (cosmetic, not functional, but worth knowing):
- Windows frontend folder: `~/dev/toughlove_app` (underscore — required, Dart/Flutter package names can't contain hyphens)
- Mac frontend folder: `~/dev/toughlove-app` (hyphenated, matches the GitHub repo name exactly since it was a fresh clone)
- Windows backend folder: `~/dev/backend`
- Mac backend folder: `~/dev/chalked-in-backend` (matches repo name)

**Development happens across two machines** (Windows desktop + Mac). The Mac was added specifically for iOS builds (Xcode/CocoaPods/Simulator), which Windows can't do. Both machines have the full toolchain: Flutter, Java 21, Android SDK, Git. Get in the habit of `git pull` before starting work on whichever machine you're using.

---

## 3. Tech Stack

- **Backend:** Java 21, Spring Boot 4.1.0 (via `spring-boot-starter-parent`), Maven (`./mvnw spring-boot:run` for local dev, `localhost:8080`). **Deployed to Render** (free tier, Docker-based via the repo's `Dockerfile`) at `https://chalked-in-backend.onrender.com` — auto-deploys on every push to `mainline`. `server.port` is a fixed `8080` matching the Dockerfile's `EXPOSE 8080`, not dynamically read from `PORT` — see the Render/Docker/PORT gotcha in section 10 for why.
- **Frontend:** Flutter/Dart, targets iOS + Android + Web from one codebase
- **Database & Auth:** Firebase — Firestore (NoSQL) + Firebase Authentication with real email/password accounts (switched 2026-08-31 from Anonymous Auth — see section 6 and section 8's design-decisions entry)
- **Firebase project ID:** `liftwithfriends-44d7a` (internal project name is a holdover from an earlier app name — cosmetic mismatch with "Chalked In" branding, never fixed, no functional impact)
- **App identifier:** `com.chalkedin.app` for both iOS (`PRODUCT_BUNDLE_IDENTIFIER`) and Android (`applicationId`/`namespace`) — changed 2026-09-01 from the `com.example.*` `flutter create` placeholder, which Apple/Google won't accept for real distribution. This is effectively permanent post-publish (changing it later means starting over as a "new" app in either store). macOS/Windows/Web identifiers were left untouched. Firebase has separate registered Android/iOS apps under this identifier on the same project — see section 6 for how that was regenerated.
- **Real-time features:** Firestore live listeners (`.snapshots()` + Flutter `StreamBuilder`) power the chat feature
- **Testing:** Backend uses JUnit 5 + AssertJ, already available via the test-scoped `spring-boot-starter-webmvc-test`/`spring-boot-starter-validation-test` dependencies in `pom.xml` — no extra dependency setup needed to write more backend tests. Frontend uses `flutter_test` (already in `pubspec.yaml`'s `dev_dependencies`).

---

## 4. Backend Architecture

All files in `src/main/java/com/chalkedin/backend/`. Package declarations must match this exact folder path or you'll get confusing "cannot be resolved to a type" compile errors — this has happened multiple times during development from files landing in `com/chalkedin/` instead of `com/chalkedin/backend/`.

**Core plan generation:**
- `IntakeRequest.java` — DTO for intake form data: `experienceLevel`, `daysPerWeek`, `goal`, `equipmentAccess`, `injuries`, `includeExplosiveTraining`, plus optional `squatOneRepMax`/`benchOneRepMax`/`deadliftOneRepMax`/`overheadPressOneRepMax`
- `Exercise.java` / `WorkoutDay.java` / `WorkoutPlan.java` — nested DTOs representing the generated plan
- `ExerciseLibrary.java` — static exercise data (~85 exercises across chest, back, legs, shoulders, biceps, triceps, abs, calves, plus an explosive/plyometric category), each with `full_gym` / `dumbbells_only` / `bodyweight_only` variants. Exercises are randomly selected per generation (`pickRandom`) for variety. **`pickRandom` now takes an optional `mustInclude` exercise name** (added 2026-08-31, see bug note below) — when set, that exercise is always included first before the remaining slots are filled randomly. Wired into `getChestExercises`/`getBackExercises`/`getLegExercises`/`getShoulderExercises` via 3-arg overloads; the other muscle-group pickers don't need it.
- `PlanGeneratorService.java` — the orchestrator:
  - `determineSplitType`: beginner → full_body, intermediate → upper_lower (≤4 days/week) or push_pull_legs (>4), advanced → push_pull_legs. Only picks the split *archetype* — does not determine day count (see bug note below).
  - `buildDays`: assembles each day's exercises by looping `i` from 1 to `intake.getDaysPerWeek()` and **cycling** through the chosen split's day-type sequence (full_body: every day is "Full Body"; upper_lower: alternates Upper/Lower; push_pull_legs: cycles Push/Pull/Legs) via six small `build*Day` helpers (`buildFullBodyDay`, `buildUpperDay`, `buildLowerDay`, `buildPushDay`, `buildPullDay`, `buildLegDay`), each labeled `"Day " + i + " - <Type>"`. Takes the full `IntakeRequest` (not just `equipmentAccess`) so it can compute `mustIncludeFor(...)` for each of the four tracked lifts and pass it through to the relevant `ExerciseLibrary` pickers on every occurrence of that day type, not just the first.
  - `adjustForGoal`: strength → 4-6 reps/4 sets/scaled weight up ~15%; general_fitness → 12-15 reps/3 sets/scaled down ~20%; hypertrophy uses the library's default 8-12 rep values as-is
  - `applyOneRepMaxScaling`: **only fires when `equipmentAccess == "full_gym"`.** Scales the four tracked lifts to a percentage of the user's entered 1RM: strength 82%, hypertrophy 72%, general_fitness 60% (grounded in NSCA %1RM-by-rep-range research). Scales the *raw entered 1RM* directly — there is no separate seeded "training max" value (see the corrected section 5 below).
  - `addExplosiveTraining`: adds 1-2 plyometric exercises to leg-focused days if the toggle was checked — applies per-day by label match, so it already worked correctly across a cycled schedule without changes.

  **Bug found and fixed 2026-08-31 (#1):** `applyOneRepMaxScaling` only scales an exercise if its name exactly matches `"Barbell Squat"`/`"Barbell Bench Press"`/`"Deadlift"`/`"Overhead Press"`. Exercise selection is otherwise fully random per muscle-group pool (e.g. the full-gym leg pool has 6 exercises, only 3 get picked for a given day) — so entering a squat 1RM used to silently do nothing about half the time, because "Barbell Squat" simply wasn't picked that day. Fixed via the `mustInclude` mechanism above: `buildDays` now forces the tracked lift into the relevant pool's picks whenever its 1RM was provided and `equipmentAccess == "full_gym"`. Covered by regression tests in `PlanGeneratorServiceTest` (`generatePlan_squatOneRepMaxForcesBarbellSquatIntoEveryLegDayAndScalesItsWeight`, run 20x to catch flakiness from the shuffle, checks both leg-day occurrences in a 6-day cycle since bug #2 below).

  **Bug found and fixed 2026-08-31 (#2), reported directly by the developer while using the app ("selecting 5 days only creates a 3 day plan"):** `buildDays` used to hardcode a fixed day count per split archetype — always exactly 3 for full_body, 2 for upper_lower, 3 for push_pull_legs — completely ignoring `daysPerWeek` except as the threshold inside `determineSplitType` for picking upper_lower vs push_pull_legs. So e.g. an advanced user selecting 5 or 6 days/week always got exactly 3 days (Push/Pull/Legs once), and an intermediate user selecting 3 days/week with upper_lower always got exactly 2. Fixed by rewriting `buildDays` to loop `daysPerWeek` times and cycle through the split's day-type pattern (see above) — a 6-day advanced plan now correctly produces Push/Pull/Legs/Push/Pull/Legs, a 4-day intermediate upper_lower plan produces Upper/Lower/Upper/Lower, etc. Verified both via the new `PlanGeneratorServiceTest` coverage (`generatePlan_dayCountAlwaysMatchesDaysPerWeek` parameterized across every experience level × 3-6 days, plus renamed/expanded cycling-specific tests) and directly via `curl` against `/api/generate-plan` with `daysPerWeek: 5`, confirming 5 days come back. **This was a significant correctness bug in the core adaptive-plan-generation feature** — worth being extra alert for similar "the number the user picked doesn't actually control what gets generated" mismatches elsewhere (e.g. double-check nothing else silently ignores `daysPerWeek`, `goal`, or `equipmentAccess` in a similar way).

**Logging & adaptive adjustment:**
- `ExerciseLog.java` — one logged exercise's actual performance (`exerciseName`, `sets`, `repsLow`, `repsHigh`, `weight`, `feltRating`: "easy"/"moderate"/"hard"/"failed")
- `WorkoutLogRequest.java` (`dayLabel`, `goal`, `List<ExerciseLog> exercises`) / `WorkoutLogResponse.java` (`List<AdjustmentResult> results`) / `AdjustmentResult.java` (`updatedExercise`, `explanation`) — request/response DTOs
- `AdjustmentService.java` — the core logic. **This is simpler than originally designed** (see corrected section 5): it adjusts each logged exercise's weight/reps based on the feel rating, goal-differentiated:
  - "easy" + bodyweight (weight == 0): +2 reps to both bounds
  - "easy" + weighted + strength goal: fixed increment (+10 lbs lower-body lifts, +5 lbs upper-body) rather than a percentage jump, since percentage-based progression at heavy strength loads moves too fast
  - "easy" + weighted + non-strength goal: weight × 1.05, rounded to nearest 0.5
  - "moderate" / "hard": no change, just an explanation string
  - "failed" + bodyweight: −2 reps, floor of 3
  - "failed" + weighted: weight × 0.9, rounded to nearest 0.5
  - It has **no concept of "training max"** — it never reads or writes `TrainingMaxes`, and treats the four tracked lifts no differently from any other exercise except for the lower/upper-body increment split under a strength goal.

**Periodization engine (backend-only, not yet wired to any frontend):**
- `Phase.java` (`name`, `durationWeeks`, `startPercentage`, `endPercentage`), `TrainingProgram.java` (`startDate`, `List<Phase>`), `TrainingMaxes.java` (`squat`/`bench`/`deadlift`/`overheadPress`), `ProgramWeekResult.java`, `ProgramStatusRequest.java` (`program`, `trainingMaxes`)
- `ProgramCalculationService.java` — given a program's phases and a start date, calculates which phase/week you're currently in (based on elapsed calendar time via `LocalDate.now()`) and computes each tracked lift's weight as `trainingMax × currentPhasePercentage`, linearly interpolated across the phase. Past the end of the last phase, holds at that phase's end percentage and marks `programComplete: true`.
- Exposed at `POST /api/program-status`. Covered by `ProgramCalculationServiceTest` (7 tests: first/last week of a phase, phase transitions, past-program-end hold, single-week phase, weight computation/rounding, missing training maxes). **This is the only place `TrainingMaxes` is actually used anywhere in the codebase** — it's an input the caller must supply, not something the app computes or persists on its own.
- User explicitly said "no rush" on building the UI for this. User wants **flexible, user-defined phases** (not a fixed 2- or 3-phase template) when this eventually gets built.

**Controller:**
- `TestController.java` exposes: `GET /api/hello` (health check), `POST /api/generate-plan`, `POST /api/log-workout`, `POST /api/program-status`
- `CorsConfig.java` — permissive CORS (`allowedOrigins("*")`) so the Flutter web build (random localhost port) can call the backend on port 8080. **Too permissive for production** — needs locking down to the real app domain before any public launch.

**Tests:** `src/test/java/com/chalkedin/backend/` — `PlanGeneratorServiceTest` (16 tests: split selection, goal-based rep/set/weight adjustment, 1RM scaling + the mustInclude regression, explosive training placement), `AdjustmentServiceTest` (9 tests: every feel-rating × bodyweight/weighted × goal combination), `ProgramCalculationServiceTest` (7 tests, see above). All added 2026-08-31 as the first real test coverage the backend has had — previously only the default Spring Boot `BackendApplicationTests.contextLoads()` placeholder existed. **Going forward, pair new backend logic with tests in the same pass rather than as a follow-up.**

---

## 5. Training Max System — DESIGN INTENTION ONLY, NEVER BUILT (important correction)

An earlier version of this document described a "training max" mechanism as if it existed: seed a training max at 90% of a user's entered 1RM at intake, scale day-to-day plan weight off that training max rather than the raw 1RM, and have logging nudge the training max over time (+10/+5 lbs on "easy", ×0.9 on "failed"), flowing into future plan generations — the same safety-buffer pattern real percentage-based programs like 5/3/1 use.

**Verified 2026-08-31 by reading the actual code: none of this exists, on either the backend or the frontend.**
- `PlanGeneratorService.applyOneRepMaxScaling` scales the four tracked lifts directly off the **raw 1RM entered at intake** — there's no separate 90%-seeded value anywhere.
- `AdjustmentService.processLog` has no connection to `TrainingMaxes` at all (see section 4).
- `TrainingMaxes.java` exists solely as an input DTO for the unrelated periodization engine (`/api/program-status`) — a caller has to supply it; nothing computes or persists it.
- The frontend has no Firestore field for `trainingMaxes` and no code that reads or writes one.

If this system gets built for real, it would need: (1) seeding logic in `PlanGeneratorService` or a new endpoint, (2) `AdjustmentService` updated to special-case the four tracked lifts and return an updated training max alongside the per-exercise adjustment, (3) frontend Firestore read/write for a `trainingMaxes` field on the user doc, (4) `PlanGeneratorService.applyOneRepMaxScaling` changed to scale off the stored training max instead of the raw entered 1RM. None of this is scheduled — decide deliberately whether it's worth building or whether the simpler direct-1RM-scaling + flat-increment-adjustment system already in place is good enough for the friend test.

---

## 6. Frontend Architecture

All files in `lib/`.

**App entry & auth:**
- **Auth model changed 2026-08-31: real email/password accounts, not anonymous.** Originally the app used Firebase Anonymous Auth (silent, no login screen — a stable UID per device). Since each friend-test participant uses their own device, and anonymous auth has no way to recover an account if local data is ever cleared, switched to real Firebase email/password accounts instead. `main.dart` no longer calls `signInAnonymously()` — it just initializes Firebase and renders `StartupScreen`, which now gates everything behind auth state.
- `auth_screen.dart` — **new 2026-08-31.** Combined sign-up/log-in screen (a single `_isSignUp` toggle switches the button/copy between modes) with email + password fields, calling `FirebaseAuth.instance.createUserWithEmailAndPassword` or `signInWithEmailAndPassword`. Shows `FirebaseAuthException.message` inline on failure. Doesn't navigate directly on success — `StartupScreen`'s `authStateChanges()` stream picks up the new signed-in state and reroutes automatically.
- `startup_screen.dart` — now two layers. The outer `StartupScreen` is a `StreamBuilder<User?>` on `FirebaseAuth.instance.authStateChanges()`: no signed-in user → `AuthScreen`; signed in → `_ProfileRouter` (private `StatefulWidget`, same file). `_ProfileRouter` holds the profile/plan-resume logic: checks `UserProfileService.getProfile()` — no profile → `ProfileSetupScreen`; profile but no `currentPlan` → `IntakeScreen`; profile with a `currentPlan` → parses it and goes to **`HomeScreen`** (added 2026-09-01, see below — this replaced going straight to `PlanScreen`, which is how the original resume gap got fixed as a side effect of the auth restructuring).
- `home_screen.dart` — **new 2026-09-01.** The landing point for a returning signed-in user who already has a plan: shows a summary card (`splitType` + day count) and two actions — "View My Plan" (pushes `PlanScreen`, back arrow returns here) and "Generate New Plan" (confirmation dialog since it replaces the current plan, then pushes `IntakeScreen`). Also carries the Friends/Logout icons so it works as a real hub, not just Plan. First-time plan generation deliberately does **not** route through here — `IntakeScreen` still goes straight to the newly generated `PlanScreen` on first submit (instant gratification); Home only appears on return visits once a plan already exists. `IntakeScreen`'s post-generate navigation changed from `Navigator.push` to `Navigator.pushReplacement` so that generating a new plan *from* Home lands cleanly on the new plan with back going to Home, rather than leaving a stale filled-out form in the stack.
- `user_profile_service.dart` — generates a random 6-character friend code, creates/reads the user's profile doc. Unchanged by the auth switch — it already worked off `FirebaseAuth.instance.currentUser?.uid`, which now just happens to be a real account's UID instead of an anonymous one.
- `profile_setup_screen.dart` — simple display-name entry, first screen a new (now real-account) user sees after signing up. Unchanged.
- **Sign-out:** `plan_screen.dart` has a logout `IconButton` in the app bar next to Friends. Calls `FirebaseAuth.instance.signOut()` then `Navigator.of(context).popUntil((route) => route.isFirst)` to pop back to the root route — necessary because `PlanScreen` is pushed on top of `StartupScreen` in the navigator stack, so signing out alone wouldn't visually return to `AuthScreen` without also popping back to root.
- **Manual setup required:** Email/Password sign-in must be enabled in the Firebase console (Authentication → Sign-in method → Email/Password → Enable) for account creation/login to work at all. Not something that can be verified or toggled from code.

**Core flow:**
- `intake_screen.dart` — the main form (experience/days/goal/equipment/injuries/explosive-training toggle). 1RM fields only render conditionally (`intermediate`/`advanced` experience + `full_gym` equipment). Submits to `/api/generate-plan`, saves via `FirestoreService.saveIntakeAndPlan`, navigates to `PlanScreen(plan: plan, goal: _goal!)`.
- `workout_plan.dart` / `workout_day.dart` / `exercise.dart` / `adjustment_result.dart` — Dart model classes mirroring the backend DTOs, each with a `fromJson` factory. `adjustment_result.dart` added 2026-08-31 to mirror the backend's `AdjustmentResult` (`updatedExercise`, `explanation`).
- `plan_screen.dart` — displays the generated plan. **Converted to `StatefulWidget` 2026-08-31** (was `StatelessWidget`) so it can hold a mutable `_days` list and reflect updates after logging a workout. Now requires a `goal` constructor param (threaded from `intake_screen.dart`) since the backend's adjustment logic needs it. Has a Friends icon in the app bar and a "Log this workout" button per day; tapping it pushes `WorkoutLogScreen` and, on return, replaces that day's exercises in `_days` with the updated ones via `setState`.
- `workout_log_screen.dart` — **new 2026-08-31**, the workout-logging screen that didn't exist before. Two-phase UI in one `StatefulWidget`: an input phase (per-exercise weight `TextField` pre-filled with the planned weight, plus Easy/Moderate/Hard/Couldn't-finish `ChoiceChip`s defaulting to "moderate") and, after submit, a results phase showing each exercise's explanation text and updated sets/reps/weight. On successful submit it POSTs to `/api/log-workout`, then calls `FirestoreService.saveWorkoutLog` (writes a `logs` entry) and `FirestoreService.updateDayExercises` (updates `currentPlan.days` in place) before showing results. Tapping "Done" pops back to `PlanScreen` with the updated `WorkoutDay` as the navigation result.
- `firestore_service.dart` — central Firestore read/write logic: `saveIntakeAndPlan` (uses `merge: true`), and **new 2026-08-31**: `saveWorkoutLog` (adds a doc to `users/{uid}/logs`) and `updateDayExercises` (reads `currentPlan`, replaces the matching day's exercises by `dayLabel`, writes back with `merge: true`). No training-max methods exist — see section 5, that system was never designed into the frontend either.

**Social layer:**
- `friend_service.dart` — send/accept/decline friend requests by code, fetch friends list. Uses `arrayUnion` to add each user to the other's `friends` array on acceptance.
- `friends_screen.dart` — own code display, add-by-code input, pending requests, friends list (tap a friend to open chat)
- `chat_service.dart` — deterministic conversation IDs (sorted UID pair joined with `_`), real-time messages via `.snapshots()` streams
- `chat_screen.dart` — live chat UI using `StreamBuilder`

**A recurring bug pattern worth knowing about:** throughout development, files were repeatedly "created" in conversation but didn't actually save (0-byte files) or landed in the wrong folder. Always verify with `ls -la` before assuming new code compiles or exists — this has cost real debugging time more than once. This is also why an earlier version of this doc incorrectly described the workout-logging frontend as "built but unverified" — it turned out to never have been started; the frontend genuinely hadn't gotten much attention yet as of 2026-08-31 (confirmed directly with the developer, not just inferred from missing files).

**Tests:** `test/adjustment_result_test.dart` (2 tests, added 2026-08-31) covers `AdjustmentResult.fromJson` parsing for both weighted and bodyweight exercises. The default-template `test/widget_test.dart` (asserted on a counter UI that hadn't existed since before this session — the real home screen is `StartupScreen`) was deleted 2026-08-31 after actually running `flutter test` for the first time and confirming it failed for exactly that reason; it provided no real coverage. Screen-level testing (the `WorkoutLogScreen`/`PlanScreen`/`AuthScreen` flows) would need HTTP-client and Firebase-auth/Firestore mocking infrastructure that isn't set up in this project yet (e.g. `mocktail`, `firebase_auth_mocks`, `fake_cloud_firestore`) — worth adding if deeper frontend test coverage becomes a priority.

---

## 7. Firestore Data Model

```
users/{uid}
  experienceLevel, daysPerWeek, goal, equipmentAccess, injuries, createdAt
  displayName, friendCode, friends: [uid, uid, ...]
  currentPlan: { splitType, days: [{ dayLabel, exercises: [{name, sets, repsLow, repsHigh, weight}, ...] }] }

users/{uid}/logs/{logId}
  dayLabel, loggedAt, exercises: [{name, sets, repsLow, repsHigh, weight}, ...]

friendRequests/{requestId}
  fromUid, fromDisplayName, toUid, status ("pending"/"accepted"/"declined"), createdAt

conversations/{conversationId}       // id = sorted UIDs joined with "_"
  participants: [uid, uid], createdAt, lastMessage, lastMessageAt

conversations/{conversationId}/messages/{messageId}
  senderUid, text, sentAt
```

**No `trainingMaxes` field exists anywhere** — see section 5's correction.

**Important:** all Firestore writes to the user doc use `SetOptions(merge: true)`, including the new `updateDayExercises` method. Without this, later writes silently wipe out earlier fields (e.g. `displayName`, `friendCode`) — this was a real bug caught and fixed during development. Keep using `merge: true` for any new fields added to the user doc.

---

## 8. Key Design Decisions (with reasoning, so they aren't re-litigated or accidentally reversed)

- **Rep ranges and 1RM percentages are grounded in NSCA training-load research**, not guessed: strength 1-5 reps/85-100% 1RM, hypertrophy 6-12 reps/67-85%, endurance 15+/under 67%. App's specific values: strength 4-6 reps @ 82%, hypertrophy 8-12 @ 72%, general fitness 12-15 @ 60%.
- **Gender is deliberately NOT collected or used as an input.** Real sex-based strength differences are well documented (upper-body differences are larger than lower-body differences, on average), but once a real 1RM exists, it already encodes the individual's actual strength — a far more precise signal than a demographic average. Gender was considered only as a *hypothetical* fallback for users with no known 1RM, and ultimately not implemented at all.
- **Explosive/plyometric training is a generic opt-in toggle**, not tied to any specific sport (originally proposed for volleyball players specifically, generalized on request). Added to leg-focused days only.
- **Streaks are deferred to after the friend test.** When built, the design is confirmed: a streak between two friends stays alive if **either** a logged workout **or** a chat message happens that day (not requiring both, unlike literal Snapchat streaks) — chosen specifically so streaks don't strictly depend on the logging feature and don't unfairly break on a planned rest day.
- **Wearable integration (Apple Watch/Garmin/Oura) is deferred to after the friend test.** Reasoning: each is a separate SDK/developer program with no shared code, and wearables don't reliably auto-capture structured strength training data anyway — better to revisit once logging exists and the core concept is validated with real users.
- **Visual design pass done 2026-08-31** (originally deferred until core features were done — logging + auth were both solid by this point, and seeing the live app with default theming prompted doing it now rather than waiting further). Central `ThemeData` in `main.dart`: `ColorScheme.fromSeed` with an "ember" orange-red seed (`0xFFE8552E`, replacing the leftover `deepPurple` from `flutter create`), light + dark variants via `ThemeMode.system`, custom component themes for `AppBar`/`Card`/`ElevatedButton`/`TextField`/`Chip` so every screen inherits a consistent look automatically. Also hand-touched: `auth_screen.dart` and `profile_setup_screen.dart` got a centered branded layout with an icon + headline; `plan_screen.dart`'s exercise rows got a name + sets/reps/weight badge layout with a per-split-type icon; `friends_screen.dart`'s friend code became a highlighted badge; `chat_screen.dart`'s message bubbles were switched from hardcoded `Colors.deepPurple`/`grey[300]` to theme colors (`colorScheme.primary`/`surfaceContainerHighest`) so they actually respect the new theme and dark mode. `intake_screen.dart`'s long flat form was grouped into three `Card` sections ("Your training" / "Known 1-rep maxes" / "Anything else") for readability. As a side effect of touching `intake_screen.dart`, also fixed the pre-existing `avoid_print` and deprecated-`value:`-on-`DropdownButtonFormField` lint warnings — `flutter analyze` is fully clean (0 issues) for the first time this session.
- **Unit tests are now a deliberate habit, not an afterthought** (established 2026-08-31, after discovering the backend had zero real coverage). Pair tests with new non-trivial logic in the same pass, in both repos.
- **Switched from Anonymous Auth to real email/password accounts** (2026-08-31). Anonymous auth only persisted identity locally on one device with no way to recover it — fine in theory, but every friend-test participant uses their own device long-term, and losing local storage (reinstall, cleared browser data, new phone) would mean losing access to their account permanently with no recourse. Real accounts cost a small amount of signup friction but make the account actually recoverable. Considered account-linking (keep anonymous-first UX, let people optionally attach a credential later) as a lower-friction alternative but went with a clean replacement instead for simplicity.

---

## 9. Testing Methodology (how this project actually gets verified — use this, don't reinvent it)

Established through this project's development; use these approaches rather than defaulting to something else (like introducing browser-automation tooling — Playwright/chromium-cli are not part of this project's workflow).

- **Backend logic in isolation**, before wiring up the frontend or when debugging backend-only behavior:
  ```bash
  curl -X POST http://localhost:8080/api/generate-plan \
    -H "Content-Type: application/json" \
    -d '{"experienceLevel":"advanced", ...}'
  ```
  Pipe through `python -m json.tool` when the raw output is too dense to read. Lets you verify split logic, 1RM scaling, and adjustment math directly against real JSON responses without clicking through the UI each time.

- **Backend compiles/runs cleanly:**
  ```bash
  ./mvnw spring-boot:run
  ```
  Watch for "Started BackendApplication" in the logs before testing anything downstream. (`./mvnw compile` alone is faster for a pure compile check; the test suite runs via `./mvnw test` — see section 4 for what's covered.)

- **Frontend, manual click-through** — the default way to verify UI changes on this project:
  ```bash
  flutter run
  ```
  Pick a target (Chrome, Windows desktop, Android emulator, or iOS simulator depending on the machine), then actually fill out the form/tap the buttons and watch the terminal for print statements or errors. Use `R` (capital, hot restart) rather than `r` (hot reload) whenever changes touch `main.dart` or anything at startup — hot reload doesn't reliably pick those up.

- **Firestore — never trust "should have worked," always check the real data.** Open the actual Firebase Console → Firestore Database and look at what landed in the `users` collection, confirming fields are actually there. This is exactly how the missing-`merge: true` bug (section 7) got caught.

- **Multi-user features specifically (friends, chat):** run two separate browser identities side by side — a regular Chrome window plus an Incognito window — since each gets its own independent anonymous Firebase Auth UID. Simulates two different people sending friend requests or chatting in real time and lets you watch both sides update live.

- **File integrity, before assuming anything would even compile:**
  ```bash
  ls -la path/to/file.java
  ```
  Given how many times a file got "created" in conversation but landed empty or in the wrong folder (see section 6), checking byte size and location first saves a lot of confused debugging later.

- **When something gets persistently, weirdly stuck:**
  ```bash
  flutter clean && flutter pub get && flutter run
  ```
  Full clean rebuild to rule out stale build cache before assuming the code itself is wrong.

---

## 10. Current Status (as of 2026-09-01)

**✅ Built and confirmed working end-to-end (all committed and pushed to `mainline` in both repos):**
- Intake → plan generation → Firestore persistence, **with day count now correctly matching `daysPerWeek`** (cycles the split pattern — see the bug fix in section 4; previously always produced a fixed 2-3 days regardless of selection)
- Real email/password accounts — sign up, profile setup, sign out, log back in, all manually click-tested and confirmed working
- Exercise library (expanded, randomized, goal-aware)
- 1RM percentage scaling (full_gym + intermediate/advanced only) — correctly forces the tracked lift into the plan (mustInclude fix, section 4)
- Explosive/plyometric training toggle
- User profiles + friend codes, friend requests, real-time chat
- Workout logging, full loop, manually click-tested in Chrome
- **Home screen for returning users** (section 6, `home_screen.dart`) — manually confirmed working: View My Plan / Generate New Plan flow, back-navigation, and the first-time-generation-skips-Home behavior
- **Visual design pass** — ember theme, per-screen polish, confirmed rendering correctly via an actual iOS Simulator screenshot (not just `flutter analyze`)
- **Real app identifiers** (`com.chalkedin.app` for iOS + Android, section 3) — verified via successful `flutter build apk`/`flutter build ios --simulator` and a working install+launch on the simulator with Firebase initializing correctly
- **Backend deployed and live** at `https://chalked-in-backend.onrender.com` (Render, free tier, Docker-based — see section 3/`Dockerfile`). Frontend's `api_config.dart` points at it. Verified with both `/api/hello` and a real `/api/generate-plan` call returning a correct 5-day cycling plan. Free tier spins down after ~15 min idle; first request after that can take 30-60s to wake — expected, not a bug.

**🟡 In progress:**
- **Apple Developer Program enrollment** — user chose to enroll ($99/year, at developer.apple.com/programs, individual account) specifically to get TestFlight distribution for the friend test. Started 2026-09-01; Apple's approval can take anywhere from minutes to a couple of days. Once approved: create the App Store Connect record for `com.chalkedin.app`, set up a TestFlight internal/external testing group, invite friends by email.
- **Android distribution** — no account needed for the basics: `flutter build apk` produces an installable file friends can sideload directly. Not yet actually built/shared. A Play Console account ($25 one-time) is only needed for Play Store-style install links instead of a raw file.

**⏸️ Backend complete, no frontend UI:**
- Periodization/program engine (`/api/program-status`). Explicitly on hold — user wants flexible custom-phase support when it's eventually built. See section 5 on whether the "training max" concept it depends on is worth building out at all.

**⬜ Not started:**
- Injuries-based exercise exclusion (the `injuries` field is collected but never used in generation logic)
- Streaks, wearable integration (both explicitly deferred to after the friend test)
- CORS is still `allowedOrigins("*")` — fine for the friend test, worth tightening to the real app's origin(s) before any wider/public launch
- Play Console setup, privacy policy (pre-launch prep)
- The actual friend test (the whole point of the project so far)

**Known gotcha (iOS Simulator + Keychain):** installing a build via `xcrun simctl install`/`launch` after building with `flutter build ios --simulator --no-codesign` can produce a Keychain access error specifically when Firebase Auth tries to read an existing signed-in session (login fails; fresh sign-up can look fine since it doesn't need to *read* a prior session). Root cause: Firebase Auth's iOS SDK needs a properly resolved keychain-access-group entitlement, which an unsigned build doesn't reliably get. Fix: drop `--no-codesign` (plain `flutter build ios --simulator`, or just `flutter run`, handles simulator signing correctly) and reinstall.

**Known gotcha (Render + Docker + PORT), fixed 2026-09-01:** the first deploy attempt built and started cleanly (logs showed `Started BackendApplication`, no errors) but was completely unreachable — every request got `x-render-routing: no-server` from Render's edge, not an app-level 404. Root cause: `server.port` was set to `${PORT:8080}`, dynamically honoring whatever `PORT` Render injected at runtime (observed as `10000` in the logs) — but Render's routing layer for this Docker service targets the port declared via the Dockerfile's `EXPOSE` line (`8080`), not whatever the app happens to bind to. The app and Render's proxy were listening/routing on two different ports. Fix: pinned `server.port=8080` (a fixed value matching `EXPOSE 8080`) instead of dynamically reading `PORT` — don't reintroduce dynamic PORT-reading for this service without also confirming it against Render's actual routing behavior, since it silently produces a "successfully running but totally unreachable" state that looks nothing like a normal crash.

---

## 11. Suggested Immediate Next Steps

1. Once Apple Developer Program enrollment is approved: set up App Store Connect + TestFlight for `com.chalkedin.app`, invite friends.
2. Build and share an Android APK directly (`flutter build apk`) whenever ready — no account/approval wait needed, could happen before step 1 finishes.
3. Decide deliberately whether the training-max system (section 5) is worth building for real, or whether direct-1RM-scaling + flat-increment logging adjustment is good enough for the friend test.
4. Pre-launch prep once the above are done: Play Console setup, privacy policy, tighten CORS → real friend test with 4-6 people over 2-4 weeks.
6. Periodization UI, streaks, and wearables are all real but explicitly *not* urgent — don't let them pull focus from getting to the friend test.
