# CodeXa Push Notifications & Android Channels

## 1. Notification Pipeline

Firebase Cloud Messaging (FCM) is utilized as a transport channel, while canonical records are persisted in the Core Database.

```
┌─────────────────────────────────┐
│     Business Event Trigger      │
│  (Window Open, DM, Approval)    │
└────────────────┬────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│    Create Record in Core DB     │
│       `Notification` Table      │
└────────────────┬────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│       FCM Push Dispatcher       │
│  (Targeting registered devices) │
└────────────────┬────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│      Android Notification       │
│     Specific Channel & Action   │
└─────────────────────────────────┘
```

---

## 2. Android Notification Channels

The app defines specific notification channels so users can configure alerts per category:

| Channel ID | Name | Importance | Description |
|---|---|---|---|
| `codexa_attendance` | Attendance | HIGH | Windows opening, Check-in status |
| `codexa_messages` | Messages | HIGH | Direct messages, Mentions, Inline reply |
| `codexa_projects` | Projects | DEFAULT | Milestone submissions, Reviews |
| `codexa_hr` | HR & Leave | DEFAULT | Leave requests, Approvals, Notices |
| `codexa_payments` | Payments | HIGH | Fee updates, Receipt confirmations |
| `codexa_documents` | Documents | DEFAULT | Newly issued certificates and letters |
| `codexa_security` | Security | HIGH | Suspicious logins, Password modifications |

---

## 3. Deep Linking Schemes

Notifications contain payload routes handled by `go_router`:
- `codexa://attendance` -> Direct to active check-in window
- `codexa://chat/:id` -> Open active conversation
- `codexa://project/:id` -> Project overview and tasks
- `codexa://leave/:id` -> Leave status overview
- `codexa://payment` -> ₹450 service fee breakdown
- `codexa://documents` -> Official documents viewer
