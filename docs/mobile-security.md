# CodeXa Mobile Security Policy

## 1. Zero-Trust Client Architecture

The CodeXa Mobile APK is treated as an inspectable, untrusted client:
- **No Private Keys in APK**: No database passwords, Supabase Service Role keys, or Firebase Service Account credentials are embedded in the APK.
- **Server-Side Authorization**: Roles (`FOUNDER`, `INTERN`, etc.) passed by the client are disregarded. Authorization is determined strictly by the validated Bearer session on the server.
- **Start-Date Attendance Guard**: Server-side logic blocks attendance check-ins before an intern's start date, regardless of any modified client timestamps or API calls.
- **Idempotency Protection**: Duplicate check-in taps return the existing attendance record and prevent duplicate entries in the database.

---

## 2. Token Management & Storage

- **Storage**: Tokens are stored using platform-encrypted storage (`FlutterSecureStorage` using Keystore on Android).
- **Session Revocation**: Users can view all active sessions via the Settings module (`GET /api/mobile/security`) and terminate remote sessions at any time (`POST /api/mobile/security`).
- **First-Time Password Change**: Users with `mustChangePassword = true` are intercepted by the router and cannot access any workspace views until a new password has been set.

---

## 3. Documents & Media Security

- Document downloads and viewings use time-limited, signed URLs authenticated through CodeXa core infrastructure.
- Direct public URLs to private files (offer letters, contracts, internal assets) are strictly prohibited.
