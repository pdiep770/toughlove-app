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

- **Backend:** Java 21, Spring Boot 4.1.0 (via `spring-boot-starter-parent`), Maven (`./mvnw spring-boot:run`, runs on `localhost:8080`)
- **Frontend:** Flutter/Dart, targets iOS + Android + Web from one codebase
- **Database & Auth:** Firebase — Firestore (NoSQL) + Firebase Authentication with real email/password accounts (switched 2026-08-31 from Anonymous Auth — see section 6 and section 8's design-decisions entry)
- **Firebase project ID:** `liftwithfriends-44d7a` (internal project name is a holdover from an earlier app name — cosmetic mismatch with "Chalked In" branding, never fixed, no functional impact)
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
  - `determineSplitType`: beginner → full_body (3 days), intermediate → upper_lower or push_pull_legs depending on days/week, advanced → push_pull_legs
  - `buildDays`: assembles each day's exercises. Now takes the full `IntakeRequest` (not just `equipmentAccess`) so it can compute `mustIncludeFor(...)` for each of the four tracked lifts and pass it through to the relevant `ExerciseLibrary` pickers.
  - `adjustForGoal`: strength → 4-6 reps/4 sets/scaled weight up ~15%; general_fitness → 12-15 reps/3 sets/scaled down ~20%; hypertrophy uses the library's default 8-12 rep values as-is
  - `applyOneRepMaxScaling`: **only fires when `equipmentAccess == "full_gym"`.** Scales the four tracked lifts to a percentage of the user's entered 1RM: strength 82%, hypertrophy 72%, general_fitness 60% (grounded in NSCA %1RM-by-rep-range research). Scales the *raw entered 1RM* directly — there is no separate seeded "training max" value (see the corrected section 5 below).
  - `addExplosiveTraining`: adds 1-2 plyometric exercises to leg-focused days if the toggle was checked

  **Bug found and fixed 2026-08-31:** `applyOneRepMaxScaling` only scales an exercise if its name exactly matches `"Barbell Squat"`/`"Barbell Bench Press"`/`"Deadlift"`/`"Overhead Press"`. Exercise selection is otherwise fully random per muscle-group pool (e.g. the full-gym leg pool has 6 exercises, only 3 get picked for a given day) — so entering a squat 1RM used to silently do nothing about half the time, because "Barbell Squat" simply wasn't picked that day. Fixed via the `mustInclude` mechanism above: `buildDays` now forces the tracked lift into the relevant pool's picks whenever its 1RM was provided and `equipmentAccess == "full_gym"`. Covered by regression tests in `PlanGeneratorServiceTest` (`generatePlan_squatOneRepMaxForcesBarbellSquatIntoEveryLegDayAndScalesItsWeight`, run 20x to catch flakiness from the shuffle).

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
- `startup_screen.dart` — now two layers. The outer `StartupScreen` is a `StreamBuilder<User?>` on `FirebaseAuth.instance.authStateChanges()`: no signed-in user → `AuthScreen`; signed in → `_ProfileRouter` (private `StatefulWidget`, same file). `_ProfileRouter` holds the pre-existing profile/plan-resume logic: checks `UserProfileService.getProfile()` — no profile → `ProfileSetupScreen`; profile but no `currentPlan` → `IntakeScreen`; profile with a `currentPlan` → parses it and goes straight to `PlanScreen(plan: ..., goal: ...)`. **This also fixes the previous resume gap** (a returning user with an existing plan used to see the intake form again every time) as a side effect of restructuring for real auth.
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

**Tests:** `test/adjustment_result_test.dart` (2 tests, added 2026-08-31) covers `AdjustmentResult.fromJson` parsing for both weighted and bodyweight exercises. The pre-existing `test/widget_test.dart` is stale default-template cruft — it pumps `MyApp()` and asserts on a counter that no longer exists in the actual app (the real home screen is `StartupScreen`, which needs Firebase initialized first); it would fail if actually run. Screen-level testing (the new `WorkoutLogScreen`/`PlanScreen` flow) would need HTTP-client and Firestore mocking infrastructure that isn't set up in this project yet (e.g. `mocktail`, `fake_cloud_firestore`) — worth adding if deeper frontend test coverage becomes a priority.

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
- **The visual design pass is deliberately deferred** until all core features are done, as one dedicated pass rather than piecemeal styling — the app currently still uses mostly default Flutter Material theming (a leftover `deepPurple` seed color from the `flutter create` template in several places).
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

## 10. Current Status (as of 2026-08-31)

**✅ Built and confirmed working end-to-end:**
- Intake → plan generation → Firestore persistence
- Real email/password accounts (see section 6) — replaced Firebase Anonymous Auth
- Exercise library (expanded, randomized, goal-aware)
- 1RM percentage scaling (full_gym + intermediate/advanced only) — now correctly forces the tracked lift into the plan (see the mustInclude bug fix, section 4)
- Explosive/plyometric training toggle
- User profiles + friend codes
- Friend requests (send/accept/decline) + friends list
- Real-time chat
- **Workout logging, full loop, manually click-tested in Chrome:** generate a plan → "Log this workout" → per-exercise weight + feel rating → submit → results screen with explanations and updated weights → `PlanScreen` reflects the change. Committed and pushed to `mainline` in both repos (backend: 1RM `mustInclude` fix + 33 unit tests; frontend: `WorkoutLogScreen`/`adjustment_result.dart`/Firestore wiring + 2 unit tests).
- **Startup resume gap, fixed:** a returning signed-in user with an existing plan now lands directly on `PlanScreen` instead of seeing the intake form again (see section 6, `_ProfileRouter`).

**🟡 Built this session (2026-08-31), not yet manually tested:**
- Email/password auth (sign-up, log-in, sign-out) — code is written and analyzes clean, but hasn't been clicked through yet. **Also needs Email/Password enabled in the Firebase console (Authentication → Sign-in method) before it can work at all** — not yet confirmed done. Not yet committed to git.

**⏸️ Backend complete, no frontend UI:**
- Periodization/program engine (`/api/program-status`). Explicitly on hold — user wants flexible custom-phase support when it's eventually built, not a fixed template. See section 5 for the separate, more fundamental question of whether the "training max" concept it depends on (`TrainingMaxes`) is worth building out at all.

**⬜ Not started:**
- Injuries-based exercise exclusion (the `injuries` field is collected but never used in generation logic)
- Streaks
- Wearable integration
- Visual design pass — explicitly reconsidered and reconfirmed as deferred on 2026-08-31 after looking at the live (still-default-themed) app; still waiting until logging/auth are both fully solid
- Deployment: backend still only runs on `localhost:8080`; no host chosen yet, no domain purchased (and none needed yet — see the deployment discussion this session, a free host subdomain is enough for the friend test)
- Pre-launch prep (Apple Developer Program enrollment, Play Console setup, privacy policy)
- The actual friend test (the whole point of the project so far)

---

## 11. Suggested Immediate Next Steps

1. **Enable Email/Password sign-in in the Firebase console**, then click-through test sign-up → profile setup → intake → plan, sign-out, and log back in on the same device to confirm the whole auth loop works.
2. Commit and push the auth changes (`main.dart`, `startup_screen.dart`, new `auth_screen.dart`, `plan_screen.dart`'s sign-out button) once verified.
3. Decide deliberately whether the training-max system (section 5) is worth building for real, or whether direct-1RM-scaling + flat-increment logging adjustment is good enough for the friend test.
4. Deploy the backend somewhere with a stable HTTPS URL (Cloud Run fits naturally given the existing GCP/Firebase project; Railway/Render are simpler alternatives) and make the frontend's API base URL configurable instead of hardcoded `localhost:8080` — needed before anyone besides the developer can use the app on their own device.
5. Once auth + logging are both confirmed solid: design pass → pre-launch prep → real friend test with 4-6 people over 2-4 weeks.
6. Periodization UI, streaks, and wearables are all real but explicitly *not* urgent — don't let them pull focus from getting to the friend test.
