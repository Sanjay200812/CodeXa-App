# CodeXa Chat Architecture

## 1. Dual-Database Model

CodeXa follows a strict separation of concerns:
- **Core Database (PostgreSQL / Prisma)**: System of record for identities, credentials, RBAC roles, employment records, attendance, payments, documents, and notifications.
- **Chat Database**: High-frequency communication storage for conversations, messages, reactions, read receipts, and moderation reports.

```
┌─────────────────────────────────┐       ┌─────────────────────────────────┐
│          CORE DATABASE          │       │          CHAT DATABASE          │
├─────────────────────────────────┤       ├─────────────────────────────────┤
│ • User                          │       │ • Conversation                  │
│ • Role & EmploymentProfile      │       │ • ConversationMember            │
│ • AttendanceWindow & Record     │       │ • Message                       │
│ • PaymentRequest & Document     │       │ • MessageRead                   │
│ • Notification                  │       │ • MessageReport                 │
└────────────────┬────────────────┘       └────────────────┬────────────────┘
                 │                                         │
                 └─────────────── coreUserId ──────────────┘
```

---

## 2. Communication Policy Enforcement

The backend enforces communication permissions according to corporate hierarchy:
- `Intern -> Intern`: Allowed
- `Intern -> Employee`: Allowed
- `Intern -> CTO / HR`: Allowed
- `Intern -> Founder`: Controlled / Moderated
- `Employee -> Founder`: Allowed

*Note: Private direct messages are end-to-end confidential and never exposed in an open admin inbox. Only explicit moderation reports trigger review workflows.*

---

## 3. Realtime Delivery & FCM Sync

1. **Active Foreground State**: Messages are transmitted via WebSocket / Supabase Realtime channels for instant UI updates.
2. **Background / Terminated State**: When a recipient is offline or in the background, a server-side push dispatcher invokes Firebase Cloud Messaging (FCM).
3. **Android Inline Reply**: Tapping "Reply" from an Android notification invokes the Kotlin `CxNotificationReplyReceiver`, directly posting to the Chat API with the user's secure token.
