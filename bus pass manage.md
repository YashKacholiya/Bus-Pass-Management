```
(Files content cropped to 300k characters, download full ingest to see more)
================================================
FILE: README.md
================================================
<div align="center">
```

```
# 🚌 ICEM Smart Bus Pass
```

```
### Pay first. Get verified. Board with a QR.
**A paperless, payment-gated bus pass system for ICEM college, built with
Flutter + Firebase.**
```

```
[![Flutter](https://img.shields.io/badge/Flutter-3.44+-02569B?
logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12-0175C2?
logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-
Auth%20%7C%20Firestore%20%7C%20Functions-FFCA28?logo=firebase&logoColor=black)]
(https://firebase.google.com)
[![Riverpod](https://img.shields.io/badge/State-Riverpod-00B8D4)](https://
riverpod.dev)
[![Razorpay](https://img.shields.io/badge/Payments-Razorpay-0C2451?
logo=razorpay&logoColor=white)](https://razorpay.com)
```

```
[![Architecture
```

```
diagram](https://gitdiagram.com/diagram-badge.svg)](https://gitdiagram.com/
yashkacholiya61-netizen/bus-pass-management?utm_source=readme&utm_medium=badge)
```

```
</div>
```

```
## 🚌 The Problem
```

```
Paper bus passes are slow to issue, easy to forge, painful to renew and
impossible to audit. Students queue at the transport office, admins reconcile
payments by hand, and conductors squint at laminated cards.
```

```
## 🚌 The Idea
```

```
ICEM Smart Bus Pass moves the whole pass lifecycle onto phones and an admin
console, built around one rule:
```

```
> **No pass becomes active until payment is verified *and* an administrator
approves it. Payment alone never activates a pass.**
```

```
Approval is a **two-key process**: a verified payment unlocks the application
for review, and an admin's explicit approval issues the pass and its QR.
```

```
## 🚌 Features
```

`###` 🎓 `Students` 

```
- **Register / sign in** with email + password or Google, with email
verification
```

- `**Apply and renew** for a pass: pick route, boarding stop and destination - **Pay with Razorpay Checkout** (fare defaults to 4,500) ₹` 

- `**Digital pass with a scannable QR**, active only after payment + admin approval` 

- `**Application history**, per-pass detail screens, payment history and receipts - **Personalization**: light / dark / system theme and accent colors (crimson, blue, green, purple), synced to Firestore` 

`### Admins (Transport Office Console)` 🛠️� `A responsive console (sidebar on desktop, drawer on mobile) with live Firestore streams:` 

```
| Area | What it does |
|---|---|
| **Dashboard** | Live KPI cards: students, active passes, pending applications,
today's revenue, buses, active drivers, pending payments, expired passes |
| **Pass Management** | Search by name / PRN / college ID, filter by status;
approve, reject, or request a correction; full application detail screen |
| **Routes** | Route management with an in-use check before deletion |
| **Buses** | Bus management with automatic bus↔route linking (one bus per
route, applied in a batch write) |
| **Students** | Suspend / activate / delete accounts; approve, reject or revoke
a student's pass |
| **Payments** | Unified view of `payments` + `receipts`; verify manual
payments, mark failed, refund (status), export PDF receipts |
| **Notifications** | Compose alerts targeted at all students, a route, a bus or
one student; schedule, edit and delete them |
| **Reports** | Custom-painted line/area, donut and bar charts; CSV and PDF
export helpers |
| **Settings** | Profile, appearance, notification preferences, security
(password change / reset) |
| **Drivers** | Driver records (add, update, delete) |
```

`###` **�** `Staff / Conductors` 

```
- Staff dashboard and a **camera QR scanner** (`mobile_scanner`)
```

```
- Verification looks the pass up in Firestore by pass number, pass ID or student
ID, and returns one of: **Valid**, **Expired**, **Revoked**, **Not Active**, or
**Invalid**
```

```
- Manual entry fallback when a QR can't be scanned
```

```
## 🚌 Security Model
```

```
| Layer | What it enforces |
|---|---|
```

```
| **Admin repository** | `approveApplication` runs in a **Firestore
transaction** that re-reads the application and aborts unless `paymentStatus` is
paid. It then atomically issues a Pass ID + Pass Number (`ICEM-BP-<year>-
<suffix>`), stamps `approvedBy` / `approvedAt`, sets validity (default **180
days**, admin-adjustable) and writes the student's `bus_passes` doc with a QR
payload |
| **Admin UI** | Unpaid applications show a locked *Payment Required* button
instead of *Approve* |
```

```
| **Firestore rules** | Students can't write `passNumber`, `qrCode`,
`approvedBy`, `approvedAt`, `validFrom`, `validUntil`, `passStatus`,
`applicationStatus`, set `status` to Approved/Active, or mark `paymentStatus` as
paid on applications; new applications must start pending/unpaid; routes, buses,
notifications, config, reports and audit logs are write-restricted |
| **Pass state** | A pass counts as active only if `paid && approved && !expired
&& !revoked` |
```

```
| **Cloud Functions** | `functions/` implements server-side Razorpay order
creation (amount read from the stored fare, double-payment guard), HMAC-SHA256
signature verification, and a payment webhook. Verification marks the
application *Pending admin approval*, **never** approved |
```

```
| **Routing** | `go_router` redirects keep unauthenticated users on public pages
and gate `/admin/*`, the staff dashboard and QR verification by role |
```

```
## 🚌 Pass Lifecycle
```

```
```mermaid
stateDiagram-v2
    [*] --> PaymentPending: Student applies
    PaymentPending --> PaidAwaitingApproval: Payment recorded / verified
    PaymentPending --> Failed: Payment failed
    PaidAwaitingApproval --> Active: Admin approves<br/>(transaction re-checks
payment)
    PaidAwaitingApproval --> Rejected: Admin rejects (reason stored)
    PaidAwaitingApproval --> CorrectionRequired: Admin requests correction
    Active --> Expired: Validity ends
    Active --> Revoked: Admin revokes (reason stored)
    Active --> Refunded: Payment refunded
    Expired --> PaymentPending: Renew
```
## 🚌 Payment Flow
```

```
```mermaid
sequenceDiagram
    autonumber
    participant S as Student App
    participant RP as Razorpay Checkout
    participant FS as Firestore
    participant A as Admin
    participant C as Conductor
    S->>RP: Open checkout (fare in paise)
    RP-->>S: Payment ID / Order ID
    S->>FS: Record payment, receipt, application → Pending
    A->>FS: Review & approve (transaction asserts paid)
    FS-->>S: Realtime: pass Active + QR
    C->>FS: Scan QR → look up pass → Valid / Expired / Revoked / Not Active
```

```
> The `functions/` directory contains the hardened server-side flow (order
creation → signature verification → webhook). Wiring the Flutter client to call
it is on the [roadmap](#-roadmap), and it is the intended production path.
```

`## Architecture` 🏗️� 

```
**Feature-first Clean Architecture**, Riverpod for state, Firestore streams as
the source of truth.
```

```
lib/
├── app/                  # MaterialApp.router + theme wiring
├── config/               # constants, go_router + role guards, themes & design
tokens
├── core/                 # failures, UseCase base, responsive helpers
├── features/
│   ├── auth/             # login, register, onboarding, splash (data / domain /
presentation)
│   ├── student/          # dashboard, apply/renew, digital pass, history
│   ├── bus_pass/         # pass model, repository, QR verification
│   ├── payment/          # Razorpay service, payment config, receipts
│   ├── admin/            # console tabs, charts, report exporter, detail
screens
│   ├── driver/           # driver repository & providers
│   └── notification/     # targeted + scheduled notification records
├── services/             # Firebase init (+ FCM), SharedPreferences settings
sync
└── shared/               # cards, buttons, skeleton loaders, status badges,
```

```
empty/error states
```

```
functions/                # Node 20 Cloud Functions (Razorpay order, verify,
webhook)
firestore.rules           # role- and field-level security
firestore.indexes.json    # composite indexes
test/                     # widget + unit tests
```
```

```
### Firestore Collections
```

```
| Collection | Purpose |
|---|---|
| `users` | Profiles, roles, preferences |
| `bus_pass_applications` | Application + payment + approval state |
| `bus_passes/{uid}` | The student's live digital pass |
| `payments`, `receipts` | Payment attempts and official receipts |
| `bus_routes`, `buses`, `drivers` | Fleet data |
| `notifications` | Targeted / scheduled alerts |
| `system_config` | Payment configuration (`payment_config`) |
| `reports`, `audit_logs` | Admin-only |
```

# `## 🚌 Tech Stack` 

```
| Layer | Choice |
|---|---|
| UI | Flutter (Material 3), Google Fonts (Outfit), `CustomPaint` charts and
onboarding art |
```

```
| State / routing | `flutter_riverpod`, `go_router` |
| Backend | Firebase Auth, Cloud Firestore, Storage, Cloud Messaging |
| Server logic | Cloud Functions (Node 20), `razorpay` SDK |
| Payments | `razorpay_flutter` |
| QR | `qr_flutter` (generate), `mobile_scanner` (scan) |
| Documents | `pdf`, `share_plus`, `path_provider` |
| Media / permissions | `image_picker`, `image_cropper`, `permission_handler` |
```

# `## 🚌 Run It Locally` 

```
**Prerequisites:** Flutter SDK (Dart `^3.12.2`), a Firebase project (Auth,
Firestore, Storage), Node.js 20 + Firebase CLI for the functions, and a Razorpay
account (test keys are fine).
```

```
```bash
```

```
git clone https://github.com/yashkacholiya61-netizen/bus-pass-management.git
cd bus-pass-management
flutter pub get
```
```

```
1. **Connect Firebase:** add your own `android/app/google-services.json` (and
`GoogleService-Info.plist` for iOS), or run `flutterfire configure`.
2. **Add assets** referenced in `pubspec.yaml`: `assets/images/bus_logo.png` and
`assets/images/college_upi_qr.png`.
3. **Deploy rules, indexes, functions:**
   ```bash
   firebase deploy --only firestore:rules,firestore:indexes
   cd functions && npm install && cd ..
   firebase functions:config:set razorpay.key_id="rzp_test_xxx"
razorpay.key_secret="xxx" razorpay.webhook_secret="xxx"
   firebase deploy --only functions
   ```
```

```
   (Functions also read `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`,
`RAZORPAY_WEBHOOK_SECRET` from the environment.)
```

```
4. **Configure payments:** set your Razorpay Key ID and fee in the
```

```
`system_config/payment_config` document (or the admin Settings screen). Without
a Key ID the app refuses to open checkout rather than faking a payment.
```

`5. **Create the first admin:** register normally, then set that user's `role` to `Admin` in the `users` collection.` 

`6. **Run:** `flutter run` (or `flutter run -d chrome` for the console).` 

# `## 🚌 Tests` 

```
```bash
flutter test
```

```
Covers payment models/config, the settings screen and theme persistence, and
admin application card behavior. Some widget tests predate recent UI copy
changes and need updating.
```

# `## Roadmap` 🗺️� 

```
- **Wire the app to Cloud Functions** (`cloud_functions` package) so order
creation and signature verification happen server-side, with the client only
displaying the result
```

- `**Move role assignment server-side** (custom claims / admin-only writes) and split *Staff* from *Admin* privileges in Firestore rules` 

- `Fix the Razorpay webhook to verify against the raw request body` 

- `A scheduled function to deliver scheduled notifications via FCM and to mark passes **Expired**` 

- `Replace placeholder dashboard stats (staff scan counts) with live data` 

- `Live bus tracking, offline-tolerant QR validation, and audit-log entries for every admin action` 

# `## 🚌 Contributing` 

`1. Fork and create a feature branch` 

`2. Keep the `data` / `domain` / `presentation` split per feature` 

`3. Never move payment or approval decisions into unprivileged client code` 

`4. Run `flutter analyze` and `flutter test` before opening a PR` 

```
<div align="center">
```

`**Built for ICEM students and transport staff.** *Verified payment + admin approval = an active pass.*` 🎟️� 

# `</div>` 

```
================================================
```

```
FILE: analysis_options.yaml
```

```
================================================
```

- `# This file configures the analyzer, which statically analyzes Dart code to # check for errors, warnings, and lints. #` 

- `# The issues identified by the analyzer are surfaced in the UI of Dart-enabled # IDEs (https://dart.dev/tools#ides-and-editors). The analyzer can also be` 

- `# invoked from the command line by running `flutter analyze`.` 

```
# The following line activates a set of recommended lints for Flutter apps,
# packages, and plugins designed to encourage good coding practices.
include: package:flutter_lints/flutter.yaml
```

```
linter:
```

- `# The lint rules applied to this project can be customized in the` 

- `# section below to disable rules from the `package:flutter_lints/flutter.yaml`` 

- `# included above or to enable additional rules. A list of all available lints` 

- `# and their documentation is published at https://dart.dev/lints. #` 

- `# Instead of disabling a lint rule for the entire project in the # section below, it can also be suppressed for a single line of code # or a specific dart file by using the `// ignore: name_of_lint` and` 

- `# `// ignore_for_file: name_of_lint` syntax on the line or in the file # producing the lint. rules:` 

- `# avoid_print: false  # Uncomment to disable the `avoid_print` rule # prefer_single_quotes: true  # Uncomment to enable the `prefer_single_quotes` rule` 

- `# Additional information about this file can be found at # https://dart.dev/guides/language/analysis-options` 

```
================================================
FILE: firebase.json
================================================
{
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "functions": [
    {
      "source": "functions",
      "codebase": "default",
      "ignore": [
        "node_modules",
        ".git",
        "firebase-debug.log",
        "firebase-debug.*.log"
      ]
    }
  ]
}
```

```
================================================
FILE: firestore.indexes.json
================================================
{
  "indexes": [
    {
      "collectionGroup": "bus_pass_applications",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "status",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "createdAt",
          "order": "DESCENDING"
        }
      ]
    }
```

```
  ],
  "fieldOverrides": []
}
```

```
================================================
FILE: firestore.rules
================================================
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    function isAdmin() {
      return isAuthenticated() && (
        request.auth.token.role in ['admin', 'Admin', 'staff', 'Staff'] ||
        get(/databases/$(database)/documents/users/$
(request.auth.uid)).data.role in ['admin', 'Admin', 'staff', 'Staff']
      );
    }
    // ── USERS COLLECTION ──
    match /users/{userId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated() && (request.auth.uid == userId ||
isAdmin());
      // Students can update their profile information, but cannot change their
own role to Admin/Staff
      allow update: if isAuthenticated() && (
        isAdmin() ||
        (
          request.auth.uid == userId &&
          (!
request.resource.data.diff(resource.data).affectedKeys().hasAny(['role']) ||
           request.resource.data.role == resource.data.role)
        )
      );
      allow delete: if isAdmin();
    }
    // ── BUS ROUTES & BUSES ──
    match /bus_routes/{routeId} {
      allow read: if isAuthenticated();
      allow write: if isAdmin();
    }
    match /buses/{busId} {
      allow read: if isAuthenticated();
      allow write: if isAdmin();
    }
    // ── BUS PASS APPLICATIONS ──
    match /bus_pass_applications/{applicationId} {
      allow read: if isAuthenticated() && (
        isAdmin() ||
```

```
        resource.data.uid == request.auth.uid ||
        resource.data.studentId == request.auth.uid
      );
      // Student can submit an initial application (must be Payment Pending /
Pending)
      // Must NOT contain passNumber, approvedAt, approvedBy, qrCode
      allow create: if isAuthenticated() && (
        isAdmin() ||
        (
          (request.resource.data.uid == request.auth.uid ||
request.resource.data.studentId == request.auth.uid) &&
          request.resource.data.paymentStatus in ['Pending', 'Unpaid',
'pending'] &&
          request.resource.data.status in ['Payment Pending', 'payment_pending',
'Pending'] &&
          request.resource.data.passStatus in ['Payment Pending',
'payment_pending', 'Pending'] &&
          !request.resource.data.keys().hasAny(['approvedAt', 'approvedBy',
'passNumber', 'qrCode', 'validFrom', 'validUntil'])
        )
      );
      // Student CANNOT mark application as 'Approved', 'Active', or 'Paid'
      // Student CANNOT directly generate passNumber or approvedAt/approvedBy
      allow update: if isAuthenticated() && (
        isAdmin() ||
        (
          (resource.data.uid == request.auth.uid || resource.data.studentId ==
request.auth.uid) &&
          !request.resource.data.diff(resource.data).affectedKeys().hasAny([
            'approvedBy', 'approvedAt', 'passNumber', 'passStatus',
'applicationStatus', 'validFrom', 'validUntil', 'qrCode'
          ]) &&
          request.resource.data.status != 'Approved' &&
          request.resource.data.status != 'approved' &&
          request.resource.data.status != 'Active' &&
          request.resource.data.paymentStatus != 'paid' &&
          request.resource.data.paymentStatus != 'Paid'
        )
      );
      allow delete: if isAdmin();
    }
    // ── BUS PASSES ──
    match /bus_passes/{userId} {
      // Conductors and admins can read any pass for QR verification; students
can read their own
      allow read: if isAuthenticated() && (isOwner(userId) || isAdmin());
      // Only Admin or trusted backend can activate, approve, or generate
passNumber
      allow create: if isAuthenticated() && (
        isAdmin() ||
        (
          isOwner(userId) &&
          request.resource.data.passStatus in ['Pending', 'Payment Pending',
'pending'] &&
          request.resource.data.status in ['Pending', 'Payment Pending',
'pending'] &&
          request.resource.data.paymentStatus in ['Pending', 'Unpaid',
'pending'] &&
          !request.resource.data.keys().hasAny(['passNumber', 'approvedAt',
```

```
'approvedBy', 'qrCode', 'validFrom', 'validUntil'])
        )
      );
      // Student cannot modify approval status, pass status, payment status,
passNumber, approvedAt, or qrCode
      allow update: if isAuthenticated() && (
        isAdmin() ||
        (
          isOwner(userId) &&
          !request.resource.data.diff(resource.data).affectedKeys().hasAny([
            'passStatus', 'applicationStatus', 'status', 'paymentStatus',
'passNumber', 'approvedAt', 'approvedBy', 'qrCode', 'validFrom', 'validUntil'
          ])
        )
      );
      allow delete: if isAdmin();
    }
    // ── PAYMENTS COLLECTION ──
    match /payments/{paymentId} {
      allow read: if isAuthenticated() && (
        isAdmin() ||
        resource.data.studentId == request.auth.uid ||
        resource.data.uid == request.auth.uid
      );
      // Students can create a payment attempt
      allow create: if isAuthenticated() && (
        isAdmin() ||
        (
          (request.resource.data.studentId == request.auth.uid ||
request.resource.data.uid == request.auth.uid) &&
          request.resource.data.paymentStatus in ['created', 'pending',
'processing', 'submitted_for_verification', 'Pending Verification']
        )
      );
      // Students CANNOT mark payments as 'paid' or 'verified'
      // Only Admin or trusted payment webhook/service can verify payments
      allow update: if isAuthenticated() && (
        isAdmin() ||
        (
          (resource.data.studentId == request.auth.uid || resource.data.uid ==
request.auth.uid) &&
          !
request.resource.data.diff(resource.data).affectedKeys().hasAny(['verifiedAt',
'verifiedBy']) &&
          request.resource.data.paymentStatus in ['failed', 'cancelled']
        )
      );
      allow delete: if isAdmin();
    }
    // ── RECEIPTS COLLECTION ──
    match /receipts/{receiptId} {
      allow read: if isAuthenticated() && (
        isAdmin() ||
        resource.data.uid == request.auth.uid ||
        resource.data.studentId == request.auth.uid
      );
      allow create, update: if isAuthenticated() && (
```

```
        isAdmin() ||
        request.resource.data.uid == request.auth.uid ||
        request.resource.data.studentId == request.auth.uid
      );
      allow delete: if isAdmin();
    }
    // ── SYSTEM CONFIGURATION ──
    match /system_config/{configId} {
      allow read: if isAuthenticated();
      allow write: if isAdmin();
    }
    // ── NOTIFICATIONS & ALERTS ──
    match /notifications/{notificationId} {
      allow read: if isAuthenticated();
      allow write: if isAdmin();
    }
    // ── REPORTS & AUDIT LOGS ──
    match /reports/{reportId} {
      allow read, write: if isAdmin();
    }
    match /audit_logs/{logId} {
      allow read, write: if isAdmin();
    }
  }
}
================================================
FILE: pubspec.lock
================================================
# Generated by pub
# See https://dart.dev/tools/pub/glossary#lockfile
packages:
  _fe_analyzer_shared:
    dependency: transitive
    description:
      name: _fe_analyzer_shared
      sha256: da0d9209ca76bde579f2da330aeb9df62b6319c834fa7baae052021b0462401f
      url: "https://pub.dev"
    source: hosted
    version: "85.0.0"
  _flutterfire_internals:
    dependency: transitive
    description:
      name: _flutterfire_internals
      sha256: "460e9e684edb461d85498fc166ff8416f303f22216838d302d80676b348c6a4c"
      url: "https://pub.dev"
    source: hosted
    version: "1.3.75"
  analyzer:
    dependency: transitive
    description:
      name: analyzer
      sha256: f4ad0fea5f102201015c9aae9d93bc02f75dd9491529a8c21f88d17a8523d44c
      url: "https://pub.dev"
    source: hosted
    version: "7.6.0"
  analyzer_plugin:
    dependency: transitive
```

```
    description:
      name: analyzer_plugin
      sha256: a5ab7590c27b779f3d4de67f31c4109dbe13dd7339f86461a6f2a8ab2594d8ce
      url: "https://pub.dev"
    source: hosted
    version: "0.13.4"
  archive:
    dependency: transitive
    description:
      name: archive
      sha256: a96e8b390886ee8abb49b7bd3ac8df6f451c621619f52a26e815fdcf568959ff
      url: "https://pub.dev"
    source: hosted
    version: "4.0.9"
  args:
    dependency: transitive
    description:
      name: args
      sha256: d0481093c50b1da8910eb0bb301626d4d8eb7284aa739614d2b394ee09e3ea04
      url: "https://pub.dev"
    source: hosted
    version: "2.7.0"
  async:
    dependency: transitive
    description:
      name: async
      sha256: e2eb0491ba5ddb6177742d2da23904574082139b07c1e33b8503b9f46f3e1a37
      url: "https://pub.dev"
    source: hosted
    version: "2.13.1"
  barcode:
    dependency: transitive
    description:
      name: barcode
      sha256: "7b6729c37e3b7f34233e2318d866e8c48ddb46c1f7ad01ff7bb2a8de1da2b9f4"
      url: "https://pub.dev"
    source: hosted
    version: "2.2.9"
  bidi:
    dependency: transitive
    description:
      name: bidi
      sha256: "77f475165e94b261745cf1032c751e2032b8ed92ccb2bf5716036db79320637d"
      url: "https://pub.dev"
    source: hosted
    version: "2.0.13"
  boolean_selector:
    dependency: transitive
    description:
      name: boolean_selector
      sha256: "8aab1771e1243a5063b8b0ff68042d67334e3feab9e95b9490f9a6ebf73b42ea"
      url: "https://pub.dev"
    source: hosted
    version: "2.1.2"
  build:
    dependency: transitive
    description:
      name: build
      sha256: "51dc711996cbf609b90cbe5b335bbce83143875a9d58e4b5c6d3c4f684d3dda7"
      url: "https://pub.dev"
    source: hosted
    version: "2.5.4"
  build_config:
    dependency: transitive
```

```
    description:
      name: build_config
      sha256: "4ae2de3e1e67ea270081eaee972e1bd8f027d459f249e0f1186730784c2e7e33"
      url: "https://pub.dev"
    source: hosted
    version: "1.1.2"
  build_daemon:
    dependency: transitive
    description:
      name: build_daemon
      sha256: fd754058c342243718d5171a95f352cfc9fcf0cba8cfa26df67cb13a5836db78
      url: "https://pub.dev"
    source: hosted
    version: "4.1.2"
  build_resolvers:
    dependency: transitive
    description:
      name: build_resolvers
      sha256: ee4257b3f20c0c90e72ed2b57ad637f694ccba48839a821e87db762548c22a62
      url: "https://pub.dev"
    source: hosted
    version: "2.5.4"
  build_runner:
    dependency: "direct dev"
    description:
      name: build_runner
      sha256: "382a4d649addbfb7ba71a3631df0ec6a45d5ab9b098638144faf27f02778eb53"
      url: "https://pub.dev"
    source: hosted
    version: "2.5.4"
  build_runner_core:
    dependency: transitive
    description:
      name: build_runner_core
      sha256: "85fbbb1036d576d966332a3f5ce83f2ce66a40bea1a94ad2d5fc29a19a0d3792"
      url: "https://pub.dev"
    source: hosted
    version: "9.1.2"
  built_collection:
    dependency: transitive
    description:
      name: built_collection
      sha256: "376e3dd27b51ea877c28d525560790aee2e6fbb5f20e2f85d5081027d94e2100"
      url: "https://pub.dev"
    source: hosted
    version: "5.1.1"
  built_value:
    dependency: transitive
    description:
      name: built_value
      sha256: "34e4067d30ce212937df995f03b69992eea683539ceeac7f679a1f1eba055b56"
      url: "https://pub.dev"
    source: hosted
    version: "8.12.6"
  characters:
    dependency: transitive
    description:
      name: characters
      sha256: faf38497bda5ead2a8c7615f4f7939df04333478bf32e4173fcb06d428b5716b
      url: "https://pub.dev"
    source: hosted
    version: "1.4.1"
  checked_yaml:
    dependency: transitive
```

```
    description:
      name: checked_yaml
      sha256: "959525d3162f249993882720d52b7e0c833978df229be20702b33d48d91de70f"
      url: "https://pub.dev"
    source: hosted
    version: "2.0.4"
  clock:
    dependency: transitive
    description:
      name: clock
      sha256: fddb70d9b5277016c77a80201021d40a2247104d9f4aa7bab7157b7e3f05b84b
      url: "https://pub.dev"
    source: hosted
    version: "1.1.2"
  cloud_firestore:
    dependency: "direct main"
    description:
      name: cloud_firestore
      sha256: e494387f1cd15e4f1c935e14a9cb884c97b8847a41364fabfaa912958a2ea842
      url: "https://pub.dev"
    source: hosted
    version: "6.7.1"
  cloud_firestore_platform_interface:
    dependency: transitive
    description:
      name: cloud_firestore_platform_interface
      sha256: bc8c479a829c1abdfa4741aa2f3a3242918e0bebd3eb50e53d9dde9b303d4330
      url: "https://pub.dev"
    source: hosted
    version: "8.0.5"
  cloud_firestore_web:
    dependency: transitive
    description:
      name: cloud_firestore_web
      sha256: cb237b3bf3cff4778ec962a8a9449ae79e831d7b4369e0ad9f5a2b6dfbd84569
      url: "https://pub.dev"
    source: hosted
    version: "5.7.1"
  code_assets:
    dependency: transitive
    description:
      name: code_assets
      sha256: bf394f466ba9205f1812a0433b392d6af280f155f56651eda7c18cc32ed493b8
      url: "https://pub.dev"
    source: hosted
    version: "1.2.1"
  code_builder:
    dependency: transitive
    description:
      name: code_builder
      sha256: "6a6cab2ba4680d6423f34a9b972a4c9a94ebe1b62ecec4e1a1f2cba91fd1319d"
      url: "https://pub.dev"
    source: hosted
    version: "4.11.1"
  collection:
    dependency: transitive
    description:
      name: collection
      sha256: "2f5709ae4d3d59dd8f7cd309b4e023046b57d8a6c82130785d2b0e5868084e76"
      url: "https://pub.dev"
    source: hosted
    version: "1.19.1"
  convert:
    dependency: transitive
```

```
    description:
      name: convert
      sha256: b30acd5944035672bc15c6b7a8b47d773e41e2f17de064350988c5d02adb1c68
      url: "https://pub.dev"
    source: hosted
    version: "3.1.2"
  cross_file:
    dependency: transitive
    description:
      name: cross_file
      sha256: "92c9c43c383bfa1c32079d3bc492d55d6d4318044b7b47edaff8971cbb555c51"
      url: "https://pub.dev"
    source: hosted
    version: "0.3.5+4"
  crypto:
    dependency: transitive
    description:
      name: crypto
      sha256: c8ea0233063ba03258fbcf2ca4d6dadfefe14f02fab57702265467a19f27fadf
      url: "https://pub.dev"
    source: hosted
    version: "3.0.7"
  cupertino_icons:
    dependency: "direct main"
    description:
      name: cupertino_icons
      sha256: "41e005c33bd814be4d3096aff55b1908d419fde52ca656c8c47719ec745873cd"
      url: "https://pub.dev"
    source: hosted
    version: "1.0.9"
  custom_lint_core:
    dependency: transitive
    description:
      name: custom_lint_core
      sha256: "31110af3dde9d29fb10828ca33f1dce24d2798477b167675543ce3d208dee8be"
      url: "https://pub.dev"
    source: hosted
    version: "0.7.5"
  custom_lint_visitor:
    dependency: transitive
    description:
      name: custom_lint_visitor
      sha256: "4a86a0d8415a91fbb8298d6ef03e9034dc8e323a599ddc4120a0e36c433983a2"
      url: "https://pub.dev"
    source: hosted
    version: "1.0.0+7.7.0"
  dart_style:
    dependency: transitive
    description:
      name: dart_style
      sha256: "8a0e5fba27e8ee025d2ffb4ee820b4e6e2cf5e4246a6b1a477eb66866947e0bb"
      url: "https://pub.dev"
    source: hosted
    version: "3.1.1"
  equatable:
    dependency: "direct main"
    description:
      name: equatable
      sha256: "3bce007a596ff8b3119c45d68aaef631272537c03d30e5d4534dd24bf4c5eaa2"
      url: "https://pub.dev"
    source: hosted
    version: "2.1.0"
  eventify:
    dependency: transitive
```

```
    description:
      name: eventify
      sha256: b829429f08586cc2001c628e7499e3e3c2493a1d895fd73b00ecb23351aa5a66
      url: "https://pub.dev"
    source: hosted
    version: "1.0.1"
  fake_async:
    dependency: transitive
    description:
      name: fake_async
      sha256: "5368f224a74523e8d2e7399ea1638b37aecfca824a3cc4dfdf77bf1fa905ac44"
      url: "https://pub.dev"
    source: hosted
    version: "1.3.3"
  ffi:
    dependency: transitive
    description:
      name: ffi
      sha256: "6d7fd89431262d8f3125e81b50d3847a091d846eafcd4fdb88dd06f36d705a45"
      url: "https://pub.dev"
    source: hosted
    version: "2.2.0"
  ffi_leak_tracker:
    dependency: transitive
    description:
      name: ffi_leak_tracker
      sha256: "4093d4ef9ca06ffe2786e73bfb25e22aa92112b9bb4ec941f11e3e6b61489a97"
      url: "https://pub.dev"
    source: hosted
    version: "0.1.2"
  file:
    dependency: transitive
    description:
      name: file
      sha256: a3b4f84adafef897088c160faf7dfffb7696046cb13ae90b508c2cbc95d3b8d4
      url: "https://pub.dev"
    source: hosted
    version: "7.0.1"
  file_selector_linux:
    dependency: transitive
    description:
      name: file_selector_linux
      sha256: "2567f398e06ac72dcf2e98a0c95df2a9edd03c2c2e0cacd4780f20cdf56263a0"
      url: "https://pub.dev"
    source: hosted
    version: "0.9.4"
  file_selector_macos:
    dependency: transitive
    description:
      name: file_selector_macos
      sha256: "5e0bbe9c312416f1787a68259ea1505b52f258c587f12920422671807c4d618a"
      url: "https://pub.dev"
    source: hosted
    version: "0.9.5"
  file_selector_platform_interface:
    dependency: transitive
    description:
      name: file_selector_platform_interface
      sha256: "35e0bd61ebcdb91a3505813b055b09b79dfdc7d0aee9c09a7ba59ae4bb13dc85"
      url: "https://pub.dev"
    source: hosted
    version: "2.7.0"
  file_selector_windows:
    dependency: transitive
```

```
    description:
      name: file_selector_windows
      sha256: "62197474ae75893a62df75939c777763d39c2bc5f73ce5b88497208bc269abfd"
      url: "https://pub.dev"
    source: hosted
    version: "0.9.3+5"
  firebase_auth:
    dependency: "direct main"
    description:
      name: firebase_auth
      sha256: "0ced04a58f0d08bb01435771069fdee06e54d85321f2a8c9dc428857098731c8"
      url: "https://pub.dev"
    source: hosted
    version: "6.5.6"
  firebase_auth_platform_interface:
    dependency: transitive
    description:
      name: firebase_auth_platform_interface
      sha256: a02aa6edb07fb5676eeea47590ff19d916c0239706ec2a35b1544cc7af44b63a
      url: "https://pub.dev"
    source: hosted
    version: "9.0.5"
  firebase_auth_web:
    dependency: transitive
    description:
      name: firebase_auth_web
      sha256: "8daa9f7665f76c6e23a2e68cabaa7f6693e1949eef3ee678712544b3835ce437"
      url: "https://pub.dev"
    source: hosted
    version: "6.2.5"
  firebase_core:
    dependency: "direct main"
    description:
      name: firebase_core
      sha256: "6f22d1c62e0c20976f02cd842c7b7cd3c0f561cc2052586411871045c08860c9"
      url: "https://pub.dev"
    source: hosted
    version: "4.12.1"
  firebase_core_platform_interface:
    dependency: transitive
    description:
      name: firebase_core_platform_interface
      sha256: f74d1d6fabccf7743b0144c2ed363d81049e258e22428ebb6fb0faec2fa7d938
      url: "https://pub.dev"
    source: hosted
    version: "8.0.0"
  firebase_core_web:
    dependency: transitive
    description:
      name: firebase_core_web
      sha256: ddab99d709b8c27dd47576eb05a1e719e07a2aa45c009a49ae92ac4d2a8ca555
      url: "https://pub.dev"
    source: hosted
    version: "3.9.1"
  firebase_messaging:
    dependency: "direct main"
    description:
      name: firebase_messaging
      sha256: "30ad2d59bcd86117dc49d278c8998a0fb390c5a3202f6e43e4bd215d3f1d0556"
      url: "https://pub.dev"
    source: hosted
    version: "16.4.3"
  firebase_messaging_platform_interface:
    dependency: transitive
```

```
    description:
      name: firebase_messaging_platform_interface
      sha256: "4d144cb42b9a5a42855596be2d7682d32c50169f42e7df2cb3278ecf935e7d63"
      url: "https://pub.dev"
    source: hosted
    version: "4.9.2"
  firebase_messaging_web:
    dependency: transitive
    description:
      name: firebase_messaging_web
      sha256: fcd25d0b9da55766ef4d28ae05a7460f5189635d6b42607adcd9f08818fd35f0
      url: "https://pub.dev"
    source: hosted
    version: "4.2.3"
  firebase_storage:
    dependency: "direct main"
    description:
      name: firebase_storage
      sha256: f81f2156232bc13f219bb65a80c46f9914d2a85589024b8cacc2bef072f7131e
      url: "https://pub.dev"
    source: hosted
    version: "13.4.5"
  firebase_storage_platform_interface:
    dependency: transitive
    description:
      name: firebase_storage_platform_interface
      sha256: d64ba6f7880b64cc095fdc07170adf9b0f3762b00b070cbfdaeff66b3cd737a6
      url: "https://pub.dev"
    source: hosted
    version: "6.0.5"
  firebase_storage_web:
    dependency: transitive
    description:
      name: firebase_storage_web
      sha256: "7b28cad89b8d11223cf1f94c0868929b99f74beb2c1611cce3dd5c02588d4bcd"
      url: "https://pub.dev"
    source: hosted
    version: "3.11.11"
  fixnum:
    dependency: transitive
    description:
      name: fixnum
      sha256: b6dc7065e46c974bc7c5f143080a6764ec7a4be6da1285ececdc37be96de53be
      url: "https://pub.dev"
    source: hosted
    version: "1.1.1"
  flutter:
    dependency: "direct main"
    description: flutter
    source: sdk
    version: "0.0.0"
  flutter_lints:
    dependency: "direct dev"
    description:
      name: flutter_lints
      sha256: "3105dc8492f6183fb076ccf1f351ac3d60564bff92e20bfc4af9cc1651f4e7e1"
      url: "https://pub.dev"
    source: hosted
    version: "6.0.0"
  flutter_plugin_android_lifecycle:
    dependency: transitive
    description:
      name: flutter_plugin_android_lifecycle
      sha256: "3854fe5e3bff0b113c658f260b90c95dea17c92db0f2addeac2e343dd9969785"
```

```
      url: "https://pub.dev"
    source: hosted
    version: "2.0.35"
  flutter_riverpod:
    dependency: "direct main"
    description:
      name: flutter_riverpod
      sha256: "9532ee6db4a943a1ed8383072a2e3eeda041db5657cdf6d2acecf3c21ecbe7e1"
      url: "https://pub.dev"
    source: hosted
    version: "2.6.1"
  flutter_svg:
    dependency: "direct main"
    description:
      name: flutter_svg
      sha256: "35882981abcbfb8c15b286f0cd690ff25bac12d95eff3e25ee207f37d4c42e7f"
      url: "https://pub.dev"
    source: hosted
    version: "2.3.0"
  flutter_test:
    dependency: "direct dev"
    description: flutter
    source: sdk
    version: "0.0.0"
  flutter_web_plugins:
    dependency: transitive
    description: flutter
    source: sdk
    version: "0.0.0"
  freezed_annotation:
    dependency: transitive
    description:
      name: freezed_annotation
      sha256: "7294967ff0a6d98638e7acb774aac3af2550777accd8149c90af5b014e6d44d8"
      url: "https://pub.dev"
    source: hosted
    version: "3.1.0"
  frontend_server_client:
    dependency: transitive
    description:
      name: frontend_server_client
      sha256: f64a0333a82f30b0cca061bc3d143813a486dc086b574bfb233b7c1372427694
      url: "https://pub.dev"
    source: hosted
    version: "4.0.0"
  glob:
    dependency: transitive
    description:
      name: glob
      sha256: c3f1ee72c96f8f78935e18aa8cecced9ab132419e8625dc187e1c2408efc20de
      url: "https://pub.dev"
    source: hosted
    version: "2.1.3"
  go_router:
    dependency: "direct main"
    description:
      name: go_router
      sha256: "5922b2861e2235a3504896f0d6fa07d84141b480cf52eecd2f42cd25585a9e8a"
      url: "https://pub.dev"
    source: hosted
    version: "17.3.0"
  google_fonts:
    dependency: "direct main"
    description:
```

```
      name: google_fonts
      sha256: d3f251381df389f7418d4dff416bd27c0a23138df22969aafd28c4a4b1bb3cd6
      url: "https://pub.dev"
    source: hosted
    version: "8.2.0"
  google_identity_services_web:
    dependency: transitive
    description:
      name: google_identity_services_web
      sha256: "5d187c46dc59e02646e10fe82665fc3884a9b71bc1c90c2b8b749316d33ee454"
      url: "https://pub.dev"
    source: hosted
    version: "0.3.3+1"
  google_sign_in:
    dependency: "direct main"
    description:
      name: google_sign_in
      sha256: "521031b65853b4409b8213c0387d57edaad7e2a949ce6dea0d8b2afc9cb29763"
      url: "https://pub.dev"
    source: hosted
    version: "7.2.0"
  google_sign_in_android:
    dependency: transitive
    description:
      name: google_sign_in_android
      sha256: a01d4fd5a0e4eb0c1961434a0289a436abf9225b0933963c8e4e5ed88c26e40b
      url: "https://pub.dev"
    source: hosted
    version: "7.2.15"
  google_sign_in_ios:
    dependency: transitive
    description:
      name: google_sign_in_ios
      sha256: ac1e4c1205267cb7999d1d81333fccffdfda29e853f434bbaf71525498bb6950
      url: "https://pub.dev"
    source: hosted
    version: "6.3.0"
  google_sign_in_platform_interface:
    dependency: transitive
    description:
      name: google_sign_in_platform_interface
      sha256: "7f59208c42b415a3cca203571128d6f84f885fead2d5b53eb65a9e27f2965bb5"
      url: "https://pub.dev"
    source: hosted
    version: "3.1.0"
  google_sign_in_web:
    dependency: transitive
    description:
      name: google_sign_in_web
      sha256: d473003eeca892f96a01a64fc803378be765071cb0c265ee872c7f8683245d14
      url: "https://pub.dev"
    source: hosted
    version: "1.1.3"
  graphs:
    dependency: transitive
    description:
      name: graphs
      sha256: "741bbf84165310a68ff28fe9e727332eef1407342fca52759cb21ad8177bb8d0"
      url: "https://pub.dev"
    source: hosted
    version: "2.3.2"
  hooks:
    dependency: transitive
    description:
```

```
      name: hooks
      sha256: "9a62a50b50b769a737bc0a8ff381f333529df3ab746b2f6b02e83760231455ba"
      url: "https://pub.dev"
    source: hosted
    version: "2.0.2"
  http:
    dependency: transitive
    description:
      name: http
      sha256: "87721a4a50b19c7f1d49001e51409bddc46303966ce89a65af4f4e6004896412"
      url: "https://pub.dev"
    source: hosted
    version: "1.6.0"
  http_multi_server:
    dependency: transitive
    description:
      name: http_multi_server
      sha256: aa6199f908078bb1c5efb8d8638d4ae191aac11b311132c3ef48ce352fb52ef8
      url: "https://pub.dev"
    source: hosted
    version: "3.2.2"
  http_parser:
    dependency: transitive
    description:
      name: http_parser
      sha256: "178d74305e7866013777bab2c3d8726205dc5a4dd935297175b19a23a2e66571"
      url: "https://pub.dev"
    source: hosted
    version: "4.1.2"
  image:
    dependency: transitive
    description:
      name: image
      sha256: "6300175e00616bbc832e2fc91bfa4d776af5402c81c7151bee6905bb08473c52"
      url: "https://pub.dev"
    source: hosted
    version: "4.9.1"
  image_cropper:
    dependency: "direct main"
    description:
      name: image_cropper
      sha256: "95782c9068ff09b95a5ece6a2b5fb31b18d8e544d79ebfa7bdafc08df39b3440"
      url: "https://pub.dev"
    source: hosted
    version: "12.2.1"
  image_cropper_for_web:
    dependency: transitive
    description:
      name: image_cropper_for_web
      sha256: e09749714bc24c4e3b31fbafa2e5b7229b0ff23e8b14d4ba44bd723b77611a0f
      url: "https://pub.dev"
    source: hosted
    version: "7.0.0"
  image_cropper_platform_interface:
    dependency: transitive
    description:
      name: image_cropper_platform_interface
      sha256: "886a30ec199362cdcc2fbb053b8e53347fbfb9dbbdaa94f9ff85622609f5e7ff"
      url: "https://pub.dev"
    source: hosted
    version: "8.0.0"
  image_picker:
    dependency: "direct main"
    description:
```

```
      name: image_picker
      sha256: d8402284df184bc05f4a2210c6c23983b0720f4cd87cbd05c5390a78af602667
      url: "https://pub.dev"
    source: hosted
    version: "1.2.3"
  image_picker_android:
    dependency: transitive
    description:
      name: image_picker_android
      sha256: "6f3a1995eafb000333174fae92202622033b0ee7fd917a6cd3730295264df84a"
      url: "https://pub.dev"
    source: hosted
    version: "0.8.13+19"
  image_picker_for_web:
    dependency: transitive
    description:
      name: image_picker_for_web
      sha256: "66257a3191ab360d23a55c8241c91a6e329d31e94efa7be9cf7a212e65850214"
      url: "https://pub.dev"
    source: hosted
    version: "3.1.1"
  image_picker_ios:
    dependency: transitive
    description:
      name: image_picker_ios
      sha256: b9c4a438a9ff4f60808c9cf0039b93a42bb6c2211ef6ebb647394b2b3fa84588
      url: "https://pub.dev"
    source: hosted
    version: "0.8.13+6"
  image_picker_linux:
    dependency: transitive
    description:
      name: image_picker_linux
      sha256: "1f81c5f2046b9ab724f85523e4af65be1d47b038160a8c8deed909762c308ed4"
      url: "https://pub.dev"
    source: hosted
    version: "0.2.2"
  image_picker_macos:
    dependency: transitive
    description:
      name: image_picker_macos
      sha256: "86f0f15a309de7e1a552c12df9ce5b59fe927e71385329355aec4776c6a8ec91"
      url: "https://pub.dev"
    source: hosted
    version: "0.2.2+1"
  image_picker_platform_interface:
    dependency: transitive
    description:
      name: image_picker_platform_interface
      sha256: "567e056716333a1647c64bb6bd873cff7622233a5c3f694be28a583d4715690c"
      url: "https://pub.dev"
    source: hosted
    version: "2.11.1"
  image_picker_windows:
    dependency: transitive
    description:
      name: image_picker_windows
      sha256: d248c86554a72b5495a31c56f060cf73a41c7ff541689327b1a7dbccc33adfae
      url: "https://pub.dev"
    source: hosted
    version: "0.2.2"
  io:
    dependency: transitive
    description:
```

```
      name: io
      sha256: dfd5a80599cf0165756e3181807ed3e77daf6dd4137caaad72d0b7931597650b
      url: "https://pub.dev"
    source: hosted
    version: "1.0.5"
  jni:
    dependency: transitive
    description:
      name: jni
      sha256: "5bc9a9daac5ccfbd6a758377600b9f7fdce13d93f26e8012a8941014a5d978d1"
      url: "https://pub.dev"
    source: hosted
    version: "1.0.2"
  jni_flutter:
    dependency: transitive
    description:
      name: jni_flutter
      sha256: "7b717011ea40d04fd47c2731d3d1d36eb99eba3435c2753d62489e8c3c9991d5"
      url: "https://pub.dev"
    source: hosted
    version: "1.0.2"
  jni_util:
    dependency: transitive
    description:
      name: jni_util
      sha256: "1ba86da04a5f2bf18fde2edb235587e70c5b0fc5bd4ba955f46b00942c3fc35f"
      url: "https://pub.dev"
    source: hosted
    version: "1.0.0"
  js:
    dependency: transitive
    description:
      name: js
      sha256: "53385261521cc4a0c4658fd0ad07a7d14591cf8fc33abbceae306ddb974888dc"
      url: "https://pub.dev"
    source: hosted
    version: "0.7.2"
  json_annotation:
    dependency: transitive
    description:
      name: json_annotation
      sha256: "2a743920d81b7910627f68ee2c9ac1fc0bfee32b9fc3403587d7c6791ca12f80"
      url: "https://pub.dev"
    source: hosted
    version: "4.12.0"
  leak_tracker:
    dependency: transitive
    description:
      name: leak_tracker
      sha256: "33e2e26bdd85a0112ec15400c8cbffea70d0f9c3407491f672a2fad47915e2de"
      url: "https://pub.dev"
    source: hosted
    version: "11.0.2"
  leak_tracker_flutter_testing:
    dependency: transitive
    description:
      name: leak_tracker_flutter_testing
      sha256: "1dbc140bb5a23c75ea9c4811222756104fbcd1a27173f0c34ca01e16bea473c1"
      url: "https://pub.dev"
    source: hosted
    version: "3.0.10"
  leak_tracker_testing:
    dependency: transitive
    description:
```

```
      name: leak_tracker_testing
      sha256: "8d5a2d49f4a66b49744b23b018848400d23e54caf9463f4eb20df3eb8acb2eb1"
      url: "https://pub.dev"
    source: hosted
    version: "3.0.2"
  lints:
    dependency: transitive
    description:
      name: lints
      sha256: "12f842a479589fea194fe5c5a3095abc7be0c1f2ddfa9a0e76aed1dbd26a87df"
      url: "https://pub.dev"
    source: hosted
    version: "6.1.0"
  logging:
    dependency: transitive
    description:
      name: logging
      sha256: c8245ada5f1717ed44271ed1c26b8ce85ca3228fd2ffdb75468ab01979309d61
      url: "https://pub.dev"
    source: hosted
    version: "1.3.0"
  matcher:
    dependency: transitive
    description:
      name: matcher
      sha256: dc0b7dc7651697ea4ff3e69ef44b0407ea32c487a39fff6a4004fa585e901861
      url: "https://pub.dev"
    source: hosted
    version: "0.12.19"
  material_color_utilities:
    dependency: transitive
    description:
      name: material_color_utilities
      sha256: "9c337007e82b1889149c82ed242ed1cb24a66044e30979c44912381e9be4c48b"
      url: "https://pub.dev"
    source: hosted
    version: "0.13.0"
  meta:
    dependency: transitive
    description:
      name: meta
      sha256: "1741988757a65eb6b36abe716829688cf01910bbf91c34354ff7ec1c3de2b349"
      url: "https://pub.dev"
    source: hosted
    version: "1.18.0"
  mime:
    dependency: transitive
    description:
      name: mime
      sha256: "41a20518f0cb1256669420fdba0cd90d21561e560ac240f26ef8322e45bb7ed6"
      url: "https://pub.dev"
    source: hosted
    version: "2.0.0"
  mobile_scanner:
    dependency: "direct main"
    description:
      name: mobile_scanner
      sha256: "5a51ea79f0cf8293f616a5d08baae185b59b5e6bb24df01f2a63037ade0bade0"
      url: "https://pub.dev"
    source: hosted
    version: "7.4.2"
  objective_c:
    dependency: transitive
    description:
```

```
      name: objective_c
      sha256: b7fb95a6d9a4f009edd63dc5ac69f07420b23a16161c6dd8660290b59c602e8e
      url: "https://pub.dev"
    source: hosted
    version: "9.5.0"
  package_config:
    dependency: transitive
    description:
      name: package_config
      sha256: f096c55ebb7deb7e384101542bfba8c52696c1b56fca2eb62827989ef2353bbc
      url: "https://pub.dev"
    source: hosted
    version: "2.2.0"
  path:
    dependency: transitive
    description:
      name: path
      sha256: "75cca69d1490965be98c73ceaea117e8a04dd21217b37b292c9ddbec0d955bc5"
      url: "https://pub.dev"
    source: hosted
    version: "1.9.1"
  path_parsing:
    dependency: transitive
    description:
      name: path_parsing
      sha256: "883402936929eac138ee0a45da5b0f2c80f89913e6dc3bf77eb65b84b409c6ca"
      url: "https://pub.dev"
    source: hosted
    version: "1.1.0"
  path_provider:
    dependency: "direct main"
    description:
      name: path_provider
      sha256: a7f4874f987173da295a61c181b8ee71dab59b332a486b391babf26a1b884825
      url: "https://pub.dev"
    source: hosted
    version: "2.1.6"
  path_provider_android:
    dependency: transitive
    description:
      name: path_provider_android
      sha256: "69cbd515a62b94d32a7944f086b2f82b4ac40a1d45bebfc00813a430ab2dabcd"
      url: "https://pub.dev"
    source: hosted
    version: "2.3.1"
  path_provider_foundation:
    dependency: transitive
    description:
      name: path_provider_foundation
      sha256: "2a376b7d6392d80cd3705782d2caa734ca4727776db0b6ec36ef3f1855197699"
      url: "https://pub.dev"
    source: hosted
    version: "2.6.0"
  path_provider_linux:
    dependency: transitive
    description:
      name: path_provider_linux
      sha256: "58c2005f147315b11e9b4a7bc889cd5203e250cba8e3f012dae259b4972b5c16"
      url: "https://pub.dev"
    source: hosted
    version: "2.2.2"
  path_provider_platform_interface:
    dependency: transitive
    description:
```

```
      name: path_provider_platform_interface
      sha256: "484838772624c3a4b94f1e44a3e19897fee738f2d5c4ce448443b0417f7c9dda"
      url: "https://pub.dev"
    source: hosted
    version: "2.1.3"
  path_provider_windows:
    dependency: transitive
    description:
      name: path_provider_windows
      sha256: bd6f00dbd873bfb70d0761682da2b3a2c2fccc2b9e84c495821639601d81afe7
      url: "https://pub.dev"
    source: hosted
    version: "2.3.0"
  pdf:
    dependency: "direct main"
    description:
      name: pdf
      sha256: "517df47af468734a23c8b513c0c6a8a62357403ab1b8ab7fad1606576a9dbdd0"
      url: "https://pub.dev"
    source: hosted
    version: "3.13.0"
  permission_handler:
    dependency: "direct main"
    description:
      name: permission_handler
      sha256: "59adad729136f01ea9e35a48f5d1395e25cba6cea552249ddbe9cf950f5d7849"
      url: "https://pub.dev"
    source: hosted
    version: "11.4.0"
  permission_handler_android:
    dependency: transitive
    description:
      name: permission_handler_android
      sha256: d3971dcdd76182a0c198c096b5db2f0884b0d4196723d21a866fc4cdea057ebc
      url: "https://pub.dev"
    source: hosted
    version: "12.1.0"
  permission_handler_apple:
    dependency: transitive
    description:
      name: permission_handler_apple
      sha256: "79dfa1df734798aa3cfdad166d3a3698c206d8813de13516ea1071b5d7e2f420"
      url: "https://pub.dev"
    source: hosted
    version: "9.4.10"
  permission_handler_html:
    dependency: transitive
    description:
      name: permission_handler_html
      sha256: "38f000e83355abb3392140f6bc3030660cfaef189e1f87824facb76300b4ff24"
      url: "https://pub.dev"
    source: hosted
    version: "0.1.3+5"
  permission_handler_platform_interface:
    dependency: transitive
    description:
      name: permission_handler_platform_interface
      sha256: eb99b295153abce5d683cac8c02e22faab63e50679b937fa1bf67d58bb282878
      url: "https://pub.dev"
    source: hosted
    version: "4.3.0"
  permission_handler_windows:
    dependency: transitive
    description:
```

```
      name: permission_handler_windows
      sha256: "1a790728016f79a41216d88672dbc5df30e686e811ad4e698bfc51f76ad91f1e"
      url: "https://pub.dev"
    source: hosted
    version: "0.2.1"
  petitparser:
    dependency: transitive
    description:
      name: petitparser
      sha256: "91bd59303e9f769f108f8df05e371341b15d59e995e6806aefab827b58336675"
      url: "https://pub.dev"
    source: hosted
    version: "7.0.2"
  platform:
    dependency: transitive
    description:
      name: platform
      sha256: "5d6b1b0036a5f331ebc77c850ebc8506cbc1e9416c27e59b439f917a902a4984"
      url: "https://pub.dev"
    source: hosted
    version: "3.1.6"
  plugin_platform_interface:
    dependency: transitive
    description:
      name: plugin_platform_interface
      sha256: "4820fbfdb9478b1ebae27888254d445073732dae3d6ea81f0b7e06d5dedc3f02"
      url: "https://pub.dev"
    source: hosted
    version: "2.1.8"
  pool:
    dependency: transitive
    description:
      name: pool
      sha256: "978783255c543aa3586a1b3c21f6e9d720eb315376a915872c61ef8b5c20177d"
      url: "https://pub.dev"
    source: hosted
    version: "1.5.2"
  posix:
    dependency: transitive
    description:
      name: posix
      sha256: bc1bad54ad2b735816e31f8d4600cfde6c7839975085ddfbca48b6c9f7c4044e
      url: "https://pub.dev"
    source: hosted
    version: "6.5.2"
  pub_semver:
    dependency: transitive
    description:
      name: pub_semver
      sha256: "5bfcf68ca79ef689f8990d1160781b4bad40a3bd5e5218ad4076ddb7f4081585"
      url: "https://pub.dev"
    source: hosted
    version: "2.2.0"
  pubspec_parse:
    dependency: transitive
    description:
      name: pubspec_parse
      sha256: "0560ba233314abbed0a48a2956f7f022cce7c3e1e73df540277da7544cad4082"
      url: "https://pub.dev"
    source: hosted
    version: "1.5.0"
  qr:
    dependency: transitive
    description:
```

```
      name: qr
      sha256: "5a1d2586170e172b8a8c8470bbbffd5eb0cd38a66c0d77155ea138d3af3a4445"
      url: "https://pub.dev"
    source: hosted
    version: "3.0.2"
  qr_flutter:
    dependency: "direct main"
    description:
      name: qr_flutter
      sha256: "5095f0fc6e3f71d08adef8feccc8cea4f12eec18a2e31c2e8d82cb6019f4b097"
      url: "https://pub.dev"
    source: hosted
    version: "4.1.0"
  razorpay_flutter:
    dependency: "direct main"
    description:
      name: razorpay_flutter
      sha256: f0ffd4e162f0c4c8d72e512deaece22d2179e653e470fd794865283c28ff9079
      url: "https://pub.dev"
    source: hosted
    version: "1.4.7"
  record_use:
    dependency: transitive
    description:
      name: record_use
      sha256: "2551bd8eecfe95d14ae75f6021ad0248be5c27f138c2ec12fcb52b500b3ba1ed"
      url: "https://pub.dev"
    source: hosted
    version: "0.6.0"
  riverpod:
    dependency: transitive
    description:
      name: riverpod
      sha256: "59062512288d3056b2321804332a13ffdd1bf16df70dcc8e506e411280a72959"
      url: "https://pub.dev"
    source: hosted
    version: "2.6.1"
  riverpod_analyzer_utils:
    dependency: transitive
    description:
      name: riverpod_analyzer_utils
      sha256: "03a17170088c63aab6c54c44456f5ab78876a1ddb6032ffde1662ddab4959611"
      url: "https://pub.dev"
    source: hosted
    version: "0.5.10"
  riverpod_annotation:
    dependency: "direct main"
    description:
      name: riverpod_annotation
      sha256: e14b0bf45b71326654e2705d462f21b958f987087be850afd60578fcd502d1b8
      url: "https://pub.dev"
    source: hosted
    version: "2.6.1"
  riverpod_generator:
    dependency: "direct dev"
    description:
      name: riverpod_generator
      sha256: "44a0992d54473eb199ede00e2260bd3c262a86560e3c6f6374503d86d0580e36"
      url: "https://pub.dev"
    source: hosted
    version: "2.6.5"
  share_plus:
    dependency: "direct main"
    description:
```

```
      name: share_plus
      sha256: "34f00f9becd2743c1fb05363d624f9f70d37f7ccdcdda47450bc0b8c9d327b8c"
      url: "https://pub.dev"
    source: hosted
    version: "13.3.0"
  share_plus_platform_interface:
    dependency: transitive
    description:
      name: share_plus_platform_interface
      sha256: "365ef7379fc22507256adda3385152942ffce08935452bc972c2e52a0bebae41"
      url: "https://pub.dev"
    source: hosted
    version: "7.2.0"
  shared_preferences:
    dependency: "direct main"
    description:
      name: shared_preferences
      sha256: c3025c5534b01739267eb7d76959bbc25a6d10f6988e1c2a3036940133dd10bf
      url: "https://pub.dev"
    source: hosted
    version: "2.5.5"
  shared_preferences_android:
    dependency: transitive
    description:
      name: shared_preferences_android
      sha256: "0634e64bd719f89c012f392938e173521f535d3ecaf66558fa94a056d22b5cc7"
      url: "https://pub.dev"
    source: hosted
    version: "2.4.27"
  shared_preferences_foundation:
    dependency: transitive
    description:
      name: shared_preferences_foundation
      sha256: "4e7eaffc2b17ba398759f1151415869a34771ba11ebbccd1b0145472a619a64f"
      url: "https://pub.dev"
    source: hosted
    version: "2.5.6"
  shared_preferences_linux:
    dependency: transitive
    description:
      name: shared_preferences_linux
      sha256: "580abfd40f415611503cae30adf626e6656dfb2f0cee8f465ece7b6defb40f2f"
      url: "https://pub.dev"
    source: hosted
    version: "2.4.1"
  shared_preferences_platform_interface:
    dependency: transitive
    description:
      name: shared_preferences_platform_interface
      sha256: "649dc798a33931919ea356c4305c2d1f81619ea6e92244070b520187b5140ef9"
      url: "https://pub.dev"
    source: hosted
    version: "2.4.2"
  shared_preferences_web:
    dependency: transitive
    description:
      name: shared_preferences_web
      sha256: c49bd060261c9a3f0ff445892695d6212ff603ef3115edbb448509d407600019
      url: "https://pub.dev"
    source: hosted
    version: "2.4.3"
  shared_preferences_windows:
    dependency: transitive
    description:
```

```
      name: shared_preferences_windows
      sha256: "94ef0f72b2d71bc3e700e025db3710911bd51a71cefb65cc609dd0d9a982e3c1"
      url: "https://pub.dev"
    source: hosted
    version: "2.4.1"
  shelf:
    dependency: transitive
    description:
      name: shelf
      sha256: e7dd780a7ffb623c57850b33f43309312fc863fb6aa3d276a754bb299839ef12
      url: "https://pub.dev"
    source: hosted
    version: "1.4.2"
  shelf_web_socket:
    dependency: transitive
    description:
      name: shelf_web_socket
      sha256: "3632775c8e90d6c9712f883e633716432a27758216dfb61bd86a8321c0580925"
      url: "https://pub.dev"
    source: hosted
    version: "3.0.0"
  sky_engine:
    dependency: transitive
    description: flutter
    source: sdk
    version: "0.0.0"
  source_gen:
    dependency: transitive
    description:
      name: source_gen
      sha256: "35c8150ece9e8c8d263337a265153c3329667640850b9304861faea59fc98f6b"
      url: "https://pub.dev"
    source: hosted
    version: "2.0.0"
  source_span:
    dependency: transitive
    description:
      name: source_span
      sha256: "56a02f1f4cd1a2d96303c0144c93bd6d909eea6bee6bf5a0e0b685edbd4c47ab"
      url: "https://pub.dev"
    source: hosted
    version: "1.10.2"
  stack_trace:
    dependency: transitive
    description:
      name: stack_trace
      sha256: "8b27215b45d22309b5cddda1aa2b19bdfec9df0e765f2de506401c071d38d1b1"
      url: "https://pub.dev"
    source: hosted
    version: "1.12.1"
  state_notifier:
    dependency: transitive
    description:
      name: state_notifier
      sha256: b8677376aa54f2d7c58280d5a007f9e8774f1968d1fb1c096adcb4792fba29bb
      url: "https://pub.dev"
    source: hosted
    version: "1.0.0"
  stream_channel:
    dependency: transitive
    description:
      name: stream_channel
      sha256: "969e04c80b8bcdf826f8f16579c7b14d780458bd97f56d107d3950fdbeef059d"
      url: "https://pub.dev"
```

```
    source: hosted
    version: "2.1.4"
  stream_transform:
    dependency: transitive
    description:
      name: stream_transform
      sha256: ad47125e588cfd37a9a7f86c7d6356dde8dfe89d071d293f80ca9e9273a33871
      url: "https://pub.dev"
    source: hosted
    version: "2.1.1"
  string_scanner:
    dependency: transitive
    description:
      name: string_scanner
      sha256: "921cd31725b72fe181906c6a94d987c78e3b98c2e205b397ea399d4054872b43"
      url: "https://pub.dev"
    source: hosted
    version: "1.4.1"
  term_glyph:
    dependency: transitive
    description:
      name: term_glyph
      sha256: "7f554798625ea768a7518313e58f83891c7f5024f88e46e7182a4558850a4b8e"
      url: "https://pub.dev"
    source: hosted
    version: "1.2.2"
  test_api:
    dependency: transitive
    description:
      name: test_api
      sha256: "949a932224383300f01be9221c39180316445ecb8e7547f70a41a35bf421fb9e"
      url: "https://pub.dev"
    source: hosted
    version: "0.7.11"
  timing:
    dependency: transitive
    description:
      name: timing
      sha256: "62ee18aca144e4a9f29d212f5a4c6a053be252b895ab14b5821996cff4ed90fe"
      url: "https://pub.dev"
    source: hosted
    version: "1.0.2"
  typed_data:
    dependency: transitive
    description:
      name: typed_data
      sha256: f9049c039ebfeb4cf7a7104a675823cd72dba8297f264b6637062516699fa006
      url: "https://pub.dev"
    source: hosted
    version: "1.4.0"
  url_launcher_linux:
    dependency: transitive
    description:
      name: url_launcher_linux
      sha256: d5e14138b3bc193a0f63c10a53c94b91d399df0512b1f29b94a043db7482384a
      url: "https://pub.dev"
    source: hosted
    version: "3.2.2"
  url_launcher_platform_interface:
    dependency: transitive
    description:
      name: url_launcher_platform_interface
      sha256: "552f8a1e663569be95a8190206a38187b531910283c3e982193e4f2733f01029"
      url: "https://pub.dev"
```

```
    source: hosted
    version: "2.3.2"
  url_launcher_web:
    dependency: transitive
    description:
      name: url_launcher_web
      sha256: "85c81589622fbc87c1c683aaea164d3604a7777495a79d91e39ffcdec39ddb34"
      url: "https://pub.dev"
    source: hosted
    version: "2.4.3"
  url_launcher_windows:
    dependency: transitive
    description:
      name: url_launcher_windows
      sha256: "712c70ab1b99744ff066053cbe3e80c73332b38d46e5e945c98689b2e66fc15f"
      url: "https://pub.dev"
    source: hosted
    version: "3.1.5"
  uuid:
    dependency: transitive
    description:
      name: uuid
      sha256: "9b129329f58692f6e6578329498a8fe9fbe98f090beb764ffbb8ee2eadd01dcd"
      url: "https://pub.dev"
    source: hosted
    version: "4.6.0"
  vector_graphics:
    dependency: transitive
    description:
      name: vector_graphics
      sha256: "2306c03da2ba81724afeb589c351ebbc0aa7d86005925be8f8735856dbe5e42d"
      url: "https://pub.dev"
    source: hosted
    version: "1.2.2"
  vector_graphics_codec:
    dependency: transitive
    description:
      name: vector_graphics_codec
      sha256: "99fd9fbd34d9f9a32efd7b6a6aae14125d8237b10403b422a6a6dfeac2806146"
      url: "https://pub.dev"
    source: hosted
    version: "1.1.13"
  vector_graphics_compiler:
    dependency: transitive
    description:
      name: vector_graphics_compiler
      sha256: "4dca4feb77dc3ec7f6e27e49c53241eb8217f55e4f9b12599a27f8903bca5682"
      url: "https://pub.dev"
    source: hosted
    version: "1.3.0"
  vector_math:
    dependency: transitive
    description:
      name: vector_math
      sha256: d530bd74fea330e6e364cda7a85019c434070188383e1cd8d9777ee586914c5b
      url: "https://pub.dev"
    source: hosted
    version: "2.2.0"
  vm_service:
    dependency: transitive
    description:
      name: vm_service
      sha256: "0016aef94fc66495ac78af5859181e3f3bf2026bd8eecc72b9565601e19ab360"
      url: "https://pub.dev"
```

```
    source: hosted
    version: "15.2.0"
  watcher:
    dependency: transitive
    description:
      name: watcher
      sha256: "1398c9f081a753f9226febe8900fce8f7d0a67163334e1c94a2438339d79d635"
      url: "https://pub.dev"
    source: hosted
    version: "1.2.1"
  web:
    dependency: transitive
    description:
      name: web
      sha256: "868d88a33d8a87b18ffc05f9f030ba328ffefba92d6c127917a2ba740f9cfe4a"
      url: "https://pub.dev"
    source: hosted
    version: "1.1.1"
  web_socket:
    dependency: transitive
    description:
      name: web_socket
      sha256: "34d64019aa8e36bf9842ac014bb5d2f5586ca73df5e4d9bf5c936975cae6982c"
      url: "https://pub.dev"
    source: hosted
    version: "1.0.1"
  web_socket_channel:
    dependency: transitive
    description:
      name: web_socket_channel
      sha256: d645757fb0f4773d602444000a8131ff5d48c9e47adfe9772652dd1a4f2d45c8
      url: "https://pub.dev"
    source: hosted
    version: "3.0.3"
  win32:
    dependency: transitive
    description:
      name: win32
      sha256: ba6f4bba816c8d7e3c1580e170f3786d216951cc6b94babc3b814c08d2cb2738
      url: "https://pub.dev"
    source: hosted
    version: "6.3.0"
  xdg_directories:
    dependency: transitive
    description:
      name: xdg_directories
      sha256: "7a3f37b05d989967cdddcbb571f1ea834867ae2faa29725fd085180e0883aa15"
      url: "https://pub.dev"
    source: hosted
    version: "1.1.0"
  xml:
    dependency: transitive
    description:
      name: xml
      sha256: "67f0aff7be013d107995e9b75bf4e7f2c3ef2dfdb2c8e68024bba0a7fd5756a4"
      url: "https://pub.dev"
    source: hosted
    version: "7.0.1"
  yaml:
    dependency: transitive
    description:
      name: yaml
      sha256: b9da305ac7c39faa3f030eccd175340f968459dae4af175130b3fc47e40d76ce
      url: "https://pub.dev"
```

```
    source: hosted
    version: "3.1.3"
sdks:
  dart: ">=3.12.2 <4.0.0"
  flutter: ">=3.44.0"
```

```
================================================
FILE: pubspec.yaml
================================================
name: icem_bus
description: "A new Flutter project."
# The following line prevents the package from being accidentally published to
# pub.dev using `flutter pub publish`. This is preferred for private packages.
publish_to: 'none' # Remove this line if you wish to publish to pub.dev
```

```
# The following defines the version and build number for your application.
# A version number is three numbers separated by dots, like 1.2.43
# followed by an optional build number separated by a +.
```

```
# Both the version and the builder number may be overridden in flutter
```

```
# build by specifying --build-name and --build-number, respectively.
# In Android, build-name is used as versionName while build-number used as
versionCode.
# Read more about Android versioning at
https://developer.android.com/studio/publish/versioning
# In iOS, build-name is used as CFBundleShortVersionString while build-number is
used as CFBundleVersion.
```

```
# Read more about iOS versioning at
# https://developer.apple.com/library/archive/documentation/General/Reference/
InfoPlistKeyReference/Articles/CoreFoundationKeys.html
```

```
# In Windows, build-name is used as the major, minor, and patch parts
# of the product and file versions while build-number is used as the build
suffix.
version: 1.0.0+1
environment:
  sdk: ^3.12.2
```

```
# Dependencies specify other packages that your package needs in order to work.
# To automatically upgrade your package dependencies to the latest versions
# consider running `flutter pub upgrade --major-versions`. Alternatively,
```

```
# dependencies can be manually updated by changing the version numbers below to
# the latest version available on pub.dev. To see which dependencies have newer
# versions available, run `flutter pub outdated`.
dependencies:
  flutter:
    sdk: flutter
```

```
  # The following adds the Cupertino Icons font to your application.
  # Use with the CupertinoIcons class for iOS style icons.
  cupertino_icons: ^1.0.8
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5
  go_router: ^17.3.0
  firebase_core: ^4.12.1
  firebase_auth: ^6.5.6
  cloud_firestore: ^6.7.1
  firebase_storage: ^13.4.5
  firebase_messaging: ^16.4.3
  shared_preferences: ^2.5.5
  google_fonts: ^8.2.0
  flutter_svg: ^2.3.0
  google_sign_in: ^7.2.0
```

```
  image_picker: ^1.0.7
  image_cropper: ^12.2.1
  permission_handler: ^11.3.0
  qr_flutter: ^4.1.0
  pdf: ^3.13.0
  path_provider: ^2.1.6
  share_plus: ^13.3.0
  equatable: ^2.1.0
  razorpay_flutter: ^1.4.7
  mobile_scanner: ^7.4.2
```

```
dev_dependencies:
  flutter_test:
    sdk: flutter
```

```
  # The "flutter_lints" package below contains a set of recommended lints to
  # encourage good coding practices. The lint set provided by the package is
  # activated in the `analysis_options.yaml` file located at the root of your
  # package. See that file for information about deactivating specific lint
  # rules and activating additional ones.
  flutter_lints: ^6.0.0
  build_runner: ^2.4.0
  riverpod_generator: ^2.4.0
```

```
# For information on the generic Dart part of this file, see the
# following page: https://dart.dev/tools/pub/pubspec
```

```
# The following section is specific to Flutter packages.
flutter:
```

```
  # The following line ensures that the Material Icons font is
  # included with your application, so that you can use the icons in
  # the material Icons class.
  uses-material-design: true
```

```
  assets:
    - assets/images/bus_logo.png
    - assets/images/college_upi_qr.png
```

```
  # To add assets to your application, add an assets section, like this:
  # assets:
  #   - images/a_dot_burr.jpeg
  #   - images/a_dot_ham.jpeg
```

```
  # An image asset can refer to one or more resolution-specific "variants", see
  # https://flutter.dev/to/resolution-aware-images
  # For details regarding adding assets from package dependencies, see
  # https://flutter.dev/to/asset-from-package
```

```
  # To add custom fonts to your application, add a fonts section here,
  # in this "flutter" section. Each entry in this list should have a
  # "family" key with the font family name, and a "fonts" key with a
  # list giving the asset and other descriptors for the font. For
  # example:
  # fonts:
  #   - family: Schyler
  #     fonts:
  #       - asset: fonts/Schyler-Regular.ttf
  #       - asset: fonts/Schyler-Italic.ttf
  #         style: italic
  #   - family: Trajan Pro
  #     fonts:
  #       - asset: fonts/TrajanPro.ttf
```

```
  #       - asset: fonts/TrajanPro_Bold.ttf
  #         weight: 700
  #
```

- `# For details regarding fonts from package dependencies,` 

- `# see https://flutter.dev/to/font-from-package` 

```
================================================
```

```
FILE: .metadata
```

- `================================================ # This file tracks properties of this Flutter project.` 

- `# Used by Flutter tool to assess capabilities and perform upgrades etc.` 

- `# # This file should be version controlled and should not be manually edited.` 

```
version:
  revision: "ee80f08bbf97172ec030b8751ceab557177a34a6"
  channel: "stable"
```

```
project_type: app
```

```
# Tracks metadata for the flutter migrate command
migration:
  platforms:
    - platform: root
      create_revision: ee80f08bbf97172ec030b8751ceab557177a34a6
      base_revision: ee80f08bbf97172ec030b8751ceab557177a34a6
    - platform: android
      create_revision: ee80f08bbf97172ec030b8751ceab557177a34a6
      base_revision: ee80f08bbf97172ec030b8751ceab557177a34a6
    - platform: ios
      create_revision: ee80f08bbf97172ec030b8751ceab557177a34a6
      base_revision: ee80f08bbf97172ec030b8751ceab557177a34a6
    - platform: linux
      create_revision: ee80f08bbf97172ec030b8751ceab557177a34a6
      base_revision: ee80f08bbf97172ec030b8751ceab557177a34a6
    - platform: macos
      create_revision: ee80f08bbf97172ec030b8751ceab557177a34a6
      base_revision: ee80f08bbf97172ec030b8751ceab557177a34a6
    - platform: web
      create_revision: ee80f08bbf97172ec030b8751ceab557177a34a6
      base_revision: ee80f08bbf97172ec030b8751ceab557177a34a6
    - platform: windows
      create_revision: ee80f08bbf97172ec030b8751ceab557177a34a6
      base_revision: ee80f08bbf97172ec030b8751ceab557177a34a6
```

- `# User provided section` 

- `# List of Local paths (relative to this file) that should be # ignored by the migrate tool. #` 

- `# Files that are not part of the templates will be ignored by default. unmanaged_files:` 

- `'lib/main.dart'` 

- `'ios/Runner.xcodeproj/project.pbxproj'` 

```
================================================
FILE: android/build.gradle.kts
```

```
================================================
allprojects {
    repositories {
```

```
        google()
        mavenCentral()
    }
}
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)
```

```
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
```

```
================================================
FILE: android/gradle.properties
```

```
================================================
org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G -XX:ReservedCodeCacheSize=512m
-XX:+HeapDumpOnOutOfMemoryError
android.useAndroidX=true
# This newDsl flag was added by the Flutter template
android.newDsl=false
# This builtInKotlin flag was added by the Flutter template
android.builtInKotlin=false
kotlin.incremental=false
```

```
================================================
FILE: android/settings.gradle.kts
================================================
pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in
local.properties" }
            flutterSdkPath
        }
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
```

```
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
}
```

```
include(":app")
```

```
================================================
FILE: android/app/build.gradle.kts
================================================
plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin
Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}
android {
    namespace = "com.icem.bus.icem_bus"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    defaultConfig {
        // TODO: Specify your own unique Application ID
(https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.icem.bus.icem_bus"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-
config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release`
works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}
flutter {
    source = "../.."
}
```

```
================================================
FILE: android/app/google-services.json
================================================
{
  "project_info": {
    "project_number": "924572816848",
    "project_id": "icem-bus",
    "storage_bucket": "icem-bus.firebasestorage.app"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:924572816848:android:a62a90c1a5b188fa24d5d5",
        "android_client_info": {
          "package_name": "com.icem.bus.icem_bus"
        }
      },
      "oauth_client": [],
      "api_key": [
        {
          "current_key": "AIzaSyBI9aeUrqK0MB1w7dKaCfl4YUL_PtjP6U0"
        }
      ],
      "services": {
        "appinvite_service": {
          "other_platform_oauth_client": []
        }
      }
    }
  ],
  "configuration_version": "1"
}
```

```
================================================
FILE: android/app/src/debug/AndroidManifest.xml
================================================
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- The INTERNET permission is required for development. Specifically,
         the Flutter tool needs it to communicate with the running application
         to allow setting breakpoints, to provide hot reload, etc.
    -->
    <uses-permission android:name="android.permission.INTERNET"/>
</manifest>
```

```
================================================
FILE: android/app/src/main/AndroidManifest.xml
================================================
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
    <application
        android:label="icem_bus"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
```

```
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|
screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|
density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <!-- Specifies an Android theme to apply to this Activity as soon as
                 the Android process has started. This theme is visible to the
user
                 while the Flutter UI initializes. After that, this theme
continues
                 to determine the Window background behind the Flutter UI. -->
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <activity
            android:name="com.yalantis.ucrop.UCropActivity"
            android:screenOrientation="portrait"
            android:theme="@style/Theme.AppCompat.Light.NoActionBar"/>
        <!-- Don't delete the meta-data below.
             This is used by the Flutter tool to generate
GeneratedPluginRegistrant.java -->
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
    <!-- Required to query activities that can process text, see:
         https://developer.android.com/training/package-visibility and
         https://developer.android.com/reference/android/content/Intent#ACTION_P
ROCESS_TEXT.
```

```
         In particular, this is used by the Flutter engine in
io.flutter.plugin.text.ProcessTextPlugin. -->
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
</manifest>
```

```
================================================
FILE: android/app/src/main/kotlin/com/icem/bus/icem_bus/MainActivity.kt
================================================
package com.icem.bus.icem_bus
import io.flutter.embedding.android.FlutterActivity
class MainActivity : FlutterActivity()
```

```
================================================
FILE: android/app/src/main/res/drawable/launch_background.xml
```

```
================================================
```

```
<?xml version="1.0" encoding="utf-8"?>
<!-- Modify this file to customize your launch splash screen -->
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@android:color/white" />
```

```
    <!-- You can insert your own image assets here -->
    <!-- <item>
        <bitmap
            android:gravity="center"
            android:src="@mipmap/launch_image" />
    </item> -->
</layer-list>
```

```
================================================
FILE: android/app/src/main/res/drawable-v21/launch_background.xml
================================================
<?xml version="1.0" encoding="utf-8"?>
<!-- Modify this file to customize your launch splash screen -->
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="?android:colorBackground" />
    <!-- You can insert your own image assets here -->
    <!-- <item>
        <bitmap
            android:gravity="center"
            android:src="@mipmap/launch_image" />
    </item> -->
</layer-list>
```

```
================================================
FILE: android/app/src/main/res/values/styles.xml
================================================
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Theme applied to the Android Window while the process is starting when
the OS's Dark Mode setting is off -->
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <!-- Show a splash screen on the activity. Automatically removed when
             the Flutter engine draws its first frame -->
        <item name="android:windowBackground">@drawable/launch_background</item>
    </style>
    <!-- Theme applied to the Android Window as soon as the process has started.
         This theme determines the color of the Android Window while your
         Flutter UI initializes, as well as behind your Flutter UI while its
         running.
         This Theme is only used starting with V2 of Flutter's Android
embedding. -->
    <style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">?android:colorBackground</item>
    </style>
</resources>
```

```
================================================
FILE: android/app/src/main/res/values-night/styles.xml
================================================
<?xml version="1.0" encoding="utf-8"?>
```

```
<resources>
```

```
    <!-- Theme applied to the Android Window while the process is starting when
the OS's Dark Mode setting is on -->
    <style name="LaunchTheme" parent="@android:style/Theme.Black.NoTitleBar">
        <!-- Show a splash screen on the activity. Automatically removed when
             the Flutter engine draws its first frame -->
        <item name="android:windowBackground">@drawable/launch_background</item>
    </style>
    <!-- Theme applied to the Android Window as soon as the process has started.
         This theme determines the color of the Android Window while your
         Flutter UI initializes, as well as behind your Flutter UI while its
         running.
         This Theme is only used starting with V2 of Flutter's Android
embedding. -->
    <style name="NormalTheme" parent="@android:style/Theme.Black.NoTitleBar">
        <item name="android:windowBackground">?android:colorBackground</item>
    </style>
</resources>
```

```
================================================
FILE: android/app/src/profile/AndroidManifest.xml
================================================
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- The INTERNET permission is required for development. Specifically,
         the Flutter tool needs it to communicate with the running application
         to allow setting breakpoints, to provide hot reload, etc.
    -->
    <uses-permission android:name="android.permission.INTERNET"/>
</manifest>
```

```
================================================
FILE: android/gradle/wrapper/gradle-wrapper.properties
================================================
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-9.1.0-all.zip
```

```
================================================
FILE: functions/index.js
================================================
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("crypto");
const Razorpay = require("razorpay");
```

```
admin.initializeApp();
const db = admin.firestore();
```

```
// Server-side Razorpay credentials (never exposed to Flutter client)
// Configured via Firebase Environment Configuration or Secret Manager:
// firebase functions:config:set razorpay.key_id="rzp_test_..."
razorpay.key_secret="..."
const getRazorpayInstance = () => {
  const keyId =
    process.env.RAZORPAY_KEY_ID ||
```

```
    functions.config().razorpay?.key_id;
  const keySecret =
    process.env.RAZORPAY_KEY_SECRET ||
    functions.config().razorpay?.key_secret;
  if (!keyId || !keySecret) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Razorpay API credentials are not configured on the server. Please set
RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET."
    );
  }
  return {
    instance: new Razorpay({ key_id: keyId, key_secret: keySecret }),
    keyId,
    keySecret,
  };
};
/**
 * 1. CREATE RAZORPAY ORDER (Callable HTTPS Function)
 * Enforces server-side amount verification (₹4500 = 450000 paise).
 */
exports.createRazorpayOrder = functions.https.onCall(async (data, context) => {
  // Ensure student is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Authentication required to initiate payment."
    );
  }
  const { applicationId, routeId } = data;
  if (!applicationId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Application ID is required."
    );
  }
  const uid = context.auth.uid;
  // Verify application from Firestore
  const appDoc = await
db.collection("bus_pass_applications").doc(applicationId).get();
  if (!appDoc.exists) {
    throw new functions.https.HttpsError(
      "not-found",
      "Bus pass application record not found."
    );
  }
  const appData = appDoc.data();
  // Ensure the caller owns the application or is admin
  if (appData.uid !== uid && appData.studentId !== uid) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Unauthorized access to application."
    );
  }
  // Prevent double payment
  if (
```

```
    appData.paymentStatus === "Paid" ||
    appData.paymentStatus === "success"
  ) {
    throw new functions.https.HttpsError(
      "already-exists",
      "This application is already paid."
    );
  }
  // Strict route fare verification (Default 4500, or exact route fare from₹
database)
  const fare = Number(appData.fare) || 4500.0;
  const amountPaise = Math.round(fare * 100); // 4500 INR = 450000 paise
  const { instance, keyId } = getRazorpayInstance();
  const receiptReference = `RCPT-${applicationId.slice(-8)}-${Date.now()}`;
  try {
    const order = await instance.orders.create({
      amount: amountPaise,
      currency: "INR",
      receipt: receiptReference,
      notes: {
        applicationId,
        studentId: uid,
        studentName: appData.fullName || appData.studentName || "Student",
        route: appData.route || appData.routeName || "",
      },
    });
    // Create tracking payment attempt in `payments` collection
    const paymentRef = db.collection("payments").doc();
    const now = admin.firestore.FieldValue.serverTimestamp();
    await paymentRef.set({
      paymentId: paymentRef.id,
      applicationId,
      studentId: uid,
      studentName: appData.fullName || appData.studentName || "Student",
      routeId: routeId || appData.routeId || "",
      routeName: appData.route || appData.routeName || "Route",
      amount: fare,
      currency: "INR",
      razorpayOrderId: order.id,
      paymentStatus: "created",
      paymentMethod: "Razorpay",
      createdAt: now,
      updatedAt: now,
    });
    // Update application with active order ID
    await appDoc.ref.update({
      razorpayOrderId: order.id,
      activePaymentId: paymentRef.id,
      updatedAt: now,
    });
    return {
      orderId: order.id,
      keyId,
      amount: amountPaise,
      currency: "INR",
      paymentId: paymentRef.id,
    };
```

```
  } catch (err) {
    console.error("Razorpay order creation failed:", err);
    throw new functions.https.HttpsError(
      "internal",
      `Failed to create Razorpay order: ${err.message || err}`
    );
  }
```

```
});
/**
 * 2. VERIFY RAZORPAY PAYMENT (Callable HTTPS Function)
 * Verifies HMAC-SHA256 signature using Razorpay Key Secret.
 * Sets paymentStatus = "paid" and applicationStatus = "pending_admin_approval"
(NEVER auto-approved).
 */
exports.verifyRazorpayPayment = functions.https.onCall(async (data, context) =>
{
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Authentication required to verify payment."
    );
  }
  const {
    applicationId,
    paymentId,
    razorpayOrderId,
    razorpayPaymentId,
    razorpaySignature,
  } = data;
  if (
    !applicationId ||
    !razorpayOrderId ||
    !razorpayPaymentId ||
    !razorpaySignature
  ) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Missing required Razorpay verification parameters."
    );
  }
  const { keySecret } = getRazorpayInstance();
  // Compute expected HMAC SHA-256 signature: hmac_sha256(order_id + "|" +
razorpay_payment_id, secret)
  const expectedSignature = crypto
    .createHmac("sha256", keySecret)
    .update(`${razorpayOrderId}|${razorpayPaymentId}`)
    .digest("hex");
  const isSignatureValid = expectedSignature === razorpaySignature;
  if (!isSignatureValid) {
    console.error("Signature verification failed", {
      expected: expectedSignature,
      received: razorpaySignature,
    });
    if (paymentId) {
      await db.collection("payments").doc(paymentId).update({
        paymentStatus: "failed",
```

```
        failureReason: "Razorpay signature verification mismatch.",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    throw new functions.https.HttpsError(
      "permission-denied",
      "Payment verification failed: cryptographic signature mismatch."
    );
  }
```

```
  const now = admin.firestore.FieldValue.serverTimestamp();
```

```
  // 1. Update Payment Record to 'paid'
  const payDocRef = paymentId
    ? db.collection("payments").doc(paymentId)
    : db.collection("payments").doc();
  await payDocRef.set(
    {
      paymentStatus: "paid",
      razorpayPaymentId,
      razorpaySignature,
      paidAt: now,
      verifiedAt: now,
      updatedAt: now,
    },
    { merge: true }
  );
  // 2. Update Application Status to Pending Admin Approval
  const appDocRef = db.collection("bus_pass_applications").doc(applicationId);
  const appSnap = await appDocRef.get();
  if (appSnap.exists) {
    const appData = appSnap.data();
    await appDocRef.update({
      paymentStatus: "Paid",
      status: "Pending", // Pending Admin Approval
      passStatus: "Pending",
      paidAt: now,
      verifiedPaymentId: razorpayPaymentId,
      updatedAt: now,
    });
    // 3. Update Bus Pass document (status Pending, pass is NOT active yet)
    const studentUid = appData.uid || appData.studentId;
    if (studentUid) {
      await db.collection("bus_passes").doc(studentUid).set(
        {
          paymentStatus: "Paid",
          status: "Pending",
          passStatus: "Pending",
          updatedAt: now,
        },
        { merge: true }
      );
    }
    // 4. Generate Official Receipt
    const receiptRef = db.collection("receipts").doc(payDocRef.id);
    await receiptRef.set({
      receiptId: receiptRef.id,
      paymentId: payDocRef.id,
```

```
      applicationId,
      studentId: studentUid,
      studentName: appData.fullName || appData.studentName || "Student",
      route: appData.route || appData.routeName || "",
      routeId: appData.routeId || "",
      boarding: appData.boardingStop || "",
      destination: appData.destinationStop || "",
      fare: appData.fare || 4500.0,
      amount: appData.fare || 4500.0,
      paymentMethod: "Razorpay",
      transactionId: razorpayPaymentId,
      razorpayOrderId,
      razorpayPaymentId,
      paymentStatus: "Paid",
      paymentDate: now,
      createdAt: now,
    });
  }
  return {
    success: true,
    message: "Payment verified successfully. Awaiting administrative approval.",
    paymentId: payDocRef.id,
  };
});
/**
 * 3. RAZORPAY WEBHOOK (HTTP Request Function)
 * Reliable asynchronous server-to-server webhook processing.
 */
exports.razorpayWebhook = functions.https.onRequest(async (req, res) => {
  if (req.method !== "POST") {
    return res.status(405).send("Method Not Allowed");
  }
  const webhookSecret =
    process.env.RAZORPAY_WEBHOOK_SECRET ||
    functions.config().razorpay?.webhook_secret;
  if (webhookSecret) {
    const signature = req.headers["x-razorpay-signature"];
    const expectedSignature = crypto
      .createHmac("sha256", webhookSecret)
      .update(JSON.stringify(req.body))
      .digest("hex");
    if (signature !== expectedSignature) {
      console.warn("Invalid webhook signature received.");
      return res.status(400).send("Invalid Signature");
    }
  }
  const event = req.body.event;
  const payload = req.body.payload;
  if (event === "payment.captured") {
    const paymentEntity = payload.payment.entity;
    const orderId = paymentEntity.order_id;
    const paymentId = paymentEntity.id;
    // Find payment document by razorpayOrderId
    const payQuery = await db
      .collection("payments")
      .where("razorpayOrderId", "==", orderId)
```

```
      .limit(1)
      .get();
    if (!payQuery.empty) {
      const payDoc = payQuery.docs[0];
      const payData = payDoc.data();
      if (payData.paymentStatus !== "paid") {
        const now = admin.firestore.FieldValue.serverTimestamp();
        await payDoc.ref.update({
          paymentStatus: "paid",
          razorpayPaymentId: paymentId,
          paidAt: now,
          verifiedAt: now,
          updatedAt: now,
        });
        // Update application
        if (payData.applicationId) {
          const appRef =
db.collection("bus_pass_applications").doc(payData.applicationId);
          await appRef.update({
            paymentStatus: "Paid",
            status: "Pending",
            passStatus: "Pending",
            paidAt: now,
            updatedAt: now,
          });
        }
      }
    }
  }
  return res.status(200).json({ status: "ok" });
});
================================================
FILE: functions/package.json
================================================
{
  "name": "icem-bus-functions",
  "description": "Secure Firebase Cloud Functions for ICEM Bus Pass Payment
Processing",
  "scripts": {
    "lint": "eslint .",
    "serve": "firebase emulators:start --only functions",
    "shell": "firebase functions:shell",
    "start": "npm run shell",
    "deploy": "firebase deploy --only functions",
    "logs": "firebase functions:log"
  },
  "engines": {
    "node": "20"
  },
  "main": "index.js",
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^5.0.0",
    "razorpay": "^2.9.4"
  },
  "private": true
}
```

```
================================================
FILE: icem_bus/lib/features/admin/presentation/views/admin_dashboard.dart
================================================
// ignore_for_file: deprecated_member_use, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/routes/app_routes.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import
'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/features/admin/domain/admin_providers.dart';
import
'package:icem_bus/features/admin/presentation/views/admin_overview_tab.dart';
import
'package:icem_bus/features/admin/presentation/views/admin_applications_tab.dart'
;
import
'package:icem_bus/features/admin/presentation/views/admin_routes_tab.dart';
import
'package:icem_bus/features/admin/presentation/views/admin_buses_tab.dart';
import
'package:icem_bus/features/admin/presentation/views/admin_students_tab.dart';
import
'package:icem_bus/features/admin/presentation/views/admin_payments_tab.dart';
import
'package:icem_bus/features/admin/presentation/views/admin_notifications_tab.dart
';
import
'package:icem_bus/features/admin/presentation/views/admin_reports_tab.dart';
import
'package:icem_bus/features/admin/presentation/views/admin_settings_tab.dart';
```

```
// ============================================================
```

```
// ADMIN DASHBOARD SCREEN
```

```
// ============================================================
```

```
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});
```

```
  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}
```

```
class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
```

```
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final currentTab = ref.watch(adminTabProvider);
    final user = authState.user;
    final theme = Theme.of(context);
```

```
    // ── Auth Guard ──
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go(AppRoutes.login);
      });
```

```
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (user.role != 'Admin') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access Denied'),
            backgroundColor: AppColors.error,
          ),
        );
        context.go(AppRoutes.studentDashboard);
      });
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.gpp_bad_rounded,
                    size: 80, color: AppColors.primaryCrimson),
                const SizedBox(height: 24),
                Text(
                  'Access Denied',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Only Administrators are authorized to view this management
console.',
                  style: TextStyle(color: Color(0xFF475569)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
    final isMobile = MediaQuery.of(context).size.width < 900;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: isMobile && currentTab != 2 && currentTab != 3
          ? AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              title: Text(
                _getTabTitle(currentTab),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF0F172A),
                ),
              ),
```

```
              leading: IconButton(
                icon: const Icon(Icons.menu_rounded, color: Color(0xFF0F172A)),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout_rounded,
                      color: AppColors.primaryCrimson),
                  onPressed: () => _handleLogout(context),
                ),
              ],
              elevation: 0,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  height: 1,
                  color: const Color(0xFFF1F5F9),
                ),
              ),
            )
          : null,
      drawer: isMobile
          ? Drawer(
              backgroundColor: Colors.white,
              child: _buildSidebarContent(context, ref, currentTab,
                  isMobile: true),
            )
          : null,
      body: SafeArea(
        child: Row(
          children: [
            // ── Desktop Sidebar ──
            if (!isMobile) ...[
              SizedBox(
                width: 260,
                child: Container(
                  color: Colors.white,
                  child: _buildSidebarContent(context, ref, currentTab,
                      isMobile: false),
                ),
              ),
              Container(
                width: 1,
                color: const Color(0xFFF1F5F9),
              ),
            ],
            // ── Main Content ──
            Expanded(
              child: Container(
                color: const Color(0xFFF8FAFC),
                child: Column(
                  children: [
                    if (!isMobile) _buildDesktopHeader(context, user.fullName),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _buildTabContent(currentTab),
                      ),
                    ),
                  ],
                ),
              ),
```

```
            ),
          ],
        ),
      ),
    );
  }
```

```
  // ── Tab Content Switcher ──
  Widget _buildTabContent(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return const AdminOverviewTab(key: ValueKey('overview'));
      case 1:
        return const AdminApplicationsTab(key: ValueKey('applications'));
      case 2:
        return const AdminRoutesTab(key: ValueKey('routes'));
      case 3:
        return const AdminBusesTab(key: ValueKey('buses'));
      case 4:
        return const AdminStudentsTab(key: ValueKey('students'));
      case 5:
        return const AdminPaymentsTab(key: ValueKey('payments'));
      case 6:
        return const AdminNotificationsTab(key: ValueKey('notifications'));
      case 7:
        return const AdminReportsTab(key: ValueKey('reports'));
      case 8:
        return const AdminSettingsTab(key: ValueKey('settings'));
      default:
        return const AdminOverviewTab(key: ValueKey('overview'));
    }
  }
```

```
  // ── Tab Titles ──
  String _getTabTitle(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return 'Overview Dashboard';
      case 1:
        return 'Pass Management';
      case 2:
        return 'Route Management';
      case 3:
        return 'Bus Management';
      case 4:
        return 'Student Management';
      case 5:
        return 'Payment Management';
      case 6:
        return 'Notifications';
      case 7:
        return 'Reports & Analytics';
      case 8:
        return 'Settings';
      default:
        return 'Admin Portal';
    }
  }
  // ── Desktop Header ──
  Widget _buildDesktopHeader(BuildContext context, String adminName) {
    final currentTab = ref.watch(adminTabProvider);
```

```
    return Container(
```

```
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 18.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF1F5F9)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ICEM Transport Office',
                style: TextStyle(
                  color: AppColors.accentGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _getTabTitle(currentTab),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.admin_panel_settings_rounded,
                        color: AppColors.accentGold, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      adminName,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Material(
                color: AppColors.primaryCrimson.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
```

```
                  onTap: () => _handleLogout(context),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.logout_rounded,
                        color: AppColors.primaryCrimson, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  // ── Sidebar Content (shared between drawer and desktop sidebar) ──
  Widget _buildSidebarContent(
    BuildContext context,
    WidgetRef ref,
    int currentTab, {
    required bool isMobile,
  }) {
    final sidebarItems = [
      _SidebarItem(0, 'Dashboard', Icons.dashboard_rounded),
      _SidebarItem(1, 'Applications', Icons.badge_rounded),
      _SidebarItem(2, 'Routes', Icons.route_rounded),
      _SidebarItem(3, 'Buses', Icons.directions_bus_rounded),
      _SidebarItem(4, 'Students', Icons.people_alt_rounded),
      _SidebarItem(5, 'Payments', Icons.receipt_long_rounded),
      _SidebarItem(6, 'Notifications', Icons.send_rounded),
      _SidebarItem(7, 'Reports', Icons.analytics_rounded),
      _SidebarItem(8, 'Settings', Icons.settings_rounded),
    ];
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    // ── Branding Header ──
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 28,
horizontal: 24),
                      child: Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primaryCrimson,
AppColors.darkCrimson],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
```

```
                                  color:
AppColors.primaryCrimson.withOpacity(0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const
Icon(Icons.admin_panel_settings_rounded,
                                color: Colors.white, size: 28),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'ICEM BUS PASS',
                            style: TextStyle(
                              color: AppColors.primaryCrimson,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Admin Console',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 1, color: const Color(0xFFF1F5F9)),
                    const SizedBox(height: 8),
                    // ── Nav Items ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(sidebarItems.length, (index) {
                          final item = sidebarItems[index];
                          final isSelected = currentTab == item.index;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Material(
                              color: isSelected
                                  ? AppColors.primaryCrimson.withOpacity(0.08)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  ref.read(adminTabProvider.notifier).state =
```

```
item.index;
```

```
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
```

```
                                  child: Row(
                                    children: [
                                      Icon(
                                        item.icon,
                                        size: 20,
                                        color: isSelected
                                            ? AppColors.primaryCrimson
                                            : const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: TextStyle(
                                            color: isSelected
                                                ? AppColors.primaryCrimson
                                                : const Color(0xFF334155),
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: AppColors.primaryCrimson,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const Spacer(),
                    // ── Logout Button ──
                    Container(height: 1, color: const Color(0xFFF1F5F9)),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Material(
                        color: AppColors.primaryCrimson.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _handleLogout(context),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14,
vertical: 12),
                            child: Row(
                              children: [
                                Icon(Icons.logout_rounded,
                                    size: 20, color: AppColors.primaryCrimson),
                                SizedBox(width: 14),
                                Text(
```

```
                                    color: AppColors.primaryCrimson,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  // ── Logout Handler ──
  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Sign Out'),
        content: const Text(
            'Are you sure you want to sign out from the Administrative
Console?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sign Out',
              style: TextStyle(
                  color: AppColors.primaryCrimson, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).logout();
      context.go(AppRoutes.login);
    }
  }
}
// ── Sidebar item data class ──
class _SidebarItem {
  final int index;
  final String title;
  final IconData icon;
```

```
  _SidebarItem(this.index, this.title, this.icon);
```

```
}
```

```
================================================
FILE: ios/Flutter/AppFrameworkInfo.plist
================================================
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
"http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>App</string>
  <key>CFBundleIdentifier</key>
  <string>io.flutter.flutter.app</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>App</string>
  <key>CFBundlePackageType</key>
  <string>FMWK</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleSignature</key>
  <string>????</string>
  <key>CFBundleVersion</key>
  <string>1.0</string>
</dict>
</plist>
================================================
FILE: ios/Flutter/Debug.xcconfig
================================================
#include "Generated.xcconfig"
================================================
FILE: ios/Flutter/Release.xcconfig
================================================
#include "Generated.xcconfig"
```

```
================================================
FILE: ios/Runner/AppDelegate.swift
================================================
import Flutter
import UIKit
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions:
[UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions:
launchOptions)
  }
```

```
  func didInitializeImplicitFlutterEngine(_ engineBridge:
FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
```

```
================================================
FILE: ios/Runner/Info.plist
================================================
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
"http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>NSCameraUsageDescription</key>
<string>ICEM Bus needs camera access to capture student profile
pictures.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>ICEM Bus needs gallery access to upload student profile
pictures.</string>
<key>CADisableMinimumFrameDurationOnPhone</key>
<true/>
<key>CFBundleDevelopmentRegion</key>
<string>$(DEVELOPMENT_LANGUAGE)</string>
<key>CFBundleDisplayName</key>
<string>Icem Bus</string>
<key>CFBundleExecutable</key>
<string>$(EXECUTABLE_NAME)</string>
<key>CFBundleIdentifier</key>
<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
<key>CFBundleInfoDictionaryVersion</key>
<string>6.0</string>
<key>CFBundleName</key>
<string>icem_bus</string>
<key>CFBundlePackageType</key>
<string>APPL</string>
<key>CFBundleShortVersionString</key>
<string>$(FLUTTER_BUILD_NAME)</string>
<key>CFBundleSignature</key>
<string>????</string>
<key>CFBundleVersion</key>
<string>$(FLUTTER_BUILD_NUMBER)</string>
<key>LSRequiresIPhoneOS</key>
<true/>
<key>UIApplicationSceneManifest</key>
<dict>
<key>UIApplicationSupportsMultipleScenes</key>
<false/>
<key>UISceneConfigurations</key>
<dict>
<key>UIWindowSceneSessionRoleApplication</key>
<array>
<dict>
<key>UISceneClassName</key>
<string>UIWindowScene</string>
<key>UISceneConfigurationName</key>
<string>flutter</string>
<key>UISceneDelegateClassName</key>
```

```
<string>$(PRODUCT_MODULE_NAME).SceneDelegate</string>
<key>UISceneStoryboardFile</key>
```

```
<string>Main</string>
</dict>
</array>
</dict>
</dict>
<key>UIApplicationSupportsIndirectInputEvents</key>
<true/>
<key>UILaunchStoryboardName</key>
<string>LaunchScreen</string>
<key>UIMainStoryboardFile</key>
<string>Main</string>
<key>UISupportedInterfaceOrientations</key>
<array>
<string>UIInterfaceOrientationPortrait</string>
<string>UIInterfaceOrientationLandscapeLeft</string>
<string>UIInterfaceOrientationLandscapeRight</string>
</array>
<key>UISupportedInterfaceOrientations~ipad</key>
<array>
<string>UIInterfaceOrientationPortrait</string>
<string>UIInterfaceOrientationPortraitUpsideDown</string>
<string>UIInterfaceOrientationLandscapeLeft</string>
<string>UIInterfaceOrientationLandscapeRight</string>
</array>
</dict>
</plist>
```

```
================================================
FILE: ios/Runner/Runner-Bridging-Header.h
================================================
#import "GeneratedPluginRegistrant.h"
```

```
================================================
FILE: ios/Runner/SceneDelegate.swift
================================================
import Flutter
import UIKit
```

```
class SceneDelegate: FlutterSceneDelegate {
```

```
}
```

```
================================================
FILE: ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json
================================================
{
  "images" : [
    {
      "size" : "20x20",
      "idiom" : "iphone",
      "filename" : "Icon-App-20x20@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "20x20",
      "idiom" : "iphone",
      "filename" : "Icon-App-20x20@3x.png",
      "scale" : "3x"
```

```
    },
    {
      "size" : "29x29",
      "idiom" : "iphone",
      "filename" : "Icon-App-29x29@1x.png",
      "scale" : "1x"
    },
    {
      "size" : "29x29",
      "idiom" : "iphone",
      "filename" : "Icon-App-29x29@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "29x29",
      "idiom" : "iphone",
      "filename" : "Icon-App-29x29@3x.png",
      "scale" : "3x"
    },
    {
      "size" : "40x40",
      "idiom" : "iphone",
      "filename" : "Icon-App-40x40@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "40x40",
      "idiom" : "iphone",
      "filename" : "Icon-App-40x40@3x.png",
      "scale" : "3x"
    },
    {
      "size" : "60x60",
      "idiom" : "iphone",
      "filename" : "Icon-App-60x60@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "60x60",
      "idiom" : "iphone",
      "filename" : "Icon-App-60x60@3x.png",
      "scale" : "3x"
    },
    {
      "size" : "20x20",
      "idiom" : "ipad",
      "filename" : "Icon-App-20x20@1x.png",
      "scale" : "1x"
    },
    {
      "size" : "20x20",
      "idiom" : "ipad",
      "filename" : "Icon-App-20x20@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "29x29",
      "idiom" : "ipad",
      "filename" : "Icon-App-29x29@1x.png",
      "scale" : "1x"
    },
    {
      "size" : "29x29",
      "idiom" : "ipad",
```

```
      "filename" : "Icon-App-29x29@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "40x40",
      "idiom" : "ipad",
      "filename" : "Icon-App-40x40@1x.png",
      "scale" : "1x"
    },
    {
      "size" : "40x40",
      "idiom" : "ipad",
      "filename" : "Icon-App-40x40@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "76x76",
      "idiom" : "ipad",
      "filename" : "Icon-App-76x76@1x.png",
      "scale" : "1x"
    },
    {
      "size" : "76x76",
      "idiom" : "ipad",
      "filename" : "Icon-App-76x76@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "83.5x83.5",
      "idiom" : "ipad",
      "filename" : "Icon-App-83.5x83.5@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "1024x1024",
      "idiom" : "ios-marketing",
      "filename" : "Icon-App-1024x1024@1x.png",
      "scale" : "1x"
    }
  ],
  "info" : {
    "version" : 1,
    "author" : "xcode"
  }
}
```

```
================================================
FILE: ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md
================================================
```

```
# Launch Screen Assets
```

```
You can customize the launch screen with your own desired assets by replacing
the image files in this directory.
```

```
You can also do it by opening your Flutter project's Xcode project with `open
ios/Runner.xcworkspace`, selecting `Runner/Assets.xcassets` in the Project
Navigator and dropping in the desired images.
```

```
================================================
FILE: ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json
================================================
```

```
{
  "images" : [
    {
      "idiom" : "universal",
      "filename" : "LaunchImage.png",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "filename" : "LaunchImage@2x.png",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "filename" : "LaunchImage@3x.png",
      "scale" : "3x"
    }
  ],
  "info" : {
    "version" : 1,
    "author" : "xcode"
  }
}
```

```
================================================
FILE: ios/Runner/Base.lproj/LaunchScreen.storyboard
================================================
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<document type="com.apple.InterfaceBuilder3.CocoaTouch.Storyboard.XIB"
version="3.0" toolsVersion="12121" systemVersion="16G29"
targetRuntime="iOS.CocoaTouch" propertyAccessControl="none" useAutolayout="YES"
launchScreen="YES" colorMatched="YES" initialViewController="01J-lp-oVM">
    <dependencies>
        <deployment identifier="iOS"/>
        <plugIn identifier="com.apple.InterfaceBuilder.IBCocoaTouchPlugin"
version="12089"/>
    </dependencies>
    <scenes>
```

```
        <!--View Controller-->
        <scene sceneID="EHf-IW-A2E">
            <objects>
                <viewController id="01J-lp-oVM" sceneMemberID="viewController">
                    <layoutGuides>
                        <viewControllerLayoutGuide type="top" id="Ydg-fD-yQy"/>
                        <viewControllerLayoutGuide type="bottom" id="xbc-2k-
c8Z"/>
                    </layoutGuides>
                    <view key="view" contentMode="scaleToFill" id="Ze5-6b-2t3">
                        <autoresizingMask key="autoresizingMask"
widthSizable="YES" heightSizable="YES"/>
                        <subviews>
                            <imageView opaque="NO" clipsSubviews="YES"
multipleTouchEnabled="YES" contentMode="center" image="LaunchImage"
translatesAutoresizingMaskIntoConstraints="NO" id="YRO-k0-Ey4">
                            </imageView>
                        </subviews>
                        <color key="backgroundColor" red="1" green="1" blue="1"
alpha="1" colorSpace="custom" customColorSpace="sRGB"/>
                        <constraints>
                            <constraint firstItem="YRO-k0-Ey4"
firstAttribute="centerX" secondItem="Ze5-6b-2t3" secondAttribute="centerX"
id="1a2-6s-vTC"/>
```

```
                            <constraint firstItem="YRO-k0-Ey4"
firstAttribute="centerY" secondItem="Ze5-6b-2t3" secondAttribute="centerY"
id="4X2-HB-R7a"/>
```

```
                        </constraints>
                    </view>
                </viewController>
                <placeholder placeholderIdentifier="IBFirstResponder" id="iYj-
Kq-Ea1" userLabel="First Responder" sceneMemberID="firstResponder"/>
            </objects>
            <point key="canvasLocation" x="53" y="375"/>
        </scene>
    </scenes>
    <resources>
        <image name="LaunchImage" width="168" height="185"/>
    </resources>
</document>
```

```
================================================
FILE: ios/Runner/Base.lproj/Main.storyboard
================================================
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<document type="com.apple.InterfaceBuilder3.CocoaTouch.Storyboard.XIB"
version="3.0" toolsVersion="10117" systemVersion="15F34"
targetRuntime="iOS.CocoaTouch" propertyAccessControl="none" useAutolayout="YES"
useTraitCollections="YES" initialViewController="BYZ-38-t0r">
    <dependencies>
        <deployment identifier="iOS"/>
        <plugIn identifier="com.apple.InterfaceBuilder.IBCocoaTouchPlugin"
version="10085"/>
    </dependencies>
    <scenes>
        <!--Flutter View Controller-->
        <scene sceneID="tne-QT-ifu">
            <objects>
                <viewController id="BYZ-38-t0r"
customClass="FlutterViewController" sceneMemberID="viewController">
                    <layoutGuides>
                        <viewControllerLayoutGuide type="top" id="y3c-jy-aDJ"/>
                        <viewControllerLayoutGuide type="bottom" id="wfy-db-
euE"/>
                    </layoutGuides>
                    <view key="view" contentMode="scaleToFill" id="8bC-Xf-vdC">
                        <rect key="frame" x="0.0" y="0.0" width="600"
height="600"/>
                        <autoresizingMask key="autoresizingMask"
widthSizable="YES" heightSizable="YES"/>
                        <color key="backgroundColor" white="1" alpha="1"
colorSpace="custom" customColorSpace="calibratedWhite"/>
                    </view>
                </viewController>
                <placeholder placeholderIdentifier="IBFirstResponder" id="dkx-
z0-nzr" sceneMemberID="firstResponder"/>
            </objects>
        </scene>
    </scenes>
</document>
```

```
================================================
FILE: ios/RunnerTests/RunnerTests.swift
================================================
```

```
import Flutter
import UIKit
import XCTest
```

```
class RunnerTests: XCTestCase {
```

```
  func testExample() {
    // If you add code to the Runner application, consider adding tests here.
    // See https://developer.apple.com/documentation/xctest for more information
about using XCTest.
  }
}
```

```
================================================
FILE: lib/main.dart
```

```
================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/app/app.dart';
import 'package:icem_bus/services/firebase/firebase_service.dart';
import 'package:icem_bus/services/storage/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
```

```
void main() async {
  // Ensure widget binding is initialized before asynchronous service calls
  WidgetsFlutterBinding.ensureInitialized();
```

```
  // Initialize SharedPreferences local cache
  final sharedPreferences = await SharedPreferences.getInstance();
  final storageService = StorageService(sharedPreferences);
```

```
  // Initialize Firebase Core & Messaging (Gracefully runs offline if config
files are not present)
  await FirebaseService.initialize();
```

```
  runApp(
    ProviderScope(
      overrides: [
```

```
        storageServiceProvider.overrideWithValue(storageService),
      ],
      child: const MyApp(),
    ),
  );
}
```

```
================================================
FILE: lib/app/app.dart
================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/config/routes/app_routes.dart';
import 'package:icem_bus/config/theme/app_theme.dart';
```

```
import 'package:icem_bus/services/storage/storage_service.dart';
```

```
class MyApp extends ConsumerWidget {
  const MyApp({super.key});
```

```
  @override
```

```
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider);
```

```
    return MaterialApp.router(
      title: 'ICEM Smart Bus Pass',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(settings.accentColor, Brightness.light),
      darkTheme: AppTheme.getTheme(settings.accentColor, Brightness.dark),
      themeMode: settings.themeMode,
      routerConfig: AppRoutes.router,
    );
  }
}
```

```
================================================
FILE: lib/app/.gitkeep
================================================
[Empty file]
```

```
================================================
FILE: lib/config/constants/app_constants.dart
================================================
class AppConstants {
  static const String appName = 'ICEM Smart Bus Pass';
  static const String appVersion = '1.0.0';
  static const String buildNumber = '1';
  static const String onboardingCompletedKey = 'onboarding_completed';
  // Animation Durations
  static const Duration splashDuration = Duration(milliseconds: 2500);
  static const Duration animationDurationSlow = Duration(milliseconds: 600);
  static const Duration animationDurationFast = Duration(milliseconds: 300);
}
```

```
================================================
FILE: lib/config/routes/app_routes.dart
================================================
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/auth/domain/entities/user_entity.dart';
import
'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import
'package:icem_bus/features/admin/presentation/views/staff_dashboard.dart';
import
'package:icem_bus/features/admin/presentation/views/admin_dashboard.dart';
import 'package:icem_bus/features/auth/presentation/views/login_screen.dart';
import
'package:icem_bus/features/auth/presentation/views/onboarding_screen.dart';
import 'package:icem_bus/features/auth/presentation/views/register_screen.dart';
import 'package:icem_bus/features/auth/presentation/views/splash_screen.dart';
import
'package:icem_bus/features/student/presentation/views/student_dashboard.dart';
import
'package:icem_bus/features/student/presentation/views/student_sub_screens.dart';
import
```

```
'package:icem_bus/features/admin/presentation/views/application_detail_screen.da
rt';
import 'package:icem_bus/shared/error_screen.dart';
import 'package:icem_bus/shared/loading_screen.dart';
import
'package:icem_bus/features/driver/presentation/views/driver_management_screen.da
rt';
import
'package:icem_bus/features/admin/presentation/views/admin_settings_screen.dart';
import
'package:icem_bus/features/payment/presentation/views/payment_receipt_screen.dar
t';
import
'package:icem_bus/features/bus_pass/presentation/views/qr_verification_screen.da
rt';
import
'package:icem_bus/features/student/presentation/views/student_pass_history_scree
n.dart';
import
'package:icem_bus/features/student/presentation/views/student_pass_detail_screen
.dart';
class AppRoutes {
  AppRoutes._();
  // Route Paths
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String studentDashboard = '/student_dashboard';
  static const String staffDashboard = '/staff_dashboard';
  static const String adminDashboard = '/admin_dashboard';
  static const String loading = '/loading';
  static const String error = '/error';
  static const String applicationDetail = '/admin/application/:id';
  static const String driverManagement = '/admin/drivers';
  static const String adminSettings = '/admin/settings';
```

```
  // Student Sub routes
  static const String studentApply = '/student/apply';
  static const String studentRenew = '/student/renew';
  static const String studentDigitalPass = '/student/digital-pass';
  static const String studentPassHistory = '/student/pass-history';
  static const String studentPassDetail = '/student/pass-detail/:id';
  static const String studentPaymentHistory = '/student/payment-history';
  static const String studentPayment = '/student/payment';
  static const String studentPaymentReceipt = '/student/payment-receipt/:id';
```

```
  // Admin & Staff verification route
  static const String qrVerification = '/admin/verify-qr';
```

```
  static final GoRouter router = GoRouter(
    initialLocation: splash,
    redirect: (BuildContext context, GoRouterState state) {
      final String path = state.uri.path;
```

```
      // Determine if it's an auth-related public page
      final bool isPublicPath = path == splash ||
          path == onboarding ||
```

```
          path == login ||
          path == register;
```

```
      // Check Firebase Auth status synchronously
```

```
      User? firebaseUser;
      try {
        firebaseUser = FirebaseAuth.instance.currentUser;
      } catch (_) {
        // Fallback for tests/environments where Firebase is not initialized
      }
      if (firebaseUser == null) {
        // If not logged in, they can only access public pages
        if (!isPublicPath) {
          return login;
        }
        return null;
      }
```

```
      // User is logged in. Check Riverpod state for loaded Firestore profile
      final container = ProviderScope.containerOf(context);
      final authState = container.read(authControllerProvider);
      final user = authState.user;
```

```
      // If user profile is not loaded yet in state, we let the app load the
page (or splash)
      if (user == null) {
        return null;
      }
```

```
      final String role = UserEntity.normalizeRole(user.role);
```

```
      if (isPublicPath) {
        // Prevent showing login/register/onboarding again if already logged in
        if (role == 'Admin') {
          return adminDashboard;
        } else if (role == 'Staff') {
          return staffDashboard;
        } else {
          return studentDashboard;
        }
      }
```

```
      // Guard QR Verification (accessible by both Admin and Staff)
      if (path == qrVerification) {
        if (role != 'Admin' && role != 'Staff') {
          Future.microtask(() {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Access Denied: Conductor or Administrator
privileges required.'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          });
          return studentDashboard;
        }
        return null;
      }
```

```
      // Guard Admin pages
      if (path == adminDashboard || (path.startsWith('/admin/') && path !=
qrVerification)) {
        if (role != 'Admin') {
          Future.microtask(() {
            if (context.mounted) {
```

```
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Access Denied'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          });
          return studentDashboard;
        }
      }
      // Guard Staff pages
      if (path == staffDashboard) {
        if (role != 'Staff') {
          Future.microtask(() {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Access Denied'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          });
          return studentDashboard;
        }
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: splash,
        builder: (BuildContext context, GoRouterState state) {
          return const SplashScreen();
        },
      ),
      GoRoute(
        path: onboarding,
        builder: (BuildContext context, GoRouterState state) {
          return const OnboardingScreen();
        },
      ),
      GoRoute(
        path: login,
        builder: (BuildContext context, GoRouterState state) {
          return const LoginScreen();
        },
      ),
      GoRoute(
        path: register,
        builder: (BuildContext context, GoRouterState state) {
          return const RegisterScreen();
        },
      ),
      GoRoute(
        path: studentDashboard,
        builder: (BuildContext context, GoRouterState state) {
          return const StudentDashboardScreen();
        },
      ),
      GoRoute(
        path: staffDashboard,
```

```
        builder: (BuildContext context, GoRouterState state) {
          return const StaffDashboardScreen();
        },
      ),
      GoRoute(
        path: adminDashboard,
        builder: (BuildContext context, GoRouterState state) {
          return const AdminDashboardScreen();
        },
      ),
      GoRoute(
        path: driverManagement,
        builder: (BuildContext context, GoRouterState state) {
          return const DriverManagementScreen();
        },
      ),
      GoRoute(
        path: '/admin/application/:id',
        builder: (BuildContext context, GoRouterState state) {
          final applicationId = state.pathParameters['id'] ?? '';
          return ApplicationDetailScreen(applicationId: applicationId);
        },
      ),
      GoRoute(
        path: adminSettings,
        builder: (BuildContext context, GoRouterState state) {
          return const AdminSettingsScreen();
        },
      ),
      GoRoute(
        path: studentApply,
        builder: (BuildContext context, GoRouterState state) {
          return const ApplyPassScreen();
        },
      ),
      GoRoute(
        path: studentRenew,
        builder: (BuildContext context, GoRouterState state) {
          return const RenewPassScreen();
        },
      ),
      GoRoute(
        path: studentDigitalPass,
        builder: (BuildContext context, GoRouterState state) {
          return const DigitalPassScreen();
        },
      ),
      GoRoute(
        path: studentPaymentHistory,
        builder: (BuildContext context, GoRouterState state) {
          return const PaymentHistoryScreen();
        },
      ),
      GoRoute(
        path: studentPayment,
        builder: (BuildContext context, GoRouterState state) {
          return const StudentPaymentScreen();
        },
      ),
      GoRoute(
        path: studentPaymentReceipt,
        builder: (BuildContext context, GoRouterState state) {
          final paymentId = state.pathParameters['id'] ?? '';
          return PaymentReceiptScreen(paymentId: paymentId);
```

```
        },
      ),
      GoRoute(
        path: studentPassHistory,
        builder: (BuildContext context, GoRouterState state) {
          return const StudentPassHistoryScreen();
        },
      ),
      GoRoute(
        path: studentPassDetail,
        builder: (BuildContext context, GoRouterState state) {
          final applicationId = state.pathParameters['id'] ?? '';
          return StudentPassDetailScreen(applicationId: applicationId);
        },
      ),
      GoRoute(
        path: qrVerification,
        builder: (BuildContext context, GoRouterState state) {
          return const QrVerificationScreen();
        },
      ),
      GoRoute(
        path: loading,
        builder: (BuildContext context, GoRouterState state) {
          return const LoadingScreen();
        },
      ),
      GoRoute(
        path: error,
        builder: (BuildContext context, GoRouterState state) {
          return ErrorScreen(
            onRetry: () {
              context.go(login);
            },
            onBack: () {
              context.go(login);
            },
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('No route defined for ${state.uri.path}'),
      ),
    ),
  );
}
```

```
================================================
FILE: lib/config/theme/app_colors.dart
================================================
import 'package:flutter/material.dart';
```

```
class AppColors {
  // ── Primary Brand Colors (Deep Navy + Luxury Crimson Direction) ──
  static const Color primaryCrimson = Color(0xFFD71920); // Vibrant ICEM Crimson
Red
  static const Color crimsonRed = Color(0xFFE31B23);    // High-energy Crimson
for accents/glow
  static const Color darkCrimson = Color(0xFF990000);   // Deep Crimson for
gradients
```

```
  static const Color lightCrimson = Color(0x26D71920);  // Translucent crimson
tint for badges
  static const Color crimsonLight = Color(0x26D71920);  // Translucent crimson
tint alias
```

```
  static const Color borderCrimson = Color(0xFFD71920); // Crimson border for
active cards
```

```
  // Crimson Scales
  static const Color crimson50 = Color(0x1AD71920);
  static const Color crimson100 = Color(0x2BD71920);
  static const Color crimson200 = Color(0x40D71920);
  static const Color crimson500 = Color(0xFFD71920);
  static const Color crimson600 = Color(0xFFE31B23);
  static const Color crimson700 = Color(0xFFB80F0A);
  static const Color crimson800 = Color(0xFF990000);
```

```
  // ── Deep Navy & Charcoal Backgrounds (Reference Style) ──
  static const Color background = Color(0xFF0B1118);       // Primary deep navy
background
  static const Color backgroundNavy = Color(0xFF0B1118);   // #0B1118
  static const Color backgroundCharcoal = Color(0xFF101820); // #101820
  static const Color backgroundLight = Color(0xFF0B1118);  // Default dark
backdrop
```

```
  // Surfaces & Cards
  static const Color surface = Color(0xFF151E28);          // Dark navy/charcoal
surface #151E28
  static const Color surfaceCard = Color(0xFF151E28);      // Standard card
surface
  static const Color surfaceElevated = Color(0xFF1A2432);  // Slightly lighter
elevated card
  static const Color surfaceLight = Color(0xFF151E28);     // Card fallback
  static const Color cardBorder = Color(0xFF222F3E);       // Subtle slate-navy
border
  static const Color cardBorderSubtle = Color(0x1FFFFFFF); // 12% white subtle
border
```

```
  // Semantic Design Aliases
  static const Color bgDark = Color(0xFF0B1118);
  static const Color cardSurface = Color(0xFF151E28);
  static const Color elevatedSurface = Color(0xFF1A2432);
  static const Color borderSubtle = Color(0xFF222F3E);
  static const Color textMuted = Color(0xFF94A3B8);
```

```
  // Secondary / Accent Colors
  static const Color accentGold = Color(0xFFF59E0B);     // Warm Amber/Gold
  static const Color secondaryDark = Color(0xFF1E293B);  // Slate navy
  // Slate Neutral Scale
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);
```

```
  // Text Colors
  static const Color textPrimary = Color(0xFFF8FAFC);     // Soft pure white for
primary text
  static const Color textSecondary = Color(0xFF94A3B8);   // Muted slate gray
```

```
for secondary info
  static const Color textLight = Color(0xFF64748B);       // Subtle helper text
  static const Color textOnPrimary = Color(0xFFFFFFFF);   // White on crimson
CTA
  // Feedback Colors
  static const Color success = Color(0xFF10B981);         // Emerald-500
  static const Color successLight = Color(0x2610B981);    // 15% Emerald
  static const Color warning = Color(0xFFF59E0B);         // Amber-500
  static const Color warningLight = Color(0x26F59E0B);    // 15% Amber
  static const Color error = Color(0xFFEF4444);           // Red-500
  static const Color errorLight = Color(0x26EF4444);      // 15% Red
  static const Color info = Color(0xFF3B82F6);            // Blue-500
  static const Color infoLight = Color(0x263B82F6);       // 15% Blue
  // Modern Soft Dark Shadow Presets
  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color(0x40000000),
      blurRadius: 14,
      spreadRadius: 0,
      offset: Offset(0, 4),
    ),
  ];
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x55000000),
      blurRadius: 20,
      spreadRadius: 0,
      offset: Offset(0, 6),
    ),
  ];
  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Color(0x70000000),
      blurRadius: 30,
      spreadRadius: 0,
      offset: Offset(0, 10),
    ),
  ];
  static const List<BoxShadow> crimsonGlow = [
    BoxShadow(
      color: Color(0x40D71920),
      blurRadius: 18,
      spreadRadius: 1,
      offset: Offset(0, 4),
    ),
  ];
}
```

```
================================================
FILE: lib/config/theme/app_theme.dart
================================================
// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
```

```
class AppTheme {
  AppTheme._();
```

```
  static Color getAccentColor(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'blue':
        return Colors.blue.shade700;
      case 'green':
        return Colors.green.shade700;
      case 'purple':
        return Colors.purple.shade700;
      case 'crimson':
      default:
        return AppColors.primaryCrimson;
    }
  }
  /// Returns the correct [ThemeData] for the given [brightness].
  /// Previously this function always returned a dark theme regardless
  /// of the [brightness] argument — that was the root cause of the
  /// theme switch not working.
  static ThemeData getTheme(String accentColorName, Brightness brightness) {
    final primaryColor = getAccentColor(accentColorName);
    return brightness == Brightness.dark
        ? _darkTheme(primaryColor)
        : _lightTheme(primaryColor);
  }
  // ─────────────────────────────────────────────────────────
  // DARK THEME — Premium Deep Navy / Charcoal
  // ─────────────────────────────────────────────────────────
  static ThemeData _darkTheme(Color primaryColor) {
    final base = ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: AppColors.surfaceElevated,
        onSecondary: Colors.white,
        error: AppColors.error,
        onError: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        primaryContainer: primaryColor.withOpacity(0.18),
        onPrimaryContainer: Colors.white,
        surfaceContainerHighest: AppColors.surfaceElevated,
        onSurfaceVariant: AppColors.textSecondary,
        outline: AppColors.cardBorder,
        outlineVariant: AppColors.cardBorderSubtle,
      ),
      scaffoldBackgroundColor: AppColors.backgroundNavy,
      dividerColor: AppColors.cardBorder,
    );
    return base.copyWith(
      textTheme: GoogleFonts.outfitTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 32, fontWeight: FontWeight.bold, color:
AppColors.textPrimary),
        displayMedium: GoogleFonts.outfit(
          fontSize: 28, fontWeight: FontWeight.bold, color:
```

```
AppColors.textPrimary),
        titleLarge: GoogleFonts.outfit(
          fontSize: 22, fontWeight: FontWeight.w700, color:
AppColors.textPrimary),
        titleMedium: GoogleFonts.outfit(
          fontSize: 18, fontWeight: FontWeight.w600, color:
AppColors.textPrimary),
        bodyLarge: GoogleFonts.outfit(
          fontSize: 15, color: AppColors.textSecondary, height: 1.5),
        bodyMedium: GoogleFonts.outfit(
          fontSize: 13, color: AppColors.textLight, height: 1.4),
        labelLarge: GoogleFonts.outfit(
          fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      elevatedButtonTheme: _elevatedBtn(primaryColor),
      outlinedButtonTheme: _outlinedBtn(primaryColor),
      textButtonTheme: _textBtn(primaryColor),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.cardBorder, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.cardBorder,
thickness: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.cardBorder, width: 1),
        ),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18, fontWeight: FontWeight.bold, color:
AppColors.textPrimary),
        contentTextStyle: GoogleFonts.outfit(
          fontSize: 14, color: AppColors.textSecondary),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundNavy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18, fontWeight: FontWeight.bold, color:
AppColors.textPrimary),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
    );
  }
  // ─────────────────────────────────────────────────────────
  // LIGHT THEME — Premium White / Soft Gray
  // ─────────────────────────────────────────────────────────
  static ThemeData _lightTheme(Color primaryColor) {
    const bgColor = Color(0xFFF4F6FA);       // Soft cool background
    const surfaceColor = Color(0xFFFFFFFF);  // Pure white cards
    const surfaceElevated = Color(0xFFF0F2F8); // Slightly gray elevated
```

```
    const onSurfaceColor = Color(0xFF1A2030); // Near-black readable text
    const onSurfaceVariant = Color(0xFF64748B); // Muted secondary text
    const borderColor = Color(0xFFDDE3EE);   // Soft border
```

```
    final base = ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: surfaceElevated,
        onSecondary: onSurfaceColor,
        error: AppColors.error,
        onError: Colors.white,
        surface: surfaceColor,
        onSurface: onSurfaceColor,
        primaryContainer: primaryColor.withOpacity(0.10),
        onPrimaryContainer: primaryColor,
        surfaceContainerHighest: surfaceElevated,
        onSurfaceVariant: onSurfaceVariant,
        outline: borderColor,
        outlineVariant: const Color(0xFFEBEFF7),
      ),
      scaffoldBackgroundColor: bgColor,
      dividerColor: borderColor,
    );
    return base.copyWith(
      textTheme: GoogleFonts.outfitTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 32, fontWeight: FontWeight.bold, color: onSurfaceColor),
        displayMedium: GoogleFonts.outfit(
          fontSize: 28, fontWeight: FontWeight.bold, color: onSurfaceColor),
        titleLarge: GoogleFonts.outfit(
          fontSize: 22, fontWeight: FontWeight.w700, color: onSurfaceColor),
        titleMedium: GoogleFonts.outfit(
          fontSize: 18, fontWeight: FontWeight.w600, color: onSurfaceColor),
        bodyLarge: GoogleFonts.outfit(
          fontSize: 15, color: onSurfaceVariant, height: 1.5),
        bodyMedium: GoogleFonts.outfit(
          fontSize: 13, color: onSurfaceVariant, height: 1.4),
        labelLarge: GoogleFonts.outfit(
          fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      elevatedButtonTheme: _elevatedBtn(primaryColor),
      outlinedButtonTheme: _outlinedBtn(primaryColor),
      textButtonTheme: _textBtn(primaryColor),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shadowColor: const Color(0x18000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: borderColor, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(color: borderColor, thickness: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: borderColor, width: 1),
```

```
        ),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18, fontWeight: FontWeight.bold, color: onSurfaceColor),
        contentTextStyle: GoogleFonts.outfit(
          fontSize: 14, color: onSurfaceVariant),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: const Color(0x14000000),
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18, fontWeight: FontWeight.bold, color: onSurfaceColor),
        iconTheme: const IconThemeData(color: onSurfaceColor),
      ),
    );
  }
  // ── Shared button styles ──
  static ElevatedButtonThemeData _elevatedBtn(Color primary) =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius:
BorderRadius.circular(20)),
          textStyle: GoogleFonts.outfit(
            fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      );
  static OutlinedButtonThemeData _outlinedBtn(Color primary) =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(double.infinity, 54),
          side: BorderSide(color: primary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius:
BorderRadius.circular(20)),
          textStyle: GoogleFonts.outfit(
            fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      );
  static TextButtonThemeData _textBtn(Color primary) =>
      TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.outfit(
            fontSize: 14, fontWeight: FontWeight.bold),
        ),
      );
}
```

```
================================================
```

```
FILE: lib/core/errors/failures.dart
================================================
/// Base class representing errors/failures in the application.
abstract class Failure {
  final String message;
  const Failure(this.message);
  @override
  String toString() => message;
}
```

```
/// Failure representing server or database connectivity/data errors (e.g.
Firestore, Cloud Functions).
class ServerFailure extends Failure {
```

```
  const ServerFailure([super.message = 'A server error occurred. Please try
again.']);
}
/// Failure representing network connectivity errors.
class ConnectionFailure extends Failure {
  const ConnectionFailure([super.message = 'No internet connection.']);
}
/// Failure representing authentication-related errors.
class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication failed.']);
}
/// Failure representing storage-related errors (e.g. SharedPreferences, Local
DB).
class StorageFailure extends Failure {
  const StorageFailure([super.message = 'Failed to load local settings.']);
}
```

```
================================================
FILE: lib/core/usecases/usecase.dart
================================================
/// Base UseCase class for Clean Architecture.
/// [T] represents the return type of the use case.
/// [Params] represents the parameters required to run the usecase.
abstract class UseCase<T, Params> {
  Future<T> call(Params params);
}
```

```
/// Use this class if a UseCase does not require any parameters.
class NoParams {
  const NoParams();
}
```

```
================================================
```

```
FILE: lib/core/utils/responsive.dart
================================================
import 'package:flutter/material.dart';
```

```
/// Utility class for responsive design breakpoints
class Responsive extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;
```

```
  const Responsive({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });
  /// Mobile breakpoint (width < 600)
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600;
  /// Tablet breakpoint (600 <= width < 1200)
  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 600 &&
      MediaQuery.sizeOf(context).width < 1200;
  /// Desktop breakpoint (width >= 1200)
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 1200;
  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    if (width >= 1200) {
      return desktop;
    } else if (width >= 600 && tablet != null) {
      return tablet!;
    } else {
      return mobile;
    }
  }
}
/// Helper extension on BuildContext to quickly access dimensions and responsive
helpers
extension ResponsiveContextExtension on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;
  bool get isMobile => Responsive.isMobile(this);
  bool get isTablet => Responsive.isTablet(this);
  bool get isDesktop => Responsive.isDesktop(this);
  /// Helper to select values based on screen size (e.g. padding, grid cross
axis count)
  T responsiveValue<T>({
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    if (isDesktop) return desktop;
    if (isTablet && tablet != null) return tablet;
    return mobile;
  }
}
```

```
================================================
FILE: lib/features/admin/.gitkeep
================================================
[Empty file]
```

```
================================================
FILE: lib/features/admin/data/.gitkeep
================================================
[Empty file]
```

```
================================================
FILE: lib/features/admin/data/repositories/admin_repository.dart
================================================
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/core/errors/failures.dart';
```

```
final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository();
});
```

```
/// Repository handling all Firestore operations for the Admin dashboard.
class AdminRepository {
  final FirebaseFirestore _firestore;
```

```
  AdminRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
```

```
  // -------------------------------------------------------
  // APPLICATION ACTIONS
  // -------------------------------------------------------
```

```
  /// Approve a bus pass application by document ID.
  ///
  /// CRITICAL SECURITY ENFORCEMENT:
  /// Verifies via Firestore Transaction that paymentStatus == 'Paid'.
  /// If payment is unpaid or pending, the transaction immediately fails.
  /// Only verified paid applications can be approved.
  /// Upon approval, generates a unique Pass ID & Pass Number,
  /// records admin UID and timestamp, and activates the student's digital pass
  /// and scannable QR code in `bus_passes`.
  Future<void> approveApplication(
    String applicationId,
    String adminUid, {
    DateTime? validUntil,
  }) async {
    final now = DateTime.now();
    final passNumber =
        'ICEM-BP-${now.year}-$
{now.millisecondsSinceEpoch.toString().substring(7)}';
    final passId =
        'ICEM-PASS-$
{now.millisecondsSinceEpoch.toRadixString(16).toUpperCase()}';
    await _firestore.runTransaction((transaction) async {
      final appRef =
          _firestore.collection('bus_pass_applications').doc(applicationId);
      final snapshot = await transaction.get(appRef);
      if (!snapshot.exists) {
        throw const ServerFailure('Application record not found.');
      }
      final data = snapshot.data()!;
      final paymentStatus =
          (data['paymentStatus'] as String? ?? '').trim().toLowerCase();
```

```
      if (paymentStatus != 'paid' && paymentStatus != 'success') {
        throw const ServerFailure(
            'Payment verification is required before approving this bus pass.');
      }
      final studentUid =
          data['uid'] as String? ?? data['studentId'] as String? ?? '';
      final validFromTimestamp = Timestamp.fromDate(now);
      final validUntilTimestamp = validUntil != null
          ? Timestamp.fromDate(validUntil)
          : (data['validUntil'] as Timestamp? ??
              data['expiryDate'] as Timestamp? ??
              Timestamp.fromDate(now.add(const Duration(days: 180))));
      // 1. Update the application document
      transaction.update(appRef, {
        'status': 'Approved',
        'applicationStatus': 'Approved',
        'passStatus': 'Active',
        'passId': passId,
        'passNumber': passNumber,
        'approvedBy': adminUid,
        'approvedAt': FieldValue.serverTimestamp(),
        'validFrom': validFromTimestamp,
        'validUntil': validUntilTimestamp,
        'expiryDate': validUntilTimestamp,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // 2. Activate the digital bus pass in bus_passes
      if (studentUid.isNotEmpty) {
        final passRef = _firestore.collection('bus_passes').doc(studentUid);
        final qrPayload = jsonEncode({
          'type': 'ICEM_BUS_PASS',
          'passNumber': passNumber,
          'passId': passId,
          'studentId': studentUid,
        });
        transaction.set(
            passRef,
            {
              'uid': studentUid,
              'studentId': studentUid,
              'applicationId': applicationId,
              'passId': passId,
              'passNumber': passNumber,
              'route': data['route'] ?? data['routeName'] ?? '',
              'routeName': data['routeName'] ?? data['route'] ?? '',
              'routeId': data['routeId'] ?? '',
              'boardingStop': data['boardingStop'] ?? '',
              'destinationStop': data['destinationStop'] ?? '',
              'fare': (data['fare'] as num?)?.toDouble() ?? 0.0,
              'busNumber': data['busNumber'] ?? 'Not Assigned',
              'busId': data['busId'],
              'status': 'Active',
              'passStatus': 'Active',
              'applicationStatus': 'Approved',
              'paymentStatus': 'Paid',
              'paymentId': data['paymentId'] ?? '',
              'expiryDate': validUntilTimestamp,
              'validFrom': validFromTimestamp,
              'validUntil': validUntilTimestamp,
```

```
              'department': data['department'],
              'course': data['course'],
              'year': data['year'],
              'semester': data['semester'],
              'distance': data['distance'],
              'approvedBy': adminUid,
              'approvedAt': FieldValue.serverTimestamp(),
              'createdAt': data['createdAt'] ?? FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
              'qrCode': qrPayload,
            },
            SetOptions(merge: true));
      }
    });
  }
  /// Reject a bus pass application by document ID.
  ///
  /// Stores passStatus = "Rejected", the rejection reason,
  /// and a server timestamp.
  Future<void> rejectApplication(
    String applicationId,
    String rejectionReason,
    String adminUid,
  ) async {
    await _firestore
        .collection('bus_pass_applications')
        .doc(applicationId)
        .update({
      'status': 'Rejected',
      'passStatus': 'Rejected',
      'rejectionReason': rejectionReason,
      'rejectedBy': adminUid,
      'rejectedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  /// Request correction on a bus pass application by document ID.
  ///
  /// Stores passStatus = "Correction Required" and the correction
  /// message for the student to act upon.
  Future<void> requestCorrection(
    String applicationId,
    String correctionMessage,
  ) async {
    await _firestore
        .collection('bus_pass_applications')
        .doc(applicationId)
        .update({
      'status': 'Correction Required',
      'passStatus': 'Correction Required',
      'correctionMessage': correctionMessage,
      'correctionRequestedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  // -------------------------------------------------------
  // ROUTE CRUD
  // -------------------------------------------------------
  Future<void> addRoute(Map<String, dynamic> routeData) async {
    routeData['createdAt'] = FieldValue.serverTimestamp();
```

```
    routeData['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('bus_routes').add(routeData);
  }
```

```
  Future<void> updateRoute(
      String routeId, Map<String, dynamic> routeData) async {
    routeData['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('bus_routes').doc(routeId).update(routeData);
  }
  Future<void> deleteRoute(String routeId) async {
    await _firestore.collection('bus_routes').doc(routeId).delete();
  }
  /// Returns true if the given route is referenced in bus_passes or
  /// bus_pass_applications (used to guard against deletion).
  Future<bool> checkRouteInUse(String routeId) async {
    final passesQuery = await _firestore
        .collection('bus_passes')
        .where('routeId', isEqualTo: routeId)
        .limit(1)
        .get();
    if (passesQuery.docs.isNotEmpty) return true;
    final appsQuery = await _firestore
        .collection('bus_pass_applications')
        .where('routeId', isEqualTo: routeId)
        .limit(1)
        .get();
    return appsQuery.docs.isNotEmpty;
  }
  // -------------------------------------------------------
  // BUS CRUD
  // -------------------------------------------------------
  Future<void> addBus(Map<String, dynamic> busData) async {
    final busRef = _firestore.collection('buses').doc();
    final busId = busRef.id;
    busData['busId'] = busId;
    busData['createdAt'] = FieldValue.serverTimestamp();
    busData['updatedAt'] = FieldValue.serverTimestamp();
    final batch = _firestore.batch();
    batch.set(busRef, busData);
    // If a route is assigned, link it on the route document
    final assignedRouteId = busData['assignedRouteId'] as String?;
    if (assignedRouteId != null && assignedRouteId.isNotEmpty) {
      final routeRef = _firestore.collection('bus_routes').doc(assignedRouteId);
      batch.update(routeRef, {
        'assignedBusId': busId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // Clear any other bus currently assigned to this route
      final otherBusesQuery = await _firestore
          .collection('buses')
          .where('assignedRouteId', isEqualTo: assignedRouteId)
          .get();
      for (final doc in otherBusesQuery.docs) {
        batch.update(doc.reference, {
          'assignedRouteId': null,
          'updatedAt': FieldValue.serverTimestamp(),
```

```
        });
      }
    }
    await batch.commit();
  }
```

```
  Future<void> updateBus(
    String busId,
    Map<String, dynamic> busData, {
    String? oldRouteId,
  }) async {
    busData['updatedAt'] = FieldValue.serverTimestamp();
    final busRef = _firestore.collection('buses').doc(busId);
    final batch = _firestore.batch();
    batch.update(busRef, busData);
```

```
    final newRouteId = busData['assignedRouteId'] as String?;
    if (newRouteId != oldRouteId) {
      // Clear old route's assigned bus
      if (oldRouteId != null && oldRouteId.isNotEmpty) {
        final oldRouteRef = _firestore.collection('bus_routes').doc(oldRouteId);
        batch.update(oldRouteRef, {
          'assignedBusId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      // Set new route's assigned bus, and clear other buses assigned to new
route
      if (newRouteId != null && newRouteId.isNotEmpty) {
        final newRouteRef = _firestore.collection('bus_routes').doc(newRouteId);
        batch.update(newRouteRef, {
          'assignedBusId': busId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        final otherBusesQuery = await _firestore
            .collection('buses')
            .where('assignedRouteId', isEqualTo: newRouteId)
            .get();
        for (final doc in otherBusesQuery.docs) {
          if (doc.id != busId) {
            batch.update(doc.reference, {
              'assignedRouteId': null,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    }
    await batch.commit();
  }
```

```
  Future<void> deleteBus(String busId, {String? assignedRouteId}) async {
    final batch = _firestore.batch();
    batch.delete(_firestore.collection('buses').doc(busId));
```

```
    if (assignedRouteId != null && assignedRouteId.isNotEmpty) {
      final routeRef = _firestore.collection('bus_routes').doc(assignedRouteId);
      batch.update(routeRef, {
        'assignedBusId': null,
        'updatedAt': FieldValue.serverTimestamp(),
```

```
      });
    }
    await batch.commit();
  }
  /// Returns true if the bus is assigned to an active route (preventing
deletion).
  Future<bool> checkBusInUse(String? assignedRouteId) async {
    if (assignedRouteId == null || assignedRouteId.isEmpty) return false;
    final doc = await
_firestore.collection('bus_routes').doc(assignedRouteId).get();
    if (!doc.exists) return false;
    final status = doc.data()?['status'] ?? 'Active';
    return status == 'Active';
  }
  /// Verify a manual cash/transfer payment by document ID.
  /// Sets paymentStatus = "Paid" in receipts, updates the application to
Pending Approval,
  /// and updates bus_passes to Paid/Pending (pass remains pending admin
approval).
  Future<void> verifyManualPayment(
    String receiptId,
    String studentUid,
    String adminUid,
  ) async {
    final batch = _firestore.batch();
    // 1. Update the receipt document
    final receiptRef = _firestore.collection('receipts').doc(receiptId);
    batch.update(receiptRef, {
      'paymentStatus': 'Paid',
      'verifiedBy': adminUid,
      'verifiedAt': FieldValue.serverTimestamp(),
      'paidAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // Also update payments document if present
    final paymentRef = _firestore.collection('payments').doc(receiptId);
    batch.set(paymentRef, {
      'paymentStatus': 'Paid',
      'verifiedBy': adminUid,
      'verifiedAt': FieldValue.serverTimestamp(),
      'paidAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    // 2. Update the pending application in bus_pass_applications
    // Payment is now verified as Paid; application is eligible for Admin
approval (status = 'Pending')
    final appQuery = await _firestore
        .collection('bus_pass_applications')
        .where('uid', isEqualTo: studentUid)
        .where('paymentStatus', whereIn: const [
          'Pending',
          'Pending Payment',
          'Pending Verification',
          'Unpaid',
          'submitted_for_verification',
          'pending',
          'created',
          'processing'
```

```
        ])
        .limit(1)
        .get();
    for (final doc in appQuery.docs) {
      batch.update(doc.reference, {
        'paymentStatus': 'Paid',
        'status': 'Pending',
        'passStatus': 'Pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    // 3. Update digital bus pass in bus_passes (Payment is verified, awaiting
Admin approval)
    final passRef = _firestore.collection('bus_passes').doc(studentUid);
    final passSnap = await passRef.get();
    if (passSnap.exists) {
      batch.update(passRef, {
        'paymentStatus': 'Paid',
        'status': 'Pending',
        'passStatus': 'Pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
  /// Mark payment as failed.
  /// Updates paymentStatus to "Failed" and deactivates or sets the
corresponding application and pass to "Failed".
  Future<void> markPaymentFailed(String receiptId, String studentUid) async {
    final batch = _firestore.batch();
    // 1. Update the receipt document
    final receiptRef = _firestore.collection('receipts').doc(receiptId);
    batch.update(receiptRef, {
      'paymentStatus': 'Failed',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final paymentRef = _firestore.collection('payments').doc(receiptId);
    batch.set(paymentRef, {
      'paymentStatus': 'Failed',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    // 2. Update the pending application in bus_pass_applications
    final appQuery = await _firestore
        .collection('bus_pass_applications')
        .where('uid', isEqualTo: studentUid)
        .where('passStatus', isEqualTo: 'Pending Payment')
        .limit(1)
        .get();
    for (final doc in appQuery.docs) {
      batch.update(doc.reference, {
        'paymentStatus': 'Failed',
        'passStatus': 'Failed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
```

```
    // 3. Update digital bus pass in bus_passes if it exists
    final passRef = _firestore.collection('bus_passes').doc(studentUid);
    final passSnap = await passRef.get();
    if (passSnap.exists) {
      batch.update(passRef, {
        'paymentStatus': 'Failed',
        'passStatus': 'Failed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
  /// Refund a successful payment (Status Only).
  /// Updates paymentStatus to "Refunded" and marks the application and pass as
"Refunded" / inactive.
  Future<void> refundPayment(String receiptId, String studentUid) async {
    final batch = _firestore.batch();
    // 1. Update the receipt document
    final receiptRef = _firestore.collection('receipts').doc(receiptId);
    batch.update(receiptRef, {
      'paymentStatus': 'Refunded',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final paymentRef = _firestore.collection('payments').doc(receiptId);
    batch.set(paymentRef, {
      'paymentStatus': 'Refunded',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    // 2. Update all applications for the student to status "Refunded"
    final appQuery = await _firestore
        .collection('bus_pass_applications')
        .where('uid', isEqualTo: studentUid)
        .get();
    for (final doc in appQuery.docs) {
      batch.update(doc.reference, {
        'paymentStatus': 'Refunded',
        'passStatus': 'Refunded',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    // 3. Update/cancel digital bus pass in bus_passes
    final passRef = _firestore.collection('bus_passes').doc(studentUid);
    final passSnap = await passRef.get();
    if (passSnap.exists) {
      batch.update(passRef, {
        'paymentStatus': 'Refunded',
        'passStatus': 'Refunded',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
```

```
  // -------------------------------------------------------
```

```
  // STUDENT ACTIONS
  // -------------------------------------------------------
  Future<void> suspendStudent(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  Future<void> activateStudent(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  Future<void> deleteStudent(String uid) async {
    final batch = _firestore.batch();
    batch.delete(_firestore.collection('users').doc(uid));
    batch.delete(_firestore.collection('bus_passes').doc(uid));
    final apps = await _firestore
        .collection('bus_pass_applications')
        .where('uid', isEqualTo: uid)
        .get();
    for (final doc in apps.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
  Future<void> approveStudentPass(
    String uid,
    String adminUid, {
    DateTime? validUntil,
  }) async {
    final now = DateTime.now();
    final passNumber =
        'ICEM-BP-${now.year}-$
{now.millisecondsSinceEpoch.toString().substring(7)}';
    await _firestore.runTransaction((transaction) async {
      final passRef = _firestore.collection('bus_passes').doc(uid);
      final passSnap = await transaction.get(passRef);
      String paymentStatus = '';
      String existingPassId = '';
      if (passSnap.exists) {
        final d = passSnap.data()!;
        paymentStatus = (d['paymentStatus'] as String? ??
'').trim().toLowerCase();
        existingPassId = d['passId'] as String? ?? '';
      }
      if (paymentStatus != 'paid' && paymentStatus != 'success') {
        throw const ServerFailure(
            'Payment required before approval. Student has not completed
verified payment.');
      }
      final passId = existingPassId.isNotEmpty
          ? existingPassId
          : 'ICEM-PASS-$
{now.millisecondsSinceEpoch.toRadixString(16).toUpperCase()}';
```

```
      final validFromTimestamp = Timestamp.fromDate(now);
      final validUntilTimestamp = validUntil != null
          ? Timestamp.fromDate(validUntil)
          : (passSnap.data()?['validUntil'] as Timestamp? ??
              passSnap.data()?['expiryDate'] as Timestamp? ??
              Timestamp.fromDate(now.add(const Duration(days: 180))));
      final qrPayload = jsonEncode({
        'type': 'ICEM_BUS_PASS',
        'passNumber': passNumber,
        'passId': passId,
        'studentId': uid,
      });
      transaction.update(passRef, {
        'status': 'Active',
        'passStatus': 'Active',
        'applicationStatus': 'Approved',
        'passNumber': passNumber,
        'passId': passId,
        'approvedBy': adminUid,
        'approvedAt': FieldValue.serverTimestamp(),
        'validFrom': validFromTimestamp,
        'validUntil': validUntilTimestamp,
        'expiryDate': validUntilTimestamp,
        'qrCode': qrPayload,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    final appQuery = await _firestore
        .collection('bus_pass_applications')
        .where('uid', isEqualTo: uid)
        .where('paymentStatus', whereIn: const ['Paid', 'paid', 'Success',
'success'])
        .get();
    for (final doc in appQuery.docs) {
      await doc.reference.update({
        'status': 'Approved',
        'applicationStatus': 'Approved',
        'passStatus': 'Active',
        'passNumber': passNumber,
        'approvedBy': adminUid,
        'approvedAt': FieldValue.serverTimestamp(),
        'validFrom': Timestamp.fromDate(now),
        'validUntil': validUntil != null
            ? Timestamp.fromDate(validUntil)
            : Timestamp.fromDate(now.add(const Duration(days: 180))),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
  /// Revoke an active bus pass.
  /// Sets passStatus = 'Revoked' in both `bus_passes` and
`bus_pass_applications`.
  Future<void> revokePass(
    String studentUid,
    String reason,
    String adminUid,
  ) async {
    final batch = _firestore.batch();
```

```
    final passRef = _firestore.collection('bus_passes').doc(studentUid);
    batch.update(passRef, {
      'status': 'Revoked',
      'passStatus': 'Revoked',
      'revokedBy': adminUid,
      'revocationReason': reason,
      'revokedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final appQuery = await _firestore
        .collection('bus_pass_applications')
        .where('uid', isEqualTo: studentUid)
        .where('passStatus', whereIn: const ['Active', 'Approved'])
        .get();
    for (final doc in appQuery.docs) {
      batch.update(doc.reference, {
        'status': 'Revoked',
        'passStatus': 'Revoked',
        'revokedBy': adminUid,
        'revocationReason': reason,
        'revokedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
  Future<void> rejectStudentPass(String uid, String reason) async {
    final batch = _firestore.batch();
    final passRef = _firestore.collection('bus_passes').doc(uid);
    final passSnap = await passRef.get();
    if (passSnap.exists) {
      batch.update(passRef, {
        'passStatus': 'Rejected',
        'rejectionReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      batch.set(passRef, {
        'uid': uid,
        'passStatus': 'Rejected',
        'rejectionReason': reason,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    final appQuery = await _firestore
        .collection('bus_pass_applications')
        .where('uid', isEqualTo: uid)
        .get();
    for (final doc in appQuery.docs) {
      batch.update(doc.reference, {
        'passStatus': 'Rejected',
        'rejectionReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
```

```
  }
  // -------------------------------------------------------
  // NOTIFICATION
  // -------------------------------------------------------
  Future<void> sendNotification({
    required String title,
    required String body,
    required String targetAudience,
  }) async {
    await _firestore.collection('notifications').add({
      'title': title,
      'body': body,
      'targetAudience': targetAudience,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });
  }
}
================================================
FILE: lib/features/admin/domain/admin_providers.dart
================================================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/features/auth/domain/entities/user_entity.dart';
// ============================================================
// TAB / SEARCH / FILTER STATE PROVIDERS
// ============================================================
/// Currently selected sidebar tab index (persisted across rebuilds)
final adminTabProvider = StateProvider<int>((ref) => 0);
```

- `/// Dashboard search query (name / PRN / college ID) final dashboardSearchQueryProvider = StateProvider.autoDispose<String>((ref) => ''); /// Dashboard status filter chip selection final dashboardStatusFilterProvider = StateProvider.autoDispose<String>((ref) => 'All'); /// Routes tab — status filter chip: 'All', 'Active', 'Inactive' final routeStatusFilterProvider = StateProvider.autoDispose<String>((ref) => 'All');` 

- `/// Routes tab — search query final routeSearchQueryProvider = StateProvider.autoDispose<String>((ref) => ''); /// Buses tab — status filter chip: 'All', 'Active', 'Maintenance', 'Inactive' final busStatusFilterProvider = StateProvider.autoDispose<String>((ref) => 'All');` 

- `/// Buses tab — search query final busSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');` 

```
// ============================================================
```

```
// LIVE FIRESTORE STREAM PROVIDERS — SUMMARY CARD COUNTS
// ============================================================
final totalStudentsStreamProvider = StreamProvider.autoDispose<int>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .snapshots()
      .map((s) => s.docs.where((d) =>
UserEntity.isStudentUser(d.data())).length);
});
final activePassesStreamProvider = StreamProvider.autoDispose<int>((ref) {
  return FirebaseFirestore.instance
      .collection('bus_passes')
      .where('passStatus', isEqualTo: 'Active')
      .snapshots()
      .map((s) => s.docs.length);
});
final pendingAppsStreamProvider = StreamProvider.autoDispose<int>((ref) {
  return FirebaseFirestore.instance
      .collection('bus_pass_applications')
      .snapshots()
      .map((s) => s.docs.where((d) {
            final st = (d.data()['status'] ?? d.data()['passStatus'] ??
'').toString();
            return st == 'Pending' || st == 'Payment Pending' || st == 'Pending
Approval' || st == 'Pending Payment';
          }).length);
});
final approvedPassesStreamProvider = StreamProvider.autoDispose<int>((ref) {
  return FirebaseFirestore.instance
      .collection('bus_pass_applications')
      .snapshots()
      .map((s) => s.docs.where((d) {
            final st = (d.data()['status'] ?? d.data()['passStatus'] ??
'').toString();
            return st == 'Approved' || st == 'Active';
          }).length);
});
final rejectedPassesStreamProvider = StreamProvider.autoDispose<int>((ref) {
  return FirebaseFirestore.instance
      .collection('bus_pass_applications')
      .snapshots()
      .map((s) => s.docs.where((d) {
            final st = (d.data()['status'] ?? d.data()['passStatus'] ??
'').toString();
            return st == 'Rejected';
          }).length);
});
final expiredPassesStreamProvider = StreamProvider.autoDispose<int>((ref) {
  return FirebaseFirestore.instance
      .collection('bus_passes')
      .where('passStatus', isEqualTo: 'Expired')
      .snapshots()
      .map((s) => s.docs.length);
});
final correctionRequiredStreamProvider =
    StreamProvider.autoDispose<int>((ref) {
  return FirebaseFirestore.instance
```

```
      .collection('bus_pass_applications')
      .where('status', isEqualTo: 'Correction Required')
      .snapshots()
      .map((s) => s.docs.length);
});
```

```
final totalRoutesStreamProvider = StreamProvider.autoDispose<int>((ref) {
  return FirebaseFirestore.instance
      .collection('bus_routes')
      .snapshots()
      .map((s) => s.docs.length);
});
```

```
final totalBusesStreamProvider = StreamProvider.autoDispose<int>((ref) {
  return FirebaseFirestore.instance
      .collection('buses')
      .snapshots()
      .map((s) => s.docs.length);
});
// ============================================================
// RECENT APPLICATIONS (latest 10)
// ============================================================
```

```
final recentApplicationsStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('bus_pass_applications')
      .orderBy('createdAt', descending: true)
      .limit(10)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList());
});
// ============================================================
// FILTERED APPLICATIONS STREAM (for applications tab)
// ============================================================
```

```
final filteredApplicationsStreamProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, statusFilter) {
  return FirebaseFirestore.instance
      .collection('bus_pass_applications')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final pStatus = (data['paymentStatus'] as String? ?? '').toLowerCase();
      final aStatus = (data['status'] as String? ?? data['passStatus'] as
String? ?? '').toLowerCase();
      if ((aStatus == 'approved' || aStatus == 'active') && pStatus != 'paid' &&
pStatus != 'success') {
        // Diagnostic warning for historical inconsistent records
        debugPrint('🚌 [INCONSISTENT APPLICATION DETECTED]: ID: ${doc.id},
Application Status: ${data['status']}, Payment Status: ${data['paymentStatus']},
Student: ${data['fullName'] ?? data['studentName']}');
      }
    }
    return snapshot.docs.map((doc) {
```

```
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).where((app) {
      if (statusFilter == 'All') return true;
      final st = (app['status'] ?? app['passStatus'] ?? '').toString();
      final pStatus = (app['paymentStatus'] ?? '').toString().toLowerCase();
      final isPaid = pStatus == 'paid' || pStatus == 'success';
```

```
      if (statusFilter == 'Pending') {
        return st == 'Pending' || st == 'Pending Approval' || st == 'Payment
Pending' || st == 'Pending Payment';
      } else if (statusFilter == 'Approved') {
        return st == 'Approved' || st == 'Active';
      } else if (statusFilter == 'Rejected') {
        return st == 'Rejected';
      } else if (statusFilter == 'Payment Pending') {
        return !isPaid && (st == 'Payment Pending' || st == 'Pending Payment' ||
st == 'Pending');
      }
      return st == statusFilter;
    }).toList();
  });
});
// ============================================================
// ROUTES, BUSES, STUDENTS LIST STREAMS
// ============================================================
```

```
final routesListStreamProvider =
```

```
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
```

```
      .collection('bus_routes')
```

```
      .snapshots()
      .map((s) => s.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList());
```

```
});
```

```
final busesListStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('buses')
      .snapshots()
      .map((s) => s.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList());
```

```
});
```

```
final studentsListStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .snapshots()
      .map((s) => s.docs
          .where((d) => UserEntity.isStudentUser(d.data()))
          .map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
```

```
          }).toList());
```

```
});
final allUsersListStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .snapshots()
      .map((s) => s.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList());
});
// ============================================================
// SINGLE APPLICATION STREAM (for detail screen)
// ============================================================
final singleApplicationStreamProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, applicationId) {
  return FirebaseFirestore.instance
      .collection('bus_pass_applications')
      .doc(applicationId)
      .snapshots()
      .map((doc) {
    if (!doc.exists) return null;
    final data = doc.data()!;
    data['id'] = doc.id;
    return data;
  });
});
final paymentsListStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('payments')
      .snapshots()
      .asyncMap((paymentsSnap) async {
        final paymentsMap = <String, Map<String, dynamic>>{};
        for (final doc in paymentsSnap.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          paymentsMap[doc.id] = data;
        }
        try {
          final receiptsSnap =
              await FirebaseFirestore.instance.collection('receipts').get();
          for (final doc in receiptsSnap.docs) {
            if (!paymentsMap.containsKey(doc.id)) {
              final data = Map<String, dynamic>.from(doc.data());
              data['id'] = doc.id;
              paymentsMap[doc.id] = data;
            }
          }
        } catch (_) {}
        final list = paymentsMap.values.toList();
        list.sort((a, b) {
          final aDate = a['createdAt'] ?? a['paymentDate'];
          final bDate = b['createdAt'] ?? b['paymentDate'];
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
```

```
          if (bDate == null) return -1;
          if (aDate is Timestamp && bDate is Timestamp) {
            return bDate.compareTo(aDate);
          }
          return 0;
        });
        return list;
      });
});
final busPassesListStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('bus_passes')
      .snapshots()
      .map((s) => s.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList());
});
final applicationsListStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('bus_pass_applications')
      .snapshots()
      .map((s) => s.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList());
});
```

```
================================================
FILE: lib/features/admin/domain/.gitkeep
================================================
[Empty file]
```

```
================================================
FILE: lib/features/admin/presentation/.gitkeep
================================================
[Empty file]
```

```
================================================
FILE: lib/features/admin/presentation/views/admin_applications_tab.dart
================================================
// ignore_for_file: deprecated_member_use, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import
'package:icem_bus/features/admin/data/repositories/admin_repository.dart';
import 'package:icem_bus/features/admin/domain/admin_providers.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_widgets.dart';
import
'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
```

```
/// Full applications management tab with search, filter,
approve/reject/correction
class AdminApplicationsTab extends ConsumerStatefulWidget {
  const AdminApplicationsTab({super.key});
```

```
  @override
  ConsumerState<AdminApplicationsTab> createState() =>
      _AdminApplicationsTabState();
}
```

```
class _AdminApplicationsTabState extends ConsumerState<AdminApplicationsTab> {
  String _searchQuery = '';
  String _statusFilter = 'All';
```

```
  @override
  Widget build(BuildContext context) {
    final applicationsAsync =
        ref.watch(filteredApplicationsStreamProvider(_statusFilter));
    return Column(
      children: [
        // Search and filter row
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            children: [
              AdminSearchBar(
                hintText: 'Search by Name, PRN, or College ID...',
                value: _searchQuery,
                onChanged: (q) => setState(() => _searchQuery = q),
              ),
              const SizedBox(height: 12),
              AdminFilterChips(
                filters: const [
                  'All',
                  'Pending',
                  'Approved',
                  'Rejected',
                  'Expired',
                ],
                selected: _statusFilter,
                onSelected: (f) => setState(() => _statusFilter = f),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Applications list
        Expanded(
          child: applicationsAsync.when(
            loading: () => const AdminLoadingState(),
            error: (e, _) => AdminErrorState(message: e.toString()),
            data: (applications) {
              var filtered = applications;
              if (_searchQuery.isNotEmpty) {
                final q = _searchQuery.toLowerCase();
                filtered = filtered.where((app) {
                  final name = (app['studentName'] ?? app['fullName'] ?? '')
                      .toString()
                      .toLowerCase();
                  final prn = (app['prn'] ?? '').toString().toLowerCase();
                  final collegeId = (app['collegeId'] ??
'').toString().toLowerCase();
                  return name.contains(q) || prn.contains(q) ||
```

```
collegeId.contains(q);
```

```
                }).toList();
              }
              if (filtered.isEmpty) {
                return const AdminEmptyState(
                  title: 'No applications found',
                  subtitle: 'Try adjusting your search or filter criteria.',
                  icon: Icons.search_off_rounded,
                );
              }
              final repo = AdminRepository();
              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final app = filtered[i];
                  return AdminApplicationCard(
                    application: app,
                    onApprove: () => _confirmApprove(repo, app['id'],
app['paymentStatus']),
                    onReject: () => _showRejectDialog(repo, app['id']),
                    onViewDetails: () => _navigateToDetail(app['id']),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
  /// Navigate to the full application detail screen
  void _navigateToDetail(String applicationId) {
    context.push('/admin/application/$applicationId');
  }
  /// Approve with confirmation — includes admin UID
  void _confirmApprove(AdminRepository repo, String applicationId, [dynamic
paymentStatus]) {
    final pStatus = (paymentStatus ?? '').toString().trim().toLowerCase();
    if (pStatus.isNotEmpty && pStatus != 'paid' && pStatus != 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment required before approval. Student must complete
verified payment first.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Approve Application'),
        content: const Text(
            'Are you sure you want to approve this bus pass application? A
unique Pass ID will be generated and digital pass activated.'),
```

```
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final adminUid =
                    ref.read(authControllerProvider).user?.uid ?? '';
                await repo.approveApplication(applicationId, adminUid);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Application approved successfully'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Approve',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  /// Reject with reason dialog
  void _showRejectDialog(AdminRepository repo, String applicationId) {
    final reasonController = TextEditingController();
```

```
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Application'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejecting this
application.'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Rejection reason...',
```

```
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a rejection reason'),
                    backgroundColor: AppColors.warning,
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                final adminUid =
                    ref.read(authControllerProvider).user?.uid ?? '';
                await repo.rejectApplication(applicationId, reason, adminUid);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Application rejected'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Reject',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

```
================================================
FILE: lib/features/admin/presentation/views/admin_charts.dart
================================================
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
class ChartDataPoint {
  final String label;
  final double value;
  ChartDataPoint(this.label, this.value);
}
// ============================================================
// LINE AREA CHART (Interactive)
// ============================================================
class LineAreaChart extends StatefulWidget {
  final List<ChartDataPoint> data;
  final String title;
  final Color primaryColor;
  final String valuePrefix;
  const LineAreaChart({
    super.key,
    required this.data,
    required this.title,
    this.primaryColor = AppColors.primaryCrimson,
    this.valuePrefix = '',
  });
  @override
  State<LineAreaChart> createState() => _LineAreaChartState();
}
class _LineAreaChartState extends State<LineAreaChart> {
  int? _selectedIndex;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.data.length < 2) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.show_chart_rounded, size: 36, color:
theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              const SizedBox(height: 10),
              Text(
                widget.data.isEmpty ? 'No data available' : 'Insufficient trend
data (requires multiple time points)',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant,
fontSize: 13),
              ),
```

```
            ],
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              const height = 180.0;
              return GestureDetector(
                onPanStart: (details) => _updateSelection(details.localPosition,
width, height),
                onPanUpdate: (details) =>
_updateSelection(details.localPosition, width, height),
                onPanEnd: (_) => setState(() => _selectedIndex = null),
                onTapDown: (details) => _updateSelection(details.localPosition,
width, height),
                onTapUp: (_) => setState(() => _selectedIndex = null),
                child: CustomPaint(
                  size: Size(width, height),
                  painter: _LineChartPainter(
                    data: widget.data,
                    primaryColor: widget.primaryColor,
                    selectedIndex: _selectedIndex,
                    valuePrefix: widget.valuePrefix,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  void _updateSelection(Offset localPos, double width, double height) {
```

```
    const paddingLeft = 40.0;
    const paddingRight = 10.0;
    final chartWidth = width - paddingLeft - paddingRight;
    if (widget.data.length < 2) return;
    final xRatio = (localPos.dx - paddingLeft) / chartWidth;
    final index = (xRatio * (widget.data.length - 1)).round().clamp(0,
widget.data.length - 1);
    setState(() {
      _selectedIndex = index;
    });
  }
}
class _LineChartPainter extends CustomPainter {
  final List<ChartDataPoint> data;
  final Color primaryColor;
  final int? selectedIndex;
  final String valuePrefix;
  _LineChartPainter({
    required this.data,
    required this.primaryColor,
    required this.selectedIndex,
    required this.valuePrefix,
  });
  @override
  void paint(Canvas canvas, Size size) {
    const paddingLeft = 40.0;
    const paddingRight = 10.0;
    const paddingTop = 20.0;
    const paddingBottom = 20.0;
    final chartWidth = size.width - paddingLeft - paddingRight;
    final chartHeight = size.height - paddingTop - paddingBottom;
    final maxVal = data.map((d) => d.value).reduce(math.max);
    final minVal = 0.0;
    final range = maxVal > 0 ? maxVal : 1.0;
    // Draw Y grid lines and labels
    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1.0;
    final textStyle = const TextStyle(color: Color(0xFF94A3B8), fontSize: 9);
    for (int i = 0; i <= 4; i++) {
      final yRatio = i / 4.0;
      final y = paddingTop + chartHeight * (1 - yRatio);
      final val = minVal + range * yRatio;
      // Grid line
      canvas.drawLine(Offset(paddingLeft, y), Offset(size.width - paddingRight,
y), gridPaint);
      // Label
      final tp = TextPainter(
        text: TextSpan(
          text: '$valuePrefix${val.toStringAsFixed(0)}',
          style: textStyle,
```

```
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(paddingLeft - tp.width - 6, y - tp.height / 2));
    }
    // Coordinates of data points
    final points = <Offset>[];
    final denom = data.length > 1 ? (data.length - 1) : 1;
    for (int i = 0; i < data.length; i++) {
      final x = paddingLeft + (i / denom) * chartWidth;
      final y = paddingTop + chartHeight * (1 - (data[i].value / range));
      points.add(Offset(x, y));
    }
    // Draw Area Fill (Gradient)
    if (points.isNotEmpty) {
      final fillPath = Path()
        ..moveTo(points.first.dx, paddingTop + chartHeight)
        ..lineTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        fillPath.lineTo(points[i].dx, points[i].dy);
      }
      fillPath.lineTo(points.last.dx, paddingTop + chartHeight);
      fillPath.close();
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            primaryColor.withValues(alpha: 0.3),
            primaryColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTRB(paddingLeft, paddingTop, size.width -
paddingRight, paddingTop + chartHeight));
```

```
      canvas.drawPath(fillPath, fillPaint);
      // Draw Stroke Line
      final strokePaint = Paint()
        ..color = primaryColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
```

```
      final strokePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        strokePath.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(strokePath, strokePaint);
    }
    // Draw X labels
    for (int i = 0; i < data.length; i++) {
      if (data.length > 6 && i % (data.length / 4).ceil() != 0 && i !=
data.length - 1) {
        continue;
      }
      final x = points[i].dx;
      final y = size.height - paddingBottom + 4;
```

```
      final tp = TextPainter(
        text: TextSpan(text: data[i].label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y));
    }
    // Draw Interactive Tooltip
    if (selectedIndex != null && selectedIndex! < points.length) {
      final selectedPoint = points[selectedIndex!];
      final item = data[selectedIndex!];
      // Vertical indicator line
      final indicatorPaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.4)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(selectedPoint.dx, paddingTop),
        Offset(selectedPoint.dx, paddingTop + chartHeight),
        indicatorPaint,
      );
      // Circle marker
      final markerInner = Paint()..color = primaryColor;
      final markerOuter = Paint()..color = Colors.white;
      canvas.drawCircle(selectedPoint, 5, markerOuter);
      canvas.drawCircle(selectedPoint, 3, markerInner);
      // Tooltip Box
      final tooltipText = '$valuePrefix${item.value.toStringAsFixed(0)}';
      final tooltipLabel = item.label;
      final tpTitle = TextPainter(
        text: TextSpan(
          text: '$tooltipLabel: ',
          style: const TextStyle(color: Colors.white70, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final tpVal = TextPainter(
        text: TextSpan(
          text: tooltipText,
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight:
FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final boxWidth = tpTitle.width + tpVal.width + 12;
      final boxHeight = 22.0;
      double boxX = selectedPoint.dx - boxWidth / 2;
      if (boxX < paddingLeft) boxX = paddingLeft;
      if (boxX + boxWidth > size.width - paddingRight) boxX = size.width -
paddingRight - boxWidth;
      double boxY = selectedPoint.dy - boxHeight - 8;
      if (boxY < paddingTop) boxY = selectedPoint.dy + 8;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(boxX, boxY, boxWidth, boxHeight),
        const Radius.circular(6),
```

```
      );
```

```
      final boxPaint = Paint()..color = const Color(0xFF0F172A);
      canvas.drawRRect(rect, boxPaint);
```

```
      tpTitle.paint(canvas, Offset(boxX + 6, boxY + (boxHeight - tpTitle.height)
/ 2));
      tpVal.paint(canvas, Offset(boxX + 6 + tpTitle.width, boxY + (boxHeight -
tpVal.height) / 2));
    }
  }
```

```
  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex || oldDelegate.data !=
data;
  }
}
// ============================================================
// DONUT PIE CHART
// ============================================================
class DonutChartWidget extends StatelessWidget {
  final Map<String, double> data;
  final String title;
  final List<Color> colors;
  const DonutChartWidget({
    super.key,
    required this.data,
    required this.title,
    required this.colors,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = data.values.fold(0.0, (sum, val) => sum + val);
    if (total == 0) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.pie_chart_outline_rounded, size: 36, color:
theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              const SizedBox(height: 10),
              Text('No sufficient data available', style: TextStyle(color:
theme.colorScheme.onSurfaceVariant, fontSize: 13)),
            ],
          ),
        ),
      );
    }
    return Container(
```

```
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 130,
                height: 130,
                child: CustomPaint(
                  painter: _DonutChartPainter(
                    data: data,
                    colors: colors,
                    total: total,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(data.keys.length, (index) {
                    final key = data.keys.elementAt(index);
                    final val = data[key]!;
                    final color = colors[index % colors.length];
                    final pct = total > 0 ? (val / total *
100).toStringAsFixed(1) : '0';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
```

```
                            child: Text(
                              key,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color:
Color(0xFF475569)),
                            ),
                          ),
                          Text(
                            '${val.toInt()} ($pct%)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
class _DonutChartPainter extends CustomPainter {
  final Map<String, double> data;
  final List<Color> colors;
  final double total;
```

```
  _DonutChartPainter({
    required this.data,
    required this.colors,
    required this.total,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(10, 10, size.width - 20, size.height - 20);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20.0
      ..strokeCap = StrokeCap.butt;
    double startAngle = -math.pi / 2;
    for (int i = 0; i < data.length; i++) {
      final val = data.values.elementAt(i);
      final sweepAngle = (val / total) * 2 * math.pi;
      if (sweepAngle > 0) {
        paint.color = colors[i % colors.length];
        canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
        startAngle += sweepAngle;
      }
    }
    final textPainter = TextPainter(
      text: TextSpan(
        children: [
```

```
          const TextSpan(
            text: 'Total\n',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 10, height:
1.2),
          ),
          TextSpan(
            text: '${total.toInt()}',
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 18,
fontWeight: FontWeight.bold, height: 1.2),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        size.width / 2 - textPainter.width / 2,
        size.height / 2 - textPainter.height / 2,
      ),
    );
  }
  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.total != total || oldDelegate.data != data;
  }
}
// ============================================================
// HORIZONTAL BAR CHART
// ============================================================
class HorizontalBarChart extends StatelessWidget {
  final List<ChartDataPoint> data;
  final String title;
  final Color barColor;
  const HorizontalBarChart({
    super.key,
    required this.data,
    required this.title,
    this.barColor = AppColors.info,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxVal = data.isEmpty ? 0.0 : data.map((d) =>
d.value).reduce(math.max);
    if (data.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
```

```
            children: [
              Icon(Icons.bar_chart_rounded, size: 36, color:
theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              const SizedBox(height: 10),
              Text('No sufficient data available', style: TextStyle(color:
theme.colorScheme.onSurfaceVariant, fontSize: 13)),
            ],
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: data.length,
            itemBuilder: (context, index) {
              final item = data[index];
              final ratio = maxVal > 0 ? item.value / maxVal : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        item.label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
```

```
                      child: Stack(
                        children: [
                          Container(
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: ratio,
                            child: Container(
                              height: 12,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    barColor.withValues(alpha: 0.8),
                                    barColor,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${item.value.toInt()}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
```

```
================================================
```

```
FILE: lib/features/admin/presentation/views/admin_dashboard.dart
================================================
// ignore_for_file: deprecated_member_use, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/routes/app_routes.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import
```

```
'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/features/admin/domain/admin_providers.dart';
import
```

```
'package:icem_bus/features/admin/presentation/views/admin_overview_tab.dart';
import
```

```
'package:icem_bus/features/admin/presentation/views/admin_applications_tab.dart'
;
import
'package:icem_bus/features/admin/presentation/views/admin_routes_tab.dart';
import
'package:icem_bus/features/admin/presentation/views/admin_buses_tab.dart';
import
'package:icem_bus/features/admin/presentation/views/admin_students_tab.dart';
import
'package:icem_bus/features/admin/presentation/views/admin_payments_tab.dart';
import
'package:icem_bus/features/admin/presentation/views/admin_notifications_tab.dart
';
```

```
import
```

```
'package:icem_bus/features/admin/presentation/views/admin_reports_tab.dart';
import
```

```
'package:icem_bus/features/admin/presentation/views/admin_settings_tab.dart';
```

```
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  ConsumerState<AdminDashboardScreen> createState() =>
_AdminDashboardScreenState();
}
```

```
class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
```

```
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final currentTab = ref.watch(adminTabProvider);
    final user = authState.user;
    final theme = Theme.of(context);
```

```
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) =>
context.go(AppRoutes.login));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (user.role != 'Admin') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:
Text('Access Denied'), backgroundColor: AppColors.error));
        context.go(AppRoutes.studentDashboard);
      });
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
```

```
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child:
Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.gpp_bad_rounded, size: 80, color:
AppColors.primaryCrimson),
          const SizedBox(height: 24),
          Text('Access Denied', style:
theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.onSurface,
fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
```

```
          Text('Only Administrators are authorized to view this management
```

```
console.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
textAlign: TextAlign.center),
        ]))),
      );
    }
    final isMobile = MediaQuery.of(context).size.width < 900;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: isMobile ? _buildMobileAppBar(context, currentTab, theme) : null,
      drawer: isMobile ? Drawer(backgroundColor: theme.colorScheme.surface,
child: _AdminDrawer(currentTab: currentTab, onNavigate: (i) => _navigate(ref,
context, i, true), onLogout: () => _handleLogout(context))) : null,
      body: SafeArea(
        child: Row(
          children: [
            if (!isMobile) ...[
              SizedBox(width: 260, child: Container(color:
theme.colorScheme.surface, child: _AdminDrawer(currentTab: currentTab,
onNavigate: (i) => _navigate(ref, context, i, false), onLogout: () =>
_handleLogout(context)))),
              Container(width: 1, color: theme.dividerColor),
            ],
            Expanded(
              child: Container(
                color: theme.scaffoldBackgroundColor,
                child: Column(children: [
                  if (!isMobile) _buildDesktopHeader(context, user.fullName),
                  Expanded(child: AnimatedSwitcher(duration: const
Duration(milliseconds: 220), transitionBuilder: (child, animation) =>
FadeTransition(opacity: animation, child: child), child:
_buildTabContent(currentTab))),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
  PreferredSizeWidget _buildMobileAppBar(BuildContext context, int currentTab,
ThemeData theme) {
    return AppBar(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(icon: Icon(Icons.menu_rounded, color:
theme.colorScheme.onSurface, size: 24), onPressed: () =>
_scaffoldKey.currentState?.openDrawer(), tooltip: 'Open Menu'),
      titleSpacing: 0,
      title: Row(children: [
        Container(width: 30, height: 30, padding: const EdgeInsets.all(4),
decoration: BoxDecoration(gradient: const LinearGradient(colors:
[AppColors.primaryCrimson, AppColors.darkCrimson], begin: Alignment.topLeft,
end: Alignment.bottomRight), borderRadius: BorderRadius.circular(8)), child:
Image.asset('assets/images/bus_logo.png', fit: BoxFit.contain)),
        const SizedBox(width: 10),
        Expanded(child: Text(_getTabTitle(currentTab), style:
TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color:
theme.colorScheme.onSurface, letterSpacing: -0.2), overflow:
TextOverflow.ellipsis, maxLines: 1)),
```

```
      ]),
      actions: [
        IconButton(icon: Icon(Icons.notifications_none_rounded, color:
theme.colorScheme.onSurfaceVariant, size: 22), onPressed: () =>
ref.read(adminTabProvider.notifier).state = 6, tooltip: 'Notifications'),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child:
Container(height: 1, color: theme.dividerColor)),
    );
  }
```

```
  Widget _buildDesktopHeader(BuildContext context, String adminName) {
    final currentTab = ref.watch(adminTabProvider);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: BoxDecoration(color: theme.colorScheme.surface, border:
Border(bottom: BorderSide(color: theme.dividerColor))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ICEM TRANSPORT OFFICE', style: TextStyle(color:
AppColors.primaryCrimson, fontWeight: FontWeight.w800, fontSize: 10,
letterSpacing: 1.4)),
            const SizedBox(height: 3),
            Text(_getTabTitle(currentTab), style: TextStyle(fontSize: 20,
fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface, letterSpacing:
-0.3)),
          ]),
          Row(children: [
            IconButton(icon: Icon(Icons.qr_code_scanner_rounded, color:
theme.colorScheme.onSurfaceVariant, size: 20), onPressed: () =>
context.push(AppRoutes.qrVerification), tooltip: 'Verify QR'),
            const SizedBox(width: 4),
```

```
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color:
theme.colorScheme.surfaceContainerHighest, borderRadius:
BorderRadius.circular(10), border: Border.all(color: theme.dividerColor)),
              child: Row(children: [const
Icon(Icons.admin_panel_settings_rounded, color: AppColors.primaryCrimson, size:
16), const SizedBox(width: 7), Text(adminName, style: TextStyle(color:
theme.colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 13))]),
            ),
```

```
            const SizedBox(width: 10),
```

```
            Material(color: AppColors.primaryCrimson.withOpacity(0.08),
borderRadius: BorderRadius.circular(10), child: InkWell(borderRadius:
BorderRadius.circular(10), onTap: () => _handleLogout(context), child: const
Padding(padding: EdgeInsets.all(9), child: Icon(Icons.logout_rounded, color:
AppColors.primaryCrimson, size: 18)))),
          ]),
        ],
      ),
    );
  }
```

```
  Widget _buildTabContent(int tabIndex) {
    switch (tabIndex) {
      case 0: return const AdminOverviewTab(key: ValueKey('overview'));
      case 1: return const AdminApplicationsTab(key: ValueKey('applications'));
      case 2: return const AdminRoutesTab(key: ValueKey('routes'));
      case 3: return const AdminBusesTab(key: ValueKey('buses'));
```

```
      case 4: return const AdminStudentsTab(key: ValueKey('students'));
      case 5: return const AdminPaymentsTab(key: ValueKey('payments'));
      case 6: return const AdminNotificationsTab(key:
ValueKey('notifications'));
      case 7: return const AdminReportsTab(key: ValueKey('reports'));
      case 8: return const AdminSettingsTab(key: ValueKey('settings'));
      default: return const AdminOverviewTab(key: ValueKey('overview'));
    }
  }
  String _getTabTitle(int tabIndex) {
    switch (tabIndex) {
      case 0: return 'Overview Dashboard';
      case 1: return 'Pass Management';
      case 2: return 'Route Management';
      case 3: return 'Bus Management';
      case 4: return 'Student Management';
      case 5: return 'Payment Management';
      case 6: return 'Notifications';
      case 7: return 'Reports & Analytics';
      case 8: return 'Settings';
      default: return 'Admin Portal';
    }
  }
  void _navigate(WidgetRef ref, BuildContext context, int tabIndex, bool
isMobile) {
    ref.read(adminTabProvider.notifier).state = tabIndex;
    if (isMobile) Navigator.pop(context);
  }
  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Sign Out'),
        content: const Text('Are you sure you want to sign out from the
Administrative Console?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const
Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const
Text('Sign Out', style: TextStyle(color: AppColors.primaryCrimson, fontWeight:
FontWeight.bold))),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).logout();
      context.go(AppRoutes.login);
    }
  }
}
// ============================================================
// PREMIUM GROUPED NAVIGATION DRAWER (Stateless, Reusable)
// ============================================================
class _AdminDrawer extends StatelessWidget {
  final int currentTab;
  final void Function(int tabIndex) onNavigate;
  final VoidCallback onLogout;
  const _AdminDrawer({required this.currentTab, required this.onNavigate,
required this.onLogout});
```

```
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: LayoutBuilder(builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
children: [
                // ── Branding Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
                  child: Row(children: [
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors:
[AppColors.primaryCrimson, AppColors.darkCrimson], begin: Alignment.topLeft,
end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [BoxShadow(color:
AppColors.primaryCrimson.withOpacity(0.25), blurRadius: 12, offset: const
Offset(0, 5))],
                      ),
                      child: Center(child: Padding(padding: const
EdgeInsets.all(8), child: Image.asset('assets/images/bus_logo.png', fit:
BoxFit.contain))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment:
CrossAxisAlignment.start, children: [
                      const Text('ADMIN PORTAL', style: TextStyle(color:
AppColors.primaryCrimson, fontWeight: FontWeight.w900, fontSize: 13,
letterSpacing: 1.2)),
                      const SizedBox(height: 2),
                      Text('Smart Campus Mobility', style: TextStyle(color:
theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w500)),
                    ])),
                  ]),
                ),
                Container(height: 1, color: theme.dividerColor),
                const SizedBox(height: 10),
```

```
                // ── OVERVIEW ──
                _SectionLabel(label: 'OVERVIEW', theme: theme),
                _NavItem(index: 0, title: 'Dashboard', icon:
Icons.dashboard_rounded, currentTab: currentTab, theme: theme, onTap: () =>
onNavigate(0)),
                const SizedBox(height: 6),
```

```
                // ── MANAGEMENT ──
                _SectionLabel(label: 'MANAGEMENT', theme: theme),
                _NavItem(index: 4, title: 'Students', icon:
Icons.people_alt_rounded, currentTab: currentTab, theme: theme, onTap: () =>
onNavigate(4)),
                _NavItem(index: 2, title: 'Routes', icon: Icons.route_rounded,
currentTab: currentTab, theme: theme, onTap: () => onNavigate(2)),
                _NavItem(index: 3, title: 'Buses', icon:
Icons.directions_bus_rounded, currentTab: currentTab, theme: theme, onTap: () =>
onNavigate(3)),
                _NavItem(index: -1, title: 'Drivers', icon: Icons.badge_rounded,
```

```
currentTab: currentTab, theme: theme, onTap: () {
                  Navigator.of(context).maybePop();
```

```
                  context.push(AppRoutes.driverManagement);
```

```
                const SizedBox(height: 6),
```

```
                // ── OPERATIONS ──
                _SectionLabel(label: 'OPERATIONS', theme: theme),
                _NavItem(index: 5, title: 'Payments', icon:
Icons.receipt_long_rounded, currentTab: currentTab, theme: theme, onTap: () =>
onNavigate(5)),
                _NavItem(index: 1, title: 'Pass Management', icon:
Icons.card_membership_rounded, currentTab: currentTab, theme: theme, onTap: ()
=> onNavigate(1)),
                _NavItem(index: 6, title: 'Notifications', icon:
Icons.notifications_rounded, currentTab: currentTab, theme: theme, onTap: () =>
onNavigate(6)),
                const SizedBox(height: 6),
```

```
                // ── ANALYTICS ──
                _SectionLabel(label: 'ANALYTICS', theme: theme),
                _NavItem(index: 7, title: 'Reports & Analytics', icon:
Icons.analytics_rounded, currentTab: currentTab, theme: theme, onTap: () =>
onNavigate(7)),
                const SizedBox(height: 6),
```

```
                // ── SYSTEM ──
                _SectionLabel(label: 'SYSTEM', theme: theme),
                _NavItem(index: 8, title: 'Settings', icon:
Icons.settings_rounded, currentTab: currentTab, theme: theme, onTap: () =>
onNavigate(8)),
```

```
                const Spacer(),
                // ── Logout ──
                Container(height: 1, color: theme.dividerColor),
                  padding: const EdgeInsets.all(12),
```

```
                  child: Material(
                    color: AppColors.primaryCrimson.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
```

```
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
```

```
                      onTap: onLogout,
                      child: const Padding(padding:
EdgeInsets.symmetric(horizontal: 14, vertical: 13), child: Row(children: [
                        Icon(Icons.logout_rounded, size: 20, color:
AppColors.primaryCrimson),
                        SizedBox(width: 14),
                        Text('Logout', style: TextStyle(color:
AppColors.primaryCrimson, fontWeight: FontWeight.w700, fontSize: 13.5)),
                      ])),
```

```
                ),
              ]),
            ),
          ),
        );
      }),
    );
  }
}
```

```
/// Muted section label in the drawer.
class _SectionLabel extends StatelessWidget {
  final String label;
  final ThemeData theme;
  const _SectionLabel({required this.label, required this.theme});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 2),
      child: Text(label, style: TextStyle(fontSize: 9.5, fontWeight:
FontWeight.w700, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
letterSpacing: 1.2)),
    );
  }
}
```

```
/// Single navigation item in the drawer.
class _NavItem extends StatelessWidget {
  final int index;
  final String title;
  final IconData icon;
  final int currentTab;
  final ThemeData theme;
  final VoidCallback onTap;
  const _NavItem({required this.index, required this.title, required this.icon,
required this.currentTab, required this.theme, required this.onTap});
```

```
  @override
  Widget build(BuildContext context) {
    final isSelected = index != -1 && currentTab == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1.5),
      child: Material(
        color: isSelected ? AppColors.primaryCrimson.withOpacity(0.10) :
Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(children: [
              Icon(icon, size: 19, color: isSelected ?
AppColors.primaryCrimson : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 13),
              Expanded(child: Text(title, style: TextStyle(color: isSelected ?
AppColors.primaryCrimson : theme.colorScheme.onSurface, fontWeight: isSelected ?
FontWeight.w700 : FontWeight.w500, fontSize: 13.5))),
              if (isSelected) Container(width: 5, height: 5, decoration: const
BoxDecoration(color: AppColors.primaryCrimson, shape: BoxShape.circle)),
            ]),
          ),
        ),
      ),
    );
  }
}
```

```
================================================
FILE: lib/features/admin/presentation/views/admin_notifications_tab.dart
================================================
// ignore_for_file: deprecated_member_use
```

```
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import
'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/features/admin/domain/admin_providers.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_widgets.dart';
import
'package:icem_bus/features/notification/domain/notification_providers.dart';
/// Rebuild Admin Notification Management panel
class AdminNotificationsTab extends ConsumerStatefulWidget {
  const AdminNotificationsTab({super.key});
```

```
  @override
  ConsumerState<AdminNotificationsTab> createState() =>
_AdminNotificationsTabState();
}
```

```
class _AdminNotificationsTabState extends ConsumerState<AdminNotificationsTab> {
  String _searchQuery = '';
  String _statusFilter = 'All';
```

```
  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER ──
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notification Management',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Broadcast alerts, schedule reminders, and track
announcement delivery.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // ── SEARCH AND FILTERS BAR ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                padding: const EdgeInsets.all(14),
```

```
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Column(
                  children: [
                    AdminSearchBar(
                      hintText: 'Search by title or description...',
                      value: _searchQuery,
                      onChanged: (q) => setState(() => _searchQuery = q),
                    ),
                    const SizedBox(height: 10),
                    AdminFilterChips(
                      filters: const ['All', 'Sent', 'Scheduled', 'Failed'],
                      selected: _statusFilter,
                      onSelected: (val) => setState(() => _statusFilter = val),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ── LIST OF NOTIFICATIONS ──
            Expanded(
              child: notificationsAsync.when(
                loading: () => const AdminLoadingState(),
                error: (err, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color:
AppColors.error),
                        const SizedBox(height: 12),
                        const Text(
                          'Failed to load notifications',
                          style: TextStyle(fontWeight: FontWeight.bold,
fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          err.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color:
Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () =>
ref.invalidate(notificationsStreamProvider),
                          style: ElevatedButton.styleFrom(backgroundColor:
AppColors.primaryCrimson),
                          child: const Text('Retry', style: TextStyle(color:
Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (list) {
                  var filtered = list;
```

```
                  // Apply filter chips
                  if (_statusFilter != 'All') {
                    filtered = filtered.where((n) => n['status'] ==
_statusFilter).toList();
                  }
                  // Apply search query
                  if (_searchQuery.trim().isNotEmpty) {
                    final q = _searchQuery.trim().toLowerCase();
                    filtered = filtered.where((n) {
                      final title = (n['title'] ?? '').toString().toLowerCase();
                      final msg = (n['message'] ?? '').toString().toLowerCase();
                      return title.contains(q) || msg.contains(q);
                    }).toList();
                  }
                  if (filtered.isEmpty) {
                    return const AdminEmptyState(
                      title: 'No alerts found',
                      subtitle: 'Try adjusting your filters or compose a new
announcement.',
                      icon: Icons.notifications_off_outlined,
                    );
                  }
                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 80),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _NotificationCard(
                        notification: item,
                        onTap: () => _showNotificationDetails(context, item),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openComposeSheet(context, null),
        backgroundColor: AppColors.primaryCrimson,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        icon: const Icon(Icons.add_alert_rounded, size: 20),
        label: const Text('Create Alert', style: TextStyle(fontWeight:
FontWeight.bold)),
      ),
    );
  }
  void _showNotificationDetails(BuildContext context, Map<String, dynamic>
notification) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotificationDetailsSheet(
        notification: notification,
```

```
        onEdit: (item) {
          Navigator.pop(context);
          _openComposeSheet(context, item);
        },
        onDelete: (id) async {
          Navigator.pop(context);
          await _deleteConfirm(id);
        },
      ),
    );
  }
  void _openComposeSheet(BuildContext context, Map<String, dynamic>?
initialNotification) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ComposeNotificationSheet(initialNotification:
initialNotification),
    );
  }
  Future<void> _deleteConfirm(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Announcement?', style: TextStyle(fontWeight:
FontWeight.bold, fontSize: 16)),
        content: const Text('Are you sure you want to permanently delete this
scheduled notification?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color:
Color(0xFF64748B))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error,
fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(notificationRepositoryProvider).deleteNotification(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Scheduled notification deleted.'),
backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e'), backgroundColor:
AppColors.error),
          );
        }
      }
    }
```

```
  }
}
// ============================================================
// NOTIFICATION CARD WIDGET
// ============================================================
class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;
  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });
  Color _getTypeColor(String type) {
    switch (type) {
      case 'Bus Delay':
        return AppColors.warning;
      case 'Route Change':
        return Colors.purple;
      case 'Pass Approved':
        return AppColors.success;
      case 'Pass Rejected':
        return AppColors.error;
      case 'Payment Reminder':
        return Colors.indigo;
      case 'Pass Expiry Reminder':
        return Colors.amber.shade900;
      case 'General':
      default:
        return AppColors.info;
    }
  }
  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Bus Delay':
        return Icons.access_time_filled_rounded;
      case 'Route Change':
        return Icons.alt_route_rounded;
      case 'Pass Approved':
        return Icons.verified_rounded;
      case 'Pass Rejected':
        return Icons.gpp_bad_rounded;
      case 'Payment Reminder':
        return Icons.currency_rupee_rounded;
      case 'Pass Expiry Reminder':
        return Icons.running_with_errors_rounded;
      case 'General':
      default:
        return Icons.notifications_active_rounded;
    }
  }
  String _formatDate(dynamic dateField) {
    if (dateField == null) return 'N/A';
    DateTime? dt;
    if (dateField is Timestamp) {
      dt = dateField.toDate();
    } else if (dateField is String) {
      dt = DateTime.tryParse(dateField);
    } else if (dateField is int) {
```

```
      dt = DateTime.fromMillisecondsSinceEpoch(dateField);
    }
    if (dt == null) return 'N/A';
    return '${dt.day.toString().padLeft(2, '0')}/$
{dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2,
'0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
  @override
  Widget build(BuildContext context) {
    final title = notification['title'] ?? 'Untitled';
    final message = notification['message'] ?? '';
    final type = notification['type'] ?? 'General';
    final status = notification['status'] ?? 'Sent';
    final targetName = notification['targetName'] ?? 'All Students';
    final scheduledAt = notification['scheduledAt'];
    final typeColor = _getTypeColor(type);
    final typeIcon = _getTypeIcon(type);
    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'Scheduled':
        statusColor = AppColors.info;
        statusIcon = Icons.schedule_rounded;
        break;
      case 'Failed':
        statusColor = AppColors.error;
        statusIcon = Icons.error_rounded;
        break;
      case 'Sent':
      default:
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_rounded;
        break;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type Icon
                Container(
```

```
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 20),
                ),
                const SizedBox(width: 14),
                // Title and Message
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Status Badge
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, color: statusColor, size: 12),
                              const SizedBox(width: 3),
                              Text(
                                status,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color:
Color(0xFF64748B), height: 1.3),
                      ),
                      const SizedBox(height: 10),
                      // Meta details row
                      Row(
                        children: [
                          Icon(Icons.people_alt_rounded, size: 11, color:
Colors.blueGrey.shade400),
                          const SizedBox(width: 4),
                          Flexible(
```

```
                            child: Text(
                              'To: $targetName',
```

```
                              maxLines: 1,
```

```
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color:
Colors.blueGrey.shade600, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.calendar_month_rounded, size: 11, color:
Colors.blueGrey.shade400),
                          const SizedBox(width: 4),
                          Text(
                            status == 'Scheduled'
                                ? 'Schedule: ${_formatDate(scheduledAt)}'
                                : 'Sent: ${_formatDate(scheduledAt)}',
                            style: TextStyle(fontSize: 11, color:
Colors.blueGrey.shade600, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
// ============================================================
// NOTIFICATION DETAILS SHEET
// ============================================================
```

```
class _NotificationDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> notification;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<String> onDelete;
```

```
  const _NotificationDetailsSheet({
    required this.notification,
    required this.onEdit,
    required this.onDelete,
  });
  String _formatDate(dynamic dateField) {
    if (dateField == null) return 'N/A';
    DateTime? dt;
    if (dateField is Timestamp) {
      dt = dateField.toDate();
    } else if (dateField is String) {
      dt = DateTime.tryParse(dateField);
    } else if (dateField is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(dateField);
    }
    if (dt == null) return 'N/A';
    return '${dt.day.toString().padLeft(2, '0')}/$
{dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2,
'0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
```

```
  @override
  Widget build(BuildContext context) {
    final id = notification['notificationId'] ?? '';
    final title = notification['title'] ?? 'Untitled';
    final message = notification['message'] ?? '';
    final type = notification['type'] ?? 'General';
    final targetType = notification['targetType'] ?? 'All Students';
    final targetName = notification['targetName'] ?? 'All Students';
    final status = notification['status'] ?? 'Sent';
    final scheduledAt = notification['scheduledAt'];
    final createdAt = notification['createdAt'];
    final isScheduled = status == 'Scheduled';
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag indicator
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Alert Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
color: Color(0xFF0F172A)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical:
4),
                decoration: BoxDecoration(
                  color: isScheduled ? AppColors.info.withOpacity(0.1) :
AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isScheduled ? AppColors.info : AppColors.success,
                  ),
                ),
              ),
            ],
```

```
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 20),
          // Title
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          // Message
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155),
height: 1.4),
            ),
          ),
          const SizedBox(height: 20),
          // Details grid
          _buildDetailRow('Alert Type', type),
          _buildDetailRow('Target Group', targetType),
          _buildDetailRow('Recipient Scope', targetName),
          if (isScheduled) _buildDetailRow('Scheduled Delivery',
_formatDate(scheduledAt)),
          _buildDetailRow('Creation Timestamp', _formatDate(createdAt)),
          const SizedBox(height: 28),
          // Action Controls
          if (isScheduled) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onDelete(id),
                    icon: const Icon(Icons.delete_forever_rounded, size: 18),
                    label: const Text('Delete Alert'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(borderRadius:
BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => onEdit(notification),
                    icon: const Icon(Icons.edit_rounded, size: 18, color:
Colors.white),
                    label: const Text('Edit Scheduled', style: TextStyle(color:
```

```
Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryCrimson,
                      shape: RoundedRectangleBorder(borderRadius:
BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check_rounded, size: 18, color:
Colors.white),
                label: const Text('Dismiss', style: TextStyle(color:
Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(borderRadius:
BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color:
Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight:
FontWeight.bold, color: Color(0xFF1E293B))),
        ],
      ),
    );
  }
}
```

```
// ============================================================
// SEARCHABLE STUDENT PICKER MODAL
// ============================================================
```

```
class _StudentPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> students;
  final ValueChanged<Map<String, dynamic>> onSelect;
```

```
  const _StudentPickerSheet({required this.students, required this.onSelect});
```

- `@override State<_StudentPickerSheet> createState() => _StudentPickerSheetState(); }` 

```
class _StudentPickerSheetState extends State<_StudentPickerSheet> {
  String _query = '';
```

```
  @override
  Widget build(BuildContext context) {
    final search = _query.trim().toLowerCase();
    final filtered = search.isEmpty
        ? widget.students
        : widget.students.where((s) {
            final name = (s['fullName'] ?? '').toString().toLowerCase();
            final prn = (s['prn'] ?? '').toString().toLowerCase();
            final email = (s['email'] ?? '').toString().toLowerCase();
            return name.contains(search) || prn.contains(search) ||
email.contains(search);
          }).toList();
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select Recipient Student',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color:
Color(0xFF0F172A)),
          ),
          const SizedBox(height: 14),
          AdminSearchBar(
            hintText: 'Search by Name or PRN...',
            value: _query,
            onChanged: (q) => setState(() => _query = q),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No students found matching query.',
style: TextStyle(color: Color(0xFF64748B))))
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final student = filtered[index];
                      final name = student['fullName'] ?? 'Unknown';
                      final prn = student['prn'] ?? 'N/A';
                      final course = student['course'] ?? 'N/A';
                      return ListTile(
                        title: Text(name, style: const TextStyle(fontWeight:
FontWeight.bold, fontSize: 14)),
                        subtitle: Text('PRN: $prn | $course', style: const
TextStyle(fontSize: 12)),
                        leading: CircleAvatar(
```

```
                          backgroundColor:
AppColors.primaryCrimson.withOpacity(0.08),
                          foregroundColor: AppColors.primaryCrimson,
                          child: const Icon(Icons.person_rounded, size: 20),
                        ),
                        onTap: () {
                          widget.onSelect(student);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
```

```
// ============================================================
// COMPOSE & EDIT NOTIFICATION SHEET
// ============================================================
```

```
class _ComposeNotificationSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialNotification;
```

```
  const _ComposeNotificationSheet({this.initialNotification});
  @override
  ConsumerState<_ComposeNotificationSheet> createState() =>
_ComposeNotificationSheetState();
}
```

```
class _ComposeNotificationSheetState extends
ConsumerState<_ComposeNotificationSheet> {
  final _titleController = TextEditingController();
  final _msgController = TextEditingController();
```

```
  String _type = 'General';
  String _targetType = 'All Students';
  String? _targetId;
  String? _targetName;
  bool _isScheduled = false;
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;
```

```
  bool _isSaving = false;
```

```
  @override
  void initState() {
    super.initState();
    final init = widget.initialNotification;
    if (init != null) {
      _titleController.text = init['title'] ?? '';
      _msgController.text = init['message'] ?? '';
      _type = init['type'] ?? 'General';
      _targetType = init['targetType'] ?? 'All Students';
      _targetId = init['targetId'];
      _targetName = init['targetName'];
      if (init['status'] == 'Scheduled') {
        _isScheduled = true;
```

```
        final timestamp = init['scheduledAt'];
        if (timestamp is Timestamp) {
          final dt = timestamp.toDate();
          _scheduledDate = dt;
          _scheduledTime = TimeOfDay.fromDateTime(dt);
        }
      }
    } else {
      _scheduledDate = DateTime.now().add(const Duration(days: 1));
      _scheduledTime = const TimeOfDay(hour: 9, minute: 0);
    }
  }
  @override
  void dispose() {
    _titleController.dispose();
    _msgController.dispose();
    super.dispose();
  }
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? DateTime.now().add(const Duration(days:
1)),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryCrimson,
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _scheduledDate = picked;
      });
    }
  }
  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime ?? const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryCrimson,
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
```

```
    if (picked != null) {
      setState(() {
        _scheduledTime = picked;
      });
    }
  }
  void _openStudentPickerModal(List<Map<String, dynamic>> students) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StudentPickerSheet(
        students: students,
        onSelect: (student) {
          setState(() {
            _targetId = student['id'];
            _targetName = student['fullName'];
          });
        },
      ),
    );
  }
  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter title'), backgroundColor:
AppColors.warning),
      );
      return;
    }
    if (_msgController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter message'), backgroundColor:
AppColors.warning),
      );
      return;
    }
    // Dynamic targets logic
    String tId = '';
    String tName = 'All Students';
    if (_targetType == 'Specific Route') {
      if (_targetId == null || _targetId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a route'),
backgroundColor: AppColors.warning),
        );
        return;
      }
      tId = _targetId!;
      tName = _targetName ?? 'Route';
    } else if (_targetType == 'Specific Bus') {
      if (_targetId == null || _targetId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a bus'), backgroundColor:
AppColors.warning),
        );
        return;
      }
      tId = _targetId!;
      tName = _targetName ?? 'Bus';
```

```
    } else if (_targetType == 'Individual Student') {
      if (_targetId == null || _targetId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a student'),
backgroundColor: AppColors.warning),
        );
        return;
      }
      tId = _targetId!;
      tName = _targetName ?? 'Student';
    }
    final adminUser = ref.read(authControllerProvider).user;
    final createdBy = adminUser?.uid ?? 'Admin';
```

```
    DateTime scheduledDateTime;
    if (_isScheduled) {
      final date = _scheduledDate ?? DateTime.now().add(const Duration(days:
1));
      final time = _scheduledTime ?? const TimeOfDay(hour: 9, minute: 0);
      scheduledDateTime = DateTime(date.year, date.month, date.day, time.hour,
time.minute);
      if (scheduledDateTime.isBefore(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scheduled time must be in the future'),
backgroundColor: AppColors.warning),
        );
        return;
      }
    } else {
      scheduledDateTime = DateTime.now();
    }
    final data = <String, dynamic>{
      'title': _titleController.text.trim(),
      'message': _msgController.text.trim(),
      'type': _type,
      'targetType': _targetType,
      'targetId': tId.isEmpty ? null : tId,
      'targetName': tName,
      'createdBy': createdBy,
      'scheduledAt': Timestamp.fromDate(scheduledDateTime),
      'status': _isScheduled ? 'Scheduled' : 'Sent',
      'isRead': false,
    };
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(notificationRepositoryProvider);
      if (widget.initialNotification != null) {
        await repo.updateNotification(widget.initialNotification!
['notificationId'], data);
      } else {
        await repo.createNotification(data);
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.initialNotification != null ? 'Alert
updated!' : 'Alert generated!'),
            backgroundColor: AppColors.success,
```

```
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor:
AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    // Watch streams to populate targets
    final routesAsync = ref.watch(routesListStreamProvider);
    final busesAsync = ref.watch(busesListStreamProvider);
    final studentsAsync = ref.watch(studentsListStreamProvider);
    final isEditMode = widget.initialNotification != null;
```

```
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24,
MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isEditMode ? 'Edit Scheduled Alert' : 'Compose Alert',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16,
color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 20),
            // Form inputs
            const Text('Alert Type', style: TextStyle(fontSize: 12, fontWeight:
FontWeight.bold, color: Color(0xFF475569))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: _inputDecoration(),
              items: const [
                DropdownMenuItem(value: 'General', child: Text('General
Announcement')),
```

```
                DropdownMenuItem(value: 'Bus Delay', child: Text('Bus Delay
Alert')),
                DropdownMenuItem(value: 'Route Change', child: Text('Route
Change Alert')),
                DropdownMenuItem(value: 'Pass Approved', child: Text('Pass
Approved Alert')),
                DropdownMenuItem(value: 'Pass Rejected', child: Text('Pass
Rejected Alert')),
                DropdownMenuItem(value: 'Payment Reminder', child: Text('Payment
Reminder')),
                DropdownMenuItem(value: 'Pass Expiry Reminder', child:
Text('Pass Expiry Reminder')),
              ],
```

```
              onChanged: (val) {
                if (val != null) setState(() => _type = val);
            const SizedBox(height: 16),
```

```
            const Text('Target Audience Group', style: TextStyle(fontSize: 12,
fontWeight: FontWeight.bold, color: Color(0xFF475569))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _targetType,
              decoration: _inputDecoration(),
              items: const [
                DropdownMenuItem(value: 'All Students', child: Text('All
Students')),
                DropdownMenuItem(value: 'Specific Route', child: Text('Specific
Route')),
                DropdownMenuItem(value: 'Specific Bus', child: Text('Specific
Bus')),
                DropdownMenuItem(value: 'Individual Student', child:
Text('Individual Student')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _targetType = val;
                    _targetId = null;
                    _targetName = null;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            // Target Group conditional input
            if (_targetType == 'Specific Route') ...[
              const Text('Select Route', style: TextStyle(fontSize: 12,
fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              routesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => const Text('Error loading routes', style:
TextStyle(color: AppColors.error)),
                data: (routes) {
                  return DropdownButtonFormField<String>(
                    value: routes.any((r) => r['id'] == _targetId) ? _targetId :
null,
                    decoration: _inputDecoration(),
                    items: routes.map((r) {
                      return DropdownMenuItem<String>(
                        value: r['id'],
```

```
                        child: Text(r['routeName'] ?? 'Route'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final r = routes.firstWhere((element) => element['id']
== val);
                        setState(() {
                          _targetId = val;
                          _targetName = r['routeName'] ?? 'Route';
                        });
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
            ] else if (_targetType == 'Specific Bus') ...[
              const Text('Select Bus', style: TextStyle(fontSize: 12,
fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              busesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => const Text('Error loading buses', style:
TextStyle(color: AppColors.error)),
                data: (buses) {
                  return DropdownButtonFormField<String>(
                    value: buses.any((b) => b['id'] == _targetId) ? _targetId :
null,
                    decoration: _inputDecoration(),
                    items: buses.map((b) {
                      return DropdownMenuItem<String>(
                        value: b['id'],
                        child: Text(b['busNo'] ?? 'Bus'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final b = buses.firstWhere((element) => element['id'] ==
val);
                        setState(() {
                          _targetId = val;
                          _targetName = 'Bus ${b['busNo'] ?? ''}';
                        });
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
            ] else if (_targetType == 'Individual Student') ...[
              const Text('Select Student', style: TextStyle(fontSize: 12,
fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              studentsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => const Text('Error loading students', style:
TextStyle(color: AppColors.error)),
                data: (students) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14,
vertical: 12),
                    decoration: BoxDecoration(
```

```
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () => _openStudentPickerModal(students),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_targetName ?? 'Tap to pick student', style:
TextStyle(color: _targetName != null ? const Color(0xFF0F172A) : const
Color(0xFF94A3B8))),
                          const Icon(Icons.arrow_drop_down, color:
Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
            // Title
            const Text('Alert Title', style: TextStyle(fontSize: 12, fontWeight:
FontWeight.bold, color: Color(0xFF475569))),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              decoration: _inputDecoration(hint: 'Enter alert title'),
            ),
            const SizedBox(height: 16),
            // Message
            const Text('Message Body', style: TextStyle(fontSize: 12,
fontWeight: FontWeight.bold, color: Color(0xFF475569))),
            const SizedBox(height: 6),
            TextField(
              controller: _msgController,
              maxLines: 4,
              decoration: _inputDecoration(hint: 'Compose alert message...'),
            ),
            const SizedBox(height: 20),
            // Delivery schedule toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Schedule Delivery', style: TextStyle(fontSize: 13,
fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text('Determine date/time of alert broadcast', style:
TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
                Switch.adaptive(
                  value: _isScheduled,
                  activeColor: AppColors.primaryCrimson,
                  onChanged: (val) {
                    setState(() {
                      _isScheduled = val;
                    });
                  },
```

```
                ),
              ],
            ),
            if (_isScheduled) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_month_rounded, size: 16),
                      label: Text(_scheduledDate == null ? 'Pick Date' : '$
{_scheduledDate!.day}/${_scheduledDate!.month}/${_scheduledDate!.year}'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius:
BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.access_time_rounded, size: 16),
                      label: Text(_scheduledTime == null ? 'Pick Time' :
_scheduledTime!.format(context)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius:
BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 28),
            // Save Broadcast Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(width: 18, height: 18, child:
CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded, size: 18, color:
Colors.white),
                label: Text(
                  _isSaving
                      ? 'Saving...'
                      : (isEditMode ? 'Update Scheduled Broadcast' :
(_isScheduled ? 'Schedule Broadcast' : 'Send Announcement Now')),
                  style: const TextStyle(color: Colors.white, fontWeight:
FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryCrimson,
```

```
                  shape: RoundedRectangleBorder(borderRadius:
BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
```

```
  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppColors.primaryCrimson)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
```

```
================================================
FILE: lib/features/admin/presentation/views/admin_overview_tab.dart
================================================
// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import
'package:icem_bus/features/admin/data/repositories/admin_repository.dart';
import 'package:icem_bus/features/admin/domain/admin_providers.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_widgets.dart';
import
'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/features/driver/domain/driver_providers.dart';
import 'package:icem_bus/config/routes/app_routes.dart';
```

```
/// Dashboard Overview Tab — Summary cards, quick actions, recent applications
class AdminOverviewTab extends ConsumerWidget {
  const AdminOverviewTab({super.key});
```

```
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(dashboardSearchQueryProvider);
    final statusFilter = ref.watch(dashboardStatusFilterProvider);
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;
    final hour = DateTime.now().hour;
    final String greetingTime = hour < 12
```

- `? 'Good Morning'` 

- `: hour < 17` 

- `? 'Good Afternoon'` 

- `: 'Good Evening';` 

```
    final adminDisplayName = user?.fullName.isNotEmpty == true ?
user!.fullName.split(' ').first : 'Admin';
    return SingleChildScrollView(
      primary: false,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Greeting Section ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greetingTime, $adminDisplayName',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Campus Mobility Overview',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical:
5),
                decoration: BoxDecoration(
                  color: AppColors.primaryCrimson.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color:
AppColors.primaryCrimson.withOpacity(0.28)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, size: 14, color:
AppColors.primaryCrimson),
                    SizedBox(width: 4),
                    Text(
                      'LIVE FLEET',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryCrimson,
                        letterSpacing: 0.8,
```

```
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
```

```
          // ── Mobility Statistics Section ──
          const AdminSectionHeader(title: 'Mobility Overview'),
          const SizedBox(height: 14),
          _buildStatCardsGrid(context, ref),
          const SizedBox(height: 28),
```

```
          // ── Quick Shortcuts (4 compact action tiles) ──
          const AdminSectionHeader(
            title: 'Quick Shortcuts',
            actionLabel: null,
          ),
          const SizedBox(height: 14),
          _buildQuickShortcuts(context, ref),
          const Size
```

