# CodeXa Mobile Architecture

## 1. System Topology

CodeXa operates with three dedicated surfaces:
1. **Admin / Control Center (Website)**: Next.js 14, Prisma, PostgreSQL, Full RBAC, Attendance Window management, Document generation, Payment verification.
2. **Daily Team Workspace (Mobile APK)**: Flutter, Material 3 Cyber theme, Native Kotlin notification bridge, Riverpod state management.
3. **AI / Developer Workspace (Desktop)**: Local IDE integrations, MCP agents, terminal controllers.

```
                    ┌───────────────────────────┐
                    │      CodeXa Web / Admin   │
                    │      (Next.js 14 + Prisma)│
                    └─────────────┬─────────────┘
                                  │
                             HTTP / JSON
                                  │
    ┌─────────────────────────────┴─────────────────────────────┐
    │                                                           │
┌───▼────────────────────────┐              ┌───────────────────▼───┐
│     CodeXa Mobile App      │              │    Firebase / FCM     │
│   (Flutter + Android APK)  │◄─────────────┤   (Push Messaging)    │
└────────────────────────────┘              └───────────────────────┘
```

---

## 2. Layered Architecture

```
lib/
├── app/
│   ├── router.dart             # GoRouter declaration with deep linking (codexa://)
│   └── main.dart               # Entrypoint with dark theme & system UI overlays
├── core/
│   ├── api/                    # Dio HTTP client, Bearer interceptors, Base URLs
│   ├── models/                 # Strongly-typed data models (User, Bootstrap, Attendance, etc.)
│   ├── providers/              # Riverpod StateNotifiers and FutureProviders
│   ├── storage/                # Encrypted FlutterSecureStorage + SharedPreferences
│   ├── theme/                  # CodeXa Cyber design tokens, fonts, spacing
│   └── widgets/                # Reusable component library (CxCard, CxButton, CxScaffold, etc.)
└── features/
    ├── auth/                   # Splash, Login, Mandatory Password Change
    ├── home/                   # Role-aware dashboard, Quick Actions, Main Shell
    ├── attendance/             # Coming Soon, Active Check-in, History, Corrections
    ├── messages/               # Direct & Group chat with Android Inline Reply
    ├── feed/                   # Official announcements, team updates, interactions
    ├── projects/               # Assigned projects, tasks, update submission
    ├── leave/                  # Application submission & tracking
    ├── payments/               # ₹450 Fee breakdown & Web handoff
    ├── documents/              # Secure authenticated document viewer
    └── settings/               # Active sessions & Remote session revocation
```

---

## 3. Native Android Kotlin Bridge

To achieve zero-lag, genuine Android notification inline replies without opening the main Flutter activity:
1. Native `RemoteInput` with `KEY_TEXT_REPLY` is configured in notification actions.
2. Android `BroadcastReceiver` (`CxNotificationReplyReceiver`) catches user inline input directly.
3. Reads the stored session token from `FlutterSharedPreferences`.
4. Asynchronously dispatches `POST /api/chat/messages` with conversation ID and text.
5. Updates the system notification immediately to confirm successful transmission.
