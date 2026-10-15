# CodeXa Mobile Workspace (APK)

Official mobile client for the **CodeXa Ecosystem** built with Flutter, Dart, and Native Kotlin components.

---

## 1. Product Ecosystem

```
┌────────────────────────────────┐
│         CODEXA ECOSYSTEM       │
├────────────────────────────────┤
│ 1. CodeXa Website              │
│    Admin / Control Center      │
│    Next.js 14 + Prisma + PG    │
├────────────────────────────────┤
│ 2. CodeXa Mobile APK           │
│    Daily Team Workspace        │
│    Flutter + Riverpod + Kotlin │
├────────────────────────────────┤
│ 3. CodeXa Desktop              │
│    AI / Developer Workspace    │
│    Desktop IDE & AI Assistant  │
└────────────────────────────────┘
```

The Mobile APK is tailored specifically for employees, interns, and management daily operational needs:

- **Authentication**: Email / Username / Employee ID / Intern ID with mandatory first-login password enforcement.
- **Home Dashboard**: Dynamic, role-aware daily status, quick actions, attendance window alerts, and project progress.
- **Attendance**:
  - Interns prior to their start date see **COMING SOON** (no Mark Present, no 0% stats, no absence penalty, no push reminders).
  - Active check-in with live server window countdown, duplicate prevention, and geolocation/idempotency protection.
  - Monthly history with accurate denominator calculation.
  - Correction request ticketing.
- **Messages**: 1-to-1 DMs and team channels with instant messaging, read indicators, and Android notification inline reply via `RemoteInput`.
- **Feed**: Official announcements and team milestones, interactive reactions, and threaded comments.
- **Projects & Tasks**: Assigned projects, progress tracking, and structured progress update submissions.
- **Leave Requests**: Application submission with balance status and approvals.
- **Payments**: Detailed ₹450 internship fee breakdown (₹150 Mandatory ID Card + ₹300 AI Dev Tools Pack) with secure handoff to the web payment portal.
- **Documents**: Secure authenticated viewing for Offer Letters, ID Cards, and Payslips.
- **Security & Devices**: Active sessions tracking and remote device session revocation.

---

## 2. Brand Design Tokens

CodeXa Mobile strictly inherits the Cyber/Dark brand identity from the CodeXa platform:

- **Background**: `#070707`
- **Card / Surface**: `#0C0C0C` / `#111111`
- **Elevated Border**: `rgba(217, 4, 41, 0.18)`
- **Crimson Brand**: `#D90429`
- **Bright Red Glow**: `#FF1E3C`
- **Deep Red Accent**: `#63000F`
- **Primary Text**: `#F7F7F7`
- **Muted Text**: `#A5A5A5`
- **Headings / Status / Display**: `Orbitron`
- **Functional UI / Content**: `Inter`

---

## 3. Tech Stack

- **Framework**: Flutter 3.47+ (Dart 3.7+)
- **State Management**: Riverpod (`flutter_riverpod`)
- **Navigation**: `go_router` (supports deep links like `codexa://attendance`, `codexa://chat/:id`)
- **Networking**: `dio` with Bearer token interceptor
- **Secure Storage**: `flutter_secure_storage` & `shared_preferences`
- **Typography**: `google_fonts` (Orbitron + Inter)
- **Native Android**: Kotlin `BroadcastReceiver` supporting `RemoteInput` for notification inline replies (`CxNotificationReplyReceiver`)

---

## 4. Setup & Running

### Prerequisites

1. Flutter SDK (`flutter doctor` must report green for Android toolchain)
2. Android SDK with platform 34+ and build tools
3. Java JDK 17+

### Commands

```bash
# Install dependencies
flutter pub get

# Static analysis
flutter analyze

# Unit & Widget tests
flutter test

# Run debug on connected device/emulator
flutter run

# Build Debug APK
flutter build apk --debug

# Build Release APK
flutter build apk --release
```

Generated APKs will be located in:
`build/app/outputs/flutter-apk/`
