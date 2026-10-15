# CodeXa Mobile API Reference

All mobile requests authenticate using `Authorization: Bearer <token>` or session cookies.

---

## 1. Authentication Endpoints

### `POST /api/mobile/auth/login`
Authenticates against existing CodeXa credentials. Accepts any identifier:
- Email (`user@codexa.work`)
- Username (`rahul`)
- Employee ID (`CXA-EMP-001`)
- Intern ID (`CXA-INT-2026-028`)

**Request:**
```json
{
  "identifier": "CXA-INT-2026-028",
  "password": "Password123!"
}
```

**Response:**
```json
{
  "ok": true,
  "token": "eyJhbGciOi...",
  "mustChangePassword": false,
  "user": {
    "id": "cm...",
    "email": "intern@codexa.work",
    "name": "Rahul Kumar",
    "role": "INTERN"
  }
}
```

### `POST /api/mobile/auth/password-change`
Enforces mandatory first-login password updates.

**Request:**
```json
{
  "newPassword": "SecureNewPassword456!"
}
```

---

## 2. Startup Aggregator

### `GET /api/mobile/bootstrap`
Single high-performance bootstrap call replacing multiple network round-trips:
- `user`: Identity and permissions.
- `role`: Canonical RBAC role (`FOUNDER`, `CEO`, `CTO`, `HR`, `EMPLOYEE`, `INTERN`).
- `internship`:
  - `status`: `UPCOMING` | `ACTIVE` | `COMPLETED`
  - `isPreStart`: Boolean guard
  - `daysUntilStart`: Countdown for pre-internship UI
- `attendance`:
  - `state`: `COMING_SOON` | `WINDOW_ACTIVE` | `WINDOW_CLOSED` | `ALREADY_MARKED`
  - `activeWindow`: Start time, end time, window title
  - `todayRecord`: Status if checked in
- `unreadMessages` & `unreadNotifications`: Badge counts
- `payment`: ₹450 service fee breakdown (`₹150 ID Card` + `₹300 AI Dev Tools`)
- `appConfig`: Minimum version, latest version, maintenance mode

---

## 3. Attendance Endpoints

### `POST /api/mobile/attendance/mark`
Server-validated check-in with strict eligibility:
- Enforces intern start date (pre-start accounts cannot check in).
- Validates active window.
- Idempotency guard prevents double marks.

### `GET /api/mobile/attendance/history`
Monthly calendar breakdown. Working day denominator strictly counts only days from the user's start date onwards.

### `POST /api/mobile/attendance/corrections`
Submits correction ticket for missed attendance windows.

---

## 4. Projects & Tasks

### `GET /api/mobile/projects`
Returns projects assigned to the current user or managed by their role.

### `POST /api/mobile/projects`
Submits milestone progress update (`progress`, `completedWork`, `blockers`).

---

## 5. Feed & Announcements

### `GET /api/mobile/posts`
Team activity feed with announcements and milestone cards.

### `POST /api/mobile/posts`
Creates post. Interns can publish team updates; official announcements require authorized roles.

### `POST /api/mobile/posts/:id/like`
Toggles like status.

### `POST /api/mobile/posts/:id/comments`
Adds threaded comment.

---

## 6. Payments

### `GET /api/mobile/payments`
Returns detailed ₹450 breakdown and direct link to website secure payment session.

---

## 7. Documents

### `GET /api/mobile/documents`
Returns authenticated documents (Offer Letters, ID Card, Payslips, Completion Certificates) with secure download URLs.

---

## 8. Security & Sessions

### `GET /api/mobile/security`
Lists active mobile and web login sessions.

### `POST /api/mobile/security`
Revokes specific session or terminates all other devices.
