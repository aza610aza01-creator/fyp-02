# AI Gym Cloud (Flutter Production Release v4.1)

**AI Gym Cloud** is a local-first Flutter fitness application with bilingual English (`en`) and Traditional Chinese (`zh-Hant`) localization, workout and routine logging, adherence analytics, body/health tracking, camera detection, and Row-Level-Security (RLS) backed Supabase cloud synchronization.

### Camera detection

The enabled glass theme uses a dotted indigo-blue backdrop, translucent frosted panels with soft specular highlights, and iridescent pill-shaped progress meters inspired by the local `re/` showcase. The glass preference applies across the responsive app shell and respects the selected light/dark theme; turning glass off retains the solid surfaces and original accent palette.

On Android, the camera uses the bundled Ultralytics YOLO26n-Pose LiteRT model for on-device pose detection, joint angles, and heuristic form feedback. The model is packaged in the APK, so first use does not need to download model weights. GPU inference is enabled with the runtime's CPU fallback. The `ultralytics_yolo` runtime and its model are AGPL-3.0; review the license obligations before distributing a production APK. iOS continues to use Google ML Kit object detection and does not currently provide YOLO pose coaching. Chrome/Edge web builds are camera-preview only. Browser camera access requires site permission and a secure origin (`localhost` or HTTPS).

On Windows, opening the camera screen starts the local Python YOLO + MediaPipe detector in `python_gym_pose/` when its virtual environment is installed. The first start may download `yolov8n-pose.pt`.

On Windows, use **Import video for YOLO analysis** from either the dashboard's **Running & pose** tab or the full camera screen to run a local video through the same YOLO + MediaPipe pipeline. The annotated frames, joint angles, movement phase, form feedback, and repetition count appear in the live showcase. The imported file stays on the device. Adjusting the confidence and IoU controls updates the detector while it is running. The bundled rules provide guide-driven push-up form checks; other exercise feedback identifies supported target poses and their measured angles and is not a substitute for a validated coaching assessment.

To set up Windows YOLO, install Python 3.11 and run `python_gym_pose/SETUP.bat` once. The Flutter app then starts the local service on camera open or video import. If automatic discovery cannot find the companion folder, set `AI_GYM_PYTHON_POSE_DIR` to its path, or start it manually with `python_gym_pose/RUN_FLUTTER.bat`. The bridge binds to `127.0.0.1:8765`; it is intended for local desktop use and is not an authenticated remote service. The Android LiteRT model is bundled at `assets/models/yolo26n-pose_w8a32.tflite`.

The exercise library includes bundled, silent looping sample clips for squats, push-ups, deadlifts, and bicep curls, plus external video demonstrations for those lifts, bench press, and shoulder press. Videos open on their hosting site; exercise records may use their own `demo_url` values.

---

## 1. Repository Layout (`D-3` / `H-1`)

```text
ai_gym_cloud/
├── analysis_options.yaml        # Flutter lints & strict analyzer configuration
├── pubspec.yaml                 # Flutter SDK & package dependencies
├── lib/
│   ├── main.dart                # Application entry point & service bootstrap
│   ├── app/
│   │   ├── app.dart             # Root AiGymCloudApp widget & stage router
│   │   ├── responsive_app_shell.dart # 5-tab mobile / NavigationRail desktop shell
│   │   └── routes.dart          # Named route constants (AppRoutes)
│   ├── controllers/             # Lifecycle-safe ChangeNotifier state controllers
│   │   ├── app_startup_controller.dart
│   │   ├── auth_flow_controller.dart
│   │   ├── health_controller.dart
│   │   ├── navigation_controller.dart
│   │   ├── sync_controller.dart
│   │   ├── user_data_controller.dart
│   │   └── workout_controller.dart
│   ├── core/
│   │   ├── constants/app_config.dart # --dart-define configuration reader
│   │   ├── errors/app_failure.dart   # Typed domain failures & AppResult<T>
│   │   ├── localization/app_localizations.dart # Bilingual EN / zh-Hant strings
│   │   ├── theme/               # Design tokens & dark glassmorphism theme
│   │   ├── utils/               # Fitness calculators (1RM, BMI, BMR) & validators
│   │   └── widgets/             # Reusable GlassPanel, SVG icons & state cards
│   ├── models/                  # Immutable domain models with JSON serialization
│   ├── repositories/            # Offline-first repositories with Supabase sync
│   ├── screens/                 # Feature screens (Auth, Onboarding, Dashboard, Workout, Library, Progress, BodyHealth, Camera, Settings, Diagnostics)
│   ├── services/                # Auth, CameraDetection, Database, Diagnostics, Notification, Preference services
│   └── widgets/                 # RealTimeDetectionShowcase, RestTimerBanner, SocialAndPlansSheet
├── supabase/
│   ├── config.toml              # Local Supabase CLI configuration
│   ├── schema.sql               # Full PostgreSQL schema & Row Level Security (RLS) policies (SEC-4)
│   ├── storage_policies.sql     # Private bucket storage RLS policies (SEC-4)
│   ├── seed.sql                 # Default exercise catalog seed data
│   └── migrations/              # Incremental RLS & storage hardening migrations
├── python_gym_pose/             # Companion desktop MediaPipe/YOLOv8 pose scripts (gym_pose.py v10)
└── test/                        # Comprehensive unit & widget test suite (QA-1..QA-5)
    ├── app_test.dart
    ├── auth_and_guest_test.dart
    ├── camera_service_test.dart
    ├── localization_test.dart
    ├── service_lifecycle_test.dart
    └── settings_and_workout_persistence_test.dart
```

---

## 2. Setup & Running Locally (`H-4`)

### Prerequisites
- Flutter SDK `>=3.13.0 <4.0.0`
- A Supabase project (optional for local-only Guest Mode; required for cloud authentication & sync)

### Step 1: Install Dependencies
```bash
flutter pub get
```

### Step 2: Configure Supabase Database & RLS (`SEC-4`)
Apply `supabase/schema.sql`, `supabase/storage_policies.sql`, and `supabase/seed.sql` in the Supabase SQL Editor or via the Supabase CLI:
```bash
supabase db reset
```

### Step 3: Configure and verify the Flutter client (`SEC-1`..`SEC-3`)
No credentials are hardcoded in source. Pass your Supabase URL and anon/publishable key via `--dart-define` (or launch without flags to test local-only **Guest Mode**):

```bash
flutter run \
  --dart-define-from-file=.dart-defines.local.json \
  --dart-define=ADMIN_EMAIL=admin@example.com
```

Copy `.dart-defines.example.json` to `.dart-defines.local.json` and fill in the
Supabase project URL (for example, `https://<project-ref>.supabase.co`) and
client-safe publishable key. If you have a REST API URL ending in `/rest/v1/`,
the app normalizes it to the project URL used by Supabase Auth. The local file is git-ignored and the
VS Code Windows, Chrome, and Android launch profiles read it automatically. Never
use an `sb_secret_` key in the Flutter app. The app initializes Supabase only when
both values are valid; local Guest Mode remains available without them. In
**More → Settings → Application**, choose **Test connection** to check Auth and
the seeded `exercises` table. A successful client connection does not install the
database schema: apply the SQL files above first, and keep Row Level Security enabled.

### Step 4: Run Static Analysis & Automated Tests (`QA-1`..`QA-5`)
```bash
flutter analyze
flutter test
```
