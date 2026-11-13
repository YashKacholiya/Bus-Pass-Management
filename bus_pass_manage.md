================================================
FILE: README.md
================================================
<div align="center">

# 🚌 ICEM Smart Bus Pass

### Pay first. Get verified. Board with a QR.
**A paperless, payment-gated bus pass system for ICEM college, built with Flutter + Firebase.**

[![Flutter](https://img.shields.io/badge/Flutter-3.44+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore%20%7C%20Functions-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![Riverpod](https://img.shields.io/badge/State-Riverpod-00B8D4)](https://riverpod.dev)
[![Razorpay](https://img.shields.io/badge/Payments-Razorpay-0C2451?logo=razorpay&logoColor=white)](https://razorpay.com)

[![Architecture diagram](https://gitdiagram.com/diagram-badge.svg)](https://gitdiagram.com/yashkacholiya61-netizen/bus-pass-management?utm_source=readme&utm_medium=badge)

</div>

---

## 🎯 The Problem

Paper bus passes are slow to issue, easy to forge, painful to renew and impossible to audit. Students queue at the transport office, admins reconcile payments by hand, and conductors squint at laminated cards.

## 💡 The Idea

ICEM Smart Bus Pass moves the whole pass lifecycle onto phones and an admin console, built around one rule:

> **No pass becomes active until payment is verified *and* an administrator approves it. Payment alone never activates a pass.**

Approval is a **two-key process**: a verified payment unlocks the application for review, and an admin's explicit approval issues the pass and its QR.

---

## ✨ Features

### 🎓 Students
- **Register / sign in** with email + password or Google, with email verification
- **Apply and renew** for a pass: pick route, boarding stop and destination
- **Pay with Razorpay Checkout** (fare defaults to ₹4,500)
- **Digital pass with a scannable QR**, active only after payment + admin approval
- **Application history**, per-pass detail screens, payment history and receipts
- **Personalization**: light / dark / system theme and accent colors (crimson, blue, green, purple), synced to Firestore

### 🛠️ Admins (Transport Office Console)
A responsive console (sidebar on desktop, drawer on mobile) with live Firestore streams:

| Area | What it does |
|---|---|
| **Dashboard** | Live KPI cards: students, active passes, pending applications, today's revenue, buses, active drivers, pending payments, expired passes |
| **Pass Management** | Search by name / PRN / college ID, filter by status; approve, reject, or request a correction; full application detail screen |
| **Routes** | Route management with an in-use check before deletion |
| **Buses** | Bus management with automatic bus↔route linking (one bus per route, applied in a batch write) |
| **Students** | Suspend / activate / delete accounts; approve, reject or revoke a student's pass |
| **Payments** | Unified view of `payments` + `receipts`; verify manual payments, mark failed, refund (status), export PDF receipts |
| **Notifications** | Compose alerts targeted at all students, a route, a bus or one student; schedule, edit and delete them |
| **Reports** | Custom-painted line/area, donut and bar charts; CSV and PDF export helpers |
| **Settings** | Profile, appearance, notification preferences, security (password change / reset) |
| **Drivers** | Driver records (add, update, delete) |

### 🧑‍✈️ Staff / Conductors
- Staff dashboard and a **camera QR scanner** (`mobile_scanner`)
- Verification looks the pass up in Firestore by pass number, pass ID or student ID, and returns one of: **Valid**, **Expired**, **Revoked**, **Not Active**, or **Invalid**
- Manual entry fallback when a QR can't be scanned

---

## 🔐 Security Model

| Layer | What it enforces |
|---|---|
| **Admin repository** | `approveApplication` runs in a **Firestore transaction** that re-reads the application and aborts unless `paymentStatus` is paid. It then atomically issues a Pass ID + Pass Number (`ICEM-BP-<year>-<suffix>`), stamps `approvedBy` / `approvedAt`, sets validity (default **180 days**, admin-adjustable) and writes the student's `bus_passes` doc with a QR payload |
| **Admin UI** | Unpaid applications show a locked *Payment Required* button instead of *Approve* |
| **Firestore rules** | Students can't write `passNumber`, `qrCode`, `approvedBy`, `approvedAt`, `validFrom`, `validUntil`, `passStatus`, `applicationStatus`, set `status` to Approved/Active, or mark `paymentStatus` as paid on applications; new applications must start pending/unpaid; routes, buses, notifications, config, reports and audit logs are write-restricted |
| **Pass state** | A pass counts as active only if `paid && approved && !expired && !revoked` |
| **Cloud Functions** | `functions/` implements server-side Razorpay order creation (amount read from the stored fare, double-payment guard), HMAC-SHA256 signature verification, and a payment webhook. Verification marks the application *Pending admin approval*, **never** approved |
| **Routing** | `go_router` redirects keep unauthenticated users on public pages and gate `/admin/*`, the staff dashboard and QR verification by role |

---

## 🔄 Pass Lifecycle

```mermaid
stateDiagram-v2
    [*] --> PaymentPending: Student applies
    PaymentPending --> PaidAwaitingApproval: Payment recorded / verified
    PaymentPending --> Failed: Payment failed
    PaidAwaitingApproval --> Active: Admin approves<br/>(transaction re-checks payment)
    PaidAwaitingApproval --> Rejected: Admin rejects (reason stored)
    PaidAwaitingApproval --> CorrectionRequired: Admin requests correction
    Active --> Expired: Validity ends
    Active --> Revoked: Admin revokes (reason stored)
    Active --> Refunded: Payment refunded
    Expired --> PaymentPending: Renew
```

## 💸 Payment Flow

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

> The `functions/` directory contains the hardened server-side flow (order creation → signature verification → webhook). Wiring the Flutter client to call it is on the [roadmap](#-roadmap), and it is the intended production path.

---

## 🏗️ Architecture

**Feature-first Clean Architecture**, Riverpod for state, Firestore streams as the source of truth.

```
lib/
├── app/                  # MaterialApp.router + theme wiring
├── config/               # constants, go_router + role guards, themes & design tokens
├── core/                 # failures, UseCase base, responsive helpers
├── features/
│   ├── auth/             # login, register, onboarding, splash (data / domain / presentation)
│   ├── student/          # dashboard, apply/renew, digital pass, history
│   ├── bus_pass/         # pass model, repository, QR verification
│   ├── payment/          # Razorpay service, payment config, receipts
│   ├── admin/            # console tabs, charts, report exporter, detail screens
│   ├── driver/           # driver repository & providers
│   └── notification/     # targeted + scheduled notification records
├── services/             # Firebase init (+ FCM), SharedPreferences settings sync
└── shared/               # cards, buttons, skeleton loaders, status badges, empty/error states

functions/                # Node 20 Cloud Functions (Razorpay order, verify, webhook)
firestore.rules           # role- and field-level security
firestore.indexes.json    # composite indexes
test/                     # widget + unit tests
```

### Firestore Collections

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

## 🧰 Tech Stack

| Layer | Choice |
|---|---|
| UI | Flutter (Material 3), Google Fonts (Outfit), `CustomPaint` charts and onboarding art |
| State / routing | `flutter_riverpod`, `go_router` |
| Backend | Firebase Auth, Cloud Firestore, Storage, Cloud Messaging |
| Server logic | Cloud Functions (Node 20), `razorpay` SDK |
| Payments | `razorpay_flutter` |
| QR | `qr_flutter` (generate), `mobile_scanner` (scan) |
| Documents | `pdf`, `share_plus`, `path_provider` |
| Media / permissions | `image_picker`, `image_cropper`, `permission_handler` |

---

## 🚀 Run It Locally

**Prerequisites:** Flutter SDK (Dart `^3.12.2`), a Firebase project (Auth, Firestore, Storage), Node.js 20 + Firebase CLI for the functions, and a Razorpay account (test keys are fine).

```bash
git clone https://github.com/yashkacholiya61-netizen/bus-pass-management.git
cd bus-pass-management
flutter pub get
```

1. **Connect Firebase:** add your own `android/app/google-services.json` (and `GoogleService-Info.plist` for iOS), or run `flutterfire configure`.
2. **Add assets** referenced in `pubspec.yaml`: `assets/images/bus_logo.png` and `assets/images/college_upi_qr.png`.
3. **Deploy rules, indexes, functions:**
   ```bash
   firebase deploy --only firestore:rules,firestore:indexes
   cd functions && npm install && cd ..
   firebase functions:config:set razorpay.key_id="rzp_test_xxx" razorpay.key_secret="xxx" razorpay.webhook_secret="xxx"
   firebase deploy --only functions
   ```
   (Functions also read `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET` from the environment.)
4. **Configure payments:** set your Razorpay Key ID and fee in the `system_config/payment_config` document (or the admin Settings screen). Without a Key ID the app refuses to open checkout rather than faking a payment.
5. **Create the first admin:** register normally, then set that user's `role` to `Admin` in the `users` collection.
6. **Run:** `flutter run` (or `flutter run -d chrome` for the console).

## 🧪 Tests

```bash
flutter test
```
Covers payment models/config, the settings screen and theme persistence, and admin application card behavior. Some widget tests predate recent UI copy changes and need updating.

---

## 🗺️ Roadmap

- **Wire the app to Cloud Functions** (`cloud_functions` package) so order creation and signature verification happen server-side, with the client only displaying the result
- **Move role assignment server-side** (custom claims / admin-only writes) and split *Staff* from *Admin* privileges in Firestore rules
- Fix the Razorpay webhook to verify against the raw request body
- A scheduled function to deliver scheduled notifications via FCM and to mark passes **Expired**
- Replace placeholder dashboard stats (staff scan counts) with live data
- Live bus tracking, offline-tolerant QR validation, and audit-log entries for every admin action

## 🤝 Contributing

1. Fork and create a feature branch
2. Keep the `data` / `domain` / `presentation` split per feature
3. Never move payment or approval decisions into unprivileged client code
4. Run `flutter analyze` and `flutter test` before opening a PR

---

<div align="center">

**Built for ICEM students and transport staff.**
*Verified payment + admin approval = an active pass.* 🎟️

</div>



================================================
FILE: analysis_options.yaml
================================================
# This file configures the analyzer, which statically analyzes Dart code to
# check for errors, warnings, and lints.
#
# The issues identified by the analyzer are surfaced in the UI of Dart-enabled
# IDEs (https://dart.dev/tools#ides-and-editors). The analyzer can also be
# invoked from the command line by running `flutter analyze`.

# The following line activates a set of recommended lints for Flutter apps,
# packages, and plugins designed to encourage good coding practices.
include: package:flutter_lints/flutter.yaml

linter:
  # The lint rules applied to this project can be customized in the
  # section below to disable rules from the `package:flutter_lints/flutter.yaml`
  # included above or to enable additional rules. A list of all available lints
  # and their documentation is published at https://dart.dev/lints.
  #
  # Instead of disabling a lint rule for the entire project in the
  # section below, it can also be suppressed for a single line of code
  # or a specific dart file by using the `// ignore: name_of_lint` and
  # `// ignore_for_file: name_of_lint` syntax on the line or in the file
  # producing the lint.
  rules:
    # avoid_print: false  # Uncomment to disable the `avoid_print` rule
    # prefer_single_quotes: true  # Uncomment to enable the `prefer_single_quotes` rule

# Additional information about this file can be found at
# https://dart.dev/guides/language/analysis-options



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
  ],
  "fieldOverrides": []
}



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
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['admin', 'Admin', 'staff', 'Staff']
      );
    }

    // ── USERS COLLECTION ──
    match /users/{userId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated() && (request.auth.uid == userId || isAdmin());
      // Students can update their profile information, but cannot change their own role to Admin/Staff
      allow update: if isAuthenticated() && (
        isAdmin() ||
        (
          request.auth.uid == userId &&
          (!request.resource.data.diff(resource.data).affectedKeys().hasAny(['role']) ||
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
        resource.data.uid == request.auth.uid ||
        resource.data.studentId == request.auth.uid
      );

      // Student can submit an initial application (must be Payment Pending / Pending)
      // Must NOT contain passNumber, approvedAt, approvedBy, qrCode
      allow create: if isAuthenticated() && (
        isAdmin() ||
        (
          (request.resource.data.uid == request.auth.uid || request.resource.data.studentId == request.auth.uid) &&
          request.resource.data.paymentStatus in ['Pending', 'Unpaid', 'pending'] &&
          request.resource.data.status in ['Payment Pending', 'payment_pending', 'Pending'] &&
          request.resource.data.passStatus in ['Payment Pending', 'payment_pending', 'Pending'] &&
          !request.resource.data.keys().hasAny(['approvedAt', 'approvedBy', 'passNumber', 'qrCode', 'validFrom', 'validUntil'])
        )
      );

      // Student CANNOT mark application as 'Approved', 'Active', or 'Paid'
      // Student CANNOT directly generate passNumber or approvedAt/approvedBy
      allow update: if isAuthenticated() && (
        isAdmin() ||
        (
          (resource.data.uid == request.auth.uid || resource.data.studentId == request.auth.uid) &&
          !request.resource.data.diff(resource.data).affectedKeys().hasAny([
            'approvedBy', 'approvedAt', 'passNumber', 'passStatus', 'applicationStatus', 'validFrom', 'validUntil', 'qrCode'
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
      // Conductors and admins can read any pass for QR verification; students can read their own
      allow read: if isAuthenticated() && (isOwner(userId) || isAdmin());

      // Only Admin or trusted backend can activate, approve, or generate passNumber
      allow create: if isAuthenticated() && (
        isAdmin() ||
        (
          isOwner(userId) &&
          request.resource.data.passStatus in ['Pending', 'Payment Pending', 'pending'] &&
          request.resource.data.status in ['Pending', 'Payment Pending', 'pending'] &&
          request.resource.data.paymentStatus in ['Pending', 'Unpaid', 'pending'] &&
          !request.resource.data.keys().hasAny(['passNumber', 'approvedAt', 'approvedBy', 'qrCode', 'validFrom', 'validUntil'])
        )
      );

      // Student cannot modify approval status, pass status, payment status, passNumber, approvedAt, or qrCode
      allow update: if isAuthenticated() && (
        isAdmin() ||
        (
          isOwner(userId) &&
          !request.resource.data.diff(resource.data).affectedKeys().hasAny([
            'passStatus', 'applicationStatus', 'status', 'paymentStatus', 'passNumber', 'approvedAt', 'approvedBy', 'qrCode', 'validFrom', 'validUntil'
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
          (request.resource.data.studentId == request.auth.uid || request.resource.data.uid == request.auth.uid) &&
          request.resource.data.paymentStatus in ['created', 'pending', 'processing', 'submitted_for_verification', 'Pending Verification']
        )
      );

      // Students CANNOT mark payments as 'paid' or 'verified'
      // Only Admin or trusted payment webhook/service can verify payments
      allow update: if isAuthenticated() && (
        isAdmin() ||
        (
          (resource.data.studentId == request.auth.uid || resource.data.uid == request.auth.uid) &&
          !request.resource.data.diff(resource.data).affectedKeys().hasAny(['verifiedAt', 'verifiedBy']) &&
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
    source: hosted
    version: "3.1.3"
sdks:
  dart: ">=3.12.2 <4.0.0"
  flutter: ">=3.44.0"



================================================
FILE: pubspec.yaml
================================================
name: icem_bus
description: "A new Flutter project."
# The following line prevents the package from being accidentally published to
# pub.dev using `flutter pub publish`. This is preferred for private packages.
publish_to: 'none' # Remove this line if you wish to publish to pub.dev

# The following defines the version and build number for your application.
# A version number is three numbers separated by dots, like 1.2.43
# followed by an optional build number separated by a +.
# Both the version and the builder number may be overridden in flutter
# build by specifying --build-name and --build-number, respectively.
# In Android, build-name is used as versionName while build-number used as versionCode.
# Read more about Android versioning at https://developer.android.com/studio/publish/versioning
# In iOS, build-name is used as CFBundleShortVersionString while build-number is used as CFBundleVersion.
# Read more about iOS versioning at
# https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html
# In Windows, build-name is used as the major, minor, and patch parts
# of the product and file versions while build-number is used as the build suffix.
version: 1.0.0+1

environment:
  sdk: ^3.12.2

# Dependencies specify other packages that your package needs in order to work.
# To automatically upgrade your package dependencies to the latest versions
# consider running `flutter pub upgrade --major-versions`. Alternatively,
# dependencies can be manually updated by changing the version numbers below to
# the latest version available on pub.dev. To see which dependencies have newer
# versions available, run `flutter pub outdated`.
dependencies:
  flutter:
    sdk: flutter

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

dev_dependencies:
  flutter_test:
    sdk: flutter

  # The "flutter_lints" package below contains a set of recommended lints to
  # encourage good coding practices. The lint set provided by the package is
  # activated in the `analysis_options.yaml` file located at the root of your
  # package. See that file for information about deactivating specific lint
  # rules and activating additional ones.
  flutter_lints: ^6.0.0
  build_runner: ^2.4.0
  riverpod_generator: ^2.4.0

# For information on the generic Dart part of this file, see the
# following page: https://dart.dev/tools/pub/pubspec

# The following section is specific to Flutter packages.
flutter:

  # The following line ensures that the Material Icons font is
  # included with your application, so that you can use the icons in
  # the material Icons class.
  uses-material-design: true

  assets:
    - assets/images/bus_logo.png
    - assets/images/college_upi_qr.png

  # To add assets to your application, add an assets section, like this:
  # assets:
  #   - images/a_dot_burr.jpeg
  #   - images/a_dot_ham.jpeg

  # An image asset can refer to one or more resolution-specific "variants", see
  # https://flutter.dev/to/resolution-aware-images

  # For details regarding adding assets from package dependencies, see
  # https://flutter.dev/to/asset-from-package

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
  #       - asset: fonts/TrajanPro_Bold.ttf
  #         weight: 700
  #
  # For details regarding fonts from package dependencies,
  # see https://flutter.dev/to/font-from-package



================================================
FILE: .metadata
================================================
# This file tracks properties of this Flutter project.
# Used by Flutter tool to assess capabilities and perform upgrades etc.
#
# This file should be version controlled and should not be manually edited.

version:
  revision: "ee80f08bbf97172ec030b8751ceab557177a34a6"
  channel: "stable"

project_type: app

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

  # User provided section

  # List of Local paths (relative to this file) that should be
  # ignored by the migrate tool.
  #
  # Files that are not part of the templates will be ignored by default.
  unmanaged_files:
    - 'lib/main.dart'
    - 'ios/Runner.xcodeproj/project.pbxproj'



================================================
FILE: android/build.gradle.kts
================================================
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

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



================================================
FILE: android/gradle.properties
================================================
org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G -XX:ReservedCodeCacheSize=512m -XX:+HeapDumpOnOutOfMemoryError
android.useAndroidX=true
# This newDsl flag was added by the Flutter template
android.newDsl=false
# This builtInKotlin flag was added by the Flutter template
android.builtInKotlin=false
kotlin.incremental=false



================================================
FILE: android/settings.gradle.kts
================================================
pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
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
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")



================================================
FILE: android/app/build.gradle.kts
================================================
plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.icem.bus.icem_bus"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
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
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <!-- Specifies an Android theme to apply to this Activity as soon as
                 the Android process has started. This theme is visible to the user
                 while the Flutter UI initializes. After that, this theme continues
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
             This is used by the Flutter tool to generate GeneratedPluginRegistrant.java -->
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
    <!-- Required to query activities that can process text, see:
         https://developer.android.com/training/package-visibility and
         https://developer.android.com/reference/android/content/Intent#ACTION_PROCESS_TEXT.

         In particular, this is used by the Flutter engine in io.flutter.plugin.text.ProcessTextPlugin. -->
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
</manifest>



================================================
FILE: android/app/src/main/kotlin/com/icem/bus/icem_bus/MainActivity.kt
================================================
package com.icem.bus.icem_bus

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()



================================================
FILE: android/app/src/main/res/drawable/launch_background.xml
================================================
<?xml version="1.0" encoding="utf-8"?>
<!-- Modify this file to customize your launch splash screen -->
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@android:color/white" />

    <!-- You can insert your own image assets here -->
    <!-- <item>
        <bitmap
            android:gravity="center"
            android:src="@mipmap/launch_image" />
    </item> -->
</layer-list>



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



================================================
FILE: android/app/src/main/res/values/styles.xml
================================================
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Theme applied to the Android Window while the process is starting when the OS's Dark Mode setting is off -->
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <!-- Show a splash screen on the activity. Automatically removed when
             the Flutter engine draws its first frame -->
        <item name="android:windowBackground">@drawable/launch_background</item>
    </style>
    <!-- Theme applied to the Android Window as soon as the process has started.
         This theme determines the color of the Android Window while your
         Flutter UI initializes, as well as behind your Flutter UI while its
         running.

         This Theme is only used starting with V2 of Flutter's Android embedding. -->
    <style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">?android:colorBackground</item>
    </style>
</resources>



================================================
FILE: android/app/src/main/res/values-night/styles.xml
================================================
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Theme applied to the Android Window while the process is starting when the OS's Dark Mode setting is on -->
    <style name="LaunchTheme" parent="@android:style/Theme.Black.NoTitleBar">
        <!-- Show a splash screen on the activity. Automatically removed when
             the Flutter engine draws its first frame -->
        <item name="android:windowBackground">@drawable/launch_background</item>
    </style>
    <!-- Theme applied to the Android Window as soon as the process has started.
         This theme determines the color of the Android Window while your
         Flutter UI initializes, as well as behind your Flutter UI while its
         running.

         This Theme is only used starting with V2 of Flutter's Android embedding. -->
    <style name="NormalTheme" parent="@android:style/Theme.Black.NoTitleBar">
        <item name="android:windowBackground">?android:colorBackground</item>
    </style>
</resources>



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



================================================
FILE: android/gradle/wrapper/gradle-wrapper.properties
================================================
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-9.1.0-all.zip



================================================
FILE: functions/index.js
================================================
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("crypto");
const Razorpay = require("razorpay");

admin.initializeApp();
const db = admin.firestore();

// Server-side Razorpay credentials (never exposed to Flutter client)
// Configured via Firebase Environment Configuration or Secret Manager:
// firebase functions:config:set razorpay.key_id="rzp_test_..." razorpay.key_secret="..."
const getRazorpayInstance = () => {
  const keyId =
    process.env.RAZORPAY_KEY_ID ||
    functions.config().razorpay?.key_id;
  const keySecret =
    process.env.RAZORPAY_KEY_SECRET ||
    functions.config().razorpay?.key_secret;

  if (!keyId || !keySecret) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Razorpay API credentials are not configured on the server. Please set RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET."
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
  const appDoc = await db.collection("bus_pass_applications").doc(applicationId).get();
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
    appData.paymentStatus === "Paid" ||
    appData.paymentStatus === "success"
  ) {
    throw new functions.https.HttpsError(
      "already-exists",
      "This application is already paid."
    );
  }

  // Strict route fare verification (Default ₹4500, or exact route fare from database)
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
  } catch (err) {
    console.error("Razorpay order creation failed:", err);
    throw new functions.https.HttpsError(
      "internal",
      `Failed to create Razorpay order: ${err.message || err}`
    );
  }
});

/**
 * 2. VERIFY RAZORPAY PAYMENT (Callable HTTPS Function)
 * Verifies HMAC-SHA256 signature using Razorpay Key Secret.
 * Sets paymentStatus = "paid" and applicationStatus = "pending_admin_approval" (NEVER auto-approved).
 */
exports.verifyRazorpayPayment = functions.https.onCall(async (data, context) => {
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

  // Compute expected HMAC SHA-256 signature: hmac_sha256(order_id + "|" + razorpay_payment_id, secret)
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
        failureReason: "Razorpay signature verification mismatch.",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    throw new functions.https.HttpsError(
      "permission-denied",
      "Payment verification failed: cryptographic signature mismatch."
    );
  }

  const now = admin.firestore.FieldValue.serverTimestamp();

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
          const appRef = db.collection("bus_pass_applications").doc(payData.applicationId);
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
  "description": "Secure Firebase Cloud Functions for ICEM Bus Pass Payment Processing",
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



================================================
FILE: icem_bus/lib/features/admin/presentation/views/admin_dashboard.dart
================================================
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/routes/app_routes.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/features/admin/domain/admin_providers.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_overview_tab.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_applications_tab.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_routes_tab.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_buses_tab.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_students_tab.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_payments_tab.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_notifications_tab.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_reports_tab.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_settings_tab.dart';

// ============================================================
// ADMIN DASHBOARD SCREEN
// ============================================================

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final currentTab = ref.watch(adminTabProvider);
    final user = authState.user;
    final theme = Theme.of(context);

    // ── Auth Guard ──
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go(AppRoutes.login);
      });
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
                  'Only Administrators are authorized to view this management console.',
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
            ),
          ],
        ),
      ),
    );
  }

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

    return Container(
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
                      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
                      child: Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primaryCrimson, AppColors.darkCrimson],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryCrimson.withOpacity(0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.admin_panel_settings_rounded,
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
                                  ref.read(adminTabProvider.notifier).state = item.index;
                                  if (isMobile) {
                                    Navigator.pop(context);
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
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
                            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Icon(Icons.logout_rounded,
                                    size: 20, color: AppColors.primaryCrimson),
                                SizedBox(width: 14),
                                Text(
                                  'Logout',
                                  style: TextStyle(
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
            'Are you sure you want to sign out from the Administrative Console?'),
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

  _SidebarItem(this.index, this.title, this.icon);
}


================================================
FILE: ios/Flutter/AppFrameworkInfo.plist
================================================
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
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



================================================
FILE: ios/Runner/AppDelegate.swift
================================================
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}



================================================
FILE: ios/Runner/Info.plist
================================================
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSCameraUsageDescription</key>
	<string>ICEM Bus needs camera access to capture student profile pictures.</string>
	<key>NSPhotoLibraryUsageDescription</key>
	<string>ICEM Bus needs gallery access to upload student profile pictures.</string>
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
					<string>$(PRODUCT_MODULE_NAME).SceneDelegate</string>
					<key>UISceneStoryboardFile</key>
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



================================================
FILE: ios/Runner/Runner-Bridging-Header.h
================================================
#import "GeneratedPluginRegistrant.h"



================================================
FILE: ios/Runner/SceneDelegate.swift
================================================
import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

}



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



================================================
FILE: ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md
================================================
# Launch Screen Assets

You can customize the launch screen with your own desired assets by replacing the image files in this directory.

You can also do it by opening your Flutter project's Xcode project with `open ios/Runner.xcworkspace`, selecting `Runner/Assets.xcassets` in the Project Navigator and dropping in the desired images.


================================================
FILE: ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json
================================================
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



================================================
FILE: ios/Runner/Base.lproj/LaunchScreen.storyboard
================================================
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<document type="com.apple.InterfaceBuilder3.CocoaTouch.Storyboard.XIB" version="3.0" toolsVersion="12121" systemVersion="16G29" targetRuntime="iOS.CocoaTouch" propertyAccessControl="none" useAutolayout="YES" launchScreen="YES" colorMatched="YES" initialViewController="01J-lp-oVM">
    <dependencies>
        <deployment identifier="iOS"/>
        <plugIn identifier="com.apple.InterfaceBuilder.IBCocoaTouchPlugin" version="12089"/>
    </dependencies>
    <scenes>
        <!--View Controller-->
        <scene sceneID="EHf-IW-A2E">
            <objects>
                <viewController id="01J-lp-oVM" sceneMemberID="viewController">
                    <layoutGuides>
                        <viewControllerLayoutGuide type="top" id="Ydg-fD-yQy"/>
                        <viewControllerLayoutGuide type="bottom" id="xbc-2k-c8Z"/>
                    </layoutGuides>
                    <view key="view" contentMode="scaleToFill" id="Ze5-6b-2t3">
                        <autoresizingMask key="autoresizingMask" widthSizable="YES" heightSizable="YES"/>
                        <subviews>
                            <imageView opaque="NO" clipsSubviews="YES" multipleTouchEnabled="YES" contentMode="center" image="LaunchImage" translatesAutoresizingMaskIntoConstraints="NO" id="YRO-k0-Ey4">
                            </imageView>
                        </subviews>
                        <color key="backgroundColor" red="1" green="1" blue="1" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>
                        <constraints>
                            <constraint firstItem="YRO-k0-Ey4" firstAttribute="centerX" secondItem="Ze5-6b-2t3" secondAttribute="centerX" id="1a2-6s-vTC"/>
                            <constraint firstItem="YRO-k0-Ey4" firstAttribute="centerY" secondItem="Ze5-6b-2t3" secondAttribute="centerY" id="4X2-HB-R7a"/>
                        </constraints>
                    </view>
                </viewController>
                <placeholder placeholderIdentifier="IBFirstResponder" id="iYj-Kq-Ea1" userLabel="First Responder" sceneMemberID="firstResponder"/>
            </objects>
            <point key="canvasLocation" x="53" y="375"/>
        </scene>
    </scenes>
    <resources>
        <image name="LaunchImage" width="168" height="185"/>
    </resources>
</document>



================================================
FILE: ios/Runner/Base.lproj/Main.storyboard
================================================
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<document type="com.apple.InterfaceBuilder3.CocoaTouch.Storyboard.XIB" version="3.0" toolsVersion="10117" systemVersion="15F34" targetRuntime="iOS.CocoaTouch" propertyAccessControl="none" useAutolayout="YES" useTraitCollections="YES" initialViewController="BYZ-38-t0r">
    <dependencies>
        <deployment identifier="iOS"/>
        <plugIn identifier="com.apple.InterfaceBuilder.IBCocoaTouchPlugin" version="10085"/>
    </dependencies>
    <scenes>
        <!--Flutter View Controller-->
        <scene sceneID="tne-QT-ifu">
            <objects>
                <viewController id="BYZ-38-t0r" customClass="FlutterViewController" sceneMemberID="viewController">
                    <layoutGuides>
                        <viewControllerLayoutGuide type="top" id="y3c-jy-aDJ"/>
                        <viewControllerLayoutGuide type="bottom" id="wfy-db-euE"/>
                    </layoutGuides>
                    <view key="view" contentMode="scaleToFill" id="8bC-Xf-vdC">
                        <rect key="frame" x="0.0" y="0.0" width="600" height="600"/>
                        <autoresizingMask key="autoresizingMask" widthSizable="YES" heightSizable="YES"/>
                        <color key="backgroundColor" white="1" alpha="1" colorSpace="custom" customColorSpace="calibratedWhite"/>
                    </view>
                </viewController>
                <placeholder placeholderIdentifier="IBFirstResponder" id="dkx-z0-nzr" sceneMemberID="firstResponder"/>
            </objects>
        </scene>
    </scenes>
</document>



================================================
FILE: ios/RunnerTests/RunnerTests.swift
================================================
import Flutter
import UIKit
import XCTest

class RunnerTests: XCTestCase {

  func testExample() {
    // If you add code to the Runner application, consider adding tests here.
    // See https://developer.apple.com/documentation/xctest for more information about using XCTest.
  }

}



================================================
FILE: lib/main.dart
================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/app/app.dart';
import 'package:icem_bus/services/firebase/firebase_service.dart';
import 'package:icem_bus/services/storage/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  // Ensure widget binding is initialized before asynchronous service calls
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences local cache
  final sharedPreferences = await SharedPreferences.getInstance();
  final storageService = StorageService(sharedPreferences);

  // Initialize Firebase Core & Messaging (Gracefully runs offline if config files are not present)
  await FirebaseService.initialize();

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storageService),
      ],
      child: const MyApp(),
    ),
  );
}



================================================
FILE: lib/app/app.dart
================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/config/routes/app_routes.dart';
import 'package:icem_bus/config/theme/app_theme.dart';

import 'package:icem_bus/services/storage/storage_service.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider);

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



================================================
FILE: lib/app/.gitkeep
================================================
[Empty file]


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



================================================
FILE: lib/config/routes/app_routes.dart
================================================
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/auth/domain/entities/user_entity.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/features/admin/presentation/views/staff_dashboard.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_dashboard.dart';
import 'package:icem_bus/features/auth/presentation/views/login_screen.dart';
import 'package:icem_bus/features/auth/presentation/views/onboarding_screen.dart';
import 'package:icem_bus/features/auth/presentation/views/register_screen.dart';
import 'package:icem_bus/features/auth/presentation/views/splash_screen.dart';
import 'package:icem_bus/features/student/presentation/views/student_dashboard.dart';
import 'package:icem_bus/features/student/presentation/views/student_sub_screens.dart';
import 'package:icem_bus/features/admin/presentation/views/application_detail_screen.dart';
import 'package:icem_bus/shared/error_screen.dart';
import 'package:icem_bus/shared/loading_screen.dart';
import 'package:icem_bus/features/driver/presentation/views/driver_management_screen.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_settings_screen.dart';
import 'package:icem_bus/features/payment/presentation/views/payment_receipt_screen.dart';
import 'package:icem_bus/features/bus_pass/presentation/views/qr_verification_screen.dart';
import 'package:icem_bus/features/student/presentation/views/student_pass_history_screen.dart';
import 'package:icem_bus/features/student/presentation/views/student_pass_detail_screen.dart';

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

  // Student Sub routes
  static const String studentApply = '/student/apply';
  static const String studentRenew = '/student/renew';
  static const String studentDigitalPass = '/student/digital-pass';
  static const String studentPassHistory = '/student/pass-history';
  static const String studentPassDetail = '/student/pass-detail/:id';
  static const String studentPaymentHistory = '/student/payment-history';
  static const String studentPayment = '/student/payment';
  static const String studentPaymentReceipt = '/student/payment-receipt/:id';

  // Admin & Staff verification route
  static const String qrVerification = '/admin/verify-qr';

  static final GoRouter router = GoRouter(
    initialLocation: splash,
    redirect: (BuildContext context, GoRouterState state) {
      final String path = state.uri.path;

      // Determine if it's an auth-related public page
      final bool isPublicPath = path == splash ||
          path == onboarding ||
          path == login ||
          path == register;

      // Check Firebase Auth status synchronously
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

      // User is logged in. Check Riverpod state for loaded Firestore profile
      final container = ProviderScope.containerOf(context);
      final authState = container.read(authControllerProvider);
      final user = authState.user;

      // If user profile is not loaded yet in state, we let the app load the page (or splash)
      if (user == null) {
        return null;
      }

      final String role = UserEntity.normalizeRole(user.role);

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

      // Guard QR Verification (accessible by both Admin and Staff)
      if (path == qrVerification) {
        if (role != 'Admin' && role != 'Staff') {
          Future.microtask(() {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Access Denied: Conductor or Administrator privileges required.'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          });
          return studentDashboard;
        }
        return null;
      }

      // Guard Admin pages
      if (path == adminDashboard || (path.startsWith('/admin/') && path != qrVerification)) {
        if (role != 'Admin') {
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



================================================
FILE: lib/config/theme/app_colors.dart
================================================
import 'package:flutter/material.dart';

class AppColors {
  // ── Primary Brand Colors (Deep Navy + Luxury Crimson Direction) ──
  static const Color primaryCrimson = Color(0xFFD71920); // Vibrant ICEM Crimson Red
  static const Color crimsonRed = Color(0xFFE31B23);    // High-energy Crimson for accents/glow
  static const Color darkCrimson = Color(0xFF990000);   // Deep Crimson for gradients
  static const Color lightCrimson = Color(0x26D71920);  // Translucent crimson tint for badges
  static const Color crimsonLight = Color(0x26D71920);  // Translucent crimson tint alias
  static const Color borderCrimson = Color(0xFFD71920); // Crimson border for active cards

  // Crimson Scales
  static const Color crimson50 = Color(0x1AD71920);
  static const Color crimson100 = Color(0x2BD71920);
  static const Color crimson200 = Color(0x40D71920);
  static const Color crimson500 = Color(0xFFD71920);
  static const Color crimson600 = Color(0xFFE31B23);
  static const Color crimson700 = Color(0xFFB80F0A);
  static const Color crimson800 = Color(0xFF990000);

  // ── Deep Navy & Charcoal Backgrounds (Reference Style) ──
  static const Color background = Color(0xFF0B1118);       // Primary deep navy background
  static const Color backgroundNavy = Color(0xFF0B1118);   // #0B1118
  static const Color backgroundCharcoal = Color(0xFF101820); // #101820
  static const Color backgroundLight = Color(0xFF0B1118);  // Default dark backdrop

  // Surfaces & Cards
  static const Color surface = Color(0xFF151E28);          // Dark navy/charcoal surface #151E28
  static const Color surfaceCard = Color(0xFF151E28);      // Standard card surface
  static const Color surfaceElevated = Color(0xFF1A2432);  // Slightly lighter elevated card
  static const Color surfaceLight = Color(0xFF151E28);     // Card fallback
  static const Color cardBorder = Color(0xFF222F3E);       // Subtle slate-navy border
  static const Color cardBorderSubtle = Color(0x1FFFFFFF); // 12% white subtle border

  // Semantic Design Aliases
  static const Color bgDark = Color(0xFF0B1118);
  static const Color cardSurface = Color(0xFF151E28);
  static const Color elevatedSurface = Color(0xFF1A2432);
  static const Color borderSubtle = Color(0xFF222F3E);
  static const Color textMuted = Color(0xFF94A3B8);

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

  // Text Colors
  static const Color textPrimary = Color(0xFFF8FAFC);     // Soft pure white for primary text
  static const Color textSecondary = Color(0xFF94A3B8);   // Muted slate gray for secondary info
  static const Color textLight = Color(0xFF64748B);       // Subtle helper text
  static const Color textOnPrimary = Color(0xFFFFFFFF);   // White on crimson CTA

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




================================================
FILE: lib/config/theme/app_theme.dart
================================================
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:icem_bus/config/theme/app_colors.dart';

class AppTheme {
  AppTheme._();

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
          fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        displayMedium: GoogleFonts.outfit(
          fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        titleLarge: GoogleFonts.outfit(
          fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        titleMedium: GoogleFonts.outfit(
          fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
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
      dividerTheme: const DividerThemeData(color: AppColors.cardBorder, thickness: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.cardBorder, width: 1),
        ),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
          fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
    const onSurfaceColor = Color(0xFF1A2030); // Near-black readable text
    const onSurfaceVariant = Color(0xFF64748B); // Muted secondary text
    const borderColor = Color(0xFFDDE3EE);   // Soft border

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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



================================================
FILE: lib/core/errors/failures.dart
================================================
/// Base class representing errors/failures in the application.
abstract class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => message;
}

/// Failure representing server or database connectivity/data errors (e.g. Firestore, Cloud Functions).
class ServerFailure extends Failure {
  const ServerFailure([super.message = 'A server error occurred. Please try again.']);
}

/// Failure representing network connectivity errors.
class ConnectionFailure extends Failure {
  const ConnectionFailure([super.message = 'No internet connection.']);
}

/// Failure representing authentication-related errors.
class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication failed.']);
}

/// Failure representing storage-related errors (e.g. SharedPreferences, Local DB).
class StorageFailure extends Failure {
  const StorageFailure([super.message = 'Failed to load local settings.']);
}



================================================
FILE: lib/core/usecases/usecase.dart
================================================
/// Base UseCase class for Clean Architecture.
/// [T] represents the return type of the use case.
/// [Params] represents the parameters required to run the usecase.
abstract class UseCase<T, Params> {
  Future<T> call(Params params);
}

/// Use this class if a UseCase does not require any parameters.
class NoParams {
  const NoParams();
}



================================================
FILE: lib/core/utils/responsive.dart
================================================
import 'package:flutter/material.dart';

/// Utility class for responsive design breakpoints
class Responsive extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

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

/// Helper extension on BuildContext to quickly access dimensions and responsive helpers
extension ResponsiveContextExtension on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;
  
  bool get isMobile => Responsive.isMobile(this);
  bool get isTablet => Responsive.isTablet(this);
  bool get isDesktop => Responsive.isDesktop(this);

  /// Helper to select values based on screen size (e.g. padding, grid cross axis count)
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



================================================
FILE: lib/features/admin/.gitkeep
================================================
[Empty file]


================================================
FILE: lib/features/admin/data/.gitkeep
================================================
[Empty file]


================================================
FILE: lib/features/admin/data/repositories/admin_repository.dart
================================================
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/core/errors/failures.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository();
});

/// Repository handling all Firestore operations for the Admin dashboard.
class AdminRepository {
  final FirebaseFirestore _firestore;

  AdminRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // -------------------------------------------------------
  // APPLICATION ACTIONS
  // -------------------------------------------------------

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
        'ICEM-BP-${now.year}-${now.millisecondsSinceEpoch.toString().substring(7)}';
    final passId =
        'ICEM-PASS-${now.millisecondsSinceEpoch.toRadixString(16).toUpperCase()}';

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
    routeData['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('bus_routes').add(routeData);
  }

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
        });
      }
    }

    await batch.commit();
  }

  Future<void> updateBus(
    String busId,
    Map<String, dynamic> busData, {
    String? oldRouteId,
  }) async {
    busData['updatedAt'] = FieldValue.serverTimestamp();
    final busRef = _firestore.collection('buses').doc(busId);
    final batch = _firestore.batch();
    batch.update(busRef, busData);

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

      // Set new route's assigned bus, and clear other buses assigned to new route
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

  Future<void> deleteBus(String busId, {String? assignedRouteId}) async {
    final batch = _firestore.batch();
    batch.delete(_firestore.collection('buses').doc(busId));

    if (assignedRouteId != null && assignedRouteId.isNotEmpty) {
      final routeRef = _firestore.collection('bus_routes').doc(assignedRouteId);
      batch.update(routeRef, {
        'assignedBusId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// Returns true if the bus is assigned to an active route (preventing deletion).
  Future<bool> checkBusInUse(String? assignedRouteId) async {
    if (assignedRouteId == null || assignedRouteId.isEmpty) return false;
    final doc = await _firestore.collection('bus_routes').doc(assignedRouteId).get();
    if (!doc.exists) return false;
    final status = doc.data()?['status'] ?? 'Active';
    return status == 'Active';
  }

  /// Verify a manual cash/transfer payment by document ID.
  /// Sets paymentStatus = "Paid" in receipts, updates the application to Pending Approval,
  /// and updates bus_passes to Paid/Pending (pass remains pending admin approval).
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
    // Payment is now verified as Paid; application is eligible for Admin approval (status = 'Pending')
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

    // 3. Update digital bus pass in bus_passes (Payment is verified, awaiting Admin approval)
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
  /// Updates paymentStatus to "Failed" and deactivates or sets the corresponding application and pass to "Failed".
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
  /// Updates paymentStatus to "Refunded" and marks the application and pass as "Refunded" / inactive.
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



  // -------------------------------------------------------
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
        'ICEM-BP-${now.year}-${now.millisecondsSinceEpoch.toString().substring(7)}';

    await _firestore.runTransaction((transaction) async {
      final passRef = _firestore.collection('bus_passes').doc(uid);
      final passSnap = await transaction.get(passRef);

      String paymentStatus = '';
      String existingPassId = '';
      if (passSnap.exists) {
        final d = passSnap.data()!;
        paymentStatus = (d['paymentStatus'] as String? ?? '').trim().toLowerCase();
        existingPassId = d['passId'] as String? ?? '';
      }

      if (paymentStatus != 'paid' && paymentStatus != 'success') {
        throw const ServerFailure(
            'Payment required before approval. Student has not completed verified payment.');
      }

      final passId = existingPassId.isNotEmpty
          ? existingPassId
          : 'ICEM-PASS-${now.millisecondsSinceEpoch.toRadixString(16).toUpperCase()}';

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
        .where('paymentStatus', whereIn: const ['Paid', 'paid', 'Success', 'success'])
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
  /// Sets passStatus = 'Revoked' in both `bus_passes` and `bus_pass_applications`.
  Future<void> revokePass(
    String studentUid,
    String reason,
    String adminUid,
  ) async {
    final batch = _firestore.batch();
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

/// Dashboard search query (name / PRN / college ID)
final dashboardSearchQueryProvider =
    StateProvider.autoDispose<String>((ref) => '');

/// Dashboard status filter chip selection
final dashboardStatusFilterProvider =
    StateProvider.autoDispose<String>((ref) => 'All');

/// Routes tab — status filter chip: 'All', 'Active', 'Inactive'
final routeStatusFilterProvider =
    StateProvider.autoDispose<String>((ref) => 'All');

/// Routes tab — search query
final routeSearchQueryProvider =
    StateProvider.autoDispose<String>((ref) => '');

/// Buses tab — status filter chip: 'All', 'Active', 'Maintenance', 'Inactive'
final busStatusFilterProvider =
    StateProvider.autoDispose<String>((ref) => 'All');

/// Buses tab — search query
final busSearchQueryProvider =
    StateProvider.autoDispose<String>((ref) => '');


// ============================================================
// LIVE FIRESTORE STREAM PROVIDERS — SUMMARY CARD COUNTS
// ============================================================

final totalStudentsStreamProvider = StreamProvider.autoDispose<int>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .snapshots()
      .map((s) => s.docs.where((d) => UserEntity.isStudentUser(d.data())).length);
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
            final st = (d.data()['status'] ?? d.data()['passStatus'] ?? '').toString();
            return st == 'Pending' || st == 'Payment Pending' || st == 'Pending Approval' || st == 'Pending Payment';
          }).length);
});

final approvedPassesStreamProvider = StreamProvider.autoDispose<int>((ref) {
  return FirebaseFirestore.instance
      .collection('bus_pass_applications')
      .snapshots()
      .map((s) => s.docs.where((d) {
            final st = (d.data()['status'] ?? d.data()['passStatus'] ?? '').toString();
            return st == 'Approved' || st == 'Active';
          }).length);
});

final rejectedPassesStreamProvider = StreamProvider.autoDispose<int>((ref) {
  return FirebaseFirestore.instance
      .collection('bus_pass_applications')
      .snapshots()
      .map((s) => s.docs.where((d) {
            final st = (d.data()['status'] ?? d.data()['passStatus'] ?? '').toString();
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
      .collection('bus_pass_applications')
      .where('status', isEqualTo: 'Correction Required')
      .snapshots()
      .map((s) => s.docs.length);
});

final totalRoutesStreamProvider = StreamProvider.autoDispose<int>((ref) {
  return FirebaseFirestore.instance
      .collection('bus_routes')
      .snapshots()
      .map((s) => s.docs.length);
});

final totalBusesStreamProvider = StreamProvider.autoDispose<int>((ref) {
  return FirebaseFirestore.instance
      .collection('buses')
      .snapshots()
      .map((s) => s.docs.length);
});

// ============================================================
// RECENT APPLICATIONS (latest 10)
// ============================================================

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
      final aStatus = (data['status'] as String? ?? data['passStatus'] as String? ?? '').toLowerCase();
      if ((aStatus == 'approved' || aStatus == 'active') && pStatus != 'paid' && pStatus != 'success') {
        // Diagnostic warning for historical inconsistent records
        debugPrint('🚨 [INCONSISTENT APPLICATION DETECTED]: ID: ${doc.id}, Application Status: ${data['status']}, Payment Status: ${data['paymentStatus']}, Student: ${data['fullName'] ?? data['studentName']}');
      }
    }

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).where((app) {
      if (statusFilter == 'All') return true;
      final st = (app['status'] ?? app['passStatus'] ?? '').toString();
      final pStatus = (app['paymentStatus'] ?? '').toString().toLowerCase();
      final isPaid = pStatus == 'paid' || pStatus == 'success';

      if (statusFilter == 'Pending') {
        return st == 'Pending' || st == 'Pending Approval' || st == 'Payment Pending' || st == 'Pending Payment';
      } else if (statusFilter == 'Approved') {
        return st == 'Approved' || st == 'Active';
      } else if (statusFilter == 'Rejected') {
        return st == 'Rejected';
      } else if (statusFilter == 'Payment Pending') {
        return !isPaid && (st == 'Payment Pending' || st == 'Pending Payment' || st == 'Pending');
      }
      return st == statusFilter;
    }).toList();
  });
});

// ============================================================
// ROUTES, BUSES, STUDENTS LIST STREAMS
// ============================================================

final routesListStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('bus_routes')
      .snapshots()
      .map((s) => s.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList());
});

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
});

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
          }).toList());
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



================================================
FILE: lib/features/admin/domain/.gitkeep
================================================
[Empty file]


================================================
FILE: lib/features/admin/presentation/.gitkeep
================================================
[Empty file]


================================================
FILE: lib/features/admin/presentation/views/admin_applications_tab.dart
================================================
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/admin/data/repositories/admin_repository.dart';
import 'package:icem_bus/features/admin/domain/admin_providers.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_widgets.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';

/// Full applications management tab with search, filter, approve/reject/correction
class AdminApplicationsTab extends ConsumerStatefulWidget {
  const AdminApplicationsTab({super.key});

  @override
  ConsumerState<AdminApplicationsTab> createState() =>
      _AdminApplicationsTabState();
}

class _AdminApplicationsTabState extends ConsumerState<AdminApplicationsTab> {
  String _searchQuery = '';
  String _statusFilter = 'All';

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
                  final collegeId = (app['collegeId'] ?? '').toString().toLowerCase();
                  return name.contains(q) || prn.contains(q) || collegeId.contains(q);
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
                    onApprove: () => _confirmApprove(repo, app['id'], app['paymentStatus']),
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
  void _confirmApprove(AdminRepository repo, String applicationId, [dynamic paymentStatus]) {
    final pStatus = (paymentStatus ?? '').toString().trim().toLowerCase();
    if (pStatus.isNotEmpty && pStatus != 'paid' && pStatus != 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment required before approval. Student must complete verified payment first.'),
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
            'Are you sure you want to approve this bus pass application? A unique Pass ID will be generated and digital pass activated.'),
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

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Application'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please provide a reason for rejecting this application.'),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Rejection reason...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
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
              Icon(Icons.show_chart_rounded, size: 36, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              const SizedBox(height: 10),
              Text(
                widget.data.isEmpty ? 'No data available' : 'Insufficient trend data (requires multiple time points)',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
              ),
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
                onPanStart: (details) => _updateSelection(details.localPosition, width, height),
                onPanUpdate: (details) => _updateSelection(details.localPosition, width, height),
                onPanEnd: (_) => setState(() => _selectedIndex = null),
                onTapDown: (details) => _updateSelection(details.localPosition, width, height),
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
    const paddingLeft = 40.0;
    const paddingRight = 10.0;
    final chartWidth = width - paddingLeft - paddingRight;

    if (widget.data.length < 2) return;

    final xRatio = (localPos.dx - paddingLeft) / chartWidth;
    final index = (xRatio * (widget.data.length - 1)).round().clamp(0, widget.data.length - 1);

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
      canvas.drawLine(Offset(paddingLeft, y), Offset(size.width - paddingRight, y), gridPaint);

      // Label
      final tp = TextPainter(
        text: TextSpan(
          text: '$valuePrefix${val.toStringAsFixed(0)}',
          style: textStyle,
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
        ).createShader(Rect.fromLTRB(paddingLeft, paddingTop, size.width - paddingRight, paddingTop + chartHeight));

      canvas.drawPath(fillPath, fillPaint);

      // Draw Stroke Line
      final strokePaint = Paint()
        ..color = primaryColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final strokePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        strokePath.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(strokePath, strokePaint);
    }

    // Draw X labels
    for (int i = 0; i < data.length; i++) {
      if (data.length > 6 && i % (data.length / 4).ceil() != 0 && i != data.length - 1) {
        continue;
      }
      final x = points[i].dx;
      final y = size.height - paddingBottom + 4;

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
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final boxWidth = tpTitle.width + tpVal.width + 12;
      final boxHeight = 22.0;

      double boxX = selectedPoint.dx - boxWidth / 2;
      if (boxX < paddingLeft) boxX = paddingLeft;
      if (boxX + boxWidth > size.width - paddingRight) boxX = size.width - paddingRight - boxWidth;

      double boxY = selectedPoint.dy - boxHeight - 8;
      if (boxY < paddingTop) boxY = selectedPoint.dy + 8;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(boxX, boxY, boxWidth, boxHeight),
        const Radius.circular(6),
      );

      final boxPaint = Paint()..color = const Color(0xFF0F172A);
      canvas.drawRRect(rect, boxPaint);

      tpTitle.paint(canvas, Offset(boxX + 6, boxY + (boxHeight - tpTitle.height) / 2));
      tpVal.paint(canvas, Offset(boxX + 6 + tpTitle.width, boxY + (boxHeight - tpVal.height) / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex || oldDelegate.data != data;
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
              Icon(Icons.pie_chart_outline_rounded, size: 36, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              const SizedBox(height: 10),
              Text('No sufficient data available', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
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
                    final pct = total > 0 ? (val / total * 100).toStringAsFixed(1) : '0';

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
                            child: Text(
                              key,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
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
          const TextSpan(
            text: 'Total\n',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 10, height: 1.2),
          ),
          TextSpan(
            text: '${total.toInt()}',
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold, height: 1.2),
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
    final maxVal = data.isEmpty ? 0.0 : data.map((d) => d.value).reduce(math.max);

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
            children: [
              Icon(Icons.bar_chart_rounded, size: 36, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              const SizedBox(height: 10),
              Text('No sufficient data available', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
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



================================================
FILE: lib/features/admin/presentation/views/admin_dashboard.dart
================================================
﻿// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/routes/app_routes.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/features/admin/domain/admin_providers.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_overview_tab.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_applications_tab.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_routes_tab.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_buses_tab.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_students_tab.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_payments_tab.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_notifications_tab.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_reports_tab.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_settings_tab.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final currentTab = ref.watch(adminTabProvider);
    final user = authState.user;
    final theme = Theme.of(context);

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go(AppRoutes.login));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (user.role != 'Admin') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Access Denied'), backgroundColor: AppColors.error));
        context.go(AppRoutes.studentDashboard);
      });
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.gpp_bad_rounded, size: 80, color: AppColors.primaryCrimson),
          const SizedBox(height: 24),
          Text('Access Denied', style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('Only Administrators are authorized to view this management console.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
        ]))),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: isMobile ? _buildMobileAppBar(context, currentTab, theme) : null,
      drawer: isMobile ? Drawer(backgroundColor: theme.colorScheme.surface, child: _AdminDrawer(currentTab: currentTab, onNavigate: (i) => _navigate(ref, context, i, true), onLogout: () => _handleLogout(context))) : null,
      body: SafeArea(
        child: Row(
          children: [
            if (!isMobile) ...[
              SizedBox(width: 260, child: Container(color: theme.colorScheme.surface, child: _AdminDrawer(currentTab: currentTab, onNavigate: (i) => _navigate(ref, context, i, false), onLogout: () => _handleLogout(context)))),
              Container(width: 1, color: theme.dividerColor),
            ],
            Expanded(
              child: Container(
                color: theme.scaffoldBackgroundColor,
                child: Column(children: [
                  if (!isMobile) _buildDesktopHeader(context, user.fullName),
                  Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 220), transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child), child: _buildTabContent(currentTab))),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar(BuildContext context, int currentTab, ThemeData theme) {
    return AppBar(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(icon: Icon(Icons.menu_rounded, color: theme.colorScheme.onSurface, size: 24), onPressed: () => _scaffoldKey.currentState?.openDrawer(), tooltip: 'Open Menu'),
      titleSpacing: 0,
      title: Row(children: [
        Container(width: 30, height: 30, padding: const EdgeInsets.all(4), decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primaryCrimson, AppColors.darkCrimson], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(8)), child: Image.asset('assets/images/bus_logo.png', fit: BoxFit.contain)),
        const SizedBox(width: 10),
        Expanded(child: Text(_getTabTitle(currentTab), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: theme.colorScheme.onSurface, letterSpacing: -0.2), overflow: TextOverflow.ellipsis, maxLines: 1)),
      ]),
      actions: [
        IconButton(icon: Icon(Icons.notifications_none_rounded, color: theme.colorScheme.onSurfaceVariant, size: 22), onPressed: () => ref.read(adminTabProvider.notifier).state = 6, tooltip: 'Notifications'),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: theme.dividerColor)),
    );
  }

  Widget _buildDesktopHeader(BuildContext context, String adminName) {
    final currentTab = ref.watch(adminTabProvider);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: BoxDecoration(color: theme.colorScheme.surface, border: Border(bottom: BorderSide(color: theme.dividerColor))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ICEM TRANSPORT OFFICE', style: TextStyle(color: AppColors.primaryCrimson, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 1.4)),
            const SizedBox(height: 3),
            Text(_getTabTitle(currentTab), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface, letterSpacing: -0.3)),
          ]),
          Row(children: [
            IconButton(icon: Icon(Icons.qr_code_scanner_rounded, color: theme.colorScheme.onSurfaceVariant, size: 20), onPressed: () => context.push(AppRoutes.qrVerification), tooltip: 'Verify QR'),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10), border: Border.all(color: theme.dividerColor)),
              child: Row(children: [const Icon(Icons.admin_panel_settings_rounded, color: AppColors.primaryCrimson, size: 16), const SizedBox(width: 7), Text(adminName, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 13))]),
            ),
            const SizedBox(width: 10),
            Material(color: AppColors.primaryCrimson.withOpacity(0.08), borderRadius: BorderRadius.circular(10), child: InkWell(borderRadius: BorderRadius.circular(10), onTap: () => _handleLogout(context), child: const Padding(padding: EdgeInsets.all(9), child: Icon(Icons.logout_rounded, color: AppColors.primaryCrimson, size: 18)))),
          ]),
        ],
      ),
    );
  }

  Widget _buildTabContent(int tabIndex) {
    switch (tabIndex) {
      case 0: return const AdminOverviewTab(key: ValueKey('overview'));
      case 1: return const AdminApplicationsTab(key: ValueKey('applications'));
      case 2: return const AdminRoutesTab(key: ValueKey('routes'));
      case 3: return const AdminBusesTab(key: ValueKey('buses'));
      case 4: return const AdminStudentsTab(key: ValueKey('students'));
      case 5: return const AdminPaymentsTab(key: ValueKey('payments'));
      case 6: return const AdminNotificationsTab(key: ValueKey('notifications'));
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

  void _navigate(WidgetRef ref, BuildContext context, int tabIndex, bool isMobile) {
    ref.read(adminTabProvider.notifier).state = tabIndex;
    if (isMobile) Navigator.pop(context);
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Sign Out'),
        content: const Text('Are you sure you want to sign out from the Administrative Console?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign Out', style: TextStyle(color: AppColors.primaryCrimson, fontWeight: FontWeight.bold))),
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
  const _AdminDrawer({required this.currentTab, required this.onNavigate, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: LayoutBuilder(builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // ── Branding Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
                  child: Row(children: [
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.primaryCrimson, AppColors.darkCrimson], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [BoxShadow(color: AppColors.primaryCrimson.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 5))],
                      ),
                      child: Center(child: Padding(padding: const EdgeInsets.all(8), child: Image.asset('assets/images/bus_logo.png', fit: BoxFit.contain))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('ADMIN PORTAL', style: TextStyle(color: AppColors.primaryCrimson, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2)),
                      const SizedBox(height: 2),
                      Text('Smart Campus Mobility', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w500)),
                    ])),
                  ]),
                ),
                Container(height: 1, color: theme.dividerColor),
                const SizedBox(height: 10),

                // ── OVERVIEW ──
                _SectionLabel(label: 'OVERVIEW', theme: theme),
                _NavItem(index: 0, title: 'Dashboard', icon: Icons.dashboard_rounded, currentTab: currentTab, theme: theme, onTap: () => onNavigate(0)),
                const SizedBox(height: 6),

                // ── MANAGEMENT ──
                _SectionLabel(label: 'MANAGEMENT', theme: theme),
                _NavItem(index: 4, title: 'Students', icon: Icons.people_alt_rounded, currentTab: currentTab, theme: theme, onTap: () => onNavigate(4)),
                _NavItem(index: 2, title: 'Routes', icon: Icons.route_rounded, currentTab: currentTab, theme: theme, onTap: () => onNavigate(2)),
                _NavItem(index: 3, title: 'Buses', icon: Icons.directions_bus_rounded, currentTab: currentTab, theme: theme, onTap: () => onNavigate(3)),
                _NavItem(index: -1, title: 'Drivers', icon: Icons.badge_rounded, currentTab: currentTab, theme: theme, onTap: () {
                  Navigator.of(context).maybePop();
                  context.push(AppRoutes.driverManagement);
                }),
                const SizedBox(height: 6),

                // ── OPERATIONS ──
                _SectionLabel(label: 'OPERATIONS', theme: theme),
                _NavItem(index: 5, title: 'Payments', icon: Icons.receipt_long_rounded, currentTab: currentTab, theme: theme, onTap: () => onNavigate(5)),
                _NavItem(index: 1, title: 'Pass Management', icon: Icons.card_membership_rounded, currentTab: currentTab, theme: theme, onTap: () => onNavigate(1)),
                _NavItem(index: 6, title: 'Notifications', icon: Icons.notifications_rounded, currentTab: currentTab, theme: theme, onTap: () => onNavigate(6)),
                const SizedBox(height: 6),

                // ── ANALYTICS ──
                _SectionLabel(label: 'ANALYTICS', theme: theme),
                _NavItem(index: 7, title: 'Reports & Analytics', icon: Icons.analytics_rounded, currentTab: currentTab, theme: theme, onTap: () => onNavigate(7)),
                const SizedBox(height: 6),

                // ── SYSTEM ──
                _SectionLabel(label: 'SYSTEM', theme: theme),
                _NavItem(index: 8, title: 'Settings', icon: Icons.settings_rounded, currentTab: currentTab, theme: theme, onTap: () => onNavigate(8)),

                const Spacer(),

                // ── Logout ──
                Container(height: 1, color: theme.dividerColor),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Material(
                    color: AppColors.primaryCrimson.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: onLogout,
                      child: const Padding(padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13), child: Row(children: [
                        Icon(Icons.logout_rounded, size: 20, color: AppColors.primaryCrimson),
                        SizedBox(width: 14),
                        Text('Logout', style: TextStyle(color: AppColors.primaryCrimson, fontWeight: FontWeight.w700, fontSize: 13.5)),
                      ])),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

/// Muted section label in the drawer.
class _SectionLabel extends StatelessWidget {
  final String label;
  final ThemeData theme;
  const _SectionLabel({required this.label, required this.theme});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 2),
      child: Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5), letterSpacing: 1.2)),
    );
  }
}

/// Single navigation item in the drawer.
class _NavItem extends StatelessWidget {
  final int index;
  final String title;
  final IconData icon;
  final int currentTab;
  final ThemeData theme;
  final VoidCallback onTap;
  const _NavItem({required this.index, required this.title, required this.icon, required this.currentTab, required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = index != -1 && currentTab == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1.5),
      child: Material(
        color: isSelected ? AppColors.primaryCrimson.withOpacity(0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(children: [
              Icon(icon, size: 19, color: isSelected ? AppColors.primaryCrimson : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 13),
              Expanded(child: Text(title, style: TextStyle(color: isSelected ? AppColors.primaryCrimson : theme.colorScheme.onSurface, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, fontSize: 13.5))),
              if (isSelected) Container(width: 5, height: 5, decoration: const BoxDecoration(color: AppColors.primaryCrimson, shape: BoxShape.circle)),
            ]),
          ),
        ),
      ),
    );
  }
}


================================================
FILE: lib/features/admin/presentation/views/admin_notifications_tab.dart
================================================
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/features/admin/domain/admin_providers.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_widgets.dart';
import 'package:icem_bus/features/notification/domain/notification_providers.dart';

/// Rebuild Admin Notification Management panel
class AdminNotificationsTab extends ConsumerStatefulWidget {
  const AdminNotificationsTab({super.key});

  @override
  ConsumerState<AdminNotificationsTab> createState() => _AdminNotificationsTabState();
}

class _AdminNotificationsTabState extends ConsumerState<AdminNotificationsTab> {
  String _searchQuery = '';
  String _statusFilter = 'All';

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
                    'Broadcast alerts, schedule reminders, and track announcement delivery.',
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
                        const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        const Text(
                          'Failed to load notifications',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          err.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref.invalidate(notificationsStreamProvider),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryCrimson),
                          child: const Text('Retry', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (list) {
                  var filtered = list;

                  // Apply filter chips
                  if (_statusFilter != 'All') {
                    filtered = filtered.where((n) => n['status'] == _statusFilter).toList();
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
                      subtitle: 'Try adjusting your filters or compose a new announcement.',
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
        label: const Text('Create Alert', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showNotificationDetails(BuildContext context, Map<String, dynamic> notification) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotificationDetailsSheet(
        notification: notification,
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

  void _openComposeSheet(BuildContext context, Map<String, dynamic>? initialNotification) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ComposeNotificationSheet(initialNotification: initialNotification),
    );
  }

  Future<void> _deleteConfirm(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Announcement?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text('Are you sure you want to permanently delete this scheduled notification?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(notificationRepositoryProvider).deleteNotification(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Scheduled notification deleted.'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
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
      dt = DateTime.fromMillisecondsSinceEpoch(dateField);
    }
    if (dt == null) return 'N/A';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
                      ),
                      const SizedBox(height: 10),
                      // Meta details row
                      Row(
                        children: [
                          Icon(Icons.people_alt_rounded, size: 11, color: Colors.blueGrey.shade400),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'To: $targetName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.calendar_month_rounded, size: 11, color: Colors.blueGrey.shade400),
                          const SizedBox(width: 4),
                          Text(
                            status == 'Scheduled'
                                ? 'Schedule: ${_formatDate(scheduledAt)}'
                                : 'Sent: ${_formatDate(scheduledAt)}',
                            style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600, fontWeight: FontWeight.w600),
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

class _NotificationDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> notification;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<String> onDelete;

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
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

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

    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isScheduled ? AppColors.info.withOpacity(0.1) : AppColors.success.withOpacity(0.1),
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
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 20),

          // Title
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
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
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
            ),
          ),
          const SizedBox(height: 20),

          // Details grid
          _buildDetailRow('Alert Type', type),
          _buildDetailRow('Target Group', targetType),
          _buildDetailRow('Recipient Scope', targetName),
          if (isScheduled) _buildDetailRow('Scheduled Delivery', _formatDate(scheduledAt)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => onEdit(notification),
                    icon: const Icon(Icons.edit_rounded, size: 18, color: Colors.white),
                    label: const Text('Edit Scheduled', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryCrimson,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                icon: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                label: const Text('Dismiss', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        ],
      ),
    );
  }
}

// ============================================================
// SEARCHABLE STUDENT PICKER MODAL
// ============================================================

class _StudentPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> students;
  final ValueChanged<Map<String, dynamic>> onSelect;

  const _StudentPickerSheet({required this.students, required this.onSelect});

  @override
  State<_StudentPickerSheet> createState() => _StudentPickerSheetState();
}

class _StudentPickerSheetState extends State<_StudentPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final search = _query.trim().toLowerCase();
    final filtered = search.isEmpty
        ? widget.students
        : widget.students.where((s) {
            final name = (s['fullName'] ?? '').toString().toLowerCase();
            final prn = (s['prn'] ?? '').toString().toLowerCase();
            final email = (s['email'] ?? '').toString().toLowerCase();
            return name.contains(search) || prn.contains(search) || email.contains(search);
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
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
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
                ? const Center(child: Text('No students found matching query.', style: TextStyle(color: Color(0xFF64748B))))
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final student = filtered[index];
                      final name = student['fullName'] ?? 'Unknown';
                      final prn = student['prn'] ?? 'N/A';
                      final course = student['course'] ?? 'N/A';
                      return ListTile(
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text('PRN: $prn | $course', style: const TextStyle(fontSize: 12)),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryCrimson.withOpacity(0.08),
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

// ============================================================
// COMPOSE & EDIT NOTIFICATION SHEET
// ============================================================

class _ComposeNotificationSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialNotification;

  const _ComposeNotificationSheet({this.initialNotification});

  @override
  ConsumerState<_ComposeNotificationSheet> createState() => _ComposeNotificationSheetState();
}

class _ComposeNotificationSheetState extends ConsumerState<_ComposeNotificationSheet> {
  final _titleController = TextEditingController();
  final _msgController = TextEditingController();

  String _type = 'General';
  String _targetType = 'All Students';

  String? _targetId;
  String? _targetName;

  bool _isScheduled = false;
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;

  bool _isSaving = false;

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
      initialDate: _scheduledDate ?? DateTime.now().add(const Duration(days: 1)),
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
        const SnackBar(content: Text('Please enter title'), backgroundColor: AppColors.warning),
      );
      return;
    }
    if (_msgController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter message'), backgroundColor: AppColors.warning),
      );
      return;
    }

    // Dynamic targets logic
    String tId = '';
    String tName = 'All Students';

    if (_targetType == 'Specific Route') {
      if (_targetId == null || _targetId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a route'), backgroundColor: AppColors.warning),
        );
        return;
      }
      tId = _targetId!;
      tName = _targetName ?? 'Route';
    } else if (_targetType == 'Specific Bus') {
      if (_targetId == null || _targetId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a bus'), backgroundColor: AppColors.warning),
        );
        return;
      }
      tId = _targetId!;
      tName = _targetName ?? 'Bus';
    } else if (_targetType == 'Individual Student') {
      if (_targetId == null || _targetId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a student'), backgroundColor: AppColors.warning),
        );
        return;
      }
      tId = _targetId!;
      tName = _targetName ?? 'Student';
    }

    final adminUser = ref.read(authControllerProvider).user;
    final createdBy = adminUser?.uid ?? 'Admin';

    DateTime scheduledDateTime;
    if (_isScheduled) {
      final date = _scheduledDate ?? DateTime.now().add(const Duration(days: 1));
      final time = _scheduledTime ?? const TimeOfDay(hour: 9, minute: 0);
      scheduledDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);

      if (scheduledDateTime.isBefore(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scheduled time must be in the future'), backgroundColor: AppColors.warning),
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
        await repo.updateNotification(widget.initialNotification!['notificationId'], data);
      } else {
        await repo.createNotification(data);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.initialNotification != null ? 'Alert updated!' : 'Alert generated!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
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

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
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
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 20),

            // Form inputs
            const Text('Alert Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: _inputDecoration(),
              items: const [
                DropdownMenuItem(value: 'General', child: Text('General Announcement')),
                DropdownMenuItem(value: 'Bus Delay', child: Text('Bus Delay Alert')),
                DropdownMenuItem(value: 'Route Change', child: Text('Route Change Alert')),
                DropdownMenuItem(value: 'Pass Approved', child: Text('Pass Approved Alert')),
                DropdownMenuItem(value: 'Pass Rejected', child: Text('Pass Rejected Alert')),
                DropdownMenuItem(value: 'Payment Reminder', child: Text('Payment Reminder')),
                DropdownMenuItem(value: 'Pass Expiry Reminder', child: Text('Pass Expiry Reminder')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _type = val);
              },
            ),
            const SizedBox(height: 16),

            const Text('Target Audience Group', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _targetType,
              decoration: _inputDecoration(),
              items: const [
                DropdownMenuItem(value: 'All Students', child: Text('All Students')),
                DropdownMenuItem(value: 'Specific Route', child: Text('Specific Route')),
                DropdownMenuItem(value: 'Specific Bus', child: Text('Specific Bus')),
                DropdownMenuItem(value: 'Individual Student', child: Text('Individual Student')),
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
              const Text('Select Route', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              routesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => const Text('Error loading routes', style: TextStyle(color: AppColors.error)),
                data: (routes) {
                  return DropdownButtonFormField<String>(
                    value: routes.any((r) => r['id'] == _targetId) ? _targetId : null,
                    decoration: _inputDecoration(),
                    items: routes.map((r) {
                      return DropdownMenuItem<String>(
                        value: r['id'],
                        child: Text(r['routeName'] ?? 'Route'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final r = routes.firstWhere((element) => element['id'] == val);
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
              const Text('Select Bus', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              busesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => const Text('Error loading buses', style: TextStyle(color: AppColors.error)),
                data: (buses) {
                  return DropdownButtonFormField<String>(
                    value: buses.any((b) => b['id'] == _targetId) ? _targetId : null,
                    decoration: _inputDecoration(),
                    items: buses.map((b) {
                      return DropdownMenuItem<String>(
                        value: b['id'],
                        child: Text(b['busNo'] ?? 'Bus'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final b = buses.firstWhere((element) => element['id'] == val);
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
              const Text('Select Student', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              studentsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => const Text('Error loading students', style: TextStyle(color: AppColors.error)),
                data: (students) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () => _openStudentPickerModal(students),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_targetName ?? 'Tap to pick student', style: TextStyle(color: _targetName != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8))),
                          const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],

            // Title
            const Text('Alert Title', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              decoration: _inputDecoration(hint: 'Enter alert title'),
            ),
            const SizedBox(height: 16),

            // Message
            const Text('Message Body', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
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
                    Text('Schedule Delivery', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text('Determine date/time of alert broadcast', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
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
                      label: Text(_scheduledDate == null ? 'Pick Date' : '${_scheduledDate!.day}/${_scheduledDate!.month}/${_scheduledDate!.year}'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.access_time_rounded, size: 16),
                      label: Text(_scheduledTime == null ? 'Pick Time' : _scheduledTime!.format(context)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                label: Text(
                  _isSaving
                      ? 'Saving...'
                      : (isEditMode ? 'Update Scheduled Broadcast' : (_isScheduled ? 'Schedule Broadcast' : 'Send Announcement Now')),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryCrimson,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryCrimson)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}



================================================
FILE: lib/features/admin/presentation/views/admin_overview_tab.dart
================================================
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/admin/data/repositories/admin_repository.dart';
import 'package:icem_bus/features/admin/domain/admin_providers.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_widgets.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/features/driver/domain/driver_providers.dart';
import 'package:icem_bus/config/routes/app_routes.dart';

/// Dashboard Overview Tab — Summary cards, quick actions, recent applications
class AdminOverviewTab extends ConsumerWidget {
  const AdminOverviewTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(dashboardSearchQueryProvider);
    final statusFilter = ref.watch(dashboardStatusFilterProvider);
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    final hour = DateTime.now().hour;
    final String greetingTime = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    final adminDisplayName = user?.fullName.isNotEmpty == true ? user!.fullName.split(' ').first : 'Admin';

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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primaryCrimson.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primaryCrimson.withOpacity(0.28)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, size: 14, color: AppColors.primaryCrimson),
                    SizedBox(width: 4),
                    Text(
                      'LIVE FLEET',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryCrimson,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // ── Mobility Statistics Section ──
          const AdminSectionHeader(title: 'Mobility Overview'),
          const SizedBox(height: 14),
          _buildStatCardsGrid(context, ref),
          const SizedBox(height: 28),

          // ── Quick Shortcuts (4 compact action tiles) ──
          const AdminSectionHeader(
            title: 'Quick Shortcuts',
            actionLabel: null,
          ),
          const SizedBox(height: 14),
          _buildQuickShortcuts(context, ref),
          const SizedBox(height: 28),

          // ── Recent Applications ──
          AdminSectionHeader(
            title: 'Recent Applications',
            actionLabel: 'View All',
            onAction: () {
              ref.read(adminTabProvider.notifier).state = 1;
            },
          ),
          const SizedBox(height: 14),

          // Search + Filter
          AdminSearchBar(
            hintText: 'Search by Name, PRN, or College ID...',
            value: searchQuery,
            onChanged: (q) =>
                ref.read(dashboardSearchQueryProvider.notifier).state = q,
          ),
          const SizedBox(height: 12),
          AdminFilterChips(
            filters: const ['All', 'Pending', 'Approved', 'Rejected', 'Expired'],
            selected: statusFilter,
            onSelected: (f) =>
                ref.read(dashboardStatusFilterProvider.notifier).state = f,
          ),
          const SizedBox(height: 16),

          // Recent application cards
          _buildRecentApplications(context, ref, searchQuery, statusFilter),
        ],
      ),
    );
  }

  // ── Stat Cards Grid (Responsive LayoutBuilder, No Overflows) ──
  Widget _buildStatCardsGrid(BuildContext context, WidgetRef ref) {
    final totalStudents = ref.watch(totalStudentsStreamProvider);
    final activePasses = ref.watch(activePassesStreamProvider);
    final pending = ref.watch(pendingAppsStreamProvider);
    final totalBuses = ref.watch(totalBusesStreamProvider);
    final expiredPasses = ref.watch(expiredPassesStreamProvider);
    final driversAsync = ref.watch(driversListStreamProvider);
    final paymentsAsync = ref.watch(paymentsListStreamProvider);

    // Compute Today's Revenue and Pending Payments from real Firestore streams
    double todayRevenue = 0.0;
    int pendingPaymentsCount = 0;
    final now = DateTime.now();

    final paymentsList = paymentsAsync.valueOrNull ?? [];
    for (final p in paymentsList) {
      final status = (p['status'] ?? p['paymentStatus'] ?? '').toString().toLowerCase();
      final isPaid = status == 'paid' || status == 'success';
      if (isPaid) {
        DateTime? dt;
        final val = p['createdAt'] ?? p['paymentDate'];
        if (val is Timestamp) dt = val.toDate();
        if (val is DateTime) dt = val;
        if (dt != null && dt.year == now.year && dt.month == now.month && dt.day == now.day) {
          final amt = p['amount'] is num
              ? (p['amount'] as num).toDouble()
              : (double.tryParse(p['amount']?.toString() ?? '') ?? 0.0);
          todayRevenue += amt;
        }
      } else if (status == 'pending' || status == 'created') {
        pendingPaymentsCount++;
      }
    }

    final todayRevFormatted = '₹${todayRevenue.toStringAsFixed(0)}';

    // Compute Active Drivers count
    final driversList = driversAsync.valueOrNull ?? [];
    final activeDriversCount = driversList.where((d) => (d['status'] ?? 'Active') == 'Active').length;

    final stats = <_StatData>[
      _StatData(
        'Total Students',
        totalStudents.when(data: (v) => v.toString(), loading: () => '...', error: (_, _) => '!'),
        Icons.people_alt_rounded,
        AppColors.info,
        totalStudents.isLoading,
        '+12 this month',
      ),
      _StatData(
        'Active Passes',
        activePasses.when(data: (v) => v.toString(), loading: () => '...', error: (_, _) => '!'),
        Icons.badge_rounded,
        AppColors.success,
        activePasses.isLoading,
        'Verified',
      ),
      _StatData(
        'Pending Apps',
        pending.when(data: (v) => v.toString(), loading: () => '...', error: (_, _) => '!'),
        Icons.pending_actions_rounded,
        AppColors.warning,
        pending.isLoading,
        'Action needed',
      ),
      _StatData(
        "Today's Revenue",
        paymentsAsync.isLoading ? '...' : todayRevFormatted,
        Icons.currency_rupee_rounded,
        AppColors.primaryCrimson,
        paymentsAsync.isLoading,
        'Live total',
      ),
      _StatData(
        'Total Buses',
        totalBuses.when(data: (v) => v.toString(), loading: () => '...', error: (_, _) => '!'),
        Icons.directions_bus_rounded,
        const Color(0xFF06B6D4),
        totalBuses.isLoading,
        'Campus fleet',
      ),
      _StatData(
        'Active Drivers',
        driversAsync.isLoading ? '...' : activeDriversCount.toString(),
        Icons.airline_seat_recline_normal_rounded,
        const Color(0xFF10B981),
        driversAsync.isLoading,
        'On duty',
      ),
      _StatData(
        'Pending Payments',
        paymentsAsync.isLoading ? '...' : pendingPaymentsCount.toString(),
        Icons.receipt_long_rounded,
        const Color(0xFFF97316),
        paymentsAsync.isLoading,
        'Unverified',
      ),
      _StatData(
        'Expired Passes',
        expiredPasses.when(data: (v) => v.toString(), loading: () => '...', error: (_, _) => '!'),
        Icons.history_toggle_off_rounded,
        const Color(0xFF8B5CF6),
        expiredPasses.isLoading,
        'Needs renewal',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 4
            : constraints.maxWidth > 600
                ? 3
                : 2;
        // mainAxisExtent generous height prevents bottom pixel overflow across all devices
        const double cardHeight = 134;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: cardHeight,
          ),
          itemCount: stats.length,
          itemBuilder: (context, i) => AdminStatCard(
            label: stats[i].label,
            value: stats[i].value,
            icon: stats[i].icon,
            color: stats[i].color,
            isLoading: stats[i].isLoading,
            subtitle: stats[i].subtitle,
          ),
        );
      },
    );
  }

  // ── Quick Shortcuts — 4 focused action tiles (navigation is in the drawer) ──
  Widget _buildQuickShortcuts(BuildContext context, WidgetRef ref) {
    final shortcuts = [
      _ActionItemData(
        'Students',
        'View & manage profiles',
        Icons.people_alt_rounded,
        AppColors.info,
        4,
      ),
      _ActionItemData(
        'Approve Passes',
        'Review pending apps',
        Icons.assignment_turned_in_rounded,
        AppColors.success,
        1,
      ),
      _ActionItemData(
        'Payments',
        'Revenue & Razorpay',
        Icons.receipt_long_rounded,
        const Color(0xFFF97316),
        5,
      ),
      _ActionItemData(
        'Notify Students',
        'Send campus alerts',
        Icons.send_rounded,
        const Color(0xFF8B5CF6),
        6,
      ),
    ];

    // Always 2 columns on mobile; 4 on desktop — fixed height avoids overflow
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
        const double cardHeight = 128;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: cardHeight,
          ),
          itemCount: shortcuts.length,
          itemBuilder: (context, i) {
            final a = shortcuts[i];
            return AdminActionCard(
              title: a.title,
              description: a.description,
              icon: a.icon,
              color: a.color,
              onTap: () {
                ref.read(adminTabProvider.notifier).state = a.tabIndex;
              },
            );
          },
        );
      },
    );
  }

  // ── Recent Applications List ──
  Widget _buildRecentApplications(
    BuildContext context,
    WidgetRef ref,
    String searchQuery,
    String statusFilter,
  ) {
    final recentApps = ref.watch(recentApplicationsStreamProvider);

    return recentApps.when(
      loading: () => const AdminLoadingState(),
      error: (e, _) => AdminErrorState(message: e.toString()),
      data: (applications) {
        var filtered = applications;

        if (searchQuery.isNotEmpty) {
          final q = searchQuery.toLowerCase();
          filtered = filtered.where((app) {
            final name =
                (app['studentName'] ?? app['fullName'] ?? '').toString().toLowerCase();
            final prn = (app['prn'] ?? '').toString().toLowerCase();
            final collegeId = (app['collegeId'] ?? '').toString().toLowerCase();
            return name.contains(q) || prn.contains(q) || collegeId.contains(q);
          }).toList();
        }

        if (statusFilter != 'All') {
          filtered =
              filtered.where((app) => app['status'] == statusFilter).toList();
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
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final app = filtered[i];
            return AdminApplicationCard(
              application: app,
              onApprove: () => _confirmApprove(context, ref, repo, app['id'], app['paymentStatus']),
              onReject: () => _showRejectDialog(context, ref, repo, app['id']),
              onViewDetails: () => context.push('/admin/application/${app['id']}'),
            );
          },
        );
      },
    );
  }

  void _confirmApprove(BuildContext context, WidgetRef ref, AdminRepository repo, String id, [dynamic paymentStatus]) {
    final pStatus = (paymentStatus ?? '').toString().trim().toLowerCase();
    if (pStatus.isNotEmpty && pStatus != 'paid' && pStatus != 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment required before approval. Student must complete verified payment first.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        title: const Text('Approve Pass Application', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Are you sure you want to approve this application and issue an active digital pass?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final adminUid = ref.read(authControllerProvider).user?.uid ?? 'admin';
              try {
                await repo.approveApplication(id, adminUid);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Application approved successfully!'), backgroundColor: AppColors.success),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Approval failed: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, WidgetRef ref, AdminRepository repo, String id) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        title: const Text('Reject Application', style: TextStyle(color: AppColors.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Specify reason for rejection:',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Invalid document or fee pending',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.elevatedSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderSubtle),
                  ),
                ),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              final adminUid = ref.read(authControllerProvider).user?.uid ?? 'admin';
              Navigator.pop(ctx);
              try {
                await repo.rejectApplication(id, reason.isNotEmpty ? reason : 'Rejected by administrator', adminUid);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Application rejected.'), backgroundColor: AppColors.error),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Rejection failed: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}

// ── Private Data Helper Classes ──
class _StatData {
  final String label;
  final String value;
  final dynamic icon;
  final Color color;
  final bool isLoading;
  final String? subtitle;

  _StatData(this.label, this.value, this.icon, this.color, this.isLoading, [this.subtitle]);
}

class _ActionItemData {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final int tabIndex;

  _ActionItemData(this.title, this.description, this.icon, this.color, this.tabIndex);
}



================================================
FILE: lib/features/admin/presentation/views/admin_payments_tab.dart
================================================
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/admin/domain/admin_providers.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_widgets.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/features/admin/data/repositories/admin_repository.dart';
import 'package:icem_bus/features/admin/presentation/views/report_exporter.dart';

/// Payment/receipt management tab
class AdminPaymentsTab extends ConsumerStatefulWidget {
  const AdminPaymentsTab({super.key});

  @override
  ConsumerState<AdminPaymentsTab> createState() => _AdminPaymentsTabState();
}

class _AdminPaymentsTabState extends ConsumerState<AdminPaymentsTab> {
  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paymentsAsync = ref.watch(paymentsListStreamProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Management',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Verify student transactions, record failures, execute refunds, and download receipts.',
                    style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── DASHBOARD SUMMARY PANEL ──
            paymentsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (err, _) => const SizedBox.shrink(),
              data: (payments) {
                // Calculate dynamic metrics
                final now = DateTime.now();
                final todayStart = DateTime(now.year, now.month, now.day);
                final monthStart = DateTime(now.year, now.month, 1);

                double totalRevenue = 0.0;
                double todayRevenue = 0.0;
                double monthlyRevenue = 0.0;
                int pendingCount = 0;
                int successCount = 0;

                for (final p in payments) {
                  final status = p['paymentStatus'] ?? 'Pending';
                  final isSuccess = status == 'Paid' || status == 'Success' || status == 'Successful';
                  final isPending = status == 'Pending' || status == 'Pending Verification' || status == 'Pending Payment';

                  final amountVal = p['amount'];
                  double amount = 0.0;
                  if (amountVal is num) {
                    amount = amountVal.toDouble();
                  } else if (amountVal is String) {
                    amount = double.tryParse(amountVal) ?? 0.0;
                  }

                  final dateField = p['createdAt'] ?? p['paymentDate'];
                  DateTime? dt;
                  if (dateField is Timestamp) {
                    dt = dateField.toDate();
                  } else if (dateField is String) {
                    dt = DateTime.tryParse(dateField);
                  }

                  if (isSuccess) {
                    successCount++;
                    totalRevenue += amount;
                    if (dt != null) {
                      if (dt.isAfter(todayStart) || dt.isAtSameMomentAs(todayStart)) {
                        todayRevenue += amount;
                      }
                      if (dt.isAfter(monthStart) || dt.isAtSameMomentAs(monthStart)) {
                        monthlyRevenue += amount;
                      }
                    }
                  } else if (isPending) {
                    pendingCount++;
                  }
                }

                return SizedBox(
                  height: 104,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _buildSummaryCard(
                        'Total Revenue',
                        '₹${totalRevenue.toStringAsFixed(0)}',
                        Colors.indigo,
                        Icons.account_balance_wallet_rounded,
                      ),
                      _buildSummaryCard(
                        "Today's Revenue",
                        '₹${todayRevenue.toStringAsFixed(0)}',
                        Colors.teal,
                        Icons.today_rounded,
                      ),
                      _buildSummaryCard(
                        'Monthly Revenue',
                        '₹${monthlyRevenue.toStringAsFixed(0)}',
                        Colors.purple,
                        Icons.calendar_month_rounded,
                      ),
                      _buildSummaryCard(
                        'Pending Verification',
                        pendingCount.toString(),
                        AppColors.warning,
                        Icons.pending_actions_rounded,
                      ),
                      _buildSummaryCard(
                        'Paid Pass Holders',
                        successCount.toString(),
                        AppColors.success,
                        Icons.verified_user_rounded,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // ── SEARCH AND FILTERS BAR ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    AdminSearchBar(
                      hintText: 'Search by name, PRN, or transaction ID...',
                      value: _searchQuery,
                      onChanged: (q) => setState(() => _searchQuery = q),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            'All',
                            'Pending',
                            'Processing',
                            'Paid',
                            'Failed',
                            'Manual Verification',
                            'Refunded',
                          ].map((filter) {
                            final isActive = filter == _statusFilter;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(filter),
                                selected: isActive,
                                onSelected: (_) => setState(() => _statusFilter = filter),
                                selectedColor: AppColors.primaryCrimson.withValues(alpha: 0.15),
                                checkmarkColor: AppColors.primaryCrimson,
                                labelStyle: TextStyle(
                                  color: isActive
                                      ? AppColors.primaryCrimson
                                      : theme.colorScheme.onSurfaceVariant,
                                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                                  fontSize: 12.5,
                                ),
                                backgroundColor: theme.colorScheme.surface,
                                side: BorderSide(
                                  color: isActive
                                      ? AppColors.primaryCrimson.withValues(alpha: 0.35)
                                      : theme.colorScheme.outlineVariant,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── PAYMENTS LIST ──
            Expanded(
              child: paymentsAsync.when(
                loading: () => const AdminLoadingState(),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        const Text(
                          'Failed to load payment history',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          e.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref.invalidate(paymentsListStreamProvider),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryCrimson),
                          child: const Text('Retry', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (payments) {
                  var filtered = payments;

                  // Status filter matching per Section 10
                  if (_statusFilter != 'All') {
                    filtered = filtered.where((p) {
                      final status = (p['paymentStatus'] ?? 'Pending').toString().toLowerCase();
                      if (_statusFilter == 'Pending') {
                        return status == 'pending' || status == 'created' || status == 'pending payment';
                      }
                      if (_statusFilter == 'Processing') {
                        return status == 'processing';
                      }
                      if (_statusFilter == 'Paid') {
                        return status == 'paid' || status == 'success' || status == 'successful';
                      }
                      if (_statusFilter == 'Failed') {
                        return status == 'failed' || status == 'cancelled';
                      }
                      if (_statusFilter == 'Manual Verification') {
                        return status == 'submitted_for_verification' || status == 'pending verification';
                      }
                      if (_statusFilter == 'Refunded') {
                        return status == 'refunded';
                      }
                      return status == _statusFilter.toLowerCase();
                    }).toList();
                  }

                  // Search query matching
                  if (_searchQuery.trim().isNotEmpty) {
                    final q = _searchQuery.trim().toLowerCase();
                    filtered = filtered.where((p) {
                      final name = (p['studentName'] ?? '').toString().toLowerCase();
                      final prn = (p['prn'] ?? '').toString().toLowerCase();
                      final txId = (p['transactionId'] ?? p['receiptId'] ?? p['id'] ?? '').toString().toLowerCase();
                      return name.contains(q) || prn.contains(q) || txId.contains(q);
                    }).toList();
                  }

                  if (filtered.isEmpty) {
                    return const AdminEmptyState(
                      title: 'No transactions found',
                      subtitle: 'Either there are no payments recorded or adjust your filters.',
                      icon: Icons.receipt_long_rounded,
                    );
                  }

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final payment = filtered[index];
                      return _PaymentListCard(
                        payment: payment,
                        onTap: () => _showPaymentDetails(context, payment),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color, IconData icon) {
    final theme = Theme.of(context);
    return Container(
      width: 155,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, color: color, size: 16),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentDetails(BuildContext context, Map<String, dynamic> payment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentDetailsModal(
        payment: payment,
        onVerify: (receiptId, studentUid) async {
          Navigator.pop(context);
          await _verifyManualPayment(receiptId, studentUid, payment['studentName'] ?? '', payment['amount']);
        },
        onFail: (receiptId, studentUid) async {
          Navigator.pop(context);
          await _failPayment(receiptId, studentUid);
        },
        onRefund: (receiptId, studentUid) async {
          Navigator.pop(context);
          await _refundPayment(receiptId, studentUid);
        },
        onDownloadReceipt: (p) async {
          await ReportExporter.exportReceipt(payment: p);
        },
      ),
    );
  }

  Future<void> _verifyManualPayment(String receiptId, String studentUid, String name, dynamic amount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Manual UPI Payment?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          'Confirm manual UPI payment of ₹$amount from $name?\n\n'
          'This will mark paymentStatus = PAID and move the application to Pending Admin Approval.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Verify Payment', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final adminUid = ref.read(authControllerProvider).user?.uid ?? 'Admin';
      try {
        await AdminRepository().verifyManualPayment(receiptId, studentUid, adminUid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Payment $receiptId approved successfully!'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verification failed: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Future<void> _failPayment(String receiptId, String studentUid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Payment as Failed?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text(
          'Mark this transaction as Failed? This will reject the associated bus pass application.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark Failed', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AdminRepository().markPaymentFailed(receiptId, studentUid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaction status set to Failed.'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Future<void> _refundPayment(String receiptId, String studentUid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Refund Transaction?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text(
          'Mark this transaction as Refunded? This will deactivate the student\'s digital bus pass.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Refund Status', style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AdminRepository().refundPayment(receiptId, studentUid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaction status updated to Refunded.'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to refund: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }
}

// ============================================================
// PAYMENT LIST CARD
// ============================================================

class _PaymentListCard extends StatelessWidget {
  final Map<String, dynamic> payment;
  final VoidCallback onTap;

  const _PaymentListCard({
    required this.payment,
    required this.onTap,
  });

  String _formatDate(dynamic dateField) {
    if (dateField == null) return 'N/A';
    DateTime? dt;
    if (dateField is Timestamp) {
      dt = dateField.toDate();
    } else if (dateField is String) {
      dt = DateTime.tryParse(dateField);
    }
    if (dt == null) return 'N/A';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final name = payment['studentName'] ?? 'Unknown';
    final appId = payment['applicationId'] ?? payment['passId'] ?? payment['id'] ?? 'N/A';
    final amount = payment['amount'] ?? 0;
    final status = (payment['paymentStatus'] ?? 'Pending').toString();
    final statusLower = status.toLowerCase();
    final createdAt = payment['createdAt'] ?? payment['paymentDate'];
    final paidAt = payment['paidAt'] ?? payment['verifiedAt'];
    final prn = payment['prn'] ?? '';
    final route = payment['routeName'] ?? payment['route'] ?? 'N/A';
    final method = (payment['paymentMethod'] ?? 'Online').toString();
    final orderId = (payment['razorpayOrderId'] ?? payment['utrNumber'] ?? '').toString();
    final paymentId = (payment['razorpayPaymentId'] ?? payment['transactionId'] ?? '').toString();

    final isPaid = statusLower == 'paid' || statusLower == 'success' || statusLower == 'successful';
    final isManualUpi = method.toLowerCase().contains('upi') ||
        statusLower == 'submitted_for_verification' ||
        statusLower == 'pending verification';

    String displayStatus;
    Color statusColor;
    IconData statusIcon;

    if (isPaid) {
      displayStatus = '✓ Payment Verified';
      statusColor = AppColors.success;
      statusIcon = Icons.check_circle_rounded;
    } else if (isManualUpi) {
      displayStatus = 'Pending Verification';
      statusColor = AppColors.warning;
      statusIcon = Icons.pending_actions_rounded;
    } else if (statusLower == 'processing') {
      displayStatus = 'Processing';
      statusColor = Colors.blue;
      statusIcon = Icons.hourglass_top_rounded;
    } else if (statusLower == 'failed' || statusLower == 'cancelled') {
      displayStatus = 'Failed';
      statusColor = AppColors.error;
      statusIcon = Icons.cancel_rounded;
    } else if (statusLower == 'refunded') {
      displayStatus = 'Refunded';
      statusColor = Colors.grey;
      statusIcon = Icons.history_rounded;
    } else {
      displayStatus = 'Pending Payment';
      statusColor = AppColors.warning;
      statusIcon = Icons.pending_actions_rounded;
    }

    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── HEADER ROW: Student / Payment Information + Status Badge ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon container
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF6366F1), size: 20),
                    ),
                    const SizedBox(width: 12),
                    // Student details (Takes remaining width)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            prn.isNotEmpty ? 'PRN: $prn • App: $appId' : 'App: $appId',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status Badge (constrained)
                    Flexible(
                      flex: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, color: statusColor, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              displayStatus,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: theme.dividerColor),
                const SizedBox(height: 10),

                // ── SEPARATE RESPONSIVE SECTION (WRAP) ──
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Amount Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryCrimson.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '₹${amount is num ? amount.toStringAsFixed(0) : amount}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppColors.primaryCrimson,
                        ),
                      ),
                    ),

                    // Payment Method Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.payment_rounded, size: 11, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            method,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Date Tag
                    if (createdAt != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 10.5, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(createdAt),
                              style: TextStyle(
                                fontSize: 10.5,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Route Tag
                    if (route != 'N/A' && route.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.directions_bus_rounded, size: 11, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 150),
                              child: Text(
                                route,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                // ── IDENTIFIERS SECTION (ORDER/UTR, PAYMENT ID, PAID TIME) ──
                if (orderId.isNotEmpty || paymentId.isNotEmpty || paidAt != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (orderId.isNotEmpty)
                        Text(
                          'Order/UTR: $orderId',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      if (paymentId.isNotEmpty)
                        Text(
                          'Payment ID: $paymentId',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      if (paidAt != null)
                        Text(
                          'Verified: ${_formatDate(paidAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// DETAILS MODAL SHEET
// ============================================================

class _PaymentDetailsModal extends StatelessWidget {
  final Map<String, dynamic> payment;
  final Function(String receiptId, String studentUid) onVerify;
  final Function(String receiptId, String studentUid) onFail;
  final Function(String receiptId, String studentUid) onRefund;
  final ValueChanged<Map<String, dynamic>> onDownloadReceipt;

  const _PaymentDetailsModal({
    required this.payment,
    required this.onVerify,
    required this.onFail,
    required this.onRefund,
    required this.onDownloadReceipt,
  });

  String _formatDate(dynamic dateField) {
    if (dateField == null) return 'N/A';
    DateTime? dt;
    if (dateField is Timestamp) {
      dt = dateField.toDate();
    } else if (dateField is String) {
      dt = DateTime.tryParse(dateField);
    }
    if (dt == null) return 'N/A';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final receiptId = payment['receiptId'] ?? payment['paymentId'] ?? payment['id'] ?? 'N/A';
    final studentUid = payment['studentId'] ?? payment['uid'] ?? '';
    final applicationId = payment['applicationId'] ?? payment['passId'] ?? payment['id'] ?? 'N/A';
    final name = payment['studentName'] ?? 'Unknown';
    final prn = payment['prn'] ?? 'N/A';
    final course = payment['course'] ?? 'N/A';
    final amount = payment['amount'] ?? 0;
    final status = (payment['paymentStatus'] ?? 'Pending').toString();
    final statusLower = status.toLowerCase();
    final method = (payment['paymentMethod'] ?? 'Online Payment').toString();
    final razorpayOrderId = payment['razorpayOrderId'] ?? 'N/A';
    final razorpayPaymentId = payment['razorpayPaymentId'] ?? payment['transactionId'] ?? 'N/A';
    final utrNumber = payment['utrNumber'] ?? 'N/A';
    final dateField = payment['createdAt'] ?? payment['paymentDate'];
    final paidAt = payment['paidAt'] ?? payment['verifiedAt'];
    final routeName = payment['routeName'] ?? payment['route'] ?? 'N/A';
    final boarding = payment['boardingStop'] ?? payment['boarding'] ?? 'N/A';
    final destination = payment['destinationStop'] ?? payment['destination'] ?? 'N/A';

    final isSuccess = statusLower == 'paid' || statusLower == 'success' || statusLower == 'successful';
    final isManualUpi = method.toLowerCase().contains('upi') ||
        statusLower == 'submitted_for_verification' ||
        statusLower == 'pending verification';
    final isPending = statusLower == 'pending' ||
        statusLower == 'pending verification' ||
        statusLower == 'submitted_for_verification' ||
        statusLower == 'pending payment' ||
        statusLower == 'created' ||
        statusLower == 'processing';

    final theme = Theme.of(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
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
              Expanded(
                child: Text(
                  'Transaction Details',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '₹${amount is num ? amount.toStringAsFixed(0) : amount}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 20),

          // Student Details Block
          const Text('Student Information', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
          const SizedBox(height: 6),
          _buildInfoRow('Name', name),
          _buildInfoRow('Application ID', applicationId),
          if (prn != 'N/A') _buildInfoRow('PRN', prn),
          if (course != 'N/A') _buildInfoRow('Course', course),
          const SizedBox(height: 16),

          // Payment Details Block
          const Text('Payment Information', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
          const SizedBox(height: 6),
          _buildInfoRow(
            'Status',
            isSuccess ? '✓ Payment Verified' : (isManualUpi && isPending ? 'Pending Verification' : status),
            isBold: true,
            valueColor: isSuccess ? AppColors.success : (isPending ? AppColors.warning : AppColors.error),
          ),
          _buildInfoRow('Method', method),
          _buildInfoRow('Receipt / Record ID', receiptId),
          if (razorpayOrderId != 'N/A') _buildInfoRow('Razorpay Order ID', razorpayOrderId),
          if (razorpayPaymentId != 'N/A') _buildInfoRow('Razorpay Payment ID', razorpayPaymentId),
          if (utrNumber != 'N/A') _buildInfoRow('UPI UTR Number', utrNumber),
          _buildInfoRow('Created Time', _formatDate(dateField)),
          if (paidAt != null) _buildInfoRow('Paid Time', _formatDate(paidAt)),
          const SizedBox(height: 16),

          // Route Details Block
          const Text('Pass & Route Details', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
          const SizedBox(height: 6),
          _buildInfoRow('Route', routeName),
          if (boarding != 'N/A') _buildInfoRow('Boarding Stop', boarding),
          if (destination != 'N/A') _buildInfoRow('Destination', destination),
          const SizedBox(height: 28),

          // Action Controls
          Column(
            children: [
              if (isPending) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => onFail(receiptId, studentUid),
                        icon: const Icon(Icons.cancel_rounded, size: 18),
                        label: const Text('Mark Failed'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    if (isManualUpi) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => onVerify(receiptId, studentUid),
                          icon: const Icon(Icons.verified_rounded, size: 18, color: Colors.white),
                          label: const Text('Verify Payment', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (!isManualUpi)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                    child: Text(
                      'Online payments are verified automatically by the Razorpay backend service.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 12),
              ] else if (isSuccess) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => onRefund(receiptId, studentUid),
                        icon: const Icon(Icons.history_rounded, size: 18),
                        label: const Text('Refund Payment'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange.shade800,
                          side: BorderSide(color: Colors.orange.shade800),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Always visible Receipt PDF download
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => onDownloadReceipt(payment),
                  icon: const Icon(Icons.download_rounded, size: 18, color: Colors.white),
                  label: const Text('Download PDF Receipt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: valueColor ?? const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}



================================================
FILE: lib/features/admin/presentation/views/admin_settings_screen.dart
================================================
import 'package:flutter/material.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_settings_tab.dart';

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/bus_logo.png',
              width: 24,
              height: 24,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            Text(
              'Settings',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: theme.dividerColor,
          ),
        ),
      ),
      body: const SafeArea(
        top: false,
        child: AdminSettingsTab(),
      ),
    );
  }
}



================================================
FILE: lib/features/admin/presentation/views/admin_students_tab.dart
================================================
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/admin/domain/admin_providers.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_widgets.dart';
import 'package:icem_bus/features/admin/data/repositories/admin_repository.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:qr_flutter/qr_flutter.dart';

// ============================================================
// STUDENT PASS PROVIDER
// ============================================================

final studentPassStreamProvider = StreamProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, uid) {
  return FirebaseFirestore.instance
      .collection('bus_passes')
      .doc(uid)
      .snapshots()
      .map((snap) {
    if (!snap.exists) return null;
    final data = snap.data();
    if (data != null) data['id'] = snap.id;
    return data;
  });
});

// ============================================================
// ADMIN STUDENTS TAB
// ============================================================

class AdminStudentsTab extends ConsumerStatefulWidget {
  const AdminStudentsTab({super.key});

  @override
  ConsumerState<AdminStudentsTab> createState() => _AdminStudentsTabState();
}

class _AdminStudentsTabState extends ConsumerState<AdminStudentsTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsListStreamProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: AdminSearchBar(
              hintText: 'Search by Name, PRN, or Email...',
              value: _searchQuery,
              onChanged: (q) => setState(() => _searchQuery = q),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: studentsAsync.when(
              loading: () => const AdminLoadingState(),
              error: (e, _) => AdminErrorState(message: e.toString()),
              data: (students) {
                var filtered = students;

                // Client-side search filtering
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  filtered = filtered.where((s) {
                    final name = (s['fullName'] ?? '').toString().toLowerCase();
                    final prn = (s['prn'] ?? '').toString().toLowerCase();
                    final email = (s['email'] ?? '').toString().toLowerCase();
                    return name.contains(q) || prn.contains(q) || email.contains(q);
                  }).toList();
                }

                if (filtered.isEmpty) {
                  return const AdminEmptyState(
                    title: 'No students found',
                    subtitle: 'Try adjusting your search criteria.',
                    icon: Icons.people_alt_rounded,
                  );
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final student = filtered[i];
                    return _StudentCard(
                      student: student,
                      onTap: () => _showStudentDetails(context, student),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showStudentDetails(BuildContext context, Map<String, dynamic> student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StudentDetailsSheet(student: student),
    );
  }
}

// ============================================================
// STUDENT CARD WIDGET
// ============================================================

class _StudentCard extends ConsumerWidget {
  final Map<String, dynamic> student;
  final VoidCallback onTap;

  const _StudentCard({
    required this.student,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final name = student['fullName'] ?? 'Unknown';
    final email = student['email'] ?? 'N/A';
    final prn = student['prn'] ?? 'N/A';
    final course = student['course'] ?? 'N/A';
    final phone = student['mobile'] ?? student['phone'] ?? 'N/A';
    final isActive = student['isActive'] ?? true;
    final photoUrl = student['photoUrl'] as String?;

    final passAsync = ref.watch(studentPassStreamProvider(student['id']));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Photo / Avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primaryCrimson.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    image: photoUrl != null && photoUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(photoUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: photoUrl == null || photoUrl.isEmpty
                      ? Center(
                          child: Text(
                            name.toString().isNotEmpty
                                ? name.toString()[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: AppColors.primaryCrimson,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),

                // Details Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name and Status Icon
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              name.toString(),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (isActive ? AppColors.success : AppColors.error).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isActive ? 'Active' : 'Suspended',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isActive ? AppColors.success : AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Academic Details
                      Row(
                        children: [
                          Text(
                            course.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('•', style: TextStyle(color: Color(0xFF94A3B8))),
                          const SizedBox(width: 6),
                          Text(
                            'PRN: $prn',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Email and Phone
                      Row(
                        children: [
                          const Icon(Icons.email_outlined, size: 13, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              email.toString(),
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.phone_android_rounded, size: 13, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 5),
                          Text(
                            phone.toString(),
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(height: 1, color: theme.dividerColor),
                      const SizedBox(height: 10),

                      // Pass and Route details (Watched asynchronously)
                      passAsync.when(
                        loading: () => const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryCrimson),
                        ),
                        error: (e, _) => const Text('Error loading pass details', style: TextStyle(fontSize: 11, color: AppColors.error)),
                        data: (pass) {
                          final passStatus = pass?['passStatus'] ?? 'No Pass';
                          final routeName = pass?['route'] ?? 'N/A';

                          Color statusColor = const Color(0xFF94A3B8); // grey for No Pass
                          if (passStatus == 'Active' || passStatus == 'Approved') statusColor = AppColors.success;
                          if (passStatus == 'Rejected') statusColor = AppColors.error;
                          if (passStatus == 'Pending' || passStatus == 'Pending Payment' || passStatus == 'Pending Verification') statusColor = AppColors.warning;

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Route Info
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(Icons.route_rounded, size: 14, color: AppColors.primaryCrimson),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        routeName.toString(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Pass Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: statusColor.withOpacity(0.12)),
                                ),
                                child: Text(
                                  passStatus.toString(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
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
// STUDENT DETAILS SHEET
// ============================================================

class _StudentDetailsSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> student;

  const _StudentDetailsSheet({required this.student});

  @override
  ConsumerState<_StudentDetailsSheet> createState() => _StudentDetailsSheetState();
}

class _StudentDetailsSheetState extends ConsumerState<_StudentDetailsSheet> {
  bool _isPerformingAction = false;

  @override
  Widget build(BuildContext context) {
    final studentId = widget.student['id'];
    final passAsync = ref.watch(studentPassStreamProvider(studentId));
    final adminUid = ref.watch(authControllerProvider).user?.uid ?? '';

    // Watch real-time changes to the user document itself to display active/inactive live
    final userSnap = FirebaseFirestore.instance.collection('users').doc(studentId).snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userSnap,
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() ?? widget.student;
        final name = userData['fullName'] ?? 'Unknown';
        final email = userData['email'] ?? 'N/A';
        final prn = userData['prn'] ?? 'N/A';
        final collegeId = userData['collegeId'] ?? 'N/A';
        final course = userData['course'] ?? 'N/A';
        final phone = userData['mobile'] ?? userData['phone'] ?? 'N/A';
        final role = userData['role'] ?? 'N/A';
        final isActive = userData['isActive'] ?? true;
        final photoUrl = userData['photoUrl'] as String?;
        final registrationDate = userData['createdAt'];

        return DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.6,
          maxChildSize: 0.97,
          builder: (context, scrollController) {
            final theme = Theme.of(context);
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.primaryCrimson.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(14),
                                image: photoUrl != null && photoUrl.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(photoUrl),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: photoUrl == null || photoUrl.isEmpty
                                  ? const Icon(Icons.person_rounded, color: AppColors.primaryCrimson, size: 24)
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name.toString(),
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    role.toString(),
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            if (_isPerformingAction)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryCrimson),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                      ],
                    ),
                  ),

                  // Detail Fields
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(24),
                      children: [
                        // Section: Personal Details
                        _SectionHeader(title: 'Personal Details', icon: Icons.person_outline_rounded),
                        const SizedBox(height: 12),
                        _buildDetailRow('PRN / Roll Number', prn.toString()),
                        _buildDetailRow('College / Faculty ID', collegeId.toString()),
                        _buildDetailRow('Course / Program', course.toString()),
                        _buildDetailRow('Email Address', email.toString()),
                        _buildDetailRow('Mobile Number', phone.toString()),
                        _buildDetailRow('Account Status', isActive ? 'Active / Authorized' : 'Suspended / Unauthorized',
                            color: isActive ? AppColors.success : AppColors.error),
                        _buildDetailRow('Registration Date', _formatDate(registrationDate)),
                        const SizedBox(height: 24),

                        // Section: Route & Pass Details (Watched asynchronously)
                        passAsync.when(
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: CircularProgressIndicator(color: AppColors.primaryCrimson),
                            ),
                          ),
                          error: (err, _) => Text('Error: $err', style: const TextStyle(color: AppColors.error)),
                          data: (pass) {
                            final routeName = pass?['route'] ?? 'N/A';
                            final boarding = pass?['boardingStop'] ?? 'N/A';
                            final destination = pass?['destinationStop'] ?? 'N/A';
                            final fareValue = pass?['fare'] ?? 'N/A';
                            final paymentStatus = pass?['paymentStatus'] ?? 'No Pass';
                            final passStatus = pass?['passStatus'] ?? 'No Pass';
                            final bool isPassPaid = paymentStatus.toString().toLowerCase() == 'paid';

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionHeader(title: 'Route Details', icon: Icons.route_rounded),
                                const SizedBox(height: 12),
                                _buildDetailRow('Assigned Route', routeName.toString()),
                                _buildDetailRow('Boarding Point', boarding.toString()),
                                _buildDetailRow('Destination Point', destination.toString()),
                                _buildDetailRow('Pass Fare Cost', fareValue != 'N/A' ? '₹$fareValue' : 'N/A'),
                                const SizedBox(height: 24),

                                _SectionHeader(title: 'Status Indicators', icon: Icons.playlist_add_check_rounded),
                                const SizedBox(height: 12),
                                _buildDetailRow('Payment State', paymentStatus.toString(),
                                    color: paymentStatus == 'Paid'
                                        ? AppColors.success
                                        : (paymentStatus == 'No Pass' ? const Color(0xFF94A3B8) : AppColors.warning)),
                                _buildDetailRow('Bus Pass State', passStatus.toString(),
                                    color: (passStatus == 'Active' || passStatus == 'Approved')
                                        ? AppColors.success
                                        : (passStatus == 'No Pass' ? const Color(0xFF94A3B8) : AppColors.warning)),
                                if (pass?['qrCode'] != null && pass!['qrCode'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Center(
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: Colors.grey.shade200),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.05),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              )
                                            ]
                                          ),
                                          child: QrImageView(
                                            data: pass['qrCode'].toString(),
                                            version: QrVersions.auto,
                                            size: 140,
                                            gapless: false,
                                            eyeStyle: const QrEyeStyle(
                                              eyeShape: QrEyeShape.square,
                                              color: AppColors.primaryCrimson,
                                            ),
                                            dataModuleStyle: const QrDataModuleStyle(
                                              dataModuleShape: QrDataModuleShape.square,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'STUDENT DIGITAL QR CODE',
                                          style: TextStyle(
                                            color: AppColors.primaryCrimson,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 24),

                                // Actions Section based on Pass Status
                                if (pass != null) ...[
                                  _SectionHeader(title: 'Administrative Controls', icon: Icons.security_rounded),
                                  const SizedBox(height: 14),
                                  if (!isPassPaid && passStatus != 'Active' && passStatus != 'Approved') ...[
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: AppColors.error.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.error.withOpacity(0.2)),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.lock_rounded, size: 16, color: AppColors.error),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Payment required before approval. Student has not completed verified payment.',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.error),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  Row(
                                    children: [
                                      if (passStatus != 'Active' && passStatus != 'Approved')
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: _isPerformingAction
                                                ? null
                                                : (isPassPaid
                                                    ? () => _approvePass(studentId, adminUid)
                                                    : () {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(
                                                            content: Text('Payment required before approval. Student must complete verified payment first.'),
                                                            backgroundColor: AppColors.error,
                                                          ),
                                                        );
                                                      }),
                                            icon: Icon(isPassPaid ? Icons.check_circle_rounded : Icons.lock_outline_rounded, size: 16),
                                            label: Text(isPassPaid ? 'Approve Pass' : 'Payment Required'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isPassPaid ? AppColors.success : Colors.grey.shade400,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                          ),
                                        ),
                                      if (passStatus != 'Active' && passStatus != 'Approved' && passStatus != 'Rejected')
                                        const SizedBox(width: 12),
                                      if (passStatus != 'Rejected' && passStatus != 'Active' && passStatus != 'Approved')
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: _isPerformingAction
                                                ? null
                                                : () => _rejectPass(studentId),
                                            icon: const Icon(Icons.cancel_rounded, size: 16),
                                            label: const Text('Reject Pass'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppColors.error,
                                              side: const BorderSide(color: AppColors.error),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                          ),
                                        ),
                                      if (passStatus == 'Active' || passStatus == 'Approved')
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: _isPerformingAction
                                                ? null
                                                : () => _revokePass(studentId),
                                            icon: const Icon(Icons.block_rounded, size: 16),
                                            label: const Text('Revoke Pass'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppColors.error,
                                              side: const BorderSide(color: AppColors.error),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                ],
                              ],
                            );
                          },
                        ),

                        // General account actions (Suspend/Activate, Delete)
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isPerformingAction
                                    ? null
                                    : () => _toggleStudentStatus(studentId, isActive),
                                icon: Icon(isActive ? Icons.lock_rounded : Icons.lock_open_rounded, size: 16),
                                label: Text(isActive ? 'Suspend User' : 'Activate User'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isActive ? AppColors.warning : AppColors.success,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isPerformingAction
                                    ? null
                                    : () => _confirmDeleteStudent(context, studentId, name.toString()),
                                icon: const Icon(Icons.delete_rounded, size: 16),
                                label: const Text('Delete Student'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: color ?? const Color(0xFF334155),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Action Handlers ──

  Future<void> _approvePass(String uid, String adminUid) async {
    setState(() => _isPerformingAction = true);
    try {
      await AdminRepository().approveStudentPass(uid, adminUid);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bus pass approved successfully'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isPerformingAction = false);
    }
  }

  Future<void> _rejectPass(String uid) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Bus Pass'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejecting this student\'s bus pass application:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Enter rejection reason...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Rejection reason is required')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Confirm Reject', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isPerformingAction = true);
      try {
        await AdminRepository().rejectStudentPass(uid, reasonController.text.trim());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bus pass application rejected'), backgroundColor: AppColors.success),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      } finally {
        if (mounted) setState(() => _isPerformingAction = false);
      }
    }
  }

  Future<void> _revokePass(String uid) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Revoke Active Pass'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to revoke this student\'s bus pass? They will no longer be authorized to board buses:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Enter revocation reason...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Revocation reason is required')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Confirm Revoke', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isPerformingAction = true);
      try {
        final adminUid = ref.read(authControllerProvider).user?.uid ?? '';
        await AdminRepository().revokePass(uid, reasonController.text.trim(), adminUid);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bus pass revoked successfully'), backgroundColor: AppColors.error),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      } finally {
        if (mounted) setState(() => _isPerformingAction = false);
      }
    }
  }

  Future<void> _toggleStudentStatus(String uid, bool currentActive) async {
    setState(() => _isPerformingAction = true);
    try {
      if (currentActive) {
        await AdminRepository().suspendStudent(uid);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student account suspended'), backgroundColor: AppColors.success),
        );
      } else {
        await AdminRepository().activateStudent(uid);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student account activated'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isPerformingAction = false);
    }
  }

  Future<void> _confirmDeleteStudent(BuildContext context, String uid, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.delete_forever_rounded, color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Delete Student'),
          ],
        ),
        content: Text('Are you sure you want to permanently delete "$name" and all associated bus passes/applications? This action is irreversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Student', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isPerformingAction = true);
      try {
        await AdminRepository().deleteStudent(uid);
        Navigator.pop(context); // close sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student account permanently deleted'), backgroundColor: AppColors.success),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      } finally {
        if (mounted) setState(() => _isPerformingAction = false);
      }
    }
  }
}

// ============================================================
// FORMAT DATE HELPER
// ============================================================

String _formatDate(dynamic value) {
  if (value == null) return 'N/A';
  DateTime? date;
  if (value is Timestamp) {
    date = value.toDate();
  } else if (value is DateTime) {
    date = value;
  }
  if (date == null) return 'N/A';
  final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final day = date.day.toString().padLeft(2, '0');
  final month = months[date.month - 1];
  final year = date.year;
  
  int hour = date.hour;
  final period = hour >= 12 ? 'PM' : 'AM';
  if (hour > 12) hour -= 12;
  if (hour == 0) hour = 12;
  final minute = date.minute.toString().padLeft(2, '0');
  
  return "$day $month $year, $hour:$minute $period";
}

// ============================================================
// SECTION HEADER HELPER
// ============================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF475569),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}



================================================
FILE: lib/features/admin/presentation/views/admin_widgets.dart
================================================
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:icem_bus/config/theme/app_colors.dart';

// ============================================================
// STAT CARD — Dark Mobility Metric Card
// ============================================================

class AdminStatCard extends StatelessWidget {
  final String label;
  final String value;
  final dynamic icon;
  final Color color;
  final bool isLoading;
  final String? subtitle;

  const AdminStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isLoading = false,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.25), width: 1),
                ),
                child: Center(
                  child: icon is Widget
                      ? (icon as Widget)
                      : Icon(icon as IconData, color: color, size: 18),
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Flexible(
                  child: Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.elevatedSurface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (isLoading)
            const _ShimmerBox(width: 48, height: 24, borderRadius: 6)
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
              ),
            ),
          const SizedBox(height: 3),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.7,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ACTION CARD — Premium layered action card with description & arrow
// ============================================================

class AdminActionCard extends StatefulWidget {
  final String title;
  final String description;
  final dynamic icon;
  final Color color;
  final VoidCallback onTap;

  const AdminActionCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<AdminActionCard> createState() => _AdminActionCardState();
}

class _AdminActionCardState extends State<AdminActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _pressed ? widget.color.withOpacity(0.5) : AppColors.borderSubtle,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: widget.color.withOpacity(0.25), width: 1),
                    ),
                    child: Center(
                      child: widget.icon is Widget
                          ? (widget.icon as Widget)
                          : Icon(widget.icon as IconData, color: widget.color, size: 20),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: AppColors.textMuted.withOpacity(0.5),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                widget.description,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Quick action alias for compatibility
class AdminQuickAction extends StatelessWidget {
  final String label;
  final dynamic icon;
  final Color color;
  final VoidCallback onTap;

  const AdminQuickAction({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AdminActionCard(
      title: label.replaceAll('\n', ' '),
      description: 'Manage & update',
      icon: icon,
      color: color,
      onTap: onTap,
    );
  }
}

// ============================================================
// STATUS BADGE — Unified dark status badge
// ============================================================

class AdminStatusBadge extends StatelessWidget {
  final String status;

  const AdminStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String label = status.toUpperCase();

    final s = status.trim().toUpperCase();

    if (s == 'ACTIVE' || s == 'APPROVED' || s == 'PAID' || s == 'PAYMENT VERIFIED' || s == 'SUCCESS') {
      color = AppColors.success;
      icon = Icons.check_circle_rounded;
      if (s == 'PAID' || s == 'PAYMENT VERIFIED' || s == 'SUCCESS') {
        label = 'PAID';
      } else if (s == 'APPROVED') {
        label = 'APPROVED';
      } else {
        label = 'ACTIVE';
      }
    } else if (s == 'REJECTED' || s == 'FAILED' || s == 'REVOKED' || s == 'INACTIVE' || s == 'SUSPENDED') {
      color = AppColors.error;
      icon = Icons.cancel_rounded;
      if (s == 'REJECTED') {
        label = 'REJECTED';
      } else if (s == 'REVOKED') {
        label = 'REVOKED';
      } else if (s == 'FAILED') {
        label = 'FAILED';
      } else {
        label = 'INACTIVE';
      }
    } else if (s == 'MAINTENANCE') {
      color = const Color(0xFFA855F7); // Purple
      icon = Icons.build_circle_rounded;
      label = 'MAINTENANCE';
    } else if (s == 'EXPIRED') {
      color = const Color(0xFF94A3B8); // Slate
      icon = Icons.history_toggle_off_rounded;
      label = 'EXPIRED';
    } else if (s == 'REFUNDED') {
      color = const Color(0xFF06B6D4); // Cyan
      icon = Icons.replay_rounded;
      label = 'REFUNDED';
    } else {
      // Pending variants
      color = AppColors.warning;
      icon = Icons.schedule_rounded;
      if (s == 'PAYMENT PENDING' || s == 'PENDING PAYMENT') {
        label = 'PAYMENT PENDING';
      } else if (s == 'PENDING APPROVAL') {
        label = 'PENDING APPROVAL';
      } else {
        label = 'PENDING';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}


// ============================================================
// APPLICATION CARD — Used in Recent Applications & Applications Tab
// ============================================================

class AdminApplicationCard extends StatelessWidget {
  final Map<String, dynamic> application;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onRequestCorrection;
  final VoidCallback? onViewDetails;

  const AdminApplicationCard({
    super.key,
    required this.application,
    this.onApprove,
    this.onReject,
    this.onRequestCorrection,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final name = application['studentName'] ?? application['fullName'] ?? 'Unknown';
    final prn = application['prn'] ?? '-';
    final collegeId = application['collegeId'] ?? '-';
    final course = application['course'] ?? '-';
    final route = application['routeName'] ?? application['route'] ?? '-';
    final boardingStop = application['boardingStop'] ?? '-';
    final destinationStop = application['destinationStop'] ?? '-';
    final fare = application['fare'];
    final photoUrl = application['photoUrl'] as String?;
    final createdAt = application['createdAt'];

    final String paymentStatusStr = (application['paymentStatus'] as String? ?? 'Pending').trim();
    final bool isPaid = paymentStatusStr.toLowerCase() == 'paid' || paymentStatusStr.toLowerCase() == 'success';
    final String rawStatus = (application['passStatus'] ?? application['status'] ?? 'Pending').toString();

    // Normalized display statuses
    String displayStatus;
    if (rawStatus == 'Approved' || rawStatus == 'Active') {
      displayStatus = 'Approved';
    } else if (rawStatus == 'Rejected') {
      displayStatus = 'Rejected';
    } else if (isPaid) {
      displayStatus = 'Pending Approval';
    } else {
      displayStatus = 'Pending Payment';
    }

    String dateStr = '-';
    if (createdAt != null) {
      DateTime? dt;
      if (createdAt is Timestamp) {
        dt = createdAt.toDate();
      } else if (createdAt is DateTime) {
        dt = createdAt;
      }
      if (dt != null) {
        dateStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      }
    }

    String fareStr = '-';
    if (fare != null) {
      fareStr = '₹${(fare is num) ? fare.toStringAsFixed(0) : fare.toString()}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderSubtle, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: Student avatar + name + status badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(photoUrl, name.toString()),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'PRN: $prn • ID: $collegeId',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AdminStatusBadge(status: displayStatus),
            ],
          ),
          const SizedBox(height: 14),

          // Payment Status Banner Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isPaid
                  ? AppColors.success.withOpacity(0.12)
                  : AppColors.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isPaid
                    ? AppColors.success.withOpacity(0.28)
                    : AppColors.warning.withOpacity(0.28),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPaid ? Icons.verified_rounded : Icons.pending_actions_rounded,
                  size: 14,
                  color: isPaid ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: 6),
                Text(
                  isPaid ? 'PAYMENT VERIFIED' : 'PAYMENT PENDING',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isPaid ? AppColors.success : AppColors.warning,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Info Chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _InfoChip(icon: Icons.school_rounded, label: course.toString()),
              _InfoChip(icon: Icons.route_rounded, label: route.toString()),
              _InfoChip(
                icon: Icons.location_on_rounded,
                label: '$boardingStop → $destinationStop',
              ),
              _InfoChip(
                icon: Icons.currency_rupee_rounded,
                label: fareStr,
              ),
              _InfoChip(
                icon: Icons.calendar_today_rounded,
                label: dateStr,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'View Details',
                  color: AppColors.info,
                  icon: Icons.visibility_rounded,
                  onTap: onViewDetails,
                ),
              ),
              if (displayStatus != 'Approved' && displayStatus != 'Rejected') ...[
                if (isPaid) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      label: 'Approve',
                      color: AppColors.success,
                      icon: Icons.check_circle_rounded,
                      onTap: onApprove,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    label: 'Reject',
                    color: AppColors.error,
                    icon: Icons.cancel_rounded,
                    onTap: onReject,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? photoUrl, String name) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          photoUrl,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildInitialAvatar(name),
        ),
      );
    }
    return _buildInitialAvatar(name);
  }

  Widget _buildInitialAvatar(String name) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.primaryCrimson.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryCrimson.withOpacity(0.3)),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: AppColors.primaryCrimson,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SEARCH BAR — Dark input with subtle border
// ============================================================

class AdminSearchBar extends StatelessWidget {
  final String hintText;
  final ValueChanged<String> onChanged;
  final String value;

  const AdminSearchBar({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.value = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle, width: 1.2),
      ),
      child: TextField(
        onChanged: onChanged,
        controller: TextEditingController(text: value)
          ..selection = TextSelection.collapsed(offset: value.length),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 13.5,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textMuted,
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ============================================================
// FILTER CHIPS ROW — Horizontally scrollable dark pills
// ============================================================

class AdminFilterChips extends StatelessWidget {
  final List<String> filters;
  final String selected;
  final ValueChanged<String> onSelected;

  const AdminFilterChips({
    super.key,
    required this.filters,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filters.map((filter) {
          final isActive = filter == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primaryCrimson.withOpacity(0.18)
                      : AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive
                        ? AppColors.primaryCrimson
                        : AppColors.borderSubtle,
                    width: isActive ? 1.4 : 1.0,
                  ),
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ============================================================
// EMPTY STATE
// ============================================================

class AdminEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? customIcon;

  const AdminEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.inbox_rounded,
    this.customIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Center(
                child: customIcon ?? Icon(icon, size: 36, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ERROR STATE
// ============================================================

class AdminErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AdminErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.12),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: const Icon(Icons.error_outline_rounded, size: 36, color: AppColors.error),
            ),
            const SizedBox(height: 20),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryCrimson,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  minimumSize: const Size(120, 44),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// LOADING STATE
// ============================================================

class AdminLoadingState extends StatelessWidget {
  const AdminLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                color: AppColors.primaryCrimson,
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 18),
            Text(
              'Loading mobility data...',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SECTION HEADER
// ============================================================

class AdminSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AdminSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
            child: Text(
              actionLabel!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryCrimson,
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================
// APPLICATION DETAIL BOTTOM SHEET
// ============================================================

class ApplicationDetailSheet extends StatelessWidget {
  final Map<String, dynamic> application;

  const ApplicationDetailSheet({super.key, required this.application});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: AppColors.borderSubtle, width: 1.5)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Application Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    _DetailRow('Student Name', application['studentName'] ?? application['fullName'] ?? '-'),
                    _DetailRow('PRN', application['prn'] ?? '-'),
                    _DetailRow('Course', application['course'] ?? '-'),
                    _DetailRow('Department', application['department'] ?? '-'),
                    _DetailRow('Year', application['year'] ?? '-'),
                    _DetailRow('Route', application['routeName'] ?? application['route'] ?? '-'),
                    _DetailRow('Payment Status', application['paymentStatus'] ?? '-'),
                    _DetailRow('Pass Status', application['status'] ?? '-'),
                    _DetailRow('Email', application['email'] ?? '-'),
                    _DetailRow('Mobile', application['mobile'] ?? '-'),
                    _DetailRow('Address', application['address'] ?? '-'),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// PRIVATE HELPER WIDGETS
// ============================================================

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.28)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final dynamic value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? '-',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}



================================================
FILE: lib/features/admin/presentation/views/application_detail_screen.dart
================================================
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/admin/data/repositories/admin_repository.dart';
import 'package:icem_bus/features/admin/domain/admin_providers.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';

/// Full-page detail screen for a single bus pass application.
///
/// Receives the application document ID via GoRouter path parameter,
/// streams the document in real-time, and provides admin actions
/// (Approve / Reject / Request Correction) with appropriate dialogs.
class ApplicationDetailScreen extends ConsumerWidget {
  final String applicationId;

  const ApplicationDetailScreen({super.key, required this.applicationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appAsync = ref.watch(singleApplicationStreamProvider(applicationId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Application Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color(0xFF0F172A),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF1F5F9)),
        ),
      ),
      body: appAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryCrimson),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  'Failed to load application',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ),
        data: (application) {
          if (application == null) {
            return const Center(
              child: Text(
                'Application not found',
                style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
              ),
            );
          }

          return _ApplicationDetailBody(
            application: application,
            applicationId: applicationId,
          );
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Detail body — extracted as StatelessWidget for clarity
// ────────────────────────────────────────────────────────────

class _ApplicationDetailBody extends ConsumerWidget {
  final Map<String, dynamic> application;
  final String applicationId;

  const _ApplicationDetailBody({
    required this.application,
    required this.applicationId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passStatus =
        application['passStatus'] ?? application['status'] ?? 'Pending';

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        // ── Student Header Card ──
        _buildStudentHeader(context),
        const SizedBox(height: 16),

        // ── Application Info Card ──
        _buildInfoCard(context, 'Application Information', [
          _row('PRN', application['prn']),
          _row('College ID', application['collegeId']),
          _row('Course', application['course']),
          _row('Department', application['department']),
          _row('Year', application['year']),
          _row('Semester', application['semester']),
        ]),
        const SizedBox(height: 16),

        // ── Route & Travel Card ──
        _buildInfoCard(context, 'Route & Travel Details', [
          _row('Route', application['routeName'] ?? application['route']),
          _row('Boarding Stop', application['boardingStop']),
          _row('Destination Stop', application['destinationStop']),
          _row('Distance', application['distance']),
          _row('Bus Number', application['busNumber']),
        ]),
        const SizedBox(height: 16),

        // ── Payment & Status Card ──
        _buildInfoCard(context, 'Payment & Status', [
          _row('Fare', _formatFare(application['fare'])),
          _row('Payment Status', application['paymentStatus']),
          _row('Pass Status', passStatus),
          _row('Pass ID', application['passId']),
          _row('Applied Date', _formatTimestamp(application['createdAt'])),
        ]),
        const SizedBox(height: 16),

        // ── Contact Card ──
        _buildInfoCard(context, 'Contact Information', [
          _row('Email', application['email']),
          _row('Mobile', application['mobile']),
          _row('Address', application['address']),
        ]),
        const SizedBox(height: 16),

        // ── Action History Card (if already actioned) ──
        if (passStatus == 'Approved' ||
            passStatus == 'Rejected' ||
            passStatus == 'Correction Required')
          ...[
            _buildHistoryCard(context, passStatus.toString()),
            const SizedBox(height: 16),
          ],

        // ── Admin Actions (for Pending or Payment Pending applications) ──
        if (passStatus == 'Pending' ||
            passStatus == 'Payment Pending' ||
            passStatus == 'Pending Payment' ||
            passStatus == 'Pending Approval') ...[
          _buildAdminActions(context, ref),
          const SizedBox(height: 32),
        ],
      ],
    );
  }

  // ── Student Header ──
  Widget _buildStudentHeader(BuildContext context) {
    final name =
        application['studentName'] ?? application['fullName'] ?? 'Unknown';
    final photoUrl = application['photoUrl'] as String?;
    final passStatus =
        application['passStatus'] ?? application['status'] ?? 'Pending';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Photo
          _buildPhoto(photoUrl, name.toString()),
          const SizedBox(width: 16),
          // Name + Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'PRN: ${application['prn'] ?? '-'}  •  ID: ${application['collegeId'] ?? '-'}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 10),
                _buildStatusChip(passStatus.toString()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoto(String? photoUrl, String name) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          photoUrl,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildInitialAvatar(name, 64),
        ),
      );
    }
    return _buildInitialAvatar(name, 64);
  }

  Widget _buildInitialAvatar(String name, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryCrimson.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: AppColors.primaryCrimson,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.4,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bgColor;
    Color textColor;

    switch (status) {
      case 'Approved':
      case 'Active':
        bgColor = AppColors.success.withOpacity(0.1);
        textColor = AppColors.success;
        break;
      case 'Rejected':
        bgColor = AppColors.error.withOpacity(0.1);
        textColor = AppColors.error;
        break;
      case 'Expired':
        bgColor = AppColors.warning.withOpacity(0.1);
        textColor = AppColors.warning;
        break;
      case 'Correction Required':
        bgColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFE65100);
        break;
      case 'Pending Approval':
        bgColor = AppColors.info.withOpacity(0.12);
        textColor = AppColors.info;
        break;
      case 'Payment Pending':
      case 'Pending Payment':
        bgColor = AppColors.warning.withOpacity(0.12);
        textColor = const Color(0xFFD97706);
        break;
      default:
        bgColor = AppColors.info.withOpacity(0.1);
        textColor = AppColors.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  // ── Info Card Builder ──
  Widget _buildInfoCard(
      BuildContext context, String title, List<Widget> rows) {
    // Filter out rows that are just dashes
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 2,
            width: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryCrimson,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(String label, dynamic value) {
    final displayValue = value?.toString();
    if (displayValue == null || displayValue.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── History Card (for already actioned applications) ──
  Widget _buildHistoryCard(BuildContext context, String status) {
    IconData icon;
    Color color;
    String title;
    List<Widget> details = [];

    switch (status) {
      case 'Approved':
        icon = Icons.check_circle_rounded;
        color = AppColors.success;
        title = 'Approved';
        details = [
          _row('Approved By', application['approvedBy']),
          _row('Approved At', _formatTimestamp(application['approvedAt'])),
          _row('Pass ID', application['passId']),
        ];
        break;
      case 'Rejected':
        icon = Icons.cancel_rounded;
        color = AppColors.error;
        title = 'Rejected';
        details = [
          _row('Rejection Reason', application['rejectionReason']),
          _row('Rejected At', _formatTimestamp(application['rejectedAt'])),
        ];
        break;
      case 'Correction Required':
        icon = Icons.edit_note_rounded;
        color = const Color(0xFFE65100);
        title = 'Correction Required';
        details = [
          _row('Correction Message', application['correctionMessage']),
          _row('Requested At',
              _formatTimestamp(application['correctionRequestedAt'])),
        ];
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...details,
        ],
      ),
    );
  }

  // ── Admin Actions (Approve / Reject / Request Correction) ──
  Widget _buildAdminActions(BuildContext context, WidgetRef ref) {
    final String paymentStatusStr = (application['paymentStatus'] as String? ?? 'Pending').trim();
    final bool isPaid = paymentStatusStr.toLowerCase() == 'paid' || paymentStatusStr.toLowerCase() == 'success';
    final String passStatus = (application['passStatus'] as String? ?? application['status'] as String? ?? 'Pending').trim();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin Actions',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 2,
            width: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryCrimson,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: 16),
          if (passStatus.toString().toLowerCase() == 'revoked') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.block_rounded, color: AppColors.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This pass was revoked by college administration. Reason: ${application['rejectionReason'] ?? application['revocationReason'] ?? "Administrative decision"}',
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (passStatus == 'Active' || passStatus == 'Approved') ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pass is ACTIVE and authorized for travel.',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (application['passNumber'] != null)
                          Text(
                            'Pass No: ${application['passNumber']}',
                            style: const TextStyle(color: Color(0xFF334155), fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: _AdminActionButton(
                label: 'Revoke Pass',
                icon: Icons.block_rounded,
                color: AppColors.error,
                onTap: () => _handleRevoke(context, ref),
              ),
            ),
          ] else ...[
            if (!isPaid) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_rounded, color: AppColors.error, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Payment required before approval. This application is unpaid and cannot be approved until verified payment is received.',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Row(
              children: [
                Expanded(
                  child: _AdminActionButton(
                    label: isPaid ? 'Approve' : 'Payment Required',
                    icon: isPaid ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                    color: isPaid ? AppColors.success : Colors.grey.shade400,
                    onTap: isPaid
                        ? () => _handleApprove(context, ref)
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Payment required before approval. Student must complete verified payment first.'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AdminActionButton(
                    label: 'Reject',
                    icon: Icons.cancel_rounded,
                    color: AppColors.error,
                    onTap: () => _handleReject(context, ref),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AdminActionButton(
                    label: 'Correction',
                    icon: Icons.edit_note_rounded,
                    color: AppColors.warning,
                    onTap: () => _handleCorrection(context),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Action Handlers ──

  void _handleRevoke(BuildContext context, WidgetRef ref) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Revoke Bus Pass'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Are you sure you want to revoke this active bus pass? The student will no longer be authorized to board buses.'),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Reason for revocation...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
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
                    content: Text('Please specify a revocation reason.'),
                    backgroundColor: AppColors.warning,
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                final studentUid = application['uid'] ?? application['studentId'] ?? '';
                final adminUid = ref.read(authControllerProvider).user?.uid ?? '';
                final repo = AdminRepository();
                await repo.revokePass(studentUid, reason, adminUid);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Bus pass revoked successfully.'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to revoke pass: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Revoke', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleApprove(BuildContext context, WidgetRef ref) {
    final String paymentStatusStr = (application['paymentStatus'] as String? ?? 'Pending').trim();
    final bool isPaid = paymentStatusStr.toLowerCase() == 'paid' || paymentStatusStr.toLowerCase() == 'success';

    if (!isPaid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment required before approval.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    DateTime selectedValidUntil = DateTime.now().add(const Duration(days: 180));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Approve Bus Pass'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This will approve the application, generate a unique Pass Number (e.g. ICEM-BP-2026-XXXXXX), and activate the student\'s Digital Pass with QR Code.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 16),
                const Text('Pass Validity Until:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedValidUntil,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedValidUntil = picked;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primaryCrimson.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(10),
                      color: AppColors.lightCrimson.withOpacity(0.3),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${selectedValidUntil.day.toString().padLeft(2, '0')}/${selectedValidUntil.month.toString().padLeft(2, '0')}/${selectedValidUntil.year}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryCrimson),
                        ),
                        const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primaryCrimson),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final adminUid = ref.read(authControllerProvider).user?.uid ?? '';
                  final repo = AdminRepository();
                  await repo.approveApplication(
                    applicationId,
                    adminUid,
                    validUntil: selectedValidUntil,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Application approved and pass activated successfully!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
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
                'Approve & Activate',
                style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleReject(BuildContext context, WidgetRef ref) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Application'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please provide a reason for rejection.'),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Rejection reason...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
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
                final repo = AdminRepository();
                await repo.rejectApplication(applicationId, reason, adminUid);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Application rejected'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
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
                  color: AppColors.error, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _handleCorrection(BuildContext context) {
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Request Correction'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Describe what corrections the student needs to make.'),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Correction message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final message = messageController.text.trim();
              if (message.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a correction message'),
                    backgroundColor: AppColors.warning,
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                final repo = AdminRepository();
                await repo.requestCorrection(applicationId, message);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Correction requested'),
                      backgroundColor: AppColors.warning,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
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
              'Send',
              style: TextStyle(
                  color: AppColors.warning, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──

  String _formatFare(dynamic fare) {
    if (fare == null) return '-';
    return '₹${(fare is num) ? fare.toStringAsFixed(0) : fare.toString()}';
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '-';
    DateTime? dt;
    if (timestamp is Timestamp) {
      dt = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dt = timestamp;
    }
    if (dt == null) return '-';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ────────────────────────────────────────────────────────────
// Admin Action Button — styled consistently
// ────────────────────────────────────────────────────────────

class _AdminActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AdminActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



================================================
FILE: lib/features/admin/presentation/views/report_exporter.dart
================================================
// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportExporter {
  ReportExporter._();

  static String _escapeCsvCell(dynamic value) {
    if (value == null) return '';
    String str = value.toString().replaceAll('"', '""');
    if (str.contains(',') || str.contains('"') || str.contains('\n') || str.contains('\r')) {
      return '"$str"';
    }
    return str;
  }

  /// Generates a standard comma-separated values (CSV) string.
  static String generateCsv(List<String> headers, List<List<dynamic>> rows) {
    final buffer = StringBuffer();
    // Headers
    buffer.writeln(headers.map(_escapeCsvCell).join(','));
    // Rows
    for (final row in rows) {
      buffer.writeln(row.map(_escapeCsvCell).join(','));
    }
    return buffer.toString();
  }

  /// Exports data as a CSV file and opens the platform share sheet.
  static Future<void> exportCsv({
    required String filename,
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) async {
    final csvContent = generateCsv(headers, rows);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$filename');
    await file.writeAsString(csvContent);
    await Share.shareXFiles([XFile(file.path)], subject: filename);
  }

  /// Exports data as a PDF document and opens the platform share sheet.
  static Future<void> exportPdf({
    required String filename,
    required String reportTitle,
    required String filterDescription,
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 20),
          child: pw.Text(
            'ICEM Bus Management Portal - Reports',
            style: pw.TextStyle(color: PdfColors.grey700, fontSize: 8),
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 20),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(color: PdfColors.grey700, fontSize: 8),
          ),
        ),
        build: (context) => [
          pw.Text(
            reportTitle,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Generated on: ${DateTime.now().toLocal().toString().split('.')[0]}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
          ),
          pw.Text(
            'Filter Date Range: $filterDescription',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo700),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          ),
        ],
      ),
    );

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], subject: filename);
  }

  /// Generates a beautiful A5 PDF receipt and triggers sharing
  static Future<void> exportReceipt({required Map<String, dynamic> payment}) async {
    final pdf = pw.Document();

    final name = payment['studentName'] ?? 'Unknown';
    final amount = payment['amount'] ?? 0;
    final status = payment['paymentStatus'] ?? 'Pending';
    final dateField = payment['createdAt'] ?? payment['paymentDate'];
    final paymentMethod = payment['paymentMethod'] ?? 'Online Payment';
    final receiptId = payment['receiptId'] ?? payment['id'] ?? 'N/A';
    final transactionId = payment['transactionId'] ?? 'N/A';
    final prn = payment['prn'] ?? 'N/A';
    final course = payment['course'] ?? 'N/A';
    final route = payment['route'] ?? 'N/A';
    final boarding = payment['boardingStop'] ?? 'N/A';
    final destination = payment['destinationStop'] ?? 'N/A';
    final fare = payment['amount'] ?? amount;

    DateTime? dt;
    if (dateField is Timestamp) {
      dt = dateField.toDate();
    } else if (dateField is String) {
      dt = DateTime.tryParse(dateField);
    }
    final dateStr = dt != null
        ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : 'N/A';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.indigo900, width: 2),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
          ),
          padding: const pw.EdgeInsets.all(16),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'INDIRA COLLEGE OF ENGINEERING & MANAGEMENT',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.indigo900),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'ICEM BUS SERVICE RECEIPT',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.indigo900),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(color: PdfColors.grey400, thickness: 1),
              pw.SizedBox(height: 6),

              _pdfRow('Receipt ID:', receiptId, isBold: true),
              _pdfRow('Transaction ID:', transactionId),
              _pdfRow('Date & Time:', dateStr),
              _pdfRow('Student Name:', name, isBold: true),
              _pdfRow('PRN:', prn),
              _pdfRow('Course:', course),

              pw.SizedBox(height: 6),
              pw.Divider(color: PdfColors.grey400, thickness: 0.5),
              pw.SizedBox(height: 6),

              _pdfRow('Bus Route:', route),
              _pdfRow('Boarding Stop:', boarding),
              _pdfRow('Destination:', destination),

              pw.SizedBox(height: 6),
              pw.Divider(color: PdfColors.grey400, thickness: 0.5),
              pw.SizedBox(height: 6),

              _pdfRow('Fare Amount:', 'INR ${fare is num ? fare.toStringAsFixed(2) : fare}', isBold: true),
              _pdfRow('Payment Method:', paymentMethod),
              _pdfRow('Payment Status:', status,
                  isBold: true,
                  color: status == 'Paid' || status == 'Success' || status == 'Successful'
                      ? PdfColors.green700
                      : (status == 'Failed' ? PdfColors.red700 : PdfColors.amber800)),

              pw.SizedBox(height: 16),
              pw.Center(
                child: pw.Text(
                  'Thank you for using ICEM Bus Services!',
                  style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/receipt_$receiptId.pdf');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], subject: 'Receipt $receiptId');
  }

  static pw.Widget _pdfRow(String label, String value, {bool isBold = false, PdfColor color = PdfColors.black}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}



================================================
FILE: lib/features/admin/presentation/views/staff_dashboard.dart
================================================
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/routes/app_routes.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/shared/custom_button.dart';
import 'package:icem_bus/shared/glass_card.dart';

class StaffDashboardScreen extends ConsumerWidget {
  const StaffDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    
    final user = authState.user;
    
    // Permission Guard: Only Staff can access
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go(AppRoutes.login);
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (user.role != 'Staff') {
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
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.gpp_bad_rounded, size: 80, color: AppColors.primaryCrimson),
                const SizedBox(height: 24),
                Text(
                  'Access Denied',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Only Transport Staff are authorized to view this scanning console.',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final String staffName = user.fullName;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        title: const Text('Staff Admin Portal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D1527),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.primaryCrimson),
            onPressed: () => _handleLogout(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting Section
              Text(
                'Welcome, $staffName',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryCrimson,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Designation: ICEM Administrative Staff',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),

              // Mock Verification Scanner GlassCard
              const Text(
                'Verification Scanner',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => context.push(AppRoutes.qrVerification),
                borderRadius: BorderRadius.circular(16),
                child: GlassCard(
                  blur: 16,
                  borderColor: AppColors.accentGold,
                  opacity: 0.12,
                  color: AppColors.secondaryDark,
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: AppColors.accentGold,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'SCAN STUDENT PASS',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Tap to launch camera scanner and verify student bus passes in real-time.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        text: 'Launch Scanner',
                        icon: Icons.camera_alt_rounded,
                        onPressed: () => context.push(AppRoutes.qrVerification),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Admin statistics Mock
              const Text(
                'Today\'s Passenger Overview',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GlassCard(
                      blur: 12,
                      borderColor: Colors.white10,
                      opacity: 0.05,
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text('Passes Verified', style: TextStyle(fontSize: 12, color: Colors.white70)),
                          const SizedBox(height: 8),
                          Text(
                            '142',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: AppColors.primaryCrimson,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GlassCard(
                      blur: 12,
                      borderColor: Colors.white10,
                      opacity: 0.05,
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text('Active Buses', style: TextStyle(fontSize: 12, color: Colors.white70)),
                          const SizedBox(height: 8),
                          Text(
                            '8 / 10',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: AppColors.accentGold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              
              // Direct logout
              SecondaryButton(
                text: 'Sign Out Portal',
                icon: Icons.logout_rounded,
                onPressed: () => _handleLogout(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Sign Out'),
        content: const Text('Are you sure you want to sign out from the scanning console?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: AppColors.primaryCrimson)),
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



================================================
FILE: lib/features/auth/.gitkeep
================================================
[Empty file]


================================================
FILE: lib/features/auth/data/.gitkeep
================================================
[Empty file]


================================================
FILE: lib/features/auth/data/models/user_model.dart
================================================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:icem_bus/features/auth/domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.uid,
    required super.fullName,
    required super.email,
    required super.role,
    super.photoUrl,
    required super.isEmailVerified,
    required super.createdAt,
    required super.updatedAt,
    super.isActive = true,
    super.mobile,
    super.address,
    super.emergencyContact,
    super.prn,
    super.collegeId,
    super.department,
    super.course,
    super.year,
    super.semester,
  });

  /// Convert a Firestore Document Snapshot Map into a UserModel
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String? ?? '',
      fullName: map['fullName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      role: UserEntity.normalizeRole(map['role'] as String?),
      photoUrl: map['photoUrl'] as String?,
      isEmailVerified: map['isEmailVerified'] as bool? ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] as bool? ?? true,
      mobile: map['mobile'] as String?,
      address: map['address'] as String?,
      emergencyContact: map['emergencyContact'] as String?,
      prn: map['prn'] as String?,
      collegeId: map['collegeId'] as String?,
      department: map['department'] as String?,
      course: map['course'] as String?,
      year: map['year'] as String?,
      semester: map['semester'] as String?,
    );
  }

  /// Convert this UserModel into a Firestore Map
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'role': role,
      'photoUrl': photoUrl,
      'isEmailVerified': isEmailVerified,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
      'mobile': mobile,
      'address': address,
      'emergencyContact': emergencyContact,
      'prn': prn,
      'collegeId': collegeId,
      'department': department,
      'course': course,
      'year': year,
      'semester': semester,
    };
  }

  /// Create a copy of this UserModel with modified fields
  UserModel copyWith({
    String? uid,
    String? fullName,
    String? email,
    String? role,
    String? photoUrl,
    bool? isEmailVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    String? mobile,
    String? address,
    String? emergencyContact,
    String? prn,
    String? collegeId,
    String? department,
    String? course,
    String? year,
    String? semester,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      mobile: mobile ?? this.mobile,
      address: address ?? this.address,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      prn: prn ?? this.prn,
      collegeId: collegeId ?? this.collegeId,
      department: department ?? this.department,
      course: course ?? this.course,
      year: year ?? this.year,
      semester: semester ?? this.semester,
    );
  }
}



================================================
FILE: lib/features/auth/data/repositories/auth_repository_impl.dart
================================================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:icem_bus/core/errors/failures.dart';
import 'package:icem_bus/features/auth/data/models/user_model.dart';
import 'package:icem_bus/features/auth/domain/entities/user_entity.dart';
import 'package:icem_bus/features/auth/domain/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    firebaseAuth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
  );
});

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth firebaseAuth;
  final FirebaseFirestore firestore;

  AuthRepositoryImpl({
    required this.firebaseAuth,
    required this.firestore,
  });

  @override
  Future<UserEntity> signUpWithEmailAndPassword({
    required String fullName,
    required String email,
    required String password,
    required String role,
    String? mobile,
    String? collegeId,
  }) async {
    try {
      // 1. Create Firebase Auth user
      final UserCredential credential = await firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw const AuthFailure('Failed to register user.');
      }

      // 2. Send email verification link
      await firebaseUser.sendEmailVerification();

      // 3. Create Firestore User profile
      final userModel = UserModel(
        uid: firebaseUser.uid,
        fullName: fullName,
        email: email,
        role: role,
        photoUrl: firebaseUser.photoURL,
        isEmailVerified: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
        mobile: mobile,
        collegeId: collegeId,
      );

      await firestore.collection('users').doc(firebaseUser.uid).set(userModel.toMap());

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'An authentication error occurred.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<UserEntity> loginWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      // 1. Sign in with Firebase Auth
      final UserCredential credential = await firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw const AuthFailure('User login failed.');
      }

      // 2. Fetch User Profile from Firestore
      final DocumentSnapshot doc = await firestore.collection('users').doc(firebaseUser.uid).get();

      if (!doc.exists) {
        // Fallback: If user doc wasn't created, populate default profile
        final fallbackUser = UserModel(
          uid: firebaseUser.uid,
          fullName: firebaseUser.displayName ?? 'College Student',
          email: firebaseUser.email ?? email,
          role: 'Engineering Student',
          photoUrl: firebaseUser.photoURL,
          isEmailVerified: firebaseUser.emailVerified,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: true,
        );
        await firestore.collection('users').doc(firebaseUser.uid).set(fallbackUser.toMap());
        return fallbackUser;
      }

      // Load Firestore model and update verification status if changed
      final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      UserModel userModel = UserModel.fromMap(data);

      if (userModel.isEmailVerified != firebaseUser.emailVerified) {
        userModel = userModel.copyWith(isEmailVerified: firebaseUser.emailVerified);
        await firestore.collection('users').doc(firebaseUser.uid).update({
          'isEmailVerified': firebaseUser.emailVerified,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'Invalid email or password.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<UserEntity> signInWithGoogle() async {
    try {
      // 1. Ensure Google Sign In is initialized (Required in v7.0.0+)
      await GoogleSignIn.instance.initialize();

      // 2. Trigger Google Sign In flow
      final GoogleSignInAccount googleUser = await GoogleSignIn.instance.authenticate();

      // 3. Fetch authentication details
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw const AuthFailure('Google authentication failed: Missing ID Token.');
      }

      // 4. Create Firebase auth credentials (accessToken is no longer returned by default in v7)
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      // 5. Sign in to Firebase Auth
      final UserCredential userCredential = await firebaseAuth.signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw const AuthFailure('Google authentication failed.');
      }

      // 6. Check if user already has a profile in Firestore
      final DocumentSnapshot doc = await firestore.collection('users').doc(firebaseUser.uid).get();

      if (!doc.exists) {
        // Create new user profile, defaulting role to Engineering Student
        final newUser = UserModel(
          uid: firebaseUser.uid,
          fullName: firebaseUser.displayName ?? googleUser.displayName ?? 'Student',
          email: firebaseUser.email ?? googleUser.email,
          role: 'Engineering Student',
          photoUrl: firebaseUser.photoURL ?? googleUser.photoUrl,
          isEmailVerified: true, // Google accounts are verified
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: true,
        );

        await firestore.collection('users').doc(firebaseUser.uid).set(newUser.toMap());
        return newUser;
      } else {
        // Load existing user profile
        final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return UserModel.fromMap(data);
      }
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'Google Sign-In failed.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'Failed to send password reset email.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await firebaseAuth.signOut();
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      throw ServerFailure('Sign out failed: ${e.toString()}');
    }
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    try {
      final User? firebaseUser = firebaseAuth.currentUser;
      if (firebaseUser == null) return null;

      try {
        final DocumentSnapshot doc = await firestore.collection('users').doc(firebaseUser.uid).get();
        if (doc.exists) {
          final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          return UserModel.fromMap(data);
        }
      } catch (_) {
        // Fallback below if Firestore query fails
      }

      // Return fallback user model when firebaseUser is authenticated but Firestore check is offline/empty
      return UserModel(
        uid: firebaseUser.uid,
        fullName: firebaseUser.displayName ?? 'Student User',
        email: firebaseUser.email ?? '',
        role: 'Engineering Student',
        photoUrl: firebaseUser.photoURL,
        isEmailVerified: firebaseUser.emailVerified,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<UserEntity> updateUserProfile({
    required String uid,
    required String fullName,
    String? mobile,
    String? department,
  }) async {
    try {
      final updates = <String, dynamic>{
        'fullName': fullName.trim(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };
      if (mobile != null) {
        updates['mobile'] = mobile.trim();
      }
      if (department != null) {
        updates['department'] = department.trim();
      }

      // Update Firestore document
      await firestore.collection('users').doc(uid).update(updates);

      // Update Firebase Auth display name if current user matches
      if (firebaseAuth.currentUser?.uid == uid) {
        await firebaseAuth.currentUser?.updateDisplayName(fullName.trim());
      }

      // Fetch and return updated model
      final doc = await firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }

      // Fallback
      return UserModel(
        uid: uid,
        fullName: fullName.trim(),
        email: firebaseAuth.currentUser?.email ?? '',
        role: 'Administrator',
        isEmailVerified: firebaseAuth.currentUser?.emailVerified ?? true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        mobile: mobile,
        department: department,
      );
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to update user profile.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = firebaseAuth.currentUser;
      if (user == null || user.email == null) {
        throw const AuthFailure('No authenticated user session found.');
      }

      // Re-authenticate with current credentials
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);

      // Update password
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw const AuthFailure('The current password entered is incorrect.');
      } else if (e.code == 'weak-password') {
        throw const AuthFailure('The new password is too weak. Please use at least 8 characters.');
      } else if (e.code == 'requires-recent-login') {
        throw const AuthFailure('Security requirement: Please log in again before changing password.');
      }
      throw AuthFailure(e.message ?? 'Failed to change password.');
    } catch (e) {
      if (e is Failure) rethrow;
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> deleteAccount({
    required String password,
  }) async {
    try {
      final user = firebaseAuth.currentUser;
      if (user == null || user.email == null) {
        throw const AuthFailure('No authenticated user session found.');
      }

      final uid = user.uid;

      // Re-authenticate prior to sensitive account deletion
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(cred);

      // Safely delete only this specific user's Firestore document
      await firestore.collection('users').doc(uid).delete();

      // Delete Firebase Auth account
      await user.delete();

      // Clear Google session if applicable
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw const AuthFailure('Incorrect password. Account deletion aborted.');
      } else if (e.code == 'requires-recent-login') {
        throw const AuthFailure('Recent login required. Please sign in again and retry.');
      }
      throw AuthFailure(e.message ?? 'Failed to delete account.');
    } catch (e) {
      if (e is Failure) rethrow;
      throw ServerFailure(e.toString());
    }
  }
}



================================================
FILE: lib/features/auth/domain/.gitkeep
================================================
[Empty file]


================================================
FILE: lib/features/auth/domain/entities/user_entity.dart
================================================
class UserEntity {
  final String uid;
  final String fullName;
  final String email;
  final String role;
  final String? photoUrl;
  final bool isEmailVerified;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final String? mobile;
  final String? address;
  final String? emergencyContact;
  final String? prn;
  final String? collegeId;
  final String? department;
  final String? course;
  final String? year;
  final String? semester;

  const UserEntity({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.role,
    this.photoUrl,
    required this.isEmailVerified,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.mobile,
    this.address,
    this.emergencyContact,
    this.prn,
    this.collegeId,
    this.department,
    this.course,
    this.year,
    this.semester,
  });

  /// Canonical role normalization helper.
  /// Maps case-insensitive variants (e.g. 'admin', 'administrator', 'staff', 'student')
  /// to the application's canonical role strings ('Admin', 'Staff', 'Engineering Student', etc.).
  static String normalizeRole(String? raw) {
    if (raw == null) return '';
    final trimmed = raw.trim();
    final lower = trimmed.toLowerCase();
    if (lower == 'admin' || lower == 'administrator') return 'Admin';
    if (lower == 'staff') return 'Staff';
    if (lower == 'engineering student' || lower == 'engineering') return 'Engineering Student';
    if (lower == 'bca student' || lower == 'bca') return 'BCA Student';
    if (lower == 'mca student' || lower == 'mca') return 'MCA Student';
    if (lower == 'student') return 'Engineering Student';
    return trimmed;
  }

  /// Checks whether a given role string belongs to an eligible student.
  static bool isStudentRole(String? role) {
    if (role == null || role.trim().isEmpty) return false;
    final lower = role.trim().toLowerCase();
    if (lower == 'admin' ||
        lower == 'administrator' ||
        lower == 'staff' ||
        lower == 'driver' ||
        lower == 'conductor' ||
        lower == 'operator') {
      return false;
    }
    final normalized = normalizeRole(role);
    if (normalized == 'Engineering Student' ||
        normalized == 'BCA Student' ||
        normalized == 'MCA Student') {
      return true;
    }
    return lower.contains('student');
  }

  /// Determines whether a Firestore user record represents an eligible student.
  static bool isStudentUser(Map<String, dynamic> data) {
    final role = data['role']?.toString().trim().toLowerCase() ?? '';
    // 1. Explicitly reject known non-student roles
    if (role == 'admin' ||
        role == 'administrator' ||
        role == 'staff' ||
        role == 'driver' ||
        role == 'conductor' ||
        role == 'operator') {
      return false;
    }

    // 2. Reject admin emails
    final email = data['email']?.toString().trim().toLowerCase() ?? '';
    if (email.startsWith('admin@') || email == 'admin@gmail.com') {
      return false;
    }

    // 3. Positively identify student roles
    if (isStudentRole(data['role']?.toString())) {
      return true;
    }

    // 4. Academic attributes indicative of student profiles
    final prn = data['prn']?.toString().trim() ?? '';
    final collegeId = data['collegeId']?.toString().trim() ?? '';
    final course = data['course']?.toString().trim() ?? '';
    if (prn.isNotEmpty || collegeId.isNotEmpty || course.isNotEmpty) {
      return true;
    }

    // 5. Default fallback: only consider student if not admin/staff/driver
    return role.isEmpty || role.contains('student');
  }
}



================================================
FILE: lib/features/auth/domain/repositories/auth_repository.dart
================================================
import 'package:icem_bus/features/auth/domain/entities/user_entity.dart';

abstract class AuthRepository {
  /// Sign up a new user with email and password
  Future<UserEntity> signUpWithEmailAndPassword({
    required String fullName,
    required String email,
    required String password,
    required String role,
    String? mobile,
    String? collegeId,
  });

  /// Log in an existing user with email and password
  Future<UserEntity> loginWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Sign in/up with Google
  Future<UserEntity> signInWithGoogle();

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email);

  /// Sign out the current user
  Future<void> signOut();

  /// Retrieve the current authenticated user's Firestore profile
  Future<UserEntity?> getCurrentUser();

  /// Update the authenticated user's profile in Firestore and Auth
  Future<UserEntity> updateUserProfile({
    required String uid,
    required String fullName,
    String? mobile,
    String? department,
  });

  /// Change password using current password re-authentication
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Delete the current authenticated user account and Firestore document
  Future<void> deleteAccount({
    required String password,
  });
}



================================================
FILE: lib/features/auth/presentation/.gitkeep
================================================
[Empty file]


================================================
FILE: lib/features/auth/presentation/controllers/auth_controller.dart
================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/core/errors/failures.dart';
import 'package:icem_bus/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:icem_bus/features/auth/domain/entities/user_entity.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_state.dart';

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Schedule loading user session after widget build completes
    Future.microtask(() => checkCurrentUser());
    return const AuthState();
  }

  /// Check if a user session is active on startup
  Future<void> checkCurrentUser() async {
    state = state.copyWith(isLoading: true);
    try {
      final repository = ref.read(authRepositoryProvider);
      final UserEntity? user = await repository.getCurrentUser();
      state = state.copyWith(user: user, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Sign Up with Email and Password
  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
    required String confirmPassword,
    required String role,
    String? mobile,
    String? collegeId,
  }) async {
    // 1. Validations
    if (fullName.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Full Name is required.');
      return;
    }
    
    final emailError = validateEmail(email);
    if (emailError != null) {
      state = state.copyWith(errorMessage: emailError);
      return;
    }

    final passwordError = validatePassword(password);
    if (passwordError != null) {
      state = state.copyWith(errorMessage: passwordError);
      return;
    }

    if (password != confirmPassword) {
      state = state.copyWith(errorMessage: 'Passwords do not match.');
      return;
    }

    if (role.isEmpty) {
      state = state.copyWith(errorMessage: 'Please select a role.');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final repository = ref.read(authRepositoryProvider);
      final user = await repository.signUpWithEmailAndPassword(
        fullName: fullName.trim(),
        email: email.trim(),
        password: password,
        role: role,
        mobile: mobile,
        collegeId: collegeId,
      );
      state = state.copyWith(user: user, isLoading: false, isSuccess: true);
    } on Failure catch (e) {
      state = state.copyWith(errorMessage: e.message, isLoading: false);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
    }
  }

  /// Log In with Email and Password
  Future<void> login({
    required String email,
    required String password,
  }) async {
    // 1. Validations
    final emailError = validateEmail(email);
    if (emailError != null) {
      state = state.copyWith(errorMessage: emailError);
      return;
    }

    if (password.isEmpty) {
      state = state.copyWith(errorMessage: 'Password is required.');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final repository = ref.read(authRepositoryProvider);
      final user = await repository.loginWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      state = state.copyWith(user: user, isLoading: false, isSuccess: true);
    } on Failure catch (e) {
      state = state.copyWith(errorMessage: e.message, isLoading: false);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
    }
  }

  /// Sign In with Google
  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repository = ref.read(authRepositoryProvider);
      final user = await repository.signInWithGoogle();
      state = state.copyWith(user: user, isLoading: false, isSuccess: true);
    } on Failure catch (e) {
      state = state.copyWith(errorMessage: e.message, isLoading: false);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
    }
  }

  /// Forgot Password - Reset Password Link
  Future<bool> forgotPassword(String email) async {
    final emailError = validateEmail(email);
    if (emailError != null) {
      state = state.copyWith(errorMessage: emailError);
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.sendPasswordResetEmail(email.trim());
      state = state.copyWith(isLoading: false);
      return true;
    } on Failure catch (e) {
      state = state.copyWith(errorMessage: e.message, isLoading: false);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
      return false;
    }
  }

  /// Sign Out current user session
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.signOut();
      state = const AuthState();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Update user profile (Name, Mobile, Department)
  Future<bool> updateProfile({
    required String fullName,
    String? mobile,
    String? department,
  }) async {
    if (fullName.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Full Name is required.');
      return false;
    }

    final currentUser = state.user;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: 'User session not found.');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repository = ref.read(authRepositoryProvider);
      final updatedUser = await repository.updateUserProfile(
        uid: currentUser.uid,
        fullName: fullName.trim(),
        mobile: mobile?.trim().isNotEmpty == true ? mobile!.trim() : null,
        department: department?.trim().isNotEmpty == true ? department!.trim() : null,
      );
      state = state.copyWith(user: updatedUser, isLoading: false, isSuccess: true);
      return true;
    } on Failure catch (e) {
      state = state.copyWith(errorMessage: e.message, isLoading: false);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
      return false;
    }
  }

  /// Change Password
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (currentPassword.isEmpty) {
      state = state.copyWith(errorMessage: 'Current password is required.');
      return false;
    }
    final pwdErr = validatePassword(newPassword);
    if (pwdErr != null) {
      state = state.copyWith(errorMessage: pwdErr);
      return false;
    }
    if (newPassword != confirmPassword) {
      state = state.copyWith(errorMessage: 'New passwords do not match.');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } on Failure catch (e) {
      state = state.copyWith(errorMessage: e.message, isLoading: false);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
      return false;
    }
  }

  /// Delete Account
  Future<bool> deleteAccount({required String password}) async {
    if (password.isEmpty) {
      state = state.copyWith(errorMessage: 'Password is required to confirm deletion.');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.deleteAccount(password: password);
      state = const AuthState();
      return true;
    } on Failure catch (e) {
      state = state.copyWith(errorMessage: e.message, isLoading: false);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
      return false;
    }
  }

  /// Reset Auth success/error states
  void resetState() {
    state = state.copyWith(errorMessage: null, isSuccess: false);
  }

  // ==========================================
  // VALIDATION HELPERS
  // ==========================================

  /// Check email structure
  String? validateEmail(String email) {
    if (email.trim().isEmpty) {
      return 'Email address is required.';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email.trim())) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  /// Check password criteria (length >= 8)
  String? validatePassword(String password) {
    if (password.isEmpty) {
      return 'Password is required.';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters long.';
    }
    return null;
  }
}



================================================
FILE: lib/features/auth/presentation/controllers/auth_state.dart
================================================
import 'package:icem_bus/features/auth/domain/entities/user_entity.dart';

class AuthState {
  final UserEntity? user;
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  AuthState copyWith({
    UserEntity? user,
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage, // Allow setting to null to clear errors
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }

  bool get isAuthenticated => user != null;
}



================================================
FILE: lib/features/auth/presentation/views/login_screen.dart
================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/routes/app_routes.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/auth/domain/entities/user_entity.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_state.dart';
import 'package:icem_bus/shared/app_card.dart';
import 'package:icem_bus/shared/app_text_field.dart';
import 'package:icem_bus/shared/custom_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLoginPressed() {
    if (_formKey.currentState!.validate()) {
      ref.read(authControllerProvider.notifier).login(
            email: _emailController.text,
            password: _passwordController.text,
          );
    }
  }

  void _showForgotPasswordDialog() {
    final emailResetController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              child: PremiumCard(
                padding: const EdgeInsets.all(24),
                borderRadius: 24,
                borderColor: AppColors.borderSubtle,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primaryCrimson.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.primaryCrimson.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.lock_reset_rounded,
                              color: AppColors.primaryCrimson,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text(
                              'Reset Password',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Enter your registered college email address and we will send you a secure link to reset your password.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      AppTextField(
                        controller: emailResetController,
                        label: 'College Email',
                        hintText: 'student@indiraicem.ac.in',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.email_outlined,
                        validator: (value) {
                          return ref.read(authControllerProvider.notifier).validateEmail(value ?? '');
                        },
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        text: 'Send Reset Link',
                        icon: Icons.send_rounded,
                        isLoading: isSubmitting,
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final email = emailResetController.text.trim();
                          
                          setModalState(() => isSubmitting = true);
                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(dialogContext);

                          final success = await ref.read(authControllerProvider.notifier).forgotPassword(email);
                          setModalState(() => isSubmitting = false);

                          if (success) {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('Password reset link sent to your email.'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                            navigator.pop();
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text(
                            'Back to Login',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    // Listen for AuthState mutations (Success routes or Error messages)
    ref.listen<AuthState>(authControllerProvider, (previous, next) async {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(authControllerProvider.notifier).resetState();
      } else if (next.isSuccess && next.user != null) {
        final user = next.user!;
        final String role = UserEntity.normalizeRole(user.role);

        if (role == 'Admin') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Welcome back, ${user.fullName}!'),
              backgroundColor: AppColors.success,
            ),
          );
          context.go(AppRoutes.adminDashboard);
          ref.read(authControllerProvider.notifier).resetState();
        } else if (role == 'Staff') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Welcome back, ${user.fullName}!'),
              backgroundColor: AppColors.success,
            ),
          );
          context.go(AppRoutes.staffDashboard);
          ref.read(authControllerProvider.notifier).resetState();
        } else if (role == 'Engineering Student' || role == 'BCA Student' || role == 'MCA Student') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Welcome back, ${user.fullName}!'),
              backgroundColor: AppColors.success,
            ),
          );
          context.go(AppRoutes.studentDashboard);
          ref.read(authControllerProvider.notifier).resetState();
        } else {
          await ref.read(authControllerProvider.notifier).logout();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User role not found. Contact the administrator.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // ICEM Logo Container with Crimson subtle border & glow
              Container(
                width: 82,
                height: 82,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryCrimson.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryCrimson.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/bus_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 20),

              // Welcome Title
              const Text(
                'Welcome Back',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your smart campus mobility starts here.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // Login Input Form wrapped in PremiumCard
              Form(
                key: _formKey,
                child: PremiumCard(
                  padding: const EdgeInsets.all(22.0),
                  borderRadius: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Email Field
                      AppTextField(
                        controller: _emailController,
                        label: 'College Email',
                        hintText: 'student@indiraicem.ac.in',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.email_outlined,
                        validator: (value) {
                          return ref.read(authControllerProvider.notifier).validateEmail(value ?? '');
                        },
                      ),
                      const SizedBox(height: 18),

                      // Password Field
                      AppTextField(
                        controller: _passwordController,
                        label: 'Password',
                        hintText: 'Enter your password',
                        isPassword: true,
                        prefixIcon: Icons.lock_outline_rounded,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password is required.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      
                      // Remember Me & Forgot Password Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: Checkbox(
                                  value: _rememberMe,
                                  activeColor: AppColors.primaryCrimson,
                                  checkColor: Colors.white,
                                  side: const BorderSide(color: AppColors.borderSubtle, width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  onChanged: (val) => setState(() => _rememberMe = val ?? false),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Remember Me',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: _showForgotPasswordDialog,
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.primaryCrimson,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Sign In Button (LOGIN)
                      PrimaryButton(
                        text: 'LOGIN',
                        icon: Icons.login_rounded,
                        isLoading: authState.isLoading,
                        onPressed: _onLoginPressed,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // OR CONTINUE WITH Divider
              Row(
                children: [
                  const Expanded(child: Divider(color: AppColors.borderSubtle, thickness: 1)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'OR CONTINUE WITH',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: AppColors.borderSubtle, thickness: 1)),
                ],
              ),
              const SizedBox(height: 24),

              // Google Login Button
              SecondaryButton(
                text: 'Google',
                icon: Icons.g_mobiledata_rounded,
                isLoading: authState.isLoading,
                onPressed: () => ref.read(authControllerProvider.notifier).signInWithGoogle(),
              ),
              const SizedBox(height: 32),

              // Register Redirection Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.register),
                    child: const Text(
                      'Create Account',
                      style: TextStyle(
                        color: AppColors.primaryCrimson,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}



================================================
FILE: lib/features/auth/presentation/views/onboarding_screen.dart
================================================
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/routes/app_routes.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/services/storage/storage_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingModel> _slides = [
    OnboardingModel(
      title: 'Smart Digital Pass',
      description: 'Ditch paper passes! Carry your secure, QR-coded student bus pass directly on your smartphone for quick boarding.',
      painter: DigitalPassPainter(),
    ),
    OnboardingModel(
      title: 'Real-time Tracking',
      description: 'Stay updated! Track your designated bus route and estimated arrival times in real-time, preventing long campus waits.',
      painter: RouteTrackingPainter(),
    ),
    OnboardingModel(
      title: 'Instant Renewals',
      description: 'Pay on the go! Renew your bus pass instantly using built-in digital payments, with immediate admin verification.',
      painter: SecurePaymentPainter(),
    ),
  ];

  Future<void> _completeOnboarding() async {
    // Set onboarding as completed in SharedPreferences
    await ref.read(storageServiceProvider).setOnboardingCompleted(true);
    if (mounted) {
      context.go(AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (_currentPage < _slides.length - 1)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton(
                onPressed: _completeOnboarding,
                child: const Text('Skip'),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Page Slider
            Expanded(
              flex: 5,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Custom Painter Illustration
                        Expanded(
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: 1.0,
                              child: Container(
                                margin: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.lightCrimson.withOpacity(0.4),
                                  shape: BoxShape.circle,
                                ),
                                child: CustomPaint(
                                  painter: slide.painter,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Title
                        Text(
                          slide.title,
                          style: theme.textTheme.displayMedium?.copyWith(
                            color: AppColors.primaryCrimson,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        // Description
                        Text(
                          slide.description,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Pagination Controls & Actions
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Dynamic Indicator Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _slides.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(right: 8),
                          height: 8,
                          width: _currentPage == index ? 24 : 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? AppColors.primaryCrimson
                                : AppColors.textLight.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Action Button (Next or Get Started)
                    ElevatedButton(
                      onPressed: () {
                        if (_currentPage == _slides.length - 1) {
                          _completeOnboarding();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        _currentPage == _slides.length - 1
                            ? 'Get Started'
                            : 'Next Route',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper model for Onboarding slides
class OnboardingModel {
  final String title;
  final String description;
  final CustomPainter painter;

  const OnboardingModel({
    required this.title,
    required this.description,
    required this.painter,
  });
}

// ==========================================
// CUSTOM VECTOR ART PAINTERS FOR AESTHETICS
// ==========================================

/// Slide 1 Painter: Smart Digital Pass (Phone, Digital Card, Ticket Mockup)
class DigitalPassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint crimsonPaint = Paint()
      ..color = AppColors.primaryCrimson
      ..style = PaintingStyle.fill;

    final Paint goldPaint = Paint()
      ..color = AppColors.accentGold
      ..style = PaintingStyle.fill;

    final Paint phonePaint = Paint()
      ..color = AppColors.secondaryDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0;

    final double cx = size.width / 2;
    final double cy = size.height / 2;

    // Draw Mock Smartphone Outline
    final Rect phoneRect = Rect.fromCenter(center: Offset(cx, cy), width: 120, height: 210);
    canvas.drawRRect(RRect.fromRectAndRadius(phoneRect, const Radius.circular(16)), phonePaint);

    // Smartphone Screen Notch
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy - 95), width: 36, height: 12),
        const Radius.circular(6),
      ),
      phonePaint..style = PaintingStyle.fill,
    );

    // Floating Digital Pass Card
    final Rect cardRect = Rect.fromCenter(center: Offset(cx + 15, cy + 10), width: 120, height: 80);
    final Paint cardBgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    // Draw card shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(cardRect.shift(const Offset(4, 4)), const Radius.circular(10)),
      Paint()..color = Colors.black.withOpacity(0.12)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(cardRect, const Radius.circular(10)),
      cardBgPaint,
    );
    
    // Draw card border
    canvas.drawRRect(
      RRect.fromRectAndRadius(cardRect, const Radius.circular(10)),
      Paint()
        ..color = AppColors.primaryCrimson.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Crimson Header Stripe on Card
    final Rect stripeRect = Rect.fromLTWH(cx - 45, cy - 30, 120, 20);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        stripeRect,
        topLeft: const Radius.circular(10),
        topRight: const Radius.circular(10),
      ),
      crimsonPaint..style = PaintingStyle.fill,
    );

    // Pass details (stub lines)
    final Paint linePaint = Paint()
      ..color = AppColors.textLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawLine(Offset(cx - 35, cy + 5), Offset(cx + 10, cy + 5), linePaint);
    canvas.drawLine(Offset(cx - 35, cy + 15), Offset(cx - 5, cy + 15), linePaint);

    // Mini Gold Pass Circle (representing pass status)
    canvas.drawCircle(Offset(cx + 35, cy + 28), 12, goldPaint);
    
    // Tiny Checkmark in Gold circle
    final Paint checkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx + 30, cy + 28), Offset(cx + 34, cy + 32), checkPaint);
    canvas.drawLine(Offset(cx + 34, cy + 32), Offset(cx + 42, cy + 24), checkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Slide 2 Painter: Route Tracking (Winding Path, Bus Icon, GPS Locator)
class RouteTrackingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    // Draw GPS pulsing circles
    final Paint pulsePaint = Paint()
      ..color = AppColors.primaryCrimson.withOpacity(0.08)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 100, pulsePaint);
    canvas.drawCircle(Offset(cx, cy), 70, pulsePaint..color = AppColors.primaryCrimson.withOpacity(0.12));

    // Winding path (dashed)
    final Path path = Path();
    path.moveTo(cx - 70, cy + 60);
    path.cubicTo(cx - 40, cy + 70, cx - 20, cy - 20, cx, cy);
    path.cubicTo(cx + 20, cy + 20, cx + 50, cy - 60, cx + 70, cy - 40);

    final Paint pathPaint = Paint()
      ..color = AppColors.secondaryDark.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    
    canvas.drawPath(path, pathPaint);

    // Draw Pin locator on top right
    final Paint pinPaint = Paint()
      ..color = AppColors.primaryCrimson
      ..style = PaintingStyle.fill;
    
    final double pinX = cx + 70;
    final double pinY = cy - 40;
    
    // Draw Pin Drop Shape
    final Path pinPath = Path();
    pinPath.moveTo(pinX, pinY);
    pinPath.cubicTo(pinX - 10, pinY - 10, pinX - 12, pinY - 22, pinX, pinY - 30);
    pinPath.cubicTo(pinX + 12, pinY - 30, pinX + 10, pinY - 10, pinX, pinY);
    canvas.drawPath(pinPath, pinPaint);
    canvas.drawCircle(Offset(pinX, pinY - 20), 4, Paint()..color = Colors.white);

    // Draw Bus Icon floating in middle
    final Rect busRect = Rect.fromCenter(center: Offset(cx - 15, cy + 10), width: 44, height: 32);
    final Paint busPaint = Paint()
      ..color = AppColors.primaryCrimson
      ..style = PaintingStyle.fill;
    
    // Bus shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(busRect.shift(const Offset(2, 2)), const Radius.circular(6)),
      Paint()..color = Colors.black.withOpacity(0.15)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
    );
    // Bus Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(busRect, const Radius.circular(6)),
      busPaint,
    );
    // Bus Windshield
    final Rect windowRect = Rect.fromLTWH(cx - 32, cy - 2, 10, 10);
    canvas.drawRect(windowRect, Paint()..color = Colors.white.withOpacity(0.7));
    // Side Windows
    canvas.drawRect(Rect.fromLTWH(cx - 18, cy - 2, 8, 10), Paint()..color = Colors.white.withOpacity(0.7));
    canvas.drawRect(Rect.fromLTWH(cx - 6, cy - 2, 8, 10), Paint()..color = Colors.white.withOpacity(0.7));

    // Wheels
    canvas.drawCircle(Offset(cx - 26, cy + 26), 5, Paint()..color = AppColors.secondaryDark);
    canvas.drawCircle(Offset(cx - 4, cy + 26), 5, Paint()..color = AppColors.secondaryDark);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Slide 3 Painter: Secure Payments (Shield, Card, Checkmark)
class SecurePaymentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    // Draw decorative background circles
    canvas.drawCircle(
      Offset(cx, cy),
      85,
      Paint()
        ..color = AppColors.accentGold.withOpacity(0.06)
        ..style = PaintingStyle.fill,
    );

    // Draw credit card back drop
    final Rect cardRect = Rect.fromCenter(center: Offset(cx - 15, cy - 15), width: 110, height: 70);
    final Paint cardPaint = Paint()
      ..color = AppColors.secondaryDark
      ..style = PaintingStyle.fill;
    
    // Draw shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(cardRect.shift(const Offset(3, 3)), const Radius.circular(8)),
      Paint()..color = Colors.black.withOpacity(0.1)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(cardRect, const Radius.circular(8)),
      cardPaint,
    );
    
    // Card Gold Chip
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - 60, cy - 40, 18, 14), const Radius.circular(3)),
      Paint()..color = AppColors.accentGold,
    );

    // Shield of security in foreground
    final double sx = cx + 25;
    final double sy = cy + 15;
    
    // Shield Shadow
    final Path shieldPath = Path();
    shieldPath.moveTo(sx, sy - 30);
    shieldPath.quadraticBezierTo(sx + 24, sy - 30, sx + 25, sy - 20);
    shieldPath.quadraticBezierTo(sx + 25, sy + 10, sx, sy + 30);
    shieldPath.quadraticBezierTo(sx - 25, sy + 10, sx - 25, sy - 20);
    shieldPath.quadraticBezierTo(sx - 24, sy - 30, sx, sy - 30);
    
    canvas.drawPath(
      shieldPath.shift(const Offset(3, 3)),
      Paint()..color = Colors.black.withOpacity(0.15)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
    );

    // Shield Body
    canvas.drawPath(
      shieldPath,
      Paint()..color = Colors.white..style = PaintingStyle.fill,
    );
    
    // Inner Crimson Shield
    canvas.drawPath(
      shieldPath,
      Paint()
        ..color = AppColors.primaryCrimson
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5,
    );

    // Inner checkmark in Shield
    final Paint checkPaint = Paint()
      ..color = AppColors.primaryCrimson
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(sx - 9, sy - 2), Offset(sx - 2, sy + 6), checkPaint);
    canvas.drawLine(Offset(sx - 2, sy + 6), Offset(sx + 10, sy - 8), checkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}



================================================
FILE: lib/features/auth/presentation/views/register_screen.dart
================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/routes/app_routes.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_state.dart';
import 'package:icem_bus/shared/app_card.dart';
import 'package:icem_bus/shared/app_text_field.dart';
import 'package:icem_bus/shared/custom_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _selectedRole;

  final List<String> _roles = [
    'Engineering Student',
    'BCA Student',
    'MCA Student',
    'Staff',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _studentIdController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onRegisterPressed() {
    if (_formKey.currentState!.validate()) {
      if (_selectedRole == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select your college role / course.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      
      ref.read(authControllerProvider.notifier).signUp(
            fullName: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            confirmPassword: _confirmPasswordController.text,
            role: _selectedRole!,
            mobile: _mobileController.text.trim().isNotEmpty ? _mobileController.text.trim() : null,
            collegeId: _studentIdController.text.trim().isNotEmpty ? _studentIdController.text.trim() : null,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    // Listen for AuthState mutations (Errors or successful registration redirects)
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(authControllerProvider.notifier).resetState();
      } else if (next.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful! Please check your inbox for verification link.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 4),
          ),
        );
        context.go(AppRoutes.login);
        ref.read(authControllerProvider.notifier).resetState();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),

              // App logo / branding
              Container(
                width: 76,
                height: 76,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryCrimson.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryCrimson.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/bus_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 18),

              const Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Join the ICEM Smart Bus Pass portal',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 26),

              // Inputs wrapped in PremiumCard
              Form(
                key: _formKey,
                child: PremiumCard(
                  padding: const EdgeInsets.all(22.0),
                  borderRadius: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section: Personal Details
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppColors.primaryCrimson,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Personal Information',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Full Name
                      AppTextField(
                        controller: _nameController,
                        label: 'Full Name',
                        hintText: 'e.g. Yash Kacholiya',
                        keyboardType: TextInputType.name,
                        prefixIcon: Icons.person_outline_rounded,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Full name is required.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Email
                      AppTextField(
                        controller: _emailController,
                        label: 'College Email Address',
                        hintText: 'student@indiraicem.ac.in',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.email_outlined,
                        validator: (value) {
                          return ref.read(authControllerProvider.notifier).validateEmail(value ?? '');
                        },
                      ),
                      const SizedBox(height: 16),

                      // Mobile Number
                      AppTextField(
                        controller: _mobileController,
                        label: 'Mobile Number',
                        hintText: '+91 98765 43210',
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_outlined,
                      ),
                      const SizedBox(height: 24),

                      // Section: Academic Details
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppColors.primaryCrimson,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Academic Details',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Course / Role Dropdown
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Course / Role',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedRole,
                            dropdownColor: AppColors.cardSurface,
                            borderRadius: BorderRadius.circular(16),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.surfaceElevated,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.textMuted, size: 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: AppColors.borderSubtle),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: AppColors.borderSubtle),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: AppColors.primaryCrimson, width: 1.5),
                              ),
                            ),
                            hint: const Text('Select course / role', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                            items: _roles.map((String role) {
                              return DropdownMenuItem<String>(
                                value: role,
                                child: Text(role),
                              );
                            }).toList(),
                            onChanged: (value) => setState(() => _selectedRole = value),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select your role / course.';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Student ID / PRN
                      AppTextField(
                        controller: _studentIdController,
                        label: 'Student ID / PRN (Optional)',
                        hintText: 'e.g. ICEM2026CS001',
                        prefixIcon: Icons.pin_outlined,
                      ),
                      const SizedBox(height: 24),

                      // Section: Security
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppColors.primaryCrimson,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Account Security',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Password
                      AppTextField(
                        controller: _passwordController,
                        label: 'Password',
                        hintText: 'At least 6 characters',
                        isPassword: true,
                        prefixIcon: Icons.lock_outline_rounded,
                        validator: (value) {
                          return ref.read(authControllerProvider.notifier).validatePassword(value ?? '');
                        },
                      ),
                      const SizedBox(height: 16),

                      // Confirm Password
                      AppTextField(
                        controller: _confirmPasswordController,
                        label: 'Confirm Password',
                        hintText: 'Re-enter your password',
                        isPassword: true,
                        prefixIcon: Icons.lock_outline_rounded,
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return 'Passwords do not match.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 26),

                      // Register Button
                      PrimaryButton(
                        text: 'CREATE ACCOUNT',
                        icon: Icons.person_add_rounded,
                        isLoading: authState.isLoading,
                        onPressed: _onRegisterPressed,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // OR Divider
              Row(
                children: [
                  const Expanded(child: Divider(color: AppColors.borderSubtle, thickness: 1)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: AppColors.borderSubtle, thickness: 1)),
                ],
              ),
              const SizedBox(height: 24),

              // Google Sign-Up Button
              SecondaryButton(
                text: 'Sign Up with Google',
                icon: Icons.g_mobiledata_rounded,
                isLoading: authState.isLoading,
                onPressed: () => ref.read(authControllerProvider.notifier).signInWithGoogle(),
              ),
              const SizedBox(height: 32),

              // Login Redirection Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.login),
                    child: const Text(
                      'Sign In',
                      style: TextStyle(
                        color: AppColors.primaryCrimson,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}



================================================
FILE: lib/features/auth/presentation/views/splash_screen.dart
================================================
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/constants/app_constants.dart';
import 'package:icem_bus/config/routes/app_routes.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/auth/domain/entities/user_entity.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/services/storage/storage_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
      ),
    );

    _animationController.forward();
    _startNavigationTimer();
  }

  void _startNavigationTimer() {
    Timer(AppConstants.splashDuration, () async {
      if (!mounted) return;
      
      User? firebaseUser;
      try {
        firebaseUser = FirebaseAuth.instance.currentUser;
      } catch (_) {
        // Safe fallback for widget tests where Firebase is not initialized
      }
      
      if (firebaseUser != null) {
        try {
          // Query Firestore directly to bypass any asynchronous Riverpod race conditions on launch
          final doc = await FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).get();
          if (!mounted) return;

          String? role;
          if (doc.exists) {
            final data = doc.data();
            role = UserEntity.normalizeRole(data?['role'] as String?);
          }

          // Pre-initialize controller state so the user object is immediately available to downstream dashboard views
          await ref.read(authControllerProvider.notifier).checkCurrentUser();

          if (!mounted) return;
          
          const supportedRoles = {'Admin', 'Staff', 'Engineering Student', 'BCA Student', 'MCA Student'};

          if (role != null && role.isNotEmpty && supportedRoles.contains(role)) {
            if (role == 'Admin') {
              context.go(AppRoutes.adminDashboard);
            } else if (role == 'Staff') {
              context.go(AppRoutes.staffDashboard);
            } else {
              context.go(AppRoutes.studentDashboard);
            }
          } else {
            await ref.read(authControllerProvider.notifier).logout();
            if (!mounted) return;
            context.go(AppRoutes.login);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('User role not found. Contact the administrator.'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        } catch (_) {
          if (!mounted) return;
          // Fallback to login if check fails due to offline state
          context.go(AppRoutes.login);
        }
      } else {
        final storage = ref.read(storageServiceProvider);
        if (storage.isOnboardingCompleted) {
          context.go(AppRoutes.login);
        } else {
          context.go(AppRoutes.onboarding);
        }
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Ambient subtle crimson glow centered behind the logo/title
          Center(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryCrimson.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Safe Area with responsive centered composition
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. [ICEM LOGO] in a premium rounded container
                      Container(
                        width: 104,
                        height: 104,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: AppColors.primaryCrimson.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryCrimson.withValues(alpha: 0.22),
                              blurRadius: 28,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/bus_logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 22),

                      // 2. [INDIRA COLLEGE OF ENGINEERING & MANAGEMENT] in a premium pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryCrimson.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primaryCrimson.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'INDIRA COLLEGE OF ENGINEERING & MANAGEMENT',
                            style: TextStyle(
                              color: AppColors.primaryCrimson,
                              fontWeight: FontWeight.w700,
                              fontSize: 10.5,
                              letterSpacing: 1.0,
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 3. [ICEM SMART BUS PASS] primary responsive title
                      const Text(
                        'ICEM',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: 2.0,
                          fontFamily: 'Outfit',
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'SMART BUS PASS',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryCrimson,
                            letterSpacing: 1.4,
                            fontFamily: 'Outfit',
                            height: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 4. [Secure Campus Mobility] subtitle
                      Text(
                        'Secure Campus Mobility',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary.withValues(alpha: 0.9),
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 5. [Smart • Secure • Connected] tagline
                      const Text(
                        'Smart • Secure • Connected',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // 6. Subtle loading spinner (never overlaps, clean spacing)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: AppColors.primaryCrimson,
                          strokeWidth: 2.2,
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
    );
  }
}



================================================
FILE: lib/features/auth/presentation/views/.gitkeep
================================================
[Empty file]


================================================
FILE: lib/features/bus_pass/.gitkeep
================================================
[Empty file]


================================================
FILE: lib/features/bus_pass/data/.gitkeep
================================================
[Empty file]


================================================
FILE: lib/features/bus_pass/data/models/bus_pass_model.dart
================================================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:icem_bus/features/bus_pass/domain/entities/bus_pass_entity.dart';

class BusPassModel extends BusPassEntity {
  const BusPassModel({
    required super.uid,
    required super.passId,
    super.passNumber,
    super.applicationId,
    super.studentId,
    required super.route,
    super.routeName,
    required super.routeId,
    required super.boardingStop,
    required super.destinationStop,
    required super.fare,
    super.busNumber,
    required super.status,
    required super.paymentStatus,
    super.applicationStatus,
    required super.expiryDate,
    super.validFrom,
    super.validUntil,
    super.department,
    super.course,
    super.year,
    super.distance,
    super.qrCode,
    super.busId,
    super.paymentId,
    super.createdAt,
    super.approvedAt,
  });

  /// Convert a Firestore Map into a BusPassModel
  factory BusPassModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val is Timestamp) return val.toDate();
      if (val is String && val.isNotEmpty) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      return fallback ?? DateTime.now();
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String && val.isNotEmpty) return DateTime.tryParse(val);
      return null;
    }

    final String passId = map['passId'] as String? ?? '';
    final String? passNumber = map['passNumber'] as String? ??
        (passId.startsWith('ICEM-BP-') ? passId : null);

    final expiry = parseDate(
      map['validUntil'] ?? map['expiryDate'],
      DateTime.now().add(const Duration(days: 180)),
    );

    return BusPassModel(
      uid: map['uid'] as String? ?? map['studentId'] as String? ?? '',
      passId: passId,
      passNumber: passNumber,
      applicationId: map['applicationId'] as String? ?? map['passId'] as String?,
      studentId: map['studentId'] as String? ?? map['uid'] as String?,
      route: map['route'] as String? ?? map['routeName'] as String? ?? '',
      routeName: map['routeName'] as String? ?? map['route'] as String?,
      routeId: map['routeId'] as String? ?? '',
      boardingStop: map['boardingStop'] as String? ?? '',
      destinationStop: map['destinationStop'] as String? ?? '',
      fare: (map['fare'] as num?)?.toDouble() ?? 0.0,
      busNumber: map['busNumber'] as String?,
      status: map['passStatus'] as String? ??
          map['status'] as String? ??
          'Payment Pending',
      paymentStatus: map['paymentStatus'] as String? ?? 'Pending',
      applicationStatus: map['applicationStatus'] as String? ??
          (map['status'] == 'Approved' ? 'Approved' : map['status'] as String?),
      expiryDate: expiry,
      validFrom: parseNullableDate(map['validFrom']),
      validUntil: parseNullableDate(map['validUntil']) ?? expiry,
      department: map['department'] as String?,
      course: map['course'] as String?,
      year: map['year'] as String?,
      distance: map['distance'] as String?,
      qrCode: map['qrCode'] as String?,
      busId: map['busId'] as String?,
      paymentId: map['paymentId'] as String?,
      createdAt: parseNullableDate(map['createdAt']),
      approvedAt: parseNullableDate(map['approvedAt']),
    );
  }

  /// Convert a BusPassModel into a Firestore Map
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'studentId': studentId ?? uid,
      'passId': passId,
      if (passNumber != null && passNumber!.isNotEmpty) 'passNumber': passNumber,
      if (applicationId != null && applicationId!.isNotEmpty)
        'applicationId': applicationId,
      'route': route,
      'routeName': routeName ?? route,
      'routeId': routeId,
      'boardingStop': boardingStop,
      'destinationStop': destinationStop,
      'fare': fare,
      'busNumber': busNumber,
      'passStatus': status,
      'status': status,
      'paymentStatus': paymentStatus,
      if (applicationStatus != null) 'applicationStatus': applicationStatus,
      'expiryDate': Timestamp.fromDate(expiryDate),
      'validUntil': Timestamp.fromDate(validUntil ?? expiryDate),
      if (validFrom != null) 'validFrom': Timestamp.fromDate(validFrom!),
      'department': department,
      'course': course,
      'year': year,
      'distance': distance,
      'qrCode': qrCode,
      'busId': busId,
      if (paymentId != null) 'paymentId': paymentId,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (approvedAt != null) 'approvedAt': Timestamp.fromDate(approvedAt!),
    };
  }

  /// Create a copy of this model with modified fields
  BusPassModel copyWith({
    String? uid,
    String? passId,
    String? passNumber,
    String? applicationId,
    String? studentId,
    String? route,
    String? routeName,
    String? routeId,
    String? boardingStop,
    String? destinationStop,
    double? fare,
    String? busNumber,
    String? status,
    String? paymentStatus,
    String? applicationStatus,
    DateTime? expiryDate,
    DateTime? validFrom,
    DateTime? validUntil,
    String? department,
    String? course,
    String? year,
    String? distance,
    String? qrCode,
    String? busId,
    String? paymentId,
    DateTime? createdAt,
    DateTime? approvedAt,
  }) {
    return BusPassModel(
      uid: uid ?? this.uid,
      passId: passId ?? this.passId,
      passNumber: passNumber ?? this.passNumber,
      applicationId: applicationId ?? this.applicationId,
      studentId: studentId ?? this.studentId,
      route: route ?? this.route,
      routeName: routeName ?? this.routeName,
      routeId: routeId ?? this.routeId,
      boardingStop: boardingStop ?? this.boardingStop,
      destinationStop: destinationStop ?? this.destinationStop,
      fare: fare ?? this.fare,
      busNumber: busNumber ?? this.busNumber,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      applicationStatus: applicationStatus ?? this.applicationStatus,
      expiryDate: expiryDate ?? this.expiryDate,
      validFrom: validFrom ?? this.validFrom,
      validUntil: validUntil ?? this.validUntil,
      department: department ?? this.department,
      course: course ?? this.course,
      year: year ?? this.year,
      distance: distance ?? this.distance,
      qrCode: qrCode ?? this.qrCode,
      busId: busId ?? this.busId,
      paymentId: paymentId ?? this.paymentId,
      createdAt: createdAt ?? this.createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
    );
  }
}




================================================
FILE: lib/features/bus_pass/data/repositories/bus_pass_repository_impl.dart
================================================
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/core/errors/failures.dart';
import 'package:icem_bus/features/bus_pass/data/models/bus_pass_model.dart';
import 'package:icem_bus/features/bus_pass/domain/entities/bus_pass_entity.dart';
import 'package:icem_bus/features/bus_pass/domain/repositories/bus_pass_repository.dart';

final busPassRepositoryProvider = Provider<BusPassRepository>((ref) {
  return BusPassRepositoryImpl(firestore: FirebaseFirestore.instance);
});

class BusPassRepositoryImpl implements BusPassRepository {
  final FirebaseFirestore firestore;

  BusPassRepositoryImpl({required this.firestore});

  @override
  Future<BusPassEntity?> getBusPass(String uid) async {
    try {
      final doc = await firestore.collection('bus_passes').doc(uid).get();
      if (!doc.exists) return null;

      final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      final pass = BusPassModel.fromMap(data);
      _triggerQrGenerationIfNeeded(pass);
      return pass;
    } catch (e) {
      throw ServerFailure('Failed to fetch bus pass status: ${e.toString()}');
    }
  }

  @override
  Stream<BusPassEntity?> watchBusPass(String uid) {
    return firestore
        .collection('bus_passes')
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      final pass = BusPassModel.fromMap(data);
      _triggerQrGenerationIfNeeded(pass);
      return pass;
    });
  }

  void _triggerQrGenerationIfNeeded(BusPassEntity pass) {
    if (pass.isActive) {
      if (pass.qrCode != null && pass.qrCode!.isNotEmpty) {
        try {
          final Map<String, dynamic> payload = jsonDecode(pass.qrCode!);
          if (payload['passNumber'] == pass.effectivePassNumber &&
              payload['passId'] == pass.passId &&
              payload['validUntil'] == pass.effectiveValidUntil.toIso8601String() &&
              payload['passStatus'] == pass.status) {
            return;
          }
        } catch (_) {}
      }

      _generateAndStoreQrCode(pass);
    }
  }

  Future<void> _generateAndStoreQrCode(BusPassEntity pass) async {
    try {
      final validFrom = pass.validFrom ?? DateTime.now();
      final validUntil = pass.effectiveValidUntil;

      // Secure payload with unique references (no passwords, secrets or private data)
      final Map<String, dynamic> qrPayloadMap = {
        'type': 'ICEM_BUS_PASS',
        'passNumber': pass.effectivePassNumber,
        'passId': pass.passId,
        'studentId': pass.uid,
        'routeId': pass.routeId,
        'validUntil': validUntil.toIso8601String(),
        'passStatus': pass.status,
      };

      final String qrPayload = jsonEncode(qrPayloadMap);

      await firestore.collection('bus_passes').doc(pass.uid).update({
        'qrCode': qrPayload,
        'validFrom': Timestamp.fromDate(validFrom),
        'validUntil': Timestamp.fromDate(validUntil),
        'expiryDate': Timestamp.fromDate(validUntil),
        'passNumber': pass.effectivePassNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Ignore background errors
    }
  }

  @override
  Future<BusPassEntity> applyForBusPass({
    required String uid,
    required String route,
    required String routeId,
    required String boardingStop,
    required String destinationStop,
    required double fare,
    String? distance,
    String? department,
  }) async {
    try {
      final passId = 'ICEM-PASS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      
      // Fetch student info
      final userDoc = await firestore.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? {};
      
      final passModel = BusPassModel(
        uid: uid,
        passId: passId,
        route: route,
        routeId: routeId,
        boardingStop: boardingStop,
        destinationStop: destinationStop,
        fare: fare,
        busNumber: null, // Assigned later by Admin
        status: 'Payment Pending', // Initial application status must be: Payment Pending
        paymentStatus: 'Pending', // Pending payment
        expiryDate: DateTime.now().add(const Duration(days: 180)),
        qrCode: null,
        validFrom: null,
        busId: null,
        distance: distance,
        department: department ?? userData['department'],
      );

      final Map<String, dynamic> appData = passModel.toMap();
      appData['applicationId'] = passId;
      appData['passId'] = passId;
      appData['uid'] = uid;
      appData['studentId'] = uid;
      appData['fullName'] = userData['fullName'] ?? 'Student';
      appData['email'] = userData['email'] ?? '';
      appData['prn'] = userData['prn'] ?? '';
      appData['mobile'] = userData['mobile'] ?? '';
      appData['collegeId'] = userData['collegeId'] ?? '';
      appData['department'] = department ?? userData['department'] ?? '';
      appData['course'] = userData['course'] ?? '';
      appData['year'] = userData['year'] ?? '';
      appData['semester'] = userData['semester'] ?? '';
      appData['status'] = 'Payment Pending';
      appData['passStatus'] = 'Payment Pending';
      appData['paymentStatus'] = 'Pending';
      appData['createdAt'] = FieldValue.serverTimestamp();
      appData['updatedAt'] = FieldValue.serverTimestamp();

      // Save to applications collection
      await firestore.collection('bus_pass_applications').doc(passId).set(appData);
      
      // Update/create the bus_passes document (Pass is NOT active, payment is pending)
      final Map<String, dynamic> passDocData = passModel.toMap();
      passDocData['status'] = 'Payment Pending';
      passDocData['passStatus'] = 'Payment Pending';
      passDocData['paymentStatus'] = 'Pending';
      passDocData['createdAt'] = FieldValue.serverTimestamp();
      passDocData['updatedAt'] = FieldValue.serverTimestamp();
      await firestore.collection('bus_passes').doc(uid).set(passDocData);

      return passModel;
    } catch (e) {
      throw ServerFailure('Failed to register pass application: ${e.toString()}');
    }
  }

  @override
  Future<BusPassEntity> renewBusPass(String uid) async {
    try {
      final currentPass = await getBusPass(uid);
      if (currentPass == null) {
        throw const AuthFailure('No existing pass record found to renew.');
      }

      final renewedModel = BusPassModel(
        uid: currentPass.uid,
        passId: currentPass.passId,
        route: currentPass.route,
        routeId: currentPass.routeId,
        boardingStop: currentPass.boardingStop,
        destinationStop: currentPass.destinationStop,
        fare: currentPass.fare,
        busNumber: currentPass.busNumber,
        status: 'Payment Pending', // Resets to Payment Pending
        paymentStatus: 'Pending',
        expiryDate: DateTime.now().add(const Duration(days: 180)),
        department: currentPass.department,
        distance: currentPass.distance,
        qrCode: null,
        validFrom: null,
        busId: null,
      );

      await firestore.collection('bus_passes').doc(uid).set(renewedModel.toMap());
      return renewedModel;
    } catch (e) {
      throw ServerFailure('Failed to process pass renewal: ${e.toString()}');
    }
  }

  @override
  Future<BusPassEntity> updatePassPayment({
    required String uid,
    required bool isSuccess,
  }) async {
    try {
      final currentPass = await getBusPass(uid);
      if (currentPass == null) {
        throw const AuthFailure('No pass application found.');
      }

      // CRITICAL SECURITY FIX:
      // When payment is successful, status becomes 'Pending' (waiting for Admin approval).
      // It MUST NOT become 'Active' or 'Approved' before Admin approval!
      final updatedModel = BusPassModel(
        uid: currentPass.uid,
        passId: currentPass.passId,
        route: currentPass.route,
        routeId: currentPass.routeId,
        boardingStop: currentPass.boardingStop,
        destinationStop: currentPass.destinationStop,
        fare: currentPass.fare,
        busNumber: currentPass.busNumber,
        status: isSuccess ? 'Pending' : 'Payment Pending',
        paymentStatus: isSuccess ? 'Paid' : 'Pending',
        expiryDate: currentPass.expiryDate,
        department: currentPass.department,
        distance: currentPass.distance,
        qrCode: null, // Blocked until Admin approval
        validFrom: null, // Blocked until Admin approval
        busId: currentPass.busId,
      );

      await firestore.collection('bus_passes').doc(uid).set(updatedModel.toMap());
      return updatedModel;
    } catch (e) {
      throw ServerFailure('Failed to update pass payment: ${e.toString()}');
    }
  }
}



================================================
FILE: lib/features/bus_pass/domain/.gitkeep
================================================
[Empty file]


================================================
FILE: lib/features/bus_pass/domain/entities/bus_pass_entity.dart
================================================
class BusPassEntity {
  final String uid;
  final String passId;
  final String? passNumber;
  final String? applicationId;
  final String? studentId;
  final String route;
  final String? routeName;
  final String routeId;
  final String boardingStop;
  final String destinationStop;
  final double fare;
  final String? busNumber;
  final String status; // 'Active', 'Pending', 'Expired', 'Revoked', 'Rejected', 'Payment Pending'
  final String paymentStatus; // 'Paid', 'Pending', 'Unpaid', 'Failed'
  final String? applicationStatus; // 'Approved', 'Pending', 'Rejected'
  final DateTime expiryDate;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final String? department;
  final String? course;
  final String? year;
  final String? distance;
  final String? qrCode;
  final String? busId;
  final String? paymentId;
  final DateTime? createdAt;
  final DateTime? approvedAt;

  const BusPassEntity({
    required this.uid,
    required this.passId,
    this.passNumber,
    this.applicationId,
    this.studentId,
    required this.route,
    this.routeName,
    required this.routeId,
    required this.boardingStop,
    required this.destinationStop,
    required this.fare,
    this.busNumber,
    required this.status,
    required this.paymentStatus,
    this.applicationStatus,
    required this.expiryDate,
    this.validFrom,
    this.validUntil,
    this.department,
    this.course,
    this.year,
    this.distance,
    this.qrCode,
    this.busId,
    this.paymentId,
    this.createdAt,
    this.approvedAt,
  });

  String get effectivePassNumber =>
      (passNumber != null && passNumber!.isNotEmpty) ? passNumber! : passId;

  DateTime get effectiveValidUntil => validUntil ?? expiryDate;

  String get effectiveRouteName =>
      (routeName != null && routeName!.isNotEmpty) ? routeName! : route;

  String get effectiveStudentId =>
      (studentId != null && studentId!.isNotEmpty) ? studentId! : uid;

  bool get isExpired => DateTime.now().isAfter(effectiveValidUntil);

  bool get isRevoked => status.trim().toLowerCase() == 'revoked';

  bool get isPaid =>
      paymentStatus.trim().toLowerCase() == 'paid' ||
      paymentStatus.trim().toLowerCase() == 'success';

  bool get isApproved =>
      (applicationStatus != null &&
          applicationStatus!.trim().toLowerCase() == 'approved') ||
      status.trim().toLowerCase() == 'approved' ||
      status.trim().toLowerCase() == 'active';

  /// True ONLY when paymentStatus == 'Paid' AND applicationStatus == 'Approved'
  /// AND not expired AND not revoked
  bool get isActive =>
      isPaid &&
      isApproved &&
      !isExpired &&
      !isRevoked &&
      (status.trim().toLowerCase() == 'active' ||
          status.trim().toLowerCase() == 'approved');
}




================================================
FILE: lib/features/bus_pass/domain/repositories/bus_pass_repository.dart
================================================
import 'package:icem_bus/features/bus_pass/domain/entities/bus_pass_entity.dart';

abstract class BusPassRepository {
  /// Fetch a student's active bus pass profile by UID
  Future<BusPassEntity?> getBusPass(String uid);

  /// Watch student's bus pass status in real-time
  Stream<BusPassEntity?> watchBusPass(String uid);

  /// Apply for a new bus pass
  Future<BusPassEntity> applyForBusPass({
    required String uid,
    required String route,
    required String routeId,
    required String boardingStop,
    required String destinationStop,
    required double fare,
    String? distance,
    String? department,
  });

  /// Renew an expired or existing bus pass
  Future<BusPassEntity> renewBusPass(String uid);

  /// Update pass status and payment status in Firestore based on payment result
  Future<BusPassEntity> updatePassPayment({
    required String uid,
    required bool isSuccess,
  });
}



================================================
FILE: lib/features/bus_pass/presentation/.gitkeep
================================================
[Empty file]


================================================
FILE: lib/features/bus_pass/presentation/controllers/bus_pass_controller.dart
================================================
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/features/bus_pass/data/repositories/bus_pass_repository_impl.dart';
import 'package:icem_bus/features/bus_pass/domain/entities/bus_pass_entity.dart';

final busPassControllerProvider = NotifierProvider<BusPassController, AsyncValue<BusPassEntity?>>(BusPassController.new);

class BusPassController extends Notifier<AsyncValue<BusPassEntity?>> {
  StreamSubscription<BusPassEntity?>? _subscription;

  @override
  AsyncValue<BusPassEntity?> build() {
    // Reactively watch user session changes
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    ref.onDispose(() {
      _subscription?.cancel();
    });

    if (user != null) {
      _subscription?.cancel();
      _subscription = ref.read(busPassRepositoryProvider).watchBusPass(user.uid).listen(
        (pass) {
          state = AsyncValue.data(pass);
        },
        onError: (err, stack) {
          state = AsyncValue.error(err, stack);
        },
      );
    } else {
      return const AsyncValue.data(null);
    }
    return const AsyncValue.loading();
  }

  /// Load bus pass details from database (falls back to single load if needed)
  Future<void> loadBusPass(String uid) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(busPassRepositoryProvider);
      final pass = await repository.getBusPass(uid);
      state = AsyncValue.data(pass);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Submit a new bus pass application
  Future<bool> applyForPass({
    required String route,
    required String routeId,
    required String boardingStop,
    required String destinationStop,
    required double fare,
    String? distance,
    String? department,
  }) async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return false;

    state = const AsyncValue.loading();
    try {
      final repository = ref.read(busPassRepositoryProvider);
      final pass = await repository.applyForBusPass(
        uid: user.uid,
        route: route,
        routeId: routeId,
        boardingStop: boardingStop,
        destinationStop: destinationStop,
        fare: fare,
        distance: distance,
        department: department,
      );
      state = AsyncValue.data(pass);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  /// Request pass renewal
  Future<bool> renewPass() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return false;

    state = const AsyncValue.loading();
    try {
      final repository = ref.read(busPassRepositoryProvider);
      final pass = await repository.renewBusPass(user.uid);
      state = AsyncValue.data(pass);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  /// Process simulated payment outcomes
  Future<bool> completePassPayment({required bool isSuccess}) async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return false;

    state = const AsyncValue.loading();
    try {
      final repository = ref.read(busPassRepositoryProvider);
      final pass = await repository.updatePassPayment(uid: user.uid, isSuccess: isSuccess);
      state = AsyncValue.data(pass);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
}



================================================
FILE: lib/features/bus_pass/presentation/views/qr_verification_screen.dart
================================================
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

enum VerificationStatus {
  valid,
  invalid,
  expired,
  revoked,
  notActive,
}

class VerificationResult {
  final VerificationStatus status;
  final String title;
  final String? studentName;
  final String? passNumber;
  final String? route;
  final String? boardingStop;
  final String? validUntil;
  final String? message;

  const VerificationResult({
    required this.status,
    required this.title,
    this.studentName,
    this.passNumber,
    this.route,
    this.boardingStop,
    this.validUntil,
    this.message,
  });
}

class QrVerificationScreen extends ConsumerStatefulWidget {
  const QrVerificationScreen({super.key});

  @override
  ConsumerState<QrVerificationScreen> createState() =>
      _QrVerificationScreenState();
}

class _QrVerificationScreenState extends ConsumerState<QrVerificationScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isProcessing = false;
  bool _isTorchOn = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    for (final barcode in capture.barcodes) {
      final String? rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.trim().isNotEmpty) {
        _verifyCode(rawValue.trim());
        break;
      }
    }
  }

  Future<void> _verifyCode(String rawCode) async {
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    try {
      final result = await _performBackendVerification(rawCode);
      if (!mounted) return;
      _showResultBottomSheet(result);
    } catch (e) {
      if (!mounted) return;
      _showResultBottomSheet(VerificationResult(
        status: VerificationStatus.invalid,
        title: '✕ Invalid Pass',
        message: 'Verification check failed: $e',
      ));
    }
  }

  Future<VerificationResult> _performBackendVerification(String raw) async {
    String passNumber = '';
    String passId = '';
    String studentId = '';

    // 1. Try parsing as JSON payload
    try {
      if (raw.startsWith('{') && raw.endsWith('}')) {
        final Map<String, dynamic> data = jsonDecode(raw);
        passNumber = (data['passNumber'] as String? ?? '').trim();
        passId = (data['passId'] as String? ?? '').trim();
        studentId = (data['studentId'] as String? ??
                data['studentUid'] as String? ??
                '')
            .trim();
      }
    } catch (_) {}

    // 2. Try parsing plain string
    if (passNumber.isEmpty && passId.isEmpty && studentId.isEmpty) {
      if (raw.startsWith('ICEM_PASS:')) {
        passNumber = raw.replaceFirst('ICEM_PASS:', '').trim();
      } else if (raw.startsWith('ICEM-BP-')) {
        passNumber = raw;
      } else if (raw.startsWith('ICEM-PASS-')) {
        passId = raw;
      } else {
        studentId = raw;
      }
    }

    final firestore = FirebaseFirestore.instance;
    Map<String, dynamic>? passData;

    // A) Search in bus_passes
    if (passNumber.isNotEmpty) {
      final snap = await firestore
          .collection('bus_passes')
          .where('passNumber', isEqualTo: passNumber)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) passData = snap.docs.first.data();
    }

    if (passData == null && passId.isNotEmpty) {
      final snap = await firestore
          .collection('bus_passes')
          .where('passId', isEqualTo: passId)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) passData = snap.docs.first.data();
    }

    if (passData == null && studentId.isNotEmpty) {
      final doc = await firestore.collection('bus_passes').doc(studentId).get();
      if (doc.exists && doc.data() != null) passData = doc.data()!;
    }

    // B) Fallback: Search in bus_pass_applications
    if (passData == null) {
      if (passNumber.isNotEmpty) {
        final snap = await firestore
            .collection('bus_pass_applications')
            .where('passNumber', isEqualTo: passNumber)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) passData = snap.docs.first.data();
      }
      if (passData == null && passId.isNotEmpty) {
        final doc = await firestore
            .collection('bus_pass_applications')
            .doc(passId)
            .get();
        if (doc.exists && doc.data() != null) passData = doc.data()!;
      }
      if (passData == null && (passNumber.isNotEmpty || raw.isNotEmpty)) {
        final queryVal = passNumber.isNotEmpty ? passNumber : raw;
        final snap = await firestore
            .collection('bus_pass_applications')
            .where('applicationId', isEqualTo: queryVal)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) passData = snap.docs.first.data();
      }
    }

    // Result 1: Not found -> INVALID PASS
    if (passData == null) {
      return const VerificationResult(
        status: VerificationStatus.invalid,
        title: '✕ Invalid Pass',
        message: 'No bus pass record found in the ICEM database for this code.',
      );
    }

    // Extract student name
    String studentName = passData['fullName'] as String? ??
        passData['studentName'] as String? ??
        '';
    final uid = passData['uid'] as String? ?? passData['studentId'] as String? ?? '';
    if (studentName.isEmpty && uid.isNotEmpty) {
      final uDoc = await firestore.collection('users').doc(uid).get();
      if (uDoc.exists && uDoc.data() != null) {
        studentName = uDoc.data()?['fullName'] as String? ?? '';
      }
    }
    if (studentName.isEmpty) studentName = 'Student';

    final effectivePassNo = (passData['passNumber'] as String? ?? '').isNotEmpty
        ? passData['passNumber'] as String
        : (passData['passId'] as String? ?? 'N/A');

    final route = (passData['routeName'] as String? ??
            passData['route'] as String? ??
            'General Route')
        .toString();
    final boardingStop =
        (passData['boardingStop'] as String? ?? 'Campus').toString();

    // Validity date
    DateTime? validUntilDate;
    final vu = passData['validUntil'] ?? passData['expiryDate'];
    if (vu is Timestamp) {
      validUntilDate = vu.toDate();
    } else if (vu is String && vu.isNotEmpty) {
      validUntilDate = DateTime.tryParse(vu);
    }

    final validUntilFormatted = validUntilDate != null
        ? '${validUntilDate.day.toString().padLeft(2, '0')}/${validUntilDate.month.toString().padLeft(2, '0')}/${validUntilDate.year}'
        : 'N/A';

    final passStatus = (passData['passStatus'] as String? ??
            passData['status'] as String? ??
            '')
        .trim();
    final passStatusLower = passStatus.toLowerCase();

    final paymentStatus = (passData['paymentStatus'] as String? ?? '').trim();
    final isPaid = paymentStatus.toLowerCase() == 'paid' ||
        paymentStatus.toLowerCase() == 'success';

    final appStatus = (passData['applicationStatus'] as String? ??
            passData['status'] as String? ??
            '')
        .trim();
    final isApproved = appStatus.toLowerCase() == 'approved' ||
        passStatusLower == 'approved' ||
        passStatusLower == 'active';

    // Result 2: Revoked -> PASS REVOKED
    if (passStatusLower == 'revoked') {
      return VerificationResult(
        status: VerificationStatus.revoked,
        title: 'PASS REVOKED',
        studentName: studentName,
        passNumber: effectivePassNo,
        route: route,
        boardingStop: boardingStop,
        validUntil: validUntilFormatted,
        message: 'This pass has been revoked by ICEM administration.',
      );
    }

    // Result 3: Expired -> PASS EXPIRED
    if (validUntilDate != null && DateTime.now().isAfter(validUntilDate)) {
      return VerificationResult(
        status: VerificationStatus.expired,
        title: 'PASS EXPIRED',
        studentName: studentName,
        passNumber: effectivePassNo,
        route: route,
        boardingStop: boardingStop,
        validUntil: validUntilFormatted,
        message: 'This pass expired on $validUntilFormatted.',
      );
    }

    // Result 4: Unpaid or Unapproved -> PASS NOT ACTIVE
    if (!isPaid || !isApproved || (passStatusLower != 'active' && passStatusLower != 'approved')) {
      final String reason = !isPaid
          ? 'Payment has not been completed or verified.'
          : 'Application is awaiting administrative approval.';
      return VerificationResult(
        status: VerificationStatus.notActive,
        title: 'PASS NOT ACTIVE',
        studentName: studentName,
        passNumber: effectivePassNo,
        route: route,
        boardingStop: boardingStop,
        validUntil: validUntilFormatted,
        message: reason,
      );
    }

    // Result 5: Valid -> VALID PASS (✓ ACTIVE)
    return VerificationResult(
      status: VerificationStatus.valid,
      title: 'VALID PASS',
      studentName: studentName,
      passNumber: effectivePassNo,
      route: route,
      boardingStop: boardingStop,
      validUntil: validUntilFormatted,
      message: '✓ ACTIVE',
    );
  }

  void _showResultBottomSheet(VerificationResult result) {
    Color headerColor;
    Color bgColor;
    IconData icon;

    switch (result.status) {
      case VerificationStatus.valid:
        headerColor = AppColors.success;
        bgColor = AppColors.success.withValues(alpha: 0.12);
        icon = Icons.check_circle_rounded;
        break;
      case VerificationStatus.expired:
        headerColor = AppColors.warning;
        bgColor = AppColors.warning.withValues(alpha: 0.12);
        icon = Icons.warning_amber_rounded;
        break;
      case VerificationStatus.revoked:
      case VerificationStatus.invalid:
      case VerificationStatus.notActive:
        headerColor = AppColors.error;
        bgColor = AppColors.error.withValues(alpha: 0.12);
        icon = Icons.cancel_rounded;
        break;
    }

    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: AppColors.borderSubtle),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 28,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Status Header Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: headerColor.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: headerColor, size: 34),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.title,
                            style: TextStyle(
                              color: headerColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          if (result.message != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              result.message!,
                              style: TextStyle(
                                color: headerColor.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Details section (if student details present)
              if (result.studentName != null) ...[
                _buildVerificationRow('Student', result.studentName!),
                const Divider(height: 18, color: AppColors.borderSubtle),
                _buildVerificationRow('Pass', result.passNumber ?? 'N/A'),
                const Divider(height: 18, color: AppColors.borderSubtle),
                _buildVerificationRow('Route', result.route ?? 'N/A'),
                const Divider(height: 18, color: AppColors.borderSubtle),
                _buildVerificationRow('Boarding Stop', result.boardingStop ?? 'N/A'),
                const Divider(height: 18, color: AppColors.borderSubtle),
                _buildVerificationRow('Valid Until', result.validUntil ?? 'N/A'),
                const Divider(height: 18, color: AppColors.borderSubtle),
                _buildVerificationRow(
                  'Status',
                  result.status == VerificationStatus.valid
                      ? '✓ ACTIVE'
                      : (result.status == VerificationStatus.expired
                          ? 'EXPIRED'
                          : (result.status == VerificationStatus.revoked
                              ? 'REVOKED'
                              : 'NOT ACTIVE')),
                  isStatus: true,
                  statusColor: headerColor,
                ),
                const SizedBox(height: 24),
              ],

              // Scan next button
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _isProcessing = false);
                },
                icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
                label: const Text(
                  'Scan Next Pass',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryCrimson,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _isProcessing = false);
    });
  }

  Widget _buildVerificationRow(
    String label,
    String value, {
    bool isStatus = false,
    Color? statusColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (isStatus)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: (statusColor ?? AppColors.primaryCrimson).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (statusColor ?? AppColors.primaryCrimson).withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: statusColor ?? AppColors.primaryCrimson,
              ),
            ),
          )
        else
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
      ],
    );
  }

  void _showManualInputDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Enter Pass Identifier',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter Student Pass Number (e.g. ICEM-BP-2026-XXXXXX), Pass ID, or Student UID to verify against database:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'ICEM-BP-2026-...',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.badge_rounded, color: AppColors.primaryCrimson),
                filled: true,
                fillColor: AppColors.elevatedSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primaryCrimson, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              _verifyCode(text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryCrimson,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Verify', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'ICEM Pass Verification',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _isTorchOn ? AppColors.accentGold : Colors.white,
            ),
            onPressed: () async {
              await _scannerController.toggleTorch();
              setState(() => _isTorchOn = !_isTorchOn);
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          // Custom Framing Reticle
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.black.withOpacity(0.55),
                child: Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _isProcessing
                            ? AppColors.accentGold
                            : AppColors.primaryCrimson,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Instruction Text
          Positioned(
            top: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                _isProcessing ? 'Verifying with database...' : 'Align Student Pass QR inside frame',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Manual Enter Button at bottom
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Column(
              children: [
                if (_isProcessing)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: CircularProgressIndicator(color: AppColors.primaryCrimson),
                  ),
                OutlinedButton.icon(
                  onPressed: _showManualInputDialog,
                  icon: const Icon(Icons.keyboard_alt_rounded, color: Colors.white),
                  label: const Text(
                    'Enter Pass ID / Number Manually',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.black54,
                    side: const BorderSide(color: Colors.white38),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



================================================
FILE: lib/features/driver/.gitkeep
================================================
[Empty file]


================================================
FILE: lib/features/driver/data/.gitkeep
================================================
[Empty file]


================================================
FILE: lib/features/driver/data/repositories/driver_repository.dart
================================================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final driverRepositoryProvider = Provider<DriverRepository>((ref) {
  return DriverRepository();
});

class DriverRepository {
  final FirebaseFirestore _firestore;

  DriverRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Stream of all drivers from Firestore collection 'drivers'
  Stream<List<Map<String, dynamic>>> getDriversStream() {
    return _firestore
        .collection('drivers')
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
          list.sort((a, b) {
            final aDate = a['createdAt'];
            final bDate = b['createdAt'];
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            if (aDate is Timestamp && bDate is Timestamp) {
              return bDate.compareTo(aDate);
            }
            return 0;
          });
          return list;
        });
  }

  /// Add a new driver to Firestore
  Future<void> addDriver(Map<String, dynamic> driverData) async {
    driverData['createdAt'] = FieldValue.serverTimestamp();
    driverData['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('drivers').add(driverData);
  }

  /// Update an existing driver in Firestore
  Future<void> updateDriver(String id, Map<String, dynamic> driverData) async {
    driverData['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('drivers').doc(id).update(driverData);
  }

  /// Delete a driver from Firestore
  Future<void> deleteDriver(String id) async {
    await _firestore.collection('drivers').doc(id).delete();
  }
}



================================================
FILE: lib/features/driver/domain/driver_providers.dart
================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/features/driver/data/repositories/driver_repository.dart';

final driversListStreamProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final repository = ref.watch(driverRepositoryProvider);
  return repository.getDriversStream();
});



================================================
FILE: lib/features/driver/domain/.gitkeep
================================================
[Empty file]


================================================
FILE: lib/features/driver/presentation/.gitkeep
================================================
[Empty file]


================================================
FILE: lib/features/notification/data/.gitkeep
================================================
[Empty file]


================================================
FILE: lib/features/notification/data/repositories/notification_repository.dart
================================================
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationRepository {
  final FirebaseFirestore _firestore;

  NotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Returns a real-time stream of all notifications sorted by creation date descending.
  Stream<List<Map<String, dynamic>>> getNotificationsStream() {
    return _firestore
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              data['notificationId'] = doc.id;
              return data;
            }).toList());
  }

  /// Creates a new notification document.
  Future<void> createNotification(Map<String, dynamic> data) async {
    final docRef = _firestore.collection('notifications').doc();
    data['notificationId'] = docRef.id;
    data['createdAt'] = FieldValue.serverTimestamp();
    // Default scheduledAt to now if not provided
    if (data['scheduledAt'] == null) {
      data['scheduledAt'] = FieldValue.serverTimestamp();
    }
    await docRef.set(data);
  }

  /// Updates an existing scheduled notification document.
  Future<void> updateNotification(String id, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('notifications').doc(id).update(data);
  }

  /// Deletes a notification document.
  Future<void> deleteNotification(String id) async {
    await _firestore.collection('notifications').doc(id).delete();
  }
}



================================================
FILE: lib/features/notification/domain/notification_providers.dart
================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/features/notification/data/repositories/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

final notificationsStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.getNotificationsStream();
});



================================================
FILE: lib/features/notification/domain/.gitkeep
================================================
[Empty file]


================================================
FILE: lib/features/notification/presentation/.gitkeep
================================================
[Empty file]


================================================
FILE: lib/features/payment/.gitkeep
================================================
[Empty file]


================================================
FILE: lib/features/payment/data/.gitkeep
================================================
[Empty file]


================================================
FILE: lib/features/payment/data/models/payment_config_model.dart
================================================
import 'package:icem_bus/features/payment/domain/entities/payment_config_entity.dart';

class PaymentConfigModel extends PaymentConfigEntity {
  const PaymentConfigModel({
    required super.upiId,
    required super.upiDisplayName,
    required super.upiQrAsset,
    super.upiQrNetworkUrl,
    required super.razorpayKeyId,
    super.currency = 'INR',
    super.defaultFee = 4500.0,
    super.environment = 'TEST',
    super.isManualUpiEnabled = true,
  });

  /// Institutional Default Configuration
  factory PaymentConfigModel.initial() {
    return const PaymentConfigModel(
      upiId: '8766629441@axl',
      upiDisplayName: 'Yash Mahendra Kacholiya',
      upiQrAsset: 'assets/images/college_upi_qr.png',
      upiQrNetworkUrl: null,
      razorpayKeyId: '', // To be configured by Admin via Razorpay Dashboard
      currency: 'INR',
      defaultFee: 4500.0,
      environment: 'TEST',
      isManualUpiEnabled: true,
    );
  }

  factory PaymentConfigModel.defaultConfig() => PaymentConfigModel.initial();

  factory PaymentConfigModel.fromMap(Map<String, dynamic> map) {
    return PaymentConfigModel(
      upiId: (map['upiId'] as String?)?.trim().isNotEmpty == true
          ? (map['upiId'] as String).trim()
          : '8766629441@axl',
      upiDisplayName: (map['upiDisplayName'] as String?)?.trim().isNotEmpty == true
          ? (map['upiDisplayName'] as String).trim()
          : 'Yash Mahendra Kacholiya',
      upiQrAsset: (map['upiQrAsset'] as String?)?.trim().isNotEmpty == true
          ? (map['upiQrAsset'] as String).trim()
          : 'assets/images/college_upi_qr.png',
      upiQrNetworkUrl: map['upiQrNetworkUrl'] as String?,
      razorpayKeyId: (map['razorpayKeyId'] as String? ?? '').trim(),
      currency: (map['currency'] as String? ?? 'INR').trim(),
      defaultFee: (map['defaultFee'] as num?)?.toDouble() ?? 4500.0,
      environment: (map['environment'] as String? ?? 'TEST').trim().toUpperCase(),
      isManualUpiEnabled: map['isManualUpiEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'upiId': upiId,
      'upiDisplayName': upiDisplayName,
      'upiQrAsset': upiQrAsset,
      'upiQrNetworkUrl': upiQrNetworkUrl,
      'razorpayKeyId': razorpayKeyId,
      'currency': currency,
      'defaultFee': defaultFee,
      'environment': environment,
      'isManualUpiEnabled': isManualUpiEnabled,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }
}



================================================
FILE: lib/features/payment/data/models/payment_model.dart
================================================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:icem_bus/features/payment/domain/entities/payment_entity.dart';

class PaymentModel extends PaymentEntity {
  const PaymentModel({
    required super.paymentId,
    required super.applicationId,
    required super.studentId,
    required super.studentName,
    required super.routeId,
    required super.routeName,
    required super.amount,
    super.currency = 'INR',
    super.razorpayOrderId,
    super.razorpayPaymentId,
    super.razorpaySignature,
    required super.paymentStatus,
    required super.paymentMethod,
    super.utrNumber,
    super.receiptId,
    required super.createdAt,
    super.paidAt,
    super.verifiedAt,
  });

  factory PaymentModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? fallback;
      return fallback;
    }

    final createdAt = parseDate(map['createdAt'] ?? map['paymentDate'], DateTime.now());
    final paidAt = map['paidAt'] != null ? parseDate(map['paidAt'], createdAt) : null;
    final verifiedAt = map['verifiedAt'] != null ? parseDate(map['verifiedAt'], createdAt) : null;

    final studentId = map['studentId'] as String? ?? map['uid'] as String? ?? '';
    final applicationId = map['applicationId'] as String? ?? map['passId'] as String? ?? '';
    final routeName = map['routeName'] as String? ?? map['route'] as String? ?? '';
    final routeId = map['routeId'] as String? ?? '';

    return PaymentModel(
      paymentId: id,
      applicationId: applicationId,
      studentId: studentId,
      studentName: map['studentName'] as String? ?? '',
      routeId: routeId,
      routeName: routeName,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] as String? ?? 'INR',
      razorpayOrderId: map['razorpayOrderId'] as String?,
      razorpayPaymentId: map['razorpayPaymentId'] as String? ?? map['transactionId'] as String?,
      razorpaySignature: map['razorpaySignature'] as String?,
      paymentStatus: map['paymentStatus'] as String? ?? 'pending',
      paymentMethod: map['paymentMethod'] as String? ?? 'Razorpay',
      utrNumber: map['utrNumber'] as String?,
      receiptId: map['receiptId'] as String? ?? id,
      createdAt: createdAt,
      paidAt: paidAt,
      verifiedAt: verifiedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'paymentId': paymentId,
      'applicationId': applicationId,
      'studentId': studentId,
      'uid': studentId,
      'passId': applicationId,
      'studentName': studentName,
      'routeId': routeId,
      'routeName': routeName,
      'route': routeName,
      'amount': amount,
      'currency': currency,
      'razorpayOrderId': razorpayOrderId,
      'razorpayPaymentId': razorpayPaymentId,
      'transactionId': razorpayPaymentId ?? utrNumber ?? paymentId,
      'razorpaySignature': razorpaySignature,
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
      'utrNumber': utrNumber,
      'receiptId': receiptId ?? paymentId,
      'createdAt': Timestamp.fromDate(createdAt),
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      'paymentDate': Timestamp.fromDate(paidAt ?? createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}



================================================
FILE: lib/features/payment/data/repositories/payment_config_repository.dart
================================================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/features/payment/data/models/payment_config_model.dart';
import 'package:icem_bus/features/payment/domain/entities/payment_config_entity.dart';

final paymentConfigRepositoryProvider = Provider<PaymentConfigRepository>((ref) {
  try {
    return PaymentConfigRepository(firestore: FirebaseFirestore.instance);
  } catch (_) {
    return PaymentConfigRepository(firestore: null);
  }
});

final paymentConfigStreamProvider = StreamProvider<PaymentConfigEntity>((ref) {
  try {
    return ref.watch(paymentConfigRepositoryProvider).watchPaymentConfig();
  } catch (_) {
    return Stream.value(PaymentConfigModel.initial());
  }
});

class PaymentConfigRepository {
  final FirebaseFirestore? firestore;

  PaymentConfigRepository({this.firestore});

  static const String _collection = 'system_config';
  static const String _doc = 'payment_config';

  /// Stream real-time payment settings from Firestore with default fallback
  Stream<PaymentConfigEntity> watchPaymentConfig() {
    final fs = firestore;
    if (fs == null) {
      return Stream.value(PaymentConfigModel.initial());
    }
    try {
      return fs
          .collection(_collection)
          .doc(_doc)
          .snapshots()
          .map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) {
          return PaymentConfigModel.initial();
        }
        return PaymentConfigModel.fromMap(snapshot.data()!);
      }).handleError((_) => PaymentConfigModel.initial());
    } catch (_) {
      return Stream.value(PaymentConfigModel.initial());
    }
  }

  /// Get current config once
  Future<PaymentConfigEntity> getPaymentConfig() async {
    final fs = firestore;
    if (fs == null) return PaymentConfigModel.initial();
    try {
      final doc = await fs.collection(_collection).doc(_doc).get();
      if (!doc.exists || doc.data() == null) {
        return PaymentConfigModel.initial();
      }
      return PaymentConfigModel.fromMap(doc.data()!);
    } catch (_) {
      return PaymentConfigModel.initial();
    }
  }

  /// Update payment configuration (Admin only)
  Future<void> updatePaymentConfig(PaymentConfigEntity config) async {
    final fs = firestore;
    if (fs == null) return;

    final model = PaymentConfigModel(
      upiId: config.upiId,
      upiDisplayName: config.upiDisplayName,
      upiQrAsset: config.upiQrAsset,
      upiQrNetworkUrl: config.upiQrNetworkUrl,
      razorpayKeyId: config.razorpayKeyId,
      currency: config.currency,
      defaultFee: config.defaultFee,
      environment: config.environment,
      isManualUpiEnabled: config.isManualUpiEnabled,
    );

    await fs
        .collection(_collection)
        .doc(_doc)
        .set(model.toMap(), SetOptions(merge: true));
  }
}



================================================
FILE: lib/features/payment/data/repositories/payment_repository_impl.dart
================================================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/core/errors/failures.dart';
import 'package:icem_bus/features/payment/data/models/payment_model.dart';
import 'package:icem_bus/features/payment/domain/entities/payment_entity.dart';
import 'package:icem_bus/features/payment/domain/repositories/payment_repository.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepositoryImpl(firestore: FirebaseFirestore.instance);
});

class PaymentRepositoryImpl implements PaymentRepository {
  final FirebaseFirestore firestore;

  PaymentRepositoryImpl({required this.firestore});

  @override
  Future<PaymentEntity> createPaymentRecord({
    required String applicationId,
    required String studentId,
    required String studentName,
    required String routeId,
    required String routeName,
    required double amount,
    required String paymentMethod,
    String? razorpayOrderId,
    String? utrNumber,
    String paymentStatus = 'pending',
  }) async {
    try {
      final paymentRef = firestore.collection('payments').doc();
      final now = DateTime.now();

      final model = PaymentModel(
        paymentId: paymentRef.id,
        applicationId: applicationId,
        studentId: studentId,
        studentName: studentName,
        routeId: routeId,
        routeName: routeName,
        amount: amount,
        currency: 'INR',
        razorpayOrderId: razorpayOrderId,
        paymentStatus: paymentStatus,
        paymentMethod: paymentMethod,
        utrNumber: utrNumber,
        createdAt: now,
      );

      await paymentRef.set(model.toMap());
      return model;
    } catch (e) {
      throw ServerFailure('Failed to create payment record: ${e.toString()}');
    }
  }

  @override
  Future<PaymentEntity> submitManualUpiPayment({
    required String applicationId,
    required String studentId,
    required String studentName,
    required String routeId,
    required String routeName,
    required double amount,
    required String utrNumber,
  }) async {
    try {
      final paymentRef = firestore.collection('payments').doc();
      final now = DateTime.now();

      final model = PaymentModel(
        paymentId: paymentRef.id,
        applicationId: applicationId,
        studentId: studentId,
        studentName: studentName,
        routeId: routeId,
        routeName: routeName,
        amount: amount,
        currency: 'INR',
        paymentStatus: 'submitted_for_verification',
        paymentMethod: 'UPI Manual QR',
        utrNumber: utrNumber,
        createdAt: now,
      );

      // Write to payments collection
      await paymentRef.set(model.toMap());

      // Also write to receipts collection so legacy streams and reports immediately pick it up
      await firestore.collection('receipts').doc(paymentRef.id).set(model.toMap());

      // Update application to Pending Verification
      final appRef = firestore.collection('bus_pass_applications').doc(applicationId);
      final appSnap = await appRef.get();
      if (appSnap.exists) {
        await appRef.update({
          'paymentStatus': 'Pending Verification',
          'status': 'Payment Pending',
          'passStatus': 'Payment Pending',
          'paymentId': paymentRef.id,
          'utrNumber': utrNumber,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update bus_passes doc as well so student dashboard knows it's submitted for verification
      final passRef = firestore.collection('bus_passes').doc(studentId);
      final passSnap = await passRef.get();
      if (passSnap.exists) {
        await passRef.update({
          'paymentStatus': 'Pending Verification',
          'status': 'Payment Pending',
          'passStatus': 'Payment Pending',
          'utrNumber': utrNumber,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      return model;
    } catch (e) {
      throw ServerFailure('Failed to submit manual UPI payment: ${e.toString()}');
    }
  }

  @override
  Future<PaymentEntity> submitPayment({
    required String uid,
    required String passId,
    required String studentName,
    required double amount,
    required String transactionId,
    required DateTime paymentDate,
    required String paymentStatus,
    required String paymentMethod,
    required String route,
    required String routeId,
    required String boarding,
    required String destination,
    required String distance,
    required double fare,
  }) async {
    try {
      final docRef = firestore.collection('payments').doc();
      final model = PaymentModel(
        paymentId: docRef.id,
        applicationId: passId,
        studentId: uid,
        studentName: studentName,
        routeId: routeId,
        routeName: route,
        amount: amount,
        currency: 'INR',
        razorpayPaymentId: transactionId,
        paymentStatus: paymentStatus,
        paymentMethod: paymentMethod,
        receiptId: docRef.id,
        createdAt: paymentDate,
        paidAt: paymentStatus.toLowerCase() == 'paid' ? paymentDate : null,
      );

      final map = model.toMap();
      map['boarding'] = boarding;
      map['destination'] = destination;
      map['distance'] = distance;
      map['fare'] = fare;

      await docRef.set(map);
      await firestore.collection('receipts').doc(docRef.id).set(map);

      return model;
    } catch (e) {
      throw ServerFailure('Failed to submit payment: ${e.toString()}');
    }
  }

  @override
  Stream<List<PaymentEntity>> watchStudentPayments(String uid) {
    return firestore
        .collection('payments')
        .where('studentId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            // Check fallback for any legacy docs queried by 'uid'
            return <PaymentEntity>[];
          }
          return snapshot.docs
              .map((doc) => PaymentModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  @override
  Future<PaymentEntity?> getPaymentById(String paymentId) async {
    try {
      final doc = await firestore.collection('payments').doc(paymentId).get();
      if (doc.exists && doc.data() != null) {
        return PaymentModel.fromMap(doc.data()!, doc.id);
      }
      final rDoc = await firestore.collection('receipts').doc(paymentId).get();
      if (rDoc.exists && rDoc.data() != null) {
        return PaymentModel.fromMap(rDoc.data()!, rDoc.id);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}



================================================
FILE: lib/features/payment/domain/.gitkeep
================================================
[Empty file]


================================================
FILE: lib/features/payment/domain/entities/payment_config_entity.dart
================================================
import 'package:equatable/equatable.dart';

/// Centralized Payment Configuration Entity.
/// Admin can configure these values in Firestore (e.g. `system_config/payment_config`),
/// with secure fallback to institutional defaults.
class PaymentConfigEntity extends Equatable {
  final String upiId;
  final String upiDisplayName;
  final String upiQrAsset;
  final String? upiQrNetworkUrl;
  final String razorpayKeyId;
  final String currency;
  final double defaultFee;
  final String environment; // 'TEST' or 'LIVE'
  final bool isManualUpiEnabled;

  const PaymentConfigEntity({
    required this.upiId,
    required this.upiDisplayName,
    required this.upiQrAsset,
    this.upiQrNetworkUrl,
    required this.razorpayKeyId,
    this.currency = 'INR',
    this.defaultFee = 4500.0,
    this.environment = 'TEST',
    this.isManualUpiEnabled = true,
  });

  bool get isRazorpayConfigured =>
      razorpayKeyId.isNotEmpty && !razorpayKeyId.contains('YOUR_KEY');

  bool get isTestMode => environment.toUpperCase() == 'TEST';

  int get feeInPaise => (defaultFee * 100).round();

  @override
  List<Object?> get props => [
        upiId,
        upiDisplayName,
        upiQrAsset,
        upiQrNetworkUrl,
        razorpayKeyId,
        currency,
        defaultFee,
        environment,
        isManualUpiEnabled,
      ];
}



================================================
FILE: lib/features/payment/domain/entities/payment_entity.dart
================================================
import 'package:equatable/equatable.dart';

class PaymentEntity extends Equatable {
  final String paymentId;
  final String applicationId;
  final String studentId;
  final String studentName;
  final String routeId;
  final String routeName;
  final double amount;
  final String currency;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final String? razorpaySignature;
  final String paymentStatus; // created, pending, processing, paid, failed, submitted_for_verification, cancelled, refunded
  final String paymentMethod; // Razorpay, UPI Manual QR, Cash (Admin)
  final String? utrNumber;
  final String? receiptId;
  final DateTime createdAt;
  final DateTime? paidAt;
  final DateTime? verifiedAt;

  // Backwards compatibility getters
  String get uid => studentId;
  String get passId => applicationId;
  DateTime get paymentDate => paidAt ?? createdAt;
  String get route => routeName;
  String get transactionId => razorpayPaymentId ?? utrNumber ?? paymentId;
  String get boarding => '';
  String get destination => '';
  String get distance => '';
  double get fare => amount;

  const PaymentEntity({
    required this.paymentId,
    required this.applicationId,
    required this.studentId,
    required this.studentName,
    required this.routeId,
    required this.routeName,
    required this.amount,
    this.currency = 'INR',
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.razorpaySignature,
    required this.paymentStatus,
    required this.paymentMethod,
    this.utrNumber,
    this.receiptId,
    required this.createdAt,
    this.paidAt,
    this.verifiedAt,
  });

  bool get isPaid =>
      paymentStatus.toLowerCase() == 'paid' ||
      paymentStatus.toLowerCase() == 'success';

  bool get isPendingVerification =>
      paymentStatus == 'submitted_for_verification' ||
      paymentStatus == 'Pending Verification';

  @override
  List<Object?> get props => [
        paymentId,
        applicationId,
        studentId,
        studentName,
        routeId,
        routeName,
        amount,
        currency,
        razorpayOrderId,
        razorpayPaymentId,
        razorpaySignature,
        paymentStatus,
        paymentMethod,
        utrNumber,
        receiptId,
        createdAt,
        paidAt,
        verifiedAt,
      ];
}



================================================
FILE: lib/features/payment/domain/repositories/payment_repository.dart
================================================
import 'package:icem_bus/features/payment/domain/entities/payment_entity.dart';

abstract class PaymentRepository {
  /// Record initial payment attempt / record
  Future<PaymentEntity> createPaymentRecord({
    required String applicationId,
    required String studentId,
    required String studentName,
    required String routeId,
    required String routeName,
    required double amount,
    required String paymentMethod,
    String? razorpayOrderId,
    String? utrNumber,
    String paymentStatus = 'pending',
  });

  /// Submit manual UPI payment for administrative verification
  Future<PaymentEntity> submitManualUpiPayment({
    required String applicationId,
    required String studentId,
    required String studentName,
    required String routeId,
    required String routeName,
    required double amount,
    required String utrNumber,
  });

  /// Legacy submitPayment for backward compatibility
  Future<PaymentEntity> submitPayment({
    required String uid,
    required String passId,
    required String studentName,
    required double amount,
    required String transactionId,
    required DateTime paymentDate,
    required String paymentStatus,
    required String paymentMethod,
    required String route,
    required String routeId,
    required String boarding,
    required String destination,
    required String distance,
    required double fare,
  });

  Stream<List<PaymentEntity>> watchStudentPayments(String uid);

  Future<PaymentEntity?> getPaymentById(String paymentId);
}



================================================
FILE: lib/features/payment/presentation/.gitkeep
================================================
[Empty file]


================================================
FILE: lib/features/payment/presentation/services/razorpay_service.dart
================================================
import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

typedef PaymentSuccessCallback = void Function(PaymentSuccessResponse response);
typedef PaymentErrorCallback = void Function(PaymentFailureResponse response);
typedef ExternalWalletCallback = void Function(ExternalWalletResponse response);

/// Service wrapper for official Razorpay Flutter SDK.
class RazorpayService {
  Razorpay? _razorpay;
  PaymentSuccessCallback? _onSuccess;
  PaymentErrorCallback? _onError;
  ExternalWalletCallback? _onExternalWallet;

  void init({
    required PaymentSuccessCallback onSuccess,
    required PaymentErrorCallback onError,
    ExternalWalletCallback? onExternalWallet,
  }) {
    dispose(); // Clean any previous instance
    _razorpay = Razorpay();
    _onSuccess = onSuccess;
    _onError = onError;
    _onExternalWallet = onExternalWallet;

    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void openCheckout({
    required String keyId,
    String? orderId,
    required int amountInPaise, // e.g. 450000 for ₹4500
    required String studentName,
    required String studentEmail,
    required String studentContact,
    required String routeName,
    String currency = 'INR',
  }) {
    if (_razorpay == null) {
      throw StateError('RazorpayService has not been initialized. Call init() first.');
    }

    final Map<String, dynamic> options = {
      'key': keyId,
      'amount': amountInPaise,
      'name': 'ICEM Bus Pass',
      'description': 'Pass Fee for $routeName',
      'currency': currency,
      'timeout': 300, // 5 minutes timeout
      'prefill': {
        'contact': studentContact.isNotEmpty ? studentContact : '9876543210',
        'email': studentEmail.isNotEmpty ? studentEmail : 'student@indiraicem.ac.in',
        'name': studentName.isNotEmpty ? studentName : 'Student',
      },
      'theme': {
        'color': '#8B0000', // ICEM Crimson Theme
      },
    };

    if (orderId != null && orderId.isNotEmpty) {
      options['order_id'] = orderId;
    }

    debugPrint('🚀 Opening Razorpay Checkout with Key: $keyId, Amount: $amountInPaise paise');
    _razorpay!.open(options);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint('✅ Razorpay Payment Success: paymentId=${response.paymentId}, orderId=${response.orderId}');
    _onSuccess?.call(response);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('❌ Razorpay Payment Error: code=${response.code}, message=${response.message}');
    _onError?.call(response);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('💳 Razorpay External Wallet: walletName=${response.walletName}');
    _onExternalWallet?.call(response);
  }

  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
    _onSuccess = null;
    _onError = null;
    _onExternalWallet = null;
  }
}



================================================
FILE: lib/features/payment/presentation/views/pay_via_upi_qr_screen.dart
================================================
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/routes/app_routes.dart';
import 'package:icem_bus/config/theme/app_colors.dart';

/// DEPRECATED: Manual UPI QR and UTR workflow has been removed per production Razorpay specification.
/// All payments must proceed through the official Razorpay Standard Checkout SDK.
@Deprecated('Use Razorpay checkout instead')
class PayViaUpiQrScreen extends StatelessWidget {
  final String applicationId;
  final String routeName;
  final String routeId;
  final double amount;
  final String? studentName;

  const PayViaUpiQrScreen({
    super.key,
    required this.applicationId,
    required this.routeName,
    required this.routeId,
    required this.amount,
    this.studentName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go(AppRoutes.studentDashboard),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.payment_rounded, size: 64, color: AppColors.primaryCrimson),
              const SizedBox(height: 20),
              const Text(
                'Direct Razorpay Checkout Required',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Manual QR scanning and manual UTR submission have been deprecated. All student payments proceed through secure Razorpay Standard Checkout.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.studentPayment),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryCrimson,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Proceed to Razorpay Checkout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



================================================
FILE: lib/features/payment/presentation/views/payment_receipt_screen.dart
================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/routes/app_routes.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:icem_bus/features/payment/domain/entities/payment_entity.dart';
import 'package:icem_bus/shared/glass_card.dart';

class PaymentReceiptScreen extends ConsumerWidget {
  final String paymentId;
  final PaymentEntity? initialPayment;

  const PaymentReceiptScreen({
    super.key,
    required this.paymentId,
    this.initialPayment,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Receipt'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go(AppRoutes.studentDashboard),
        ),
      ),
      body: SafeArea(
        child: initialPayment != null
            ? _buildReceiptContent(context, initialPayment!)
            : FutureBuilder<PaymentEntity?>(
                future: ref.read(paymentRepositoryProvider).getPaymentById(paymentId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primaryCrimson));
                  }

                  final payment = snapshot.data;
                  if (payment == null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textLight),
                          const SizedBox(height: 16),
                          const Text('Receipt record not found.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => context.go(AppRoutes.studentDashboard),
                            child: const Text('Back to Dashboard'),
                          ),
                        ],
                      ),
                    );
                  }

                  return _buildReceiptContent(context, payment);
                },
              ),
      ),
    );
  }

  Widget _buildReceiptContent(BuildContext context, PaymentEntity payment) {
    final dateStr = payment.paidAt != null
        ? payment.paidAt.toString().substring(0, 16)
        : payment.createdAt.toString().substring(0, 16);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      child: Column(
        children: [
          // Receipt Container
          GlassCard(
            blur: 16,
            borderColor: AppColors.primaryCrimson.withValues(alpha: 0.25),
            opacity: 0.05,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                        // Institution Header
                        Image.asset(
                          'assets/images/bus_logo.png',
                          height: 54,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.directions_bus_filled_rounded,
                            size: 48,
                            color: AppColors.primaryCrimson,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'ICEM',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            color: AppColors.primaryCrimson,
                            letterSpacing: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Bus Pass Payment Receipt',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: payment.isPaid
                                ? AppColors.success.withValues(alpha: 0.12)
                                : AppColors.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: payment.isPaid ? AppColors.success : AppColors.warning,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                payment.isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
                                size: 16,
                                color: payment.isPaid ? AppColors.success : AppColors.warning,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                payment.isPaid ? 'PAID / VERIFIED' : 'PENDING VERIFICATION',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: payment.isPaid ? AppColors.success : AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Amount Block
                        Text(
                          payment.amount == 4500 ? '₹4,500' : '₹${payment.amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryCrimson,
                          ),
                        ),
                        const Text(
                          'Total Fee Paid',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        // Detailed receipt rows per Section 13
                        _receiptRow('Student', payment.studentName),
                        _receiptRow('Application ID', payment.applicationId),
                        _receiptRow('Route', payment.routeName),
                        _receiptRow('Amount', payment.amount == 4500 ? '₹4,500' : '₹${payment.amount.toStringAsFixed(0)}'),
                        _receiptRow('Payment Method', payment.paymentMethod),
                        if (payment.razorpayPaymentId != null && payment.razorpayPaymentId!.isNotEmpty)
                          _receiptRow('Razorpay Payment ID', payment.razorpayPaymentId!),
                        if (payment.utrNumber != null && payment.utrNumber!.isNotEmpty)
                          _receiptRow('UTR Reference', payment.utrNumber!),
                        _receiptRow('Payment Date', dateStr),
                        _receiptRow('Payment Status', payment.isPaid ? 'PAID / VERIFIED' : payment.paymentStatus.toUpperCase()),
                        _receiptRow('Receipt ID', payment.receiptId ?? payment.paymentId),

                        const SizedBox(height: 20),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        const Row(
                          children: [
                            Icon(Icons.verified_user_rounded, color: AppColors.success, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Official system generated electronic receipt. Valid for college transport services.',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Return Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => context.go(AppRoutes.studentDashboard),
                      icon: const Icon(Icons.dashboard_rounded, color: AppColors.primaryCrimson),
                      label: const Text('Return to Dashboard', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryCrimson)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primaryCrimson),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            );
  }

  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}



================================================
FILE: lib/features/payment/presentation/views/student_payment_screen.dart
================================================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/routes/app_routes.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/auth/domain/entities/user_entity.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/features/bus_pass/presentation/controllers/bus_pass_controller.dart';
import 'package:icem_bus/features/payment/data/models/payment_config_model.dart';
import 'package:icem_bus/features/payment/data/repositories/payment_config_repository.dart';
import 'package:icem_bus/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:icem_bus/features/payment/domain/entities/payment_config_entity.dart';
import 'package:icem_bus/features/payment/domain/entities/payment_entity.dart';
import 'package:icem_bus/features/payment/presentation/services/razorpay_service.dart';
import 'package:icem_bus/shared/app_card.dart';
import 'package:icem_bus/shared/status_badge.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

final studentPendingPassStreamProvider = StreamProvider.autoDispose<QuerySnapshot<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authControllerProvider).user;
  if (user == null) {
    return const Stream.empty();
  }
  return FirebaseFirestore.instance
      .collection('bus_passes')
      .where('uid', isEqualTo: user.uid)
      .where('paymentStatus', whereIn: const ['Pending', 'Failed', 'Unpaid', 'pending', 'Payment Pending'])
      .snapshots();
});

class StudentPaymentScreen extends ConsumerStatefulWidget {
  final String? testApplicationId;
  final String? testRouteName;
  final String? testStudentName;
  final String? testStudentEmail;
  final String? testStudentPhone;
  final double? testRouteFee;

  const StudentPaymentScreen({
    super.key,
    this.testApplicationId,
    this.testRouteName,
    this.testStudentName,
    this.testStudentEmail,
    this.testStudentPhone,
    this.testRouteFee,
  });

  @override
  ConsumerState<StudentPaymentScreen> createState() => _StudentPaymentScreenState();
}

class _StudentPaymentScreenState extends ConsumerState<StudentPaymentScreen> {
  final RazorpayService _razorpayService = RazorpayService();
  bool _isProcessing = false;
  String? _paymentErrorMessage;
  PaymentEntity? _verifiedPayment;

  @override
  void initState() {
    super.initState();
    _razorpayService.init(
      onSuccess: _onRazorpaySuccess,
      onError: _onRazorpayError,
      onExternalWallet: _onRazorpayExternalWallet,
    );
  }

  @override
  void dispose() {
    _razorpayService.dispose();
    super.dispose();
  }

  void _onRazorpaySuccess(PaymentSuccessResponse response) async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;

    setState(() {
      _isProcessing = true;
      _paymentErrorMessage = null;
    });

    debugPrint('✅ Razorpay checkout success: paymentId=${response.paymentId}, orderId=${response.orderId}');

    try {
      final appQuery = await FirebaseFirestore.instance
          .collection('bus_pass_applications')
          .where('uid', isEqualTo: user.uid)
          .where('paymentStatus', whereIn: const ['Pending', 'Unpaid', 'pending', 'Pending Payment', 'Payment Pending'])
          .limit(1)
          .get();

      if (appQuery.docs.isNotEmpty) {
        final appDoc = appQuery.docs.first;
        final appData = appDoc.data();
        final fare = (appData['fare'] as num?)?.toDouble() ?? 4500.0;
        final routeName = appData['route'] ?? appData['routeName'] ?? 'Bus Route';
        final routeId = appData['routeId'] ?? '';

        // 1. Create verified payment record with paymentStatus = 'paid'
        final paymentModel = await ref.read(paymentRepositoryProvider).createPaymentRecord(
              applicationId: appDoc.id,
              studentId: user.uid,
              studentName: user.fullName,
              routeId: routeId,
              routeName: routeName,
              amount: fare,
              paymentMethod: 'Razorpay',
              razorpayOrderId: response.orderId,
              paymentStatus: 'paid',
            );

        final now = DateTime.now();

        // 2. Transition Application Status to Pending Admin Approval (Section 6: MUST NOT auto-approve!)
        await appDoc.reference.update({
          'paymentStatus': 'Paid',
          'applicationStatus': 'pending_admin_approval',
          'status': 'Pending', // Pending Admin Approval
          'passStatus': 'Pending',
          'razorpayPaymentId': response.paymentId,
          'razorpayOrderId': response.orderId,
          'razorpaySignature': response.signature,
          'paidAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 3. Update bus_passes document (Pass is NOT active yet, awaiting admin approval)
        await FirebaseFirestore.instance.collection('bus_passes').doc(user.uid).set(
          {
            'paymentStatus': 'Paid',
            'applicationStatus': 'pending_admin_approval',
            'status': 'Pending',
            'passStatus': 'Pending',
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        // 4. Create official receipt linked to payment record
        await FirebaseFirestore.instance.collection('receipts').doc(paymentModel.paymentId).set({
          'receiptId': paymentModel.paymentId,
          'paymentId': paymentModel.paymentId,
          'applicationId': appDoc.id,
          'studentId': user.uid,
          'studentName': user.fullName,
          'route': routeName,
          'routeId': routeId,
          'amount': fare,
          'paymentMethod': 'Razorpay',
          'transactionId': response.paymentId ?? paymentModel.paymentId,
          'razorpayPaymentId': response.paymentId,
          'razorpayOrderId': response.orderId,
          'razorpaySignature': response.signature,
          'paymentStatus': 'Paid',
          'paymentDate': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        await ref.read(busPassControllerProvider.notifier).loadBusPass(user.uid);

        if (mounted) {
          setState(() {
            _isProcessing = false;
            _verifiedPayment = PaymentEntity(
              paymentId: paymentModel.paymentId,
              applicationId: appDoc.id,
              studentId: user.uid,
              studentName: user.fullName,
              routeId: routeId,
              routeName: routeName,
              amount: fare,
              paymentStatus: 'paid',
              paymentMethod: 'Razorpay',
              razorpayPaymentId: response.paymentId,
              razorpayOrderId: response.orderId,
              razorpaySignature: response.signature,
              receiptId: paymentModel.paymentId,
              createdAt: now,
              paidAt: now,
              verifiedAt: now,
            );
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _paymentErrorMessage = 'Payment recorded with error: ${e.toString()}';
        });
      }
    }
  }

  void _onRazorpayError(PaymentFailureResponse response) {
    debugPrint('❌ Razorpay payment error/cancellation: code=${response.code}, message=${response.message}');
    if (!mounted) return;

    setState(() {
      _isProcessing = false;
      // Section 7 Requirement: clear user-friendly message
      _paymentErrorMessage = 'Payment was not completed. Please try again.';
    });
  }

  void _onRazorpayExternalWallet(ExternalWalletResponse response) {
    debugPrint('💳 Razorpay External Wallet Selected: ${response.walletName}');
  }

  void _initiateRazorpayPayment({
    required BuildContext context,
    required PaymentConfigEntity config,
    required Map<String, dynamic> passData,
    required String passDocId,
    required double fare,
    required UserEntity? user,
  }) {
    setState(() => _paymentErrorMessage = null);

    // Section 20 Requirement: DO NOT FAKE PAYMENT.
    // If Razorpay Key ID is not configured, inform administrator / student.
    if (!config.isRazorpayConfigured) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: AppColors.warning, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Razorpay Gateway Setup Required',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Razorpay Key ID is missing from system configuration.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Client-side fake payments are prohibited. The college administrator must configure the Razorpay Key ID in Admin Settings -> Payment Gateway Configuration.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryCrimson,
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Amount strictly 450000 paise for ₹4500 (Section 1 & 2)
    final int amountInPaise = (fare * 100).round();
    final String routeName = passData['route'] ?? passData['routeName'] ?? 'Bus Route';

    try {
      _razorpayService.openCheckout(
        keyId: config.razorpayKeyId,
        amountInPaise: amountInPaise,
        studentName: user?.fullName ?? 'Student',
        studentEmail: user?.email ?? 'student@indiraicem.ac.in',
        studentContact: user?.mobile ?? '',
        routeName: routeName,
        currency: config.currency,
      );
    } catch (e) {
      setState(() {
        _paymentErrorMessage = 'Failed to launch Razorpay Checkout: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider).user;
    final pendingPassAsync = ref.watch(studentPendingPassStreamProvider);
    final configAsync = ref.watch(paymentConfigStreamProvider);

    final config = configAsync.value ?? PaymentConfigModel.initial();

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Bus Pass Payment',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.go(AppRoutes.studentDashboard),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: _verifiedPayment != null
              ? _buildPaymentSuccessView(theme, _verifiedPayment!)
              : (widget.testApplicationId != null
                  ? _buildPaymentCardAndButtons(
                      theme: theme,
                      config: config,
                      user: user,
                      passDocId: widget.testApplicationId!,
                      passData: {
                        'route': widget.testRouteName ?? 'Selected Route',
                        'routeId': 'ROUTE-01',
                        'fare': widget.testRouteFee ?? config.defaultFee,
                        'paymentStatus': 'Payment Pending',
                      },
                      routeName: widget.testRouteName ?? 'Selected Route',
                      studentName: widget.testStudentName ?? 'Student',
                      fare: widget.testRouteFee ?? config.defaultFee,
                      paymentStatusStr: 'Payment Pending',
                    )
                  : pendingPassAsync.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 80.0),
                          child: CircularProgressIndicator(color: AppColors.primaryCrimson),
                        ),
                      ),
                      error: (err, stack) => Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 80.0),
                          child: Text('Error loading application: $err', style: const TextStyle(color: AppColors.error)),
                        ),
                      ),
                      data: (snapshot) {
                        if (snapshot.docs.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 60.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check_circle_outline_rounded, size: 48, color: AppColors.success),
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    'No Payment Pending',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'You have no outstanding bus pass fee payments.',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                  ),
                                  const SizedBox(height: 28),
                                  ElevatedButton(
                                    onPressed: () => context.go(AppRoutes.studentDashboard),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.cardSurface,
                                      foregroundColor: AppColors.textPrimary,
                                      side: const BorderSide(color: AppColors.borderSubtle),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                    ),
                                    child: const Text('Back to Dashboard', style: TextStyle(fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final passDoc = snapshot.docs.first;
                        final passData = passDoc.data();
                        final String routeName = passData['route'] as String? ?? 'No Route Selected';
                        final double fare = (passData['fare'] as num?)?.toDouble() ?? config.defaultFee;
                        final String studentName = user?.fullName.isNotEmpty == true ? user!.fullName : 'Student';
                        final String paymentStatusStr = passData['paymentStatus'] as String? ?? 'Payment Pending';

                        return _buildPaymentCardAndButtons(
                          theme: theme,
                          config: config,
                          user: user,
                          passDocId: passDoc.id,
                          passData: passData,
                          routeName: routeName,
                          studentName: studentName,
                          fare: fare,
                          paymentStatusStr: paymentStatusStr,
                        );
                      },
                    )),
        ),
      ),
    );
  }

  /// SECTION 13: Premium Dark Payment Screen UI before opening Razorpay
  Widget _buildPaymentCardAndButtons({
    required ThemeData theme,
    required PaymentConfigEntity config,
    required UserEntity? user,
    required String passDocId,
    required Map<String, dynamic> passData,
    required String routeName,
    required String studentName,
    required double fare,
    required String paymentStatusStr,
  }) {
    final formattedFee = fare == 4500 ? '₹4,500' : '₹${fare.toStringAsFixed(0)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── TOP HEADER ──
        const Text(
          'BUS PASS PAYMENT',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: AppColors.primaryCrimson,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Complete Pass Activation',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 20),

        // ── MAIN PAYMENT CARD ──
        PremiumCard(
          borderRadius: 24,
          borderColor: AppColors.borderSubtle,
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryCrimson.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.directions_bus_rounded, color: AppColors.primaryCrimson, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'ICEM TRANSIT PASS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  StatusBadge(status: paymentStatusStr),
                ],
              ),
              const SizedBox(height: 20),
              Container(height: 1, color: AppColors.borderSubtle),
              const SizedBox(height: 20),

              _detailRow('Student', studentName, theme),
              const SizedBox(height: 14),
              _detailRow('Route', routeName, theme),
              const SizedBox(height: 14),
              _detailRow('Academic Session', '2026 – 2027', theme),
              const SizedBox(height: 20),

              // ── TOTAL AMOUNT DISPLAY ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.elevatedSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Annual Bus Pass Fee',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      formattedFee,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── FAILURE NOTICE ──
        if (_paymentErrorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment was not completed. Please try again.',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error, fontSize: 13),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Your bus pass application remains pending payment. You may re-attempt checkout.',
                        style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () {
                setState(() => _paymentErrorMessage = null);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryCrimson,
                side: const BorderSide(color: AppColors.primaryCrimson, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('TRY AGAIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── PRIMARY BUTTON: PAY ₹4,500 ──
        SizedBox(
          width: double.infinity,
          height: 56,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryCrimson, AppColors.darkCrimson],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryCrimson.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isProcessing
                  ? null
                  : () => _initiateRazorpayPayment(
                        context: context,
                        config: config,
                        passData: passData,
                        passDocId: passDocId,
                        fare: fare,
                        user: user,
                      ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: _isProcessing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                        ),
                        SizedBox(width: 14),
                        Text(
                          'Opening Razorpay...',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                        ),
                      ],
                    )
                  : Text(
                      'PAY $formattedFee',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ── SMALL TEXT: SECURE PAYMENT POWERED BY RAZORPAY ──
        const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, size: 13, color: AppColors.textSecondary),
              SizedBox(width: 6),
              Text(
                'Secure payment powered by Razorpay',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// SECTION 11: Payment Successful View with receipt navigation
  Widget _buildPaymentSuccessView(ThemeData theme, PaymentEntity payment) {
    final dt = payment.paidAt ?? payment.createdAt;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final formattedDate = '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}, $hour:$minute $ampm';
    final formattedFee = payment.amount == 4500 ? '₹4,500' : '₹${payment.amount.toStringAsFixed(0)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumCard(
          borderRadius: 24,
          borderColor: AppColors.success.withValues(alpha: 0.35),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 26),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Successful',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                      Text(
                        'Transaction completed & recorded',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(height: 1, color: AppColors.borderSubtle),
              const SizedBox(height: 18),

              _detailRow('Amount', formattedFee, theme, valueColor: AppColors.success, isBold: true, fontSize: 18),
              const SizedBox(height: 12),
              _detailRow('Payment ID', payment.razorpayPaymentId ?? payment.paymentId, theme),
              const SizedBox(height: 12),
              _detailRow('Order ID', payment.razorpayOrderId ?? 'N/A', theme),
              const SizedBox(height: 12),
              _detailRow('Payment Method', payment.paymentMethod, theme),
              const SizedBox(height: 12),
              _detailRow('Payment Date', formattedDate, theme),
              const SizedBox(height: 12),
              _detailRow(
                'Application Status',
                'Pending Admin Approval',
                theme,
                valueColor: AppColors.warning,
                isBold: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── VIEW RECEIPT BUTTON ──
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () {
              context.push('/student/payment-receipt/${payment.paymentId}');
            },
            icon: const Icon(Icons.receipt_long_rounded, color: Colors.white),
            label: const Text(
              'VIEW RECEIPT',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryCrimson,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () => context.go(AppRoutes.studentDashboard),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.borderSubtle),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Back to Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value, ThemeData theme,
      {Color? valueColor, bool isBold = false, double fontSize = 13.5}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}



================================================
FILE: lib/features/profile/data/.gitkeep
================================================
[Empty file]


================================================
FILE: lib/features/profile/domain/.gitkeep
================================================
[Empty file]


================================================
FILE: lib/features/profile/presentation/.gitkeep
================================================
[Empty file]


================================================
FILE: lib/features/student/.gitkeep
================================================
[Empty file]


================================================
FILE: lib/features/student/data/.gitkeep
================================================
[Empty file]


================================================
FILE: lib/features/student/domain/.gitkeep
================================================
[Empty file]


================================================
FILE: lib/features/student/presentation/.gitkeep
================================================
[Empty file]


================================================
FILE: lib/features/student/presentation/views/student_pass_detail_screen.dart
================================================
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/routes/app_routes.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:qr_flutter/qr_flutter.dart';

final singleApplicationDetailProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, applicationId) {
  return FirebaseFirestore.instance
      .collection('bus_pass_applications')
      .doc(applicationId)
      .snapshots()
      .map((doc) {
    if (!doc.exists || doc.data() == null) return null;
    final data = doc.data()!;
    data['id'] = doc.id;
    return data;
  });
});

class StudentPassDetailScreen extends ConsumerWidget {
  final String applicationId;

  const StudentPassDetailScreen({super.key, required this.applicationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appAsync = ref.watch(singleApplicationDetailProvider(applicationId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Application & Pass Details',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: SafeArea(
        child: appAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primaryCrimson),
          ),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text('Error: $err', style: const TextStyle(color: AppColors.error)),
            ),
          ),
          data: (app) {
            if (app == null) {
              return const Center(
                child: Text('Application not found',
                    style: TextStyle(color: Color(0xFF64748B))),
              );
            }

            return _buildDetailContent(context, app);
          },
        ),
      ),
    );
  }

  Widget _buildDetailContent(BuildContext context, Map<String, dynamic> app) {
    final String? passNumber = app['passNumber'];
    final String appId = app['id'] ?? applicationId;

    final String paymentStatusStr =
        (app['paymentStatus'] as String? ?? 'Pending').trim();
    final bool isPaid = paymentStatusStr.toLowerCase() == 'paid' ||
        paymentStatusStr.toLowerCase() == 'success';

    final String rawStatus =
        (app['passStatus'] as String? ?? app['status'] as String? ?? 'Pending')
            .trim();
    final bool isApproved = rawStatus.toLowerCase() == 'approved' ||
        rawStatus.toLowerCase() == 'active';
    final bool isRejected = rawStatus.toLowerCase() == 'rejected';
    final bool isRevoked = rawStatus.toLowerCase() == 'revoked';

    // Validity dates
    DateTime? validFromDate;
    final vf = app['validFrom'];
    if (vf is Timestamp) validFromDate = vf.toDate();

    DateTime? validUntilDate;
    final vu = app['validUntil'] ?? app['expiryDate'];
    if (vu is Timestamp) validUntilDate = vu.toDate();

    final bool isExpired =
        validUntilDate != null && DateTime.now().isAfter(validUntilDate);

    // Active ONLY when paid AND approved AND not expired AND not revoked
    final bool isActivePass =
        isPaid && isApproved && !isExpired && !isRevoked;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status Header
          _buildStatusBanner(
            isActive: isActivePass,
            isPaid: isPaid,
            isApproved: isApproved,
            isRejected: isRejected,
            isExpired: isExpired,
            isRevoked: isRevoked,
            rejectionReason: app['rejectionReason'],
          ),
          const SizedBox(height: 20),

          // Pass Number & Application Card
          _buildSectionCard(
            title: 'Credential Identifiers',
            icon: Icons.badge_rounded,
            children: [
              _buildRow('Pass Number', passNumber != null && passNumber.isNotEmpty ? passNumber : 'Generated upon Admin Approval', isBold: passNumber != null),
              _buildDivider(),
              _buildRow('Application ID', appId),
              if (app['approvedAt'] is Timestamp) ...[
                _buildDivider(),
                _buildRow('Approved At', _formatTimestamp(app['approvedAt'])),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Route & Stop Information
          _buildSectionCard(
            title: 'Route & Commute Details',
            icon: Icons.directions_bus_rounded,
            children: [
              _buildRow('Route Name', app['routeName'] ?? app['route'] ?? 'N/A'),
              _buildDivider(),
              _buildRow('Boarding Stop', app['boardingStop'] ?? 'N/A'),
              _buildDivider(),
              _buildRow('Destination', app['destinationStop'] ?? 'ICEM Campus'),
              if (app['busNumber'] != null) ...[
                _buildDivider(),
                _buildRow('Assigned Bus', app['busNumber'].toString()),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Validity Section
          _buildSectionCard(
            title: 'Pass Validity',
            icon: Icons.calendar_month_rounded,
            children: [
              _buildRow(
                'Valid From',
                validFromDate != null ? _formatDate(validFromDate) : 'Upon Approval',
              ),
              _buildDivider(),
              _buildRow(
                'Valid Until',
                validUntilDate != null ? _formatDate(validUntilDate) : 'Not Activated',
                color: isExpired ? AppColors.error : null,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Payment Details
          _buildSectionCard(
            title: 'Payment Information',
            icon: Icons.payments_rounded,
            children: [
              _buildRow('Amount / Fare', '₹${app['fare'] ?? app['amount'] ?? 0.0}'),
              _buildDivider(),
              _buildRow(
                'Payment Status',
                isPaid ? 'PAID ✓' : paymentStatusStr.toUpperCase(),
                color: isPaid ? AppColors.success : AppColors.warning,
                isBold: true,
              ),
              _buildDivider(),
              _buildRow('Payment Method', app['paymentMethod'] ?? 'Online / Razorpay'),
              if (app['razorpayPaymentId'] != null || app['paymentId'] != null) ...[
                _buildDivider(),
                _buildRow('Transaction Ref', app['razorpayPaymentId'] ?? app['paymentId']),
              ],
              if (app['paidAt'] is Timestamp) ...[
                _buildDivider(),
                _buildRow('Paid On', _formatTimestamp(app['paidAt'])),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Student Details
          _buildSectionCard(
            title: 'Student Information',
            icon: Icons.person_rounded,
            children: [
              _buildRow('Student Name', app['fullName'] ?? app['studentName'] ?? 'N/A'),
              _buildDivider(),
              _buildRow('PRN / Enrollment', app['prn'] ?? 'N/A'),
              _buildDivider(),
              _buildRow('Department', app['department'] ?? 'N/A'),
              if (app['course'] != null) ...[
                _buildDivider(),
                _buildRow('Course', app['course'].toString()),
              ],
              if (app['year'] != null) ...[
                _buildDivider(),
                _buildRow('Academic Year', app['year'].toString()),
              ],
            ],
          ),
          const SizedBox(height: 24),

          // QR Code Section - ONLY shown for ACTIVE approved passes
          if (isActivePass) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primaryCrimson.withOpacity(0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.qr_code_2_rounded, color: AppColors.primaryCrimson),
                      const SizedBox(width: 8),
                      const Text(
                        'ACTIVE DIGITAL PASS QR',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryCrimson,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: QrImageView(
                      data: jsonEncode({
                        'type': 'ICEM_BUS_PASS',
                        'passNumber': passNumber ?? appId,
                        'passId': appId,
                        'studentId': app['uid'] ?? app['studentId'],
                      }),
                      version: QrVersions.auto,
                      size: 160,
                      gapless: false,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: AppColors.primaryCrimson,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Scannable by ICEM transport conductors',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => context.push(AppRoutes.studentDigitalPass),
                    icon: const Icon(Icons.badge_rounded),
                    label: const Text('View Full Digital Pass'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryCrimson,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock_rounded, color: Color(0xFF64748B), size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'QR Code Inactive',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          !isPaid
                              ? 'Complete payment to proceed with pass approval.'
                              : (!isApproved
                                  ? 'Your payment is verified. QR code activates upon Admin approval.'
                                  : (isRevoked ? 'This pass has been revoked.' : 'This pass has expired.')),
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!isPaid) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.push(AppRoutes.studentPayment),
                icon: const Icon(Icons.payment_rounded),
                label: const Text('Complete Payment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryCrimson,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStatusBanner({
    required bool isActive,
    required bool isPaid,
    required bool isApproved,
    required bool isRejected,
    required bool isExpired,
    required bool isRevoked,
    String? rejectionReason,
  }) {
    Color bannerColor;
    IconData icon;
    String title;
    String subtext;

    if (isRevoked) {
      bannerColor = AppColors.error;
      icon = Icons.block_rounded;
      title = 'Pass Revoked';
      subtext = 'This pass is no longer valid for ICEM transport.';
    } else if (isExpired) {
      bannerColor = AppColors.warning;
      icon = Icons.warning_amber_rounded;
      title = 'Pass Expired';
      subtext = 'The validity period for this pass has ended.';
    } else if (isRejected) {
      bannerColor = AppColors.error;
      icon = Icons.cancel_rounded;
      title = 'Application Rejected';
      subtext = rejectionReason ?? 'Application was rejected by college administration.';
    } else if (isActive) {
      bannerColor = AppColors.success;
      icon = Icons.check_circle_rounded;
      title = 'Active Digital Pass';
      subtext = 'Authorized for ICEM bus transport.';
    } else if (isPaid && !isApproved) {
      bannerColor = AppColors.info;
      icon = Icons.hourglass_top_rounded;
      title = 'Paid — Waiting for Admin Approval';
      subtext = 'Payment verified. Administration will review and approve credential.';
    } else {
      bannerColor = AppColors.warning;
      icon = Icons.payment_rounded;
      title = 'Payment Pending';
      subtext = 'Payment is required to submit application for approval.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bannerColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: bannerColor, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: bannerColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtext,
                  style: TextStyle(fontSize: 12, color: bannerColor.withOpacity(0.85)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primaryCrimson),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {Color? color, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? const Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() => const Divider(height: 16, color: Color(0xFFF1F5F9));

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _formatTimestamp(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return _formatDate(dt);
    }
    return 'N/A';
  }
}



================================================
FILE: lib/features/student/presentation/views/student_pass_history_screen.dart
================================================
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/routes/app_routes.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/shared/app_card.dart';
import 'package:icem_bus/shared/empty_state.dart';
import 'package:icem_bus/shared/loading_skeleton.dart';
import 'package:icem_bus/shared/status_badge.dart';

final studentPassHistoryStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authControllerProvider).user;
  if (user == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('bus_pass_applications')
      .where('uid', isEqualTo: user.uid)
      .snapshots()
      .map((snapshot) {
    final list = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();

    // Sort descending by createdAt
    list.sort((a, b) {
      final aTime = a['createdAt'];
      final bTime = b['createdAt'];
      if (aTime is Timestamp && bTime is Timestamp) {
        return bTime.compareTo(aTime);
      }
      return 0;
    });

    return list;
  });
});

class StudentPassHistoryScreen extends ConsumerWidget {
  const StudentPassHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(studentPassHistoryStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Pass & Application History',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: SafeArea(
        child: historyAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              children: [
                LoadingSkeleton.card(height: 120, borderRadius: 16),
                SizedBox(height: 14),
                LoadingSkeleton.card(height: 120, borderRadius: 16),
                SizedBox(height: 14),
                LoadingSkeleton.card(height: 120, borderRadius: 16),
              ],
            ),
          ),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text('Error loading history: $err',
                  style: const TextStyle(color: AppColors.error)),
            ),
          ),
          data: (historyList) {
            if (historyList.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: EmptyState(
                  icon: Icons.history_edu_rounded,
                  title: 'No Applications Found',
                  description: "You haven't submitted any bus pass applications yet.",
                  actionText: 'Apply for Bus Pass',
                  onAction: () => context.push(AppRoutes.studentApply),
                ),
              );
            }

            return ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount: historyList.length,
              separatorBuilder: (context, index) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final app = historyList[index];
                return _buildHistoryCard(context, app);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, Map<String, dynamic> app) {
    final String appId = app['id'] ?? app['applicationId'] ?? 'N/A';
    final String? passNumber = app['passNumber'];
    final String route = app['routeName'] ?? app['route'] ?? 'Bus Route';
    final String boardingStop = app['boardingStop'] ?? 'Campus';

    final dynamic createdData = app['createdAt'];
    String dateString = 'Recent';
    if (createdData is Timestamp) {
      final dt = createdData.toDate();
      dateString =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    }

    // Determine Statuses
    final paymentStatus = (app['paymentStatus'] as String? ?? 'Pending').trim();
    final isPaid = paymentStatus.toLowerCase() == 'paid' ||
        paymentStatus.toLowerCase() == 'success';

    final rawStatus = (app['passStatus'] as String? ??
            app['status'] as String? ??
            'Pending')
        .trim();
    final isApproved = rawStatus.toLowerCase() == 'approved' ||
        rawStatus.toLowerCase() == 'active';
    final isRejected = rawStatus.toLowerCase() == 'rejected';
    final isRevoked = rawStatus.toLowerCase() == 'revoked';

    // Validity check
    final dynamic vu = app['validUntil'] ?? app['expiryDate'];
    bool isExpired = false;
    if (vu is Timestamp) {
      isExpired = DateTime.now().isAfter(vu.toDate());
    }

    String displayPassStatus;
    if (isRevoked) {
      displayPassStatus = 'REJECTED';
    } else if (isExpired) {
      displayPassStatus = 'EXPIRED';
    } else if (isRejected) {
      displayPassStatus = 'REJECTED';
    } else if (isPaid && isApproved) {
      displayPassStatus = 'ACTIVE';
    } else if (isPaid && !isApproved) {
      displayPassStatus = 'PENDING';
    } else {
      displayPassStatus = 'UNPAID';
    }

    return PremiumCard(
      borderRadius: 18,
      padding: const EdgeInsets.all(18),
      onTap: () {
        context.push('/student/pass-detail/$appId');
      },
      borderColor: displayPassStatus == 'ACTIVE'
          ? AppColors.primaryCrimson.withValues(alpha: 0.3)
          : AppColors.slate200,
      isSelected: displayPassStatus == 'ACTIVE',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Pass Number & Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.badge_rounded,
                      size: 18, color: AppColors.primaryCrimson),
                  const SizedBox(width: 8),
                  Text(
                    passNumber != null && passNumber.isNotEmpty
                        ? passNumber
                        : appId,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.slate900,
                    ),
                  ),
                ],
              ),
              Text(
                dateString,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.slate400,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Route & Stop
          Row(
            children: [
              const Icon(Icons.directions_bus_rounded,
                  size: 16, color: AppColors.slate500),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  route,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.slate800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Text(
              'Boarding: $boardingStop',
              style: const TextStyle(fontSize: 12, color: AppColors.slate600),
            ),
          ),
          const SizedBox(height: 14),

          // Badges Row: Payment, Approval, Pass Status
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              StatusBadge(
                status: isPaid ? 'PAID' : 'UNPAID',
                label: isPaid ? 'PAID ✓' : 'PAYMENT PENDING',
              ),
              StatusBadge(
                status: isApproved
                    ? 'ACTIVE'
                    : (isRejected ? 'REJECTED' : 'PENDING'),
                label: isApproved
                    ? 'APPROVED ✓'
                    : (isRejected ? 'REJECTED ✕' : 'IN REVIEW'),
              ),
              StatusBadge(
                status: displayPassStatus,
              ),
            ],
          ),
        ],
      ),
    );
  }
}



================================================
FILE: lib/services/firebase/firebase_service.dart
================================================
import 'dart:developer';
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FirebaseService {
  FirebaseService._();

  /// Initialize Firebase Services and FCM
  static Future<void> initialize() async {
    try {
      // Initialize Firebase core.
      // Note: If you have generated options using 'flutterfire configure',
      // you can pass 'DefaultFirebaseOptions.currentPlatform' here.
      await Firebase.initializeApp();
      log('Firebase initialized successfully.');
      
      // Setup Firebase Cloud Messaging (FCM) — not supported on Windows desktop
      if (!Platform.isWindows) {
        await _setupMessaging();
      } else {
        log('Skipping FCM setup on Windows (not supported).');
      }
    } catch (e) {
      log('Firebase initialization failed (likely due to missing google-services.json/GoogleService-Info.plist). Running in offline mode: $e');
    }
  }


  /// Configure Firebase Cloud Messaging
  static Future<void> _setupMessaging() async {
    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;

      // Request notifications permissions
      final NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: true,
        sound: true,
      );

      log('FCM permission authorization status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Fetch the FCM token for notification targeting
        final token = await messaging.getToken();
        log('FCM Registration Token: $token');

        // Handle foreground notifications
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          log('Received a foreground notification: ${message.notification?.title}');
        });

        // Handle notifications that opened the app
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          log('A notification opened the app: ${message.data}');
        });
      }
    } catch (e) {
      log('Failed to configure Firebase Cloud Messaging: $e');
    }
  }
}



================================================
FILE: lib/services/storage/storage_service.dart
================================================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:icem_bus/config/constants/app_constants.dart';

/// Provider for StorageService, to be overridden in main.dart after SharedPreferences initializes
final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('storageServiceProvider must be overridden in ProviderScope');
});

class StorageService {
  final SharedPreferences _sharedPreferences;

  StorageService(this._sharedPreferences);

  /// Check if the onboarding has been completed
  bool get isOnboardingCompleted {
    return _sharedPreferences.getBool(AppConstants.onboardingCompletedKey) ?? false;
  }

  /// Mark onboarding as completed
  Future<bool> setOnboardingCompleted(bool completed) async {
    return await _sharedPreferences.setBool(AppConstants.onboardingCompletedKey, completed);
  }

  /// Generic helpers for preferences storage
  String? getString(String key) => _sharedPreferences.getString(key);
  Future<bool> setString(String key, String val) => _sharedPreferences.setString(key, val);

  bool? getBool(String key) => _sharedPreferences.getBool(key);
  Future<bool> setBool(String key, bool val) => _sharedPreferences.setBool(key, val);

  /// Clear all stored data (useful for logout/reset)
  Future<bool> clearAll() async {
    return await _sharedPreferences.clear();
  }
}

// ==========================================
// PREFERENCES & SETTINGS RIVERPOD CONFIG
// ==========================================
class SettingsState {
  final ThemeMode themeMode;
  final String accentColor;
  final String language;
  final bool isCompactDensity;
  final bool notificationsEnabled;
  final bool passExpiryReminderEnabled;
  final bool appUpdatesEnabled;
  final bool newApplicationsEnabled;
  final bool paymentNotificationsEnabled;
  final bool passDecisionNotificationsEnabled;
  final bool systemNotificationsEnabled;

  const SettingsState({
    required this.themeMode,
    required this.accentColor,
    required this.language,
    this.isCompactDensity = false,
    required this.notificationsEnabled,
    required this.passExpiryReminderEnabled,
    this.appUpdatesEnabled = true,
    this.newApplicationsEnabled = true,
    this.paymentNotificationsEnabled = true,
    this.passDecisionNotificationsEnabled = true,
    this.systemNotificationsEnabled = true,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    String? accentColor,
    String? language,
    bool? isCompactDensity,
    bool? notificationsEnabled,
    bool? passExpiryReminderEnabled,
    bool? appUpdatesEnabled,
    bool? newApplicationsEnabled,
    bool? paymentNotificationsEnabled,
    bool? passDecisionNotificationsEnabled,
    bool? systemNotificationsEnabled,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
      language: language ?? this.language,
      isCompactDensity: isCompactDensity ?? this.isCompactDensity,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      passExpiryReminderEnabled: passExpiryReminderEnabled ?? this.passExpiryReminderEnabled,
      appUpdatesEnabled: appUpdatesEnabled ?? this.appUpdatesEnabled,
      newApplicationsEnabled: newApplicationsEnabled ?? this.newApplicationsEnabled,
      paymentNotificationsEnabled: paymentNotificationsEnabled ?? this.paymentNotificationsEnabled,
      passDecisionNotificationsEnabled: passDecisionNotificationsEnabled ?? this.passDecisionNotificationsEnabled,
      systemNotificationsEnabled: systemNotificationsEnabled ?? this.systemNotificationsEnabled,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    final storage = ref.watch(storageServiceProvider);
    
    // We schedule firestore sync after the build completes
    Future.microtask(() => _syncFromFirestore());

    return SettingsState(
      themeMode: _parseThemeMode(storage.getString('themeMode') ?? 'system'),
      accentColor: storage.getString('accentColor') ?? 'crimson',
      language: storage.getString('language') ?? 'english',
      isCompactDensity: storage.getBool('isCompactDensity') ?? false,
      notificationsEnabled: storage.getBool('notificationsEnabled') ?? true,
      passExpiryReminderEnabled: storage.getBool('passExpiryReminderEnabled') ?? true,
      appUpdatesEnabled: storage.getBool('appUpdatesEnabled') ?? true,
      newApplicationsEnabled: storage.getBool('newApplicationsEnabled') ?? true,
      paymentNotificationsEnabled: storage.getBool('paymentNotificationsEnabled') ?? true,
      passDecisionNotificationsEnabled: storage.getBool('passDecisionNotificationsEnabled') ?? true,
      systemNotificationsEnabled: storage.getBool('systemNotificationsEnabled') ?? true,
    );
  }

  static ThemeMode _parseThemeMode(String val) {
    switch (val) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  Future<void> _syncFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final storage = ref.read(storageServiceProvider);
      final localTheme = storage.getString('themeMode');

      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null && doc.data()!.containsKey('preferences')) {
        final prefs = doc.data()!['preferences'] as Map<String, dynamic>;
        
        final firestoreTheme = prefs['themeMode'] as String?;
        // If local theme was explicitly set by user, don't let a null or default 'system' overwrite it
        String theme;
        if (localTheme != null && localTheme.isNotEmpty && localTheme != 'system') {
          if (firestoreTheme != null && firestoreTheme.isNotEmpty && firestoreTheme != 'system') {
            theme = firestoreTheme;
          } else {
            theme = localTheme;
            // Push local theme to Firestore
            await _syncToFirestore();
          }
        } else {
          theme = firestoreTheme ?? localTheme ?? 'system';
        }

        final accent = prefs['accentColor'] as String? ?? storage.getString('accentColor') ?? 'crimson';
        final lang = prefs['language'] as String? ?? storage.getString('language') ?? 'english';
        final compact = prefs['isCompactDensity'] as bool? ?? storage.getBool('isCompactDensity') ?? false;
        final notif = prefs['notificationsEnabled'] as bool? ?? storage.getBool('notificationsEnabled') ?? true;
        final expiry = prefs['passExpiryReminderEnabled'] as bool? ?? storage.getBool('passExpiryReminderEnabled') ?? true;
        final appUp = prefs['appUpdatesEnabled'] as bool? ?? storage.getBool('appUpdatesEnabled') ?? true;
        final newApp = prefs['newApplicationsEnabled'] as bool? ?? storage.getBool('newApplicationsEnabled') ?? true;
        final payNotif = prefs['paymentNotificationsEnabled'] as bool? ?? storage.getBool('paymentNotificationsEnabled') ?? true;
        final decNotif = prefs['passDecisionNotificationsEnabled'] as bool? ?? storage.getBool('passDecisionNotificationsEnabled') ?? true;
        final sysNotif = prefs['systemNotificationsEnabled'] as bool? ?? storage.getBool('systemNotificationsEnabled') ?? true;

        state = SettingsState(
          themeMode: _parseThemeMode(theme),
          accentColor: accent,
          language: lang,
          isCompactDensity: compact,
          notificationsEnabled: notif,
          passExpiryReminderEnabled: expiry,
          appUpdatesEnabled: appUp,
          newApplicationsEnabled: newApp,
          paymentNotificationsEnabled: payNotif,
          passDecisionNotificationsEnabled: decNotif,
          systemNotificationsEnabled: sysNotif,
        );

        await storage.setString('themeMode', theme);
        await storage.setString('accentColor', accent);
        await storage.setString('language', lang);
        await storage.setBool('isCompactDensity', compact);
        await storage.setBool('notificationsEnabled', notif);
        await storage.setBool('passExpiryReminderEnabled', expiry);
        await storage.setBool('appUpdatesEnabled', appUp);
        await storage.setBool('newApplicationsEnabled', newApp);
        await storage.setBool('paymentNotificationsEnabled', payNotif);
        await storage.setBool('passDecisionNotificationsEnabled', decNotif);
        await storage.setBool('systemNotificationsEnabled', sysNotif);
      } else {
        await _syncToFirestore();
      }
    } catch (_) {}
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    final str = mode.toString().split('.').last;
    state = state.copyWith(themeMode: mode);
    final storage = ref.read(storageServiceProvider);
    await storage.setString('themeMode', str);
    await _syncToFirestore();
  }

  Future<void> updateCompactDensity(bool val) async {
    state = state.copyWith(isCompactDensity: val);
    final storage = ref.read(storageServiceProvider);
    await storage.setBool('isCompactDensity', val);
    await _syncToFirestore();
  }

  Future<void> updateAccentColor(String color) async {
    state = state.copyWith(accentColor: color);
    final storage = ref.read(storageServiceProvider);
    await storage.setString('accentColor', color);
    await _syncToFirestore();
  }

  Future<void> updateLanguage(String lang) async {
    state = state.copyWith(language: lang);
    final storage = ref.read(storageServiceProvider);
    await storage.setString('language', lang);
    await _syncToFirestore();
  }

  Future<void> updateNotificationsEnabled(bool val) async {
    state = state.copyWith(notificationsEnabled: val);
    final storage = ref.read(storageServiceProvider);
    await storage.setBool('notificationsEnabled', val);
    await _syncToFirestore();
  }

  Future<void> updatePassExpiryReminderEnabled(bool val) async {
    state = state.copyWith(passExpiryReminderEnabled: val);
    final storage = ref.read(storageServiceProvider);
    await storage.setBool('passExpiryReminderEnabled', val);
    await _syncToFirestore();
  }

  Future<void> updateAppUpdatesEnabled(bool val) async {
    state = state.copyWith(appUpdatesEnabled: val);
    final storage = ref.read(storageServiceProvider);
    await storage.setBool('appUpdatesEnabled', val);
    await _syncToFirestore();
  }

  Future<void> updateNewApplicationsEnabled(bool val) async {
    state = state.copyWith(newApplicationsEnabled: val);
    final storage = ref.read(storageServiceProvider);
    await storage.setBool('newApplicationsEnabled', val);
    await _syncToFirestore();
  }

  Future<void> updatePaymentNotificationsEnabled(bool val) async {
    state = state.copyWith(paymentNotificationsEnabled: val);
    final storage = ref.read(storageServiceProvider);
    await storage.setBool('paymentNotificationsEnabled', val);
    await _syncToFirestore();
  }

  Future<void> updatePassDecisionNotificationsEnabled(bool val) async {
    state = state.copyWith(passDecisionNotificationsEnabled: val);
    final storage = ref.read(storageServiceProvider);
    await storage.setBool('passDecisionNotificationsEnabled', val);
    await _syncToFirestore();
  }

  Future<void> updateSystemNotificationsEnabled(bool val) async {
    state = state.copyWith(systemNotificationsEnabled: val);
    final storage = ref.read(storageServiceProvider);
    await storage.setBool('systemNotificationsEnabled', val);
    await _syncToFirestore();
  }

  /// Safe local cache clear: resets non-essential cached keys in SharedPreferences
  Future<void> clearLocalCache() async {
    final storage = ref.read(storageServiceProvider);
    // Remove transient preferences while maintaining basic onboarding state
    await storage.setBool('appUpdatesEnabled', true);
    await storage.setBool('newApplicationsEnabled', true);
    await storage.setBool('paymentNotificationsEnabled', true);
    await storage.setBool('passDecisionNotificationsEnabled', true);
    await storage.setBool('systemNotificationsEnabled', true);
    state = state.copyWith(
      appUpdatesEnabled: true,
      newApplicationsEnabled: true,
      paymentNotificationsEnabled: true,
      passDecisionNotificationsEnabled: true,
      systemNotificationsEnabled: true,
    );
  }

  Future<void> syncPreferences() async {
    await _syncFromFirestore();
    await _syncToFirestore();
  }

  Future<void> _syncToFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final themeStr = state.themeMode.toString().split('.').last;
      
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'preferences': {
          'themeMode': themeStr,
          'accentColor': state.accentColor,
          'language': state.language,
          'isCompactDensity': state.isCompactDensity,
          'notificationsEnabled': state.notificationsEnabled,
          'passExpiryReminderEnabled': state.passExpiryReminderEnabled,
          'appUpdatesEnabled': state.appUpdatesEnabled,
          'newApplicationsEnabled': state.newApplicationsEnabled,
          'paymentNotificationsEnabled': state.paymentNotificationsEnabled,
          'passDecisionNotificationsEnabled': state.passDecisionNotificationsEnabled,
          'systemNotificationsEnabled': state.systemNotificationsEnabled,
        }
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}

final settingsNotifierProvider = NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);



================================================
FILE: lib/shared/app_card.dart
================================================
import 'package:flutter/material.dart';
import 'package:icem_bus/config/theme/app_colors.dart';

class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final bool isSelected;
  final List<BoxShadow>? boxShadow;
  final Gradient? gradient;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 22,
    this.isSelected = false,
    this.boxShadow,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBg = isSelected
        ? AppColors.primaryCrimson.withValues(alpha: 0.12)
        : (backgroundColor ?? AppColors.surface);

    final effectiveBorderColor = isSelected
        ? AppColors.primaryCrimson
        : (borderColor ?? AppColors.cardBorder);

    final cardContent = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? effectiveBg : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: effectiveBorderColor,
          width: isSelected ? 1.8 : 1.0,
        ),
        boxShadow: isSelected
            ? AppColors.crimsonGlow
            : (boxShadow ?? AppColors.cardShadow),
      ),
      child: child,
    );

    if (onTap != null) {
      return Container(
        margin: margin,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(borderRadius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(borderRadius),
            splashColor: AppColors.primaryCrimson.withValues(alpha: 0.16),
            highlightColor: AppColors.primaryCrimson.withValues(alpha: 0.08),
            child: cardContent,
          ),
        ),
      );
    }

    if (margin != null) {
      return Container(margin: margin, child: cardContent);
    }

    return cardContent;
  }
}



================================================
FILE: lib/shared/app_text_field.dart
================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icem_bus/config/theme/app_colors.dart';

class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String label;
  final String? hint;
  final String? hintText;
  final String? helperText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool isPassword;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final bool enabled;
  final bool readOnly;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;

  const AppTextField({
    super.key,
    this.controller,
    this.initialValue,
    required this.label,
    this.hint,
    this.hintText,
    this.helperText,
    this.prefixIcon,
    this.suffixIcon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.inputFormatters,
    this.focusNode,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          initialValue: widget.initialValue,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          inputFormatters: widget.inputFormatters,
          maxLines: widget.isPassword ? 1 : widget.maxLines,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onFieldSubmitted,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: widget.hintText ?? widget.hint,
            hintStyle: const TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
            ),
            helperText: widget.helperText,
            helperMaxLines: 2,
            filled: true,
            fillColor: widget.enabled ? AppColors.surface : AppColors.surfaceElevated,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            prefixIcon: widget.prefixIcon != null
                ? Icon(
                    widget.prefixIcon,
                    size: 20,
                    color: AppColors.textSecondary,
                  )
                : null,
            suffixIcon: widget.isPassword
                ? IconButton(
                    icon: Icon(
                      _obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  )
                : widget.suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: AppColors.cardBorder,
                width: 1.0,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: AppColors.cardBorder,
                width: 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: AppColors.primaryCrimson,
                width: 1.8,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: AppColors.error,
                width: 1.2,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: AppColors.error,
                width: 1.8,
              ),
            ),
          ),
        ),
      ],
    );
  }
}



================================================
FILE: lib/shared/custom_button.dart
================================================
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:icem_bus/config/theme/app_colors.dart';

class PrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> with SingleTickerProviderStateMixin {
  late double _scale;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.03,
    )..addListener(() {
        setState(() {});
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scale = 1 - _controller.value;
    final theme = Theme.of(context);
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    return GestureDetector(
      onTapDown: isEnabled ? (_) => _controller.forward() : null,
      onTapUp: isEnabled ? (_) => _controller.reverse() : null,
      onTapCancel: isEnabled ? () => _controller.reverse() : null,
      onTap: isEnabled ? widget.onPressed : null,
      child: Transform.scale(
        scale: _scale,
        child: Container(
          height: 54,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: isEnabled
                ? const LinearGradient(
                    colors: [AppColors.crimsonRed, AppColors.primaryCrimson],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : null,
            color: isEnabled ? null : AppColors.surfaceElevated,
            boxShadow: isEnabled ? AppColors.crimsonGlow : null,
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.text,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isEnabled ? Colors.white : AppColors.textLight,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: 0.4,
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

class SecondaryButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  const SecondaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton> with SingleTickerProviderStateMixin {
  late double _scale;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.03,
    )..addListener(() {
        setState(() {});
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scale = 1 - _controller.value;
    final theme = Theme.of(context);
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    return GestureDetector(
      onTapDown: isEnabled ? (_) => _controller.forward() : null,
      onTapUp: isEnabled ? (_) => _controller.reverse() : null,
      onTapCancel: isEnabled ? () => _controller.reverse() : null,
      onTap: isEnabled ? widget.onPressed : null,
      child: Transform.scale(
        scale: _scale,
        child: Container(
          height: 54,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isEnabled ? AppColors.surfaceElevated : AppColors.surface,
            border: Border.all(
              color: isEnabled ? AppColors.cardBorder : AppColors.cardBorderSubtle,
              width: 1.2,
            ),
            boxShadow: isEnabled ? AppColors.softShadow : null,
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: AppColors.primaryCrimson,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(
                          widget.icon,
                          color: isEnabled ? AppColors.textPrimary : AppColors.textLight,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.text,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isEnabled ? AppColors.textPrimary : AppColors.textLight,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          letterSpacing: 0.2,
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




================================================
FILE: lib/shared/empty_state.dart
================================================
import 'package:flutter/material.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/shared/custom_button.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionText;
  final VoidCallback? onAction;
  final IconData? actionIcon;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionText,
    this.onAction,
    this.actionIcon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.slate800
                    : AppColors.primaryCrimson.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? AppColors.slate700
                      : AppColors.primaryCrimson.withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
              child: Icon(
                icon,
                size: 38,
                color: AppColors.primaryCrimson,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.slate50 : AppColors.slate900,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.slate400 : AppColors.slate500,
                height: 1.45,
              ),
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: PrimaryButton(
                  text: actionText!,
                  icon: actionIcon,
                  onPressed: onAction,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}



================================================
FILE: lib/shared/error_screen.dart
================================================
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/shared/custom_button.dart';
import 'package:icem_bus/shared/glass_card.dart';

class ErrorScreen extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onBack;

  const ErrorScreen({
    super.key,
    this.title = 'Connection Timeout',
    this.message = 'We could not link to the college server. Check your network link and try again.',
    this.onRetry,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Background ambient shapes
          Positioned(
            top: 80,
            right: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.error.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryCrimson.withOpacity(0.04),
              ),
            ),
          ),
          
          // Main error panel
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GlassCard(
                  blur: 14,
                  borderColor: AppColors.error.withOpacity(0.3),
                  opacity: 0.08,
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    children: [
                      // Warning circular icon
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: AppColors.lightCrimson,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.error.withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.wifi_off_rounded,
                            size: 38,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Error Title
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      // Error Message
                      Text(
                        message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Action Buttons
                PrimaryButton(
                  text: 'Try Again',
                  icon: Icons.refresh_rounded,
                  onPressed: onRetry ?? () {},
                ),
                if (onBack != null) ...[
                  const SizedBox(height: 14),
                  SecondaryButton(
                    text: 'Go Back',
                    icon: Icons.arrow_back_ios_new_rounded,
                    onPressed: onBack,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}



================================================
FILE: lib/shared/glass_card.dart
================================================
// ignore_for_file: deprecated_member_use

import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color color;
  final Color borderColor;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;

  const GlassCard({
    super.key,
    required this.child,
    this.blur = 12.0,
    this.opacity = 0.07,
    this.color = Colors.white,
    this.borderColor = Colors.white,
    this.borderRadius = const BorderRadius.all(Radius.circular(24.0)),
    this.padding = const EdgeInsets.all(20.0),
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            spreadRadius: -4,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color.withOpacity(opacity),
              borderRadius: borderRadius,
              border: Border.all(
                color: borderColor.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}



================================================
FILE: lib/shared/loading_screen.dart
================================================
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/shared/glass_card.dart';

class LoadingScreen extends StatefulWidget {
  final String message;
  final String subMessage;

  const LoadingScreen({
    super.key,
    this.message = 'Loading ICEM Portal...',
    this.subMessage = 'Establishing secure handshake...',
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.88, end: 1.02).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Background ambient shapes
          Positioned(
            top: 100,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryCrimson.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentGold.withOpacity(0.06),
              ),
            ),
          ),
          
          // Main frosted loading panel
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: ScaleTransition(
              scale: _pulseAnimation,
              child: GlassCard(
                blur: 16,
                borderColor: AppColors.primaryCrimson,
                opacity: 0.08,
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Loading Monogram/Icon Container
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryCrimson.withOpacity(0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                        border: Border.all(
                          color: AppColors.primaryCrimson.withOpacity(0.15),
                          width: 1.5,
                        ),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryCrimson,
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Primary Loading Message
                    Text(
                      widget.message,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    // Sub Message
                    Text(
                      widget.subMessage,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}



================================================
FILE: lib/shared/loading_skeleton.dart
================================================
import 'package:flutter/material.dart';
import 'package:icem_bus/config/theme/app_colors.dart';

class LoadingSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const LoadingSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
    this.margin,
  });

  const LoadingSkeleton.card({
    super.key,
    this.width = double.infinity,
    this.height = 140,
    this.borderRadius = 18,
    this.margin,
  });

  const LoadingSkeleton.circle({
    super.key,
    required double size,
    this.margin,
  })  : width = size,
        height = size,
        borderRadius = 999;

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor = isDark ? AppColors.slate800 : const Color(0xFFF1F5F9);
    final highlightColor = isDark ? AppColors.slate700 : const Color(0xFFE2E8F0);

    return Container(
      margin: widget.margin,
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        color: baseColor,
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.1, 0.5, 0.9],
                colors: [baseColor, highlightColor, baseColor],
                transform: _SlidingGradientTransform(_animation.value),
              ).createShader(bounds);
            },
            blendMode: BlendMode.srcATop,
            child: Container(
              color: baseColor,
            ),
          );
        },
      ),
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform(this.slidePercent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}



================================================
FILE: lib/shared/status_badge.dart
================================================
import 'package:flutter/material.dart';
import 'package:icem_bus/config/theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final String? label;
  final bool showDot;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const StatusBadge({
    super.key,
    required this.status,
    this.label,
    this.showDot = true,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  });

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toUpperCase();

    Color bgColor;
    Color textColor;
    IconData? icon;

    switch (normalized) {
      case 'ACTIVE':
      case 'APPROVED':
      case 'PAID':
        bgColor = AppColors.successLight;
        textColor = AppColors.success;
        icon = Icons.check_circle_rounded;
        break;
      case 'PENDING':
      case 'WAITING FOR APPROVAL':
      case 'PAYMENT SUCCESSFUL — WAITING FOR ADMIN APPROVAL':
      case 'PENDING APPROVAL':
      case 'PENDING_ADMIN_APPROVAL':
        bgColor = AppColors.infoLight;
        textColor = AppColors.info;
        icon = Icons.hourglass_top_rounded;
        break;
      case 'PAYMENT PENDING':
      case 'UNPAID':
      case 'SUBMITTED_FOR_VERIFICATION':
      case 'VERIFICATION PENDING':
        bgColor = AppColors.warningLight;
        textColor = AppColors.warning;
        icon = Icons.pending_actions_rounded;
        break;
      case 'EXPIRED':
        bgColor = AppColors.warningLight;
        textColor = AppColors.warning;
        icon = Icons.history_toggle_off_rounded;
        break;
      case 'REJECTED':
      case 'REVOKED':
      case 'FAILED':
        bgColor = AppColors.errorLight;
        textColor = AppColors.error;
        icon = Icons.cancel_rounded;
        break;
      default:
        bgColor = AppColors.slate100;
        textColor = AppColors.slate600;
        icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withValues(alpha: 0.28), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Icon(icon, size: fontSize + 2, color: textColor),
            const SizedBox(width: 5),
          ],
          Text(
            label ?? normalized,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}



================================================
FILE: linux/CMakeLists.txt
================================================
# Project-level configuration.
cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "icem_bus")
# The unique GTK application identifier for this application. See:
# https://wiki.gnome.org/HowDoI/ChooseApplicationID
set(APPLICATION_ID "com.icem.bus.icem_bus")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(SET CMP0063 NEW)

# Load bundled libraries from the lib/ directory relative to the binary.
set(CMAKE_INSTALL_RPATH "$ORIGIN/lib")

# Root filesystem for cross-building.
if(FLUTTER_TARGET_PLATFORM_SYSROOT)
  set(CMAKE_SYSROOT ${FLUTTER_TARGET_PLATFORM_SYSROOT})
  set(CMAKE_FIND_ROOT_PATH ${CMAKE_SYSROOT})
  set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
  set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
  set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
  set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
endif()

# Define build configuration options.
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE "Debug" CACHE
    STRING "Flutter build mode" FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
    "Debug" "Profile" "Release")
endif()

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_14)
  target_compile_options(${TARGET} PRIVATE -Wall -Werror)
  target_compile_options(${TARGET} PRIVATE "$<$<NOT:$<CONFIG:Debug>>:-O3>")
  target_compile_definitions(${TARGET} PRIVATE "$<$<NOT:$<CONFIG:Debug>>:NDEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# System-level dependencies.
find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK REQUIRED IMPORTED_TARGET gtk+-3.0)

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)

# Only the install-generated bundle's copy of the executable will launch
# correctly, since the resources must in the right relative locations. To avoid
# people trying to run the unbundled copy, put it in a subdirectory instead of
# the default top-level location.
set_target_properties(${BINARY_NAME}
  PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/intermediates_do_not_run"
)


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)


# === Installation ===
# By default, "installing" just makes a relocatable bundle in the build
# directory.
set(BUILD_BUNDLE_DIR "${PROJECT_BINARY_DIR}/bundle")
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

# Start with a clean build bundle directory every time.
install(CODE "
  file(REMOVE_RECURSE \"${BUILD_BUNDLE_DIR}/\")
  " COMPONENT Runtime)

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}/lib")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

foreach(bundled_library ${PLUGIN_BUNDLED_LIBRARIES})
  install(FILES "${bundled_library}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endforeach(bundled_library)

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/linux/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
if(NOT CMAKE_BUILD_TYPE MATCHES "Debug")
  install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()



================================================
FILE: linux/flutter/CMakeLists.txt
================================================
# This file controls Flutter-level build steps. It should not be edited.
cmake_minimum_required(VERSION 3.10)

set(EPHEMERAL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ephemeral")

# Configuration provided via flutter tool.
include(${EPHEMERAL_DIR}/generated_config.cmake)

# TODO: Move the rest of this into files in ephemeral. See
# https://github.com/flutter/flutter/issues/57146.

# Serves the same purpose as list(TRANSFORM ... PREPEND ...),
# which isn't available in 3.10.
function(list_prepend LIST_NAME PREFIX)
    set(NEW_LIST "")
    foreach(element ${${LIST_NAME}})
        list(APPEND NEW_LIST "${PREFIX}${element}")
    endforeach(element)
    set(${LIST_NAME} "${NEW_LIST}" PARENT_SCOPE)
endfunction()

# === Flutter Library ===
# System-level dependencies.
find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK REQUIRED IMPORTED_TARGET gtk+-3.0)
pkg_check_modules(GLIB REQUIRED IMPORTED_TARGET glib-2.0)
pkg_check_modules(GIO REQUIRED IMPORTED_TARGET gio-2.0)

set(FLUTTER_LIBRARY "${EPHEMERAL_DIR}/libflutter_linux_gtk.so")

# Published to parent scope for install step.
set(FLUTTER_LIBRARY ${FLUTTER_LIBRARY} PARENT_SCOPE)
set(FLUTTER_ICU_DATA_FILE "${EPHEMERAL_DIR}/icudtl.dat" PARENT_SCOPE)
set(PROJECT_BUILD_DIR "${PROJECT_DIR}/build/" PARENT_SCOPE)
set(AOT_LIBRARY "${PROJECT_DIR}/build/lib/libapp.so" PARENT_SCOPE)

list(APPEND FLUTTER_LIBRARY_HEADERS
  "fl_basic_message_channel.h"
  "fl_binary_codec.h"
  "fl_binary_messenger.h"
  "fl_dart_project.h"
  "fl_engine.h"
  "fl_json_message_codec.h"
  "fl_json_method_codec.h"
  "fl_message_codec.h"
  "fl_method_call.h"
  "fl_method_channel.h"
  "fl_method_codec.h"
  "fl_method_response.h"
  "fl_plugin_registrar.h"
  "fl_plugin_registry.h"
  "fl_standard_message_codec.h"
  "fl_standard_method_codec.h"
  "fl_string_codec.h"
  "fl_value.h"
  "fl_view.h"
  "flutter_linux.h"
)
list_prepend(FLUTTER_LIBRARY_HEADERS "${EPHEMERAL_DIR}/flutter_linux/")
add_library(flutter INTERFACE)
target_include_directories(flutter INTERFACE
  "${EPHEMERAL_DIR}"
)
target_link_libraries(flutter INTERFACE "${FLUTTER_LIBRARY}")
target_link_libraries(flutter INTERFACE
  PkgConfig::GTK
  PkgConfig::GLIB
  PkgConfig::GIO
)
add_dependencies(flutter flutter_assemble)

# === Flutter tool backend ===
# _phony_ is a non-existent file to force this command to run every time,
# since currently there's no way to get a full input/output list from the
# flutter tool.
add_custom_command(
  OUTPUT ${FLUTTER_LIBRARY} ${FLUTTER_LIBRARY_HEADERS}
    ${CMAKE_CURRENT_BINARY_DIR}/_phony_
  COMMAND ${CMAKE_COMMAND} -E env
    ${FLUTTER_TOOL_ENVIRONMENT}
    "${FLUTTER_ROOT}/packages/flutter_tools/bin/tool_backend.sh"
      ${FLUTTER_TARGET_PLATFORM} ${CMAKE_BUILD_TYPE}
  VERBATIM
)
add_custom_target(flutter_assemble DEPENDS
  "${FLUTTER_LIBRARY}"
  ${FLUTTER_LIBRARY_HEADERS}
)



================================================
FILE: linux/flutter/generated_plugin_registrant.cc
================================================
//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <file_selector_linux/file_selector_plugin.h>
#include <url_launcher_linux/url_launcher_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) file_selector_linux_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "FileSelectorPlugin");
  file_selector_plugin_register_with_registrar(file_selector_linux_registrar);
  g_autoptr(FlPluginRegistrar) url_launcher_linux_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "UrlLauncherPlugin");
  url_launcher_plugin_register_with_registrar(url_launcher_linux_registrar);
}



================================================
FILE: linux/flutter/generated_plugin_registrant.h
================================================
//
//  Generated file. Do not edit.
//

// clang-format off

#ifndef GENERATED_PLUGIN_REGISTRANT_
#define GENERATED_PLUGIN_REGISTRANT_

#include <flutter_linux/flutter_linux.h>

// Registers Flutter plugins.
void fl_register_plugins(FlPluginRegistry* registry);

#endif  // GENERATED_PLUGIN_REGISTRANT_



================================================
FILE: linux/flutter/generated_plugins.cmake
================================================
#
# Generated file, do not edit.
#

list(APPEND FLUTTER_PLUGIN_LIST
  file_selector_linux
  url_launcher_linux
)

list(APPEND FLUTTER_FFI_PLUGIN_LIST
  jni
)

set(PLUGIN_BUNDLED_LIBRARIES)

foreach(plugin ${FLUTTER_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${plugin}/linux plugins/${plugin})
  target_link_libraries(${BINARY_NAME} PRIVATE ${plugin}_plugin)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES $<TARGET_FILE:${plugin}_plugin>)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${plugin}_bundled_libraries})
endforeach(plugin)

foreach(ffi_plugin ${FLUTTER_FFI_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${ffi_plugin}/linux plugins/${ffi_plugin})
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${ffi_plugin}_bundled_libraries})
endforeach(ffi_plugin)



================================================
FILE: linux/runner/CMakeLists.txt
================================================
cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the application ID.
add_definitions(-DAPPLICATION_ID="${APPLICATION_ID}")

# Add dependency libraries. Add any application-specific dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")



================================================
FILE: linux/runner/main.cc
================================================
#include "my_application.h"

int main(int argc, char** argv) {
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}



================================================
FILE: linux/runner/my_application.cc
================================================
#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "icem_bus");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "icem_bus");
  }

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}



================================================
FILE: linux/runner/my_application.h
================================================
#ifndef FLUTTER_MY_APPLICATION_H_
#define FLUTTER_MY_APPLICATION_H_

#include <gtk/gtk.h>

G_DECLARE_FINAL_TYPE(MyApplication,
                     my_application,
                     MY,
                     APPLICATION,
                     GtkApplication)

/**
 * my_application_new:
 *
 * Creates a new Flutter-based application.
 *
 * Returns: a new #MyApplication.
 */
MyApplication* my_application_new();

#endif  // FLUTTER_MY_APPLICATION_H_



================================================
FILE: macos/Flutter/Flutter-Debug.xcconfig
================================================
#include "ephemeral/Flutter-Generated.xcconfig"



================================================
FILE: macos/Flutter/Flutter-Release.xcconfig
================================================
#include "ephemeral/Flutter-Generated.xcconfig"



================================================
FILE: macos/Flutter/GeneratedPluginRegistrant.swift
================================================
//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import cloud_firestore
import file_selector_macos
import firebase_auth
import firebase_core
import firebase_messaging
import firebase_storage
import google_sign_in_ios
import mobile_scanner
import share_plus
import shared_preferences_foundation

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  FLTFirebaseFirestorePlugin.register(with: registry.registrar(forPlugin: "FLTFirebaseFirestorePlugin"))
  FileSelectorPlugin.register(with: registry.registrar(forPlugin: "FileSelectorPlugin"))
  FLTFirebaseAuthPlugin.register(with: registry.registrar(forPlugin: "FLTFirebaseAuthPlugin"))
  FLTFirebaseCorePlugin.register(with: registry.registrar(forPlugin: "FLTFirebaseCorePlugin"))
  FLTFirebaseMessagingPlugin.register(with: registry.registrar(forPlugin: "FLTFirebaseMessagingPlugin"))
  FLTFirebaseStoragePlugin.register(with: registry.registrar(forPlugin: "FLTFirebaseStoragePlugin"))
  FLTGoogleSignInPlugin.register(with: registry.registrar(forPlugin: "FLTGoogleSignInPlugin"))
  MobileScannerPlugin.register(with: registry.registrar(forPlugin: "MobileScannerPlugin"))
  SharePlusMacosPlugin.register(with: registry.registrar(forPlugin: "SharePlusMacosPlugin"))
  SharedPreferencesPlugin.register(with: registry.registrar(forPlugin: "SharedPreferencesPlugin"))
}



================================================
FILE: macos/Runner/AppDelegate.swift
================================================
import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}



================================================
FILE: macos/Runner/DebugProfile.entitlements
================================================
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
	<key>com.apple.security.cs.allow-jit</key>
	<true/>
	<key>com.apple.security.network.server</key>
	<true/>
</dict>
</plist>



================================================
FILE: macos/Runner/Info.plist
================================================
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>$(DEVELOPMENT_LANGUAGE)</string>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIconFile</key>
	<string></string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$(PRODUCT_NAME)</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$(FLUTTER_BUILD_NAME)</string>
	<key>CFBundleVersion</key>
	<string>$(FLUTTER_BUILD_NUMBER)</string>
	<key>LSMinimumSystemVersion</key>
	<string>$(MACOSX_DEPLOYMENT_TARGET)</string>
	<key>NSHumanReadableCopyright</key>
	<string>$(PRODUCT_COPYRIGHT)</string>
	<key>NSMainNibFile</key>
	<string>MainMenu</string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>



================================================
FILE: macos/Runner/MainFlutterWindow.swift
================================================
import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}



================================================
FILE: macos/Runner/Release.entitlements
================================================
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
</dict>
</plist>



================================================
FILE: macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json
================================================
{
  "images" : [
    {
      "size" : "16x16",
      "idiom" : "mac",
      "filename" : "app_icon_16.png",
      "scale" : "1x"
    },
    {
      "size" : "16x16",
      "idiom" : "mac",
      "filename" : "app_icon_32.png",
      "scale" : "2x"
    },
    {
      "size" : "32x32",
      "idiom" : "mac",
      "filename" : "app_icon_32.png",
      "scale" : "1x"
    },
    {
      "size" : "32x32",
      "idiom" : "mac",
      "filename" : "app_icon_64.png",
      "scale" : "2x"
    },
    {
      "size" : "128x128",
      "idiom" : "mac",
      "filename" : "app_icon_128.png",
      "scale" : "1x"
    },
    {
      "size" : "128x128",
      "idiom" : "mac",
      "filename" : "app_icon_256.png",
      "scale" : "2x"
    },
    {
      "size" : "256x256",
      "idiom" : "mac",
      "filename" : "app_icon_256.png",
      "scale" : "1x"
    },
    {
      "size" : "256x256",
      "idiom" : "mac",
      "filename" : "app_icon_512.png",
      "scale" : "2x"
    },
    {
      "size" : "512x512",
      "idiom" : "mac",
      "filename" : "app_icon_512.png",
      "scale" : "1x"
    },
    {
      "size" : "512x512",
      "idiom" : "mac",
      "filename" : "app_icon_1024.png",
      "scale" : "2x"
    }
  ],
  "info" : {
    "version" : 1,
    "author" : "xcode"
  }
}



================================================
FILE: macos/Runner/Base.lproj/MainMenu.xib
================================================
<?xml version="1.0" encoding="UTF-8"?>
<document type="com.apple.InterfaceBuilder3.Cocoa.XIB" version="3.0" toolsVersion="14490.70" targetRuntime="MacOSX.Cocoa" propertyAccessControl="none" useAutolayout="YES" customObjectInstantitationMethod="direct">
    <dependencies>
        <deployment identifier="macosx"/>
        <plugIn identifier="com.apple.InterfaceBuilder.CocoaPlugin" version="14490.70"/>
        <capability name="documents saved in the Xcode 8 format" minToolsVersion="8.0"/>
    </dependencies>
    <objects>
        <customObject id="-2" userLabel="File's Owner" customClass="NSApplication">
            <connections>
                <outlet property="delegate" destination="Voe-Tx-rLC" id="GzC-gU-4Uq"/>
            </connections>
        </customObject>
        <customObject id="-1" userLabel="First Responder" customClass="FirstResponder"/>
        <customObject id="-3" userLabel="Application" customClass="NSObject"/>
        <customObject id="Voe-Tx-rLC" customClass="AppDelegate" customModule="Runner" customModuleProvider="target">
            <connections>
                <outlet property="applicationMenu" destination="uQy-DD-JDr" id="XBo-yE-nKs"/>
                <outlet property="mainFlutterWindow" destination="QvC-M9-y7g" id="gIp-Ho-8D9"/>
            </connections>
        </customObject>
        <customObject id="YLy-65-1bz" customClass="NSFontManager"/>
        <menu title="Main Menu" systemMenu="main" id="AYu-sK-qS6">
            <items>
                <menuItem title="APP_NAME" id="1Xt-HY-uBw">
                    <modifierMask key="keyEquivalentModifierMask"/>
                    <menu key="submenu" title="APP_NAME" systemMenu="apple" id="uQy-DD-JDr">
                        <items>
                            <menuItem title="About APP_NAME" id="5kV-Vb-QxS">
                                <modifierMask key="keyEquivalentModifierMask"/>
                                <connections>
                                    <action selector="orderFrontStandardAboutPanel:" target="-1" id="Exp-CZ-Vem"/>
                                </connections>
                            </menuItem>
                            <menuItem isSeparatorItem="YES" id="VOq-y0-SEH"/>
                            <menuItem title="Preferences…" keyEquivalent="," id="BOF-NM-1cW"/>
                            <menuItem isSeparatorItem="YES" id="wFC-TO-SCJ"/>
                            <menuItem title="Services" id="NMo-om-nkz">
                                <modifierMask key="keyEquivalentModifierMask"/>
                                <menu key="submenu" title="Services" systemMenu="services" id="hz9-B4-Xy5"/>
                            </menuItem>
                            <menuItem isSeparatorItem="YES" id="4je-JR-u6R"/>
                            <menuItem title="Hide APP_NAME" keyEquivalent="h" id="Olw-nP-bQN">
                                <connections>
                                    <action selector="hide:" target="-1" id="PnN-Uc-m68"/>
                                </connections>
                            </menuItem>
                            <menuItem title="Hide Others" keyEquivalent="h" id="Vdr-fp-XzO">
                                <modifierMask key="keyEquivalentModifierMask" option="YES" command="YES"/>
                                <connections>
                                    <action selector="hideOtherApplications:" target="-1" id="VT4-aY-XCT"/>
                                </connections>
                            </menuItem>
                            <menuItem title="Show All" id="Kd2-mp-pUS">
                                <modifierMask key="keyEquivalentModifierMask"/>
                                <connections>
                                    <action selector="unhideAllApplications:" target="-1" id="Dhg-Le-xox"/>
                                </connections>
                            </menuItem>
                            <menuItem isSeparatorItem="YES" id="kCx-OE-vgT"/>
                            <menuItem title="Quit APP_NAME" keyEquivalent="q" id="4sb-4s-VLi">
                                <connections>
                                    <action selector="terminate:" target="-1" id="Te7-pn-YzF"/>
                                </connections>
                            </menuItem>
                        </items>
                    </menu>
                </menuItem>
                <menuItem title="Edit" id="5QF-Oa-p0T">
                    <modifierMask key="keyEquivalentModifierMask"/>
                    <menu key="submenu" title="Edit" id="W48-6f-4Dl">
                        <items>
                            <menuItem title="Undo" keyEquivalent="z" id="dRJ-4n-Yzg">
                                <connections>
                                    <action selector="undo:" target="-1" id="M6e-cu-g7V"/>
                                </connections>
                            </menuItem>
                            <menuItem title="Redo" keyEquivalent="Z" id="6dh-zS-Vam">
                                <connections>
                                    <action selector="redo:" target="-1" id="oIA-Rs-6OD"/>
                                </connections>
                            </menuItem>
                            <menuItem isSeparatorItem="YES" id="WRV-NI-Exz"/>
                            <menuItem title="Cut" keyEquivalent="x" id="uRl-iY-unG">
                                <connections>
                                    <action selector="cut:" target="-1" id="YJe-68-I9s"/>
                                </connections>
                            </menuItem>
                            <menuItem title="Copy" keyEquivalent="c" id="x3v-GG-iWU">
                                <connections>
                                    <action selector="copy:" target="-1" id="G1f-GL-Joy"/>
                                </connections>
                            </menuItem>
                            <menuItem title="Paste" keyEquivalent="v" id="gVA-U4-sdL">
                                <connections>
                                    <action selector="paste:" target="-1" id="UvS-8e-Qdg"/>
                                </connections>
                            </menuItem>
                            <menuItem title="Paste and Match Style" keyEquivalent="V" id="WeT-3V-zwk">
                                <modifierMask key="keyEquivalentModifierMask" option="YES" command="YES"/>
                                <connections>
                                    <action selector="pasteAsPlainText:" target="-1" id="cEh-KX-wJQ"/>
                                </connections>
                            </menuItem>
                            <menuItem title="Delete" id="pa3-QI-u2k">
                                <modifierMask key="keyEquivalentModifierMask"/>
                                <connections>
                                    <action selector="delete:" target="-1" id="0Mk-Ml-PaM"/>
                                </connections>
                            </menuItem>
                            <menuItem title="Select All" keyEquivalent="a" id="Ruw-6m-B2m">
                                <connections>
                                    <action selector="selectAll:" target="-1" id="VNm-Mi-diN"/>
                                </connections>
                            </menuItem>
                            <menuItem isSeparatorItem="YES" id="uyl-h8-XO2"/>
                            <menuItem title="Find" id="4EN-yA-p0u">
                                <modifierMask key="keyEquivalentModifierMask"/>
                                <menu key="submenu" title="Find" id="1b7-l0-nxx">
                                    <items>
                                        <menuItem title="Find…" tag="1" keyEquivalent="f" id="Xz5-n4-O0W">
                                            <connections>
                                                <action selector="performFindPanelAction:" target="-1" id="cD7-Qs-BN4"/>
                                            </connections>
                                        </menuItem>
                                        <menuItem title="Find and Replace…" tag="12" keyEquivalent="f" id="YEy-JH-Tfz">
                                            <modifierMask key="keyEquivalentModifierMask" option="YES" command="YES"/>
                                            <connections>
                                                <action selector="performFindPanelAction:" target="-1" id="WD3-Gg-5AJ"/>
                                            </connections>
                                        </menuItem>
                                        <menuItem title="Find Next" tag="2" keyEquivalent="g" id="q09-fT-Sye">
                                            <connections>
                                                <action selector="performFindPanelAction:" target="-1" id="NDo-RZ-v9R"/>
                                            </connections>
                                        </menuItem>
                                        <menuItem title="Find Previous" tag="3" keyEquivalent="G" id="OwM-mh-QMV">
                                            <connections>
                                                <action selector="performFindPanelAction:" target="-1" id="HOh-sY-3ay"/>
                                            </connections>
                                        </menuItem>
                                        <menuItem title="Use Selection for Find" tag="7" keyEquivalent="e" id="buJ-ug-pKt">
                                            <connections>
                                                <action selector="performFindPanelAction:" target="-1" id="U76-nv-p5D"/>
                                            </connections>
                                        </menuItem>
                                        <menuItem title="Jump to Selection" keyEquivalent="j" id="S0p-oC-mLd">
                                            <connections>
                                                <action selector="centerSelectionInVisibleArea:" target="-1" id="IOG-6D-g5B"/>
                                            </connections>
                                        </menuItem>
                                    </items>
                                </menu>
                            </menuItem>
                            <menuItem title="Spelling and Grammar" id="Dv1-io-Yv7">
                                <modifierMask key="keyEquivalentModifierMask"/>
                                <menu key="submenu" title="Spelling" id="3IN-sU-3Bg">
                                    <items>
                                        <menuItem title="Show Spelling and Grammar" keyEquivalent=":" id="HFo-cy-zxI">
                                            <connections>
                                                <action selector="showGuessPanel:" target="-1" id="vFj-Ks-hy3"/>
                                            </connections>
                                        </menuItem>
                                        <menuItem title="Check Document Now" keyEquivalent=";" id="hz2-CU-CR7">
                                            <connections>
                                                <action selector="checkSpelling:" target="-1" id="fz7-VC-reM"/>
                                            </connections>
                                        </menuItem>
                                        <menuItem isSeparatorItem="YES" id="bNw-od-mp5"/>
                                        <menuItem title="Check Spelling While Typing" id="rbD-Rh-wIN">
                                            <modifierMask key="keyEquivalentModifierMask"/>
                                            <connections>
                                                <action selector="toggleContinuousSpellChecking:" target="-1" id="7w6-Qz-0kB"/>
                                            </connections>
                                        </menuItem>
                                        <menuItem title="Check Grammar With Spelling" id="mK6-2p-4JG">
                                            <modifierMask key="keyEquivalentModifierMask"/>
                                            <connections>
                                                <action selector="toggleGrammarChecking:" target="-1" id="muD-Qn-j4w"/>
                                            </connections>
                                        </menuItem>
                                        <menuItem title="Correct Spelling Automatically" id="78Y-hA-62v">
                                            <modifierMask key="keyEquivalentModifierMask"/>
                                            <connections>
                                                <action selector="toggleAutomaticSpellingCorrection:" target="-1" id="2lM-Qi-WAP"/>
                                            </connections>
                                        </menuItem>
                                    </items>
                                </menu>
                            </menuItem>
                            <menuItem title="Substitutions" id="9ic-FL-obx">
                                <modifierMask key="keyEquivalentModifierMask"/>
                                <menu key="submenu" title="Substitutions" id="FeM-D8-WVr">
                                    <items>
                                        <menuItem title="Show Substitutions" id="z6F-FW-3nz">
                                            <modifierMask key="keyEquivalentModifierMask"/>
                                            <connections>
                                                <action selector="orderFrontSubstitutionsPanel:" target="-1" id="oku-mr-iSq"/>
                                            </connections>
                                        </menuItem>
                                        <menuItem isSeparatorItem="YES" id="gPx-C9-uUO"/>
                                        <menuItem title="Smart Copy/Paste" id="9yt-4B-nSM">
                                            <modifierMask key="keyEquivalentModifierMask"/>
                                            <connections>
                                                <action selector="toggleSmartInsertDelete:" target="-1" id="3IJ-Se-DZD"/>
                                            </connections>
                                        </menuItem>
                                        <menuItem title="Smart Quotes" id="hQb-2v-fYv">
                                            <modifierMask key="keyEquivalentModifierMask"/>
                                            <connections>
                                                <action selector="toggleAutomaticQuoteSubstitution:" target="-1" id="ptq-xd-QOA"/>
                                            </connections>
                                        </menuItem>
                                        <menuItem title="Smart Dashes" id="rgM-f4-ycn">
                                            <modifierMask key="keyEquivalentModifierMask"/>
                                            <connections>
                                                <action selector="toggleAutomaticDashSubstitution:" target="-1" id="oCt-pO-9gS"/>
                                            </connections>
                                        </menuItem>
                                        <menuItem title="Smart Links" id="cwL-P1-jid">
                                            <modifierMask key="keyEquivalentModifierMask"/>
                                            <connections>
                                                <action selector="toggleAutomaticLinkDetection:" target="-1" id="Gip-E3-Fov"/>
                                            </connections>
                                        </menuItem>
                                        <menuItem title="Data Detectors" id="tRr-pd-1PS">
                                            <modifierMask key="keyEquivalentModifierMask"/>
                                            <connections>
                                                <action selector="toggleAutomaticDataDetection:" target="-1" id="R1I-Nq-Kbl"/>
                                            </connections>
                                        </menuItem>
                                        <menuItem title="Text Replacement" id="HFQ-gK-NFA">
                                            <modifierMask key="keyEquivalentModifierMask"/>
                                            <connections>
                                                <action selector="toggleAutomaticTextReplacement:" target="-1" id="DvP-Fe-Py6"/>
                                            </connections>
                                        </menuItem>
                                    </items>
                                </menu>
                            </menuItem>
                            <menuItem title="Transformations" id="2oI-Rn-ZJC">
                                <modifierMask key="keyEquivalentModifierMask"/>
                                <menu key="submenu" title="Transformations" id="c8a-y6-VQd">
                                    <items>
                                        <menuItem title="Make Upper Case" id="vmV-6d-7jI">
                                            <modifierMask key="keyEquivalentModifierMask"/>
                                            <connections>
                                                <action selector="uppercaseWord:" target="-1" id="sPh-Tk-edu"/>
                                            </connections>
                                        </menuItem>
                                        <menuItem title="Make Lower Case" id="d9M-CD-aMd">
                                            <modifierMask key="keyEquivalentModifierMask"/>
                                            <connections>
                                                <action selector="lowercaseWord:" target="-1" id="iUZ-b5-hil"/>
                                            </connections>
                                        </menuItem>
                                        <menuItem title="Capitalize" id="UEZ-Bs-lqG">
                                            <modifierMask key="keyEquivalentModifierMask"/>
                                            <connections>
                                                <action selector="capitalizeWord:" target="-1" id="26H-TL-nsh"/>
                                            </connections>
                                        </menuItem>
                                    </items>
                                </menu>
                            </menuItem>
                            <menuItem title="Speech" id="xrE-MZ-jX0">
                                <modifierMask key="keyEquivalentModifierMask"/>
                                <menu key="submenu" title="Speech" id="3rS-ZA-NoH">
                                    <items>
                                        <menuItem title="Start Speaking" id="Ynk-f8-cLZ">
                                            <modifierMask key="keyEquivalentModifierMask"/>
                                            <connections>
                                                <action selector="startSpeaking:" target="-1" id="654-Ng-kyl"/>
                                            </connections>
                                        </menuItem>
                                        <menuItem title="Stop Speaking" id="Oyz-dy-DGm">
                                            <modifierMask key="keyEquivalentModifierMask"/>
                                            <connections>
                                                <action selector="stopSpeaking:" target="-1" id="dX8-6p-jy9"/>
                                            </connections>
                                        </menuItem>
                                    </items>
                                </menu>
                            </menuItem>
                        </items>
                    </menu>
                </menuItem>
                <menuItem title="View" id="H8h-7b-M4v">
                    <modifierMask key="keyEquivalentModifierMask"/>
                    <menu key="submenu" title="View" id="HyV-fh-RgO">
                        <items>
                            <menuItem title="Enter Full Screen" keyEquivalent="f" id="4J7-dP-txa">
                                <modifierMask key="keyEquivalentModifierMask" control="YES" command="YES"/>
                                <connections>
                                    <action selector="toggleFullScreen:" target="-1" id="dU3-MA-1Rq"/>
                                </connections>
                            </menuItem>
                        </items>
                    </menu>
                </menuItem>
                <menuItem title="Window" id="aUF-d1-5bR">
                    <modifierMask key="keyEquivalentModifierMask"/>
                    <menu key="submenu" title="Window" systemMenu="window" id="Td7-aD-5lo">
                        <items>
                            <menuItem title="Minimize" keyEquivalent="m" id="OY7-WF-poV">
                                <connections>
                                    <action selector="performMiniaturize:" target="-1" id="VwT-WD-YPe"/>
                                </connections>
                            </menuItem>
                            <menuItem title="Zoom" id="R4o-n2-Eq4">
                                <modifierMask key="keyEquivalentModifierMask"/>
                                <connections>
                                    <action selector="performZoom:" target="-1" id="DIl-cC-cCs"/>
                                </connections>
                            </menuItem>
                            <menuItem isSeparatorItem="YES" id="eu3-7i-yIM"/>
                            <menuItem title="Bring All to Front" id="LE2-aR-0XJ">
                                <modifierMask key="keyEquivalentModifierMask"/>
                                <connections>
                                    <action selector="arrangeInFront:" target="-1" id="DRN-fu-gQh"/>
                                </connections>
                            </menuItem>
                        </items>
                    </menu>
                </menuItem>
                <menuItem title="Help" id="EPT-qC-fAb">
                    <modifierMask key="keyEquivalentModifierMask"/>
                    <menu key="submenu" title="Help" systemMenu="help" id="rJ0-wn-3NY"/>
                </menuItem>
            </items>
            <point key="canvasLocation" x="142" y="-258"/>
        </menu>
        <window title="APP_NAME" allowsToolTipsWhenApplicationIsInactive="NO" autorecalculatesKeyViewLoop="NO" releasedWhenClosed="NO" animationBehavior="default" id="QvC-M9-y7g" customClass="MainFlutterWindow" customModule="Runner" customModuleProvider="target">
            <windowStyleMask key="styleMask" titled="YES" closable="YES" miniaturizable="YES" resizable="YES"/>
            <rect key="contentRect" x="335" y="390" width="800" height="600"/>
            <rect key="screenRect" x="0.0" y="0.0" width="2560" height="1577"/>
            <view key="contentView" wantsLayer="YES" id="EiT-Mj-1SZ">
                <rect key="frame" x="0.0" y="0.0" width="800" height="600"/>
                <autoresizingMask key="autoresizingMask"/>
            </view>
        </window>
    </objects>
</document>



================================================
FILE: macos/Runner/Configs/AppInfo.xcconfig
================================================
// Application-level settings for the Runner target.
//
// This may be replaced with something auto-generated from metadata (e.g., pubspec.yaml) in the
// future. If not, the values below would default to using the project name when this becomes a
// 'flutter create' template.

// The application's name. By default this is also the title of the Flutter window.
PRODUCT_NAME = icem_bus

// The application's bundle identifier
PRODUCT_BUNDLE_IDENTIFIER = com.icem.bus.icemBus

// The copyright displayed in application information
PRODUCT_COPYRIGHT = Copyright © 2026 com.icem.bus. All rights reserved.



================================================
FILE: macos/Runner/Configs/Debug.xcconfig
================================================
#include "../../Flutter/Flutter-Debug.xcconfig"
#include "Warnings.xcconfig"



================================================
FILE: macos/Runner/Configs/Release.xcconfig
================================================
#include "../../Flutter/Flutter-Release.xcconfig"
#include "Warnings.xcconfig"



================================================
FILE: macos/Runner/Configs/Warnings.xcconfig
================================================
WARNING_CFLAGS = -Wall -Wconditional-uninitialized -Wnullable-to-nonnull-conversion -Wmissing-method-return-type -Woverlength-strings
GCC_WARN_UNDECLARED_SELECTOR = YES
CLANG_UNDEFINED_BEHAVIOR_SANITIZER_NULLABILITY = YES
CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE
CLANG_WARN__DUPLICATE_METHOD_MATCH = YES
CLANG_WARN_PRAGMA_PACK = YES
CLANG_WARN_STRICT_PROTOTYPES = YES
CLANG_WARN_COMMA = YES
GCC_WARN_STRICT_SELECTOR_MATCH = YES
CLANG_WARN_OBJC_REPEATED_USE_OF_WEAK = YES
CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES
GCC_WARN_SHADOW = YES
CLANG_WARN_UNREACHABLE_CODE = YES



================================================
FILE: macos/RunnerTests/RunnerTests.swift
================================================
import Cocoa
import FlutterMacOS
import XCTest

class RunnerTests: XCTestCase {

  func testExample() {
    // If you add code to the Runner application, consider adding tests here.
    // See https://developer.apple.com/documentation/xctest for more information about using XCTest.
  }

}



================================================
FILE: test/bus_pass_security_widget_test.dart
================================================
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_widgets.dart';

void main() {
  group('AdminApplicationCard Security & State Tests', () {
    testWidgets('Unpaid application has disabled/locked approve button and shows warning', (tester) async {
      bool approved = false;

      final unpaidApp = {
        'id': 'APP-UNPAID-001',
        'studentName': 'Rahul Sharma',
        'prn': 'PRN12345',
        'collegeId': 'ENG001',
        'course': 'Computer Engineering',
        'routeName': 'Route 1 - Nigdi to ICEM',
        'boardingStop': 'Nigdi',
        'destinationStop': 'ICEM Campus',
        'fare': 4500.0,
        'paymentStatus': 'Pending',
        'passStatus': 'Payment Pending',
        'status': 'Payment Pending',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminApplicationCard(
              application: unpaidApp,
              onApprove: () {
                approved = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check displayed statuses
      expect(find.text('Status: Payment Pending'), findsOneWidget);
      expect(find.text('Payment: Unpaid'), findsOneWidget);

      // Check security warning
      expect(find.text('Payment required before approval'), findsOneWidget);

      // Verify Approve button is locked as 'Payment Required'
      expect(find.text('Payment Required'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);

      // Tap the locked button
      await tester.tap(find.text('Payment Required'));
      await tester.pumpAndSettle();

      // Verify onApprove was NOT called
      expect(approved, isFalse);

      // Verify SnackBar was shown
      expect(find.textContaining('Payment required before approval'), findsWidgets);
    });

    testWidgets('Verified paid application enables Approve button and triggers onApprove', (tester) async {
      bool approved = false;

      final paidApp = {
        'id': 'APP-PAID-002',
        'studentName': 'Priya Patil',
        'prn': 'PRN67890',
        'collegeId': 'ENG002',
        'course': 'IT Engineering',
        'routeName': 'Route 2 - Hinjewadi to ICEM',
        'boardingStop': 'Hinjewadi Phase 1',
        'destinationStop': 'ICEM Campus',
        'fare': 4500.0,
        'paymentStatus': 'Paid',
        'passStatus': 'Pending',
        'status': 'Pending',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminApplicationCard(
              application: paidApp,
              onApprove: () {
                approved = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check displayed statuses
      expect(find.text('Status: Pending Approval'), findsOneWidget);
      expect(find.text('Payment: Paid'), findsOneWidget);

      // Warning should NOT be present for paid application
      expect(find.text('Payment required before approval'), findsNothing);

      // Verify Approve button is enabled
      expect(find.text('Approve'), findsOneWidget);

      // Tap Approve
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      // Verify onApprove was called
      expect(approved, isTrue);
    });

    testWidgets('Approved application displays Approved status and does not show approve button', (tester) async {
      final approvedApp = {
        'id': 'APP-APPROVED-003',
        'studentName': 'Amit Deshmukh',
        'prn': 'PRN11223',
        'collegeId': 'ENG003',
        'course': 'Mechanical Engineering',
        'routeName': 'Route 1 - Nigdi to ICEM',
        'boardingStop': 'Akurdi',
        'destinationStop': 'ICEM Campus',
        'fare': 4500.0,
        'paymentStatus': 'Paid',
        'passStatus': 'Approved',
        'status': 'Approved',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminApplicationCard(
              application: approvedApp,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Status: Approved'), findsOneWidget);
      expect(find.text('Payment: Paid'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Payment Required'), findsNothing);
    });

    testWidgets('Unpaid application with pending status prevents approval and displays error toast', (tester) async {
      bool approved = false;

      final unpaidPendingApp = {
        'id': 'APP-UNPAID-004',
        'studentName': 'Sneha More',
        'prn': 'PRN99887',
        'collegeId': 'ENG004',
        'course': 'Civil Engineering',
        'routeName': 'Route 3 - Kothrud to ICEM',
        'boardingStop': 'Chandani Chowk',
        'destinationStop': 'ICEM Campus',
        'fare': 4500.0,
        'paymentStatus': 'Unpaid',
        'passStatus': 'Payment Pending',
        'status': 'Payment Pending',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminApplicationCard(
              application: unpaidPendingApp,
              onApprove: () {
                approved = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ensure button says Payment Required
      final paymentReqBtn = find.text('Payment Required');
      expect(paymentReqBtn, findsOneWidget);

      // Attempt to tap
      await tester.tap(paymentReqBtn);
      await tester.pumpAndSettle();

      // Must NOT be approved
      expect(approved, isFalse);

      // SnackBar with required text displayed
      expect(find.text('Payment required before approval. Student must complete verified payment first.'), findsOneWidget);
    });
  });
}



================================================
FILE: test/payment_system_test.dart
================================================
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/features/payment/data/models/payment_config_model.dart';
import 'package:icem_bus/features/payment/domain/entities/payment_entity.dart';
import 'package:icem_bus/features/payment/data/models/payment_model.dart';
import 'package:icem_bus/features/payment/presentation/views/student_payment_screen.dart';
import 'package:icem_bus/features/payment/presentation/views/pay_via_upi_qr_screen.dart';
import 'package:icem_bus/features/payment/presentation/views/payment_receipt_screen.dart';
import 'package:icem_bus/features/payment/data/repositories/payment_config_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Payment Config & Model Unit Tests', () {
    test('Default payment configuration contains correct fee and settings', () {
      final config = PaymentConfigModel.defaultConfig();
      expect(config.defaultFee, 4500.0);
      expect(config.feeInPaise, 450000);
      expect(config.currency, 'INR');
      expect(config.environment, 'TEST');
    });

    test('PaymentModel serializes and deserializes accurately with consistent ₹4500', () {
      final model = PaymentModel(
        paymentId: 'PAY-101',
        applicationId: 'APP-202',
        studentId: 'STU-303',
        studentName: 'Yash Kacholiya',
        routeId: 'ROUTE-01',
        routeName: 'Route 1 - Nigdi to ICEM',
        amount: 4500.0,
        currency: 'INR',
        paymentStatus: 'paid',
        paymentMethod: 'Razorpay',
        razorpayOrderId: 'order_12345',
        razorpayPaymentId: 'pay_67890',
        createdAt: DateTime(2026, 9, 28, 12, 0),
        paidAt: DateTime(2026, 9, 28, 12, 5),
      );

      final map = model.toMap();
      expect(map['amount'], 4500.0);
      expect(map['currency'], 'INR');
      expect(map['paymentStatus'], 'paid');
      expect(map['paymentMethod'], 'Razorpay');
      expect(map['razorpayOrderId'], 'order_12345');
      expect(map['razorpayPaymentId'], 'pay_67890');

      final fromMap = PaymentModel.fromMap(map, 'PAY-101');
      expect(fromMap.paymentId, 'PAY-101');
      expect(fromMap.amount, 4500.0);
      expect(fromMap.studentName, 'Yash Kacholiya');
      expect(fromMap.routeName, 'Route 1 - Nigdi to ICEM');
      expect(fromMap.fare, 4500.0);
    });
  });

  group('StudentPaymentScreen Razorpay Standard Checkout Tests', () {
    testWidgets('Renders simple and premium UI per Section 10 with PAY ₹4,500', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paymentConfigStreamProvider.overrideWith(
              (ref) => Stream.value(PaymentConfigModel.defaultConfig()),
            ),
          ],
          child: const MaterialApp(
            home: StudentPaymentScreen(
              testApplicationId: 'APP-TEST-999',
              testRouteName: 'Route 1 - Nigdi to ICEM',
              testStudentName: 'Yash Kacholiya',
              testStudentEmail: 'student@icem.edu',
              testStudentPhone: '9876543210',
              testRouteFee: 4500.0,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header and core items (Section 10)
      expect(find.text('ICEM BUS PASS PAYMENT'), findsOneWidget);
      expect(find.text('Route 1 - Nigdi to ICEM'), findsOneWidget);
      expect(find.text('Yash Kacholiya'), findsOneWidget);
      expect(find.text('₹4,500'), findsOneWidget);
      expect(find.text('Payment Pending'), findsWidgets);

      // Check primary button: PAY ₹4,500
      expect(find.text('PAY ₹4,500'), findsOneWidget);

      // Check small text: Secure payment powered by Razorpay
      expect(find.text('Secure payment powered by Razorpay'), findsOneWidget);

      // Verify custom manual UPI QR / UTR fields are REMOVED from the normal student payment screen
      expect(find.text('Pay via UPI QR'), findsNothing);
      expect(find.text('Direct UPI Transfer'), findsNothing);
      expect(find.text('Enter the 12-digit UTR'), findsNothing);
      expect(find.text('8766629441@axl'), findsNothing);
    });
  });

  group('Deprecated PayViaUpiQrScreen Test', () {
    testWidgets('Renders deprecation notice and redirect button to Razorpay checkout', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PayViaUpiQrScreen(
            applicationId: 'APP-TEST-999',
            routeName: 'Route 1 - Nigdi to ICEM',
            routeId: 'ROUTE-01',
            studentName: 'Yash Kacholiya',
            amount: 4500.0,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Direct Razorpay Checkout Required'), findsOneWidget);
      expect(find.text('Proceed to Razorpay Checkout'), findsOneWidget);
    });
  });

  group('PaymentReceiptScreen Widget Tests', () {
    testWidgets('Renders Section 13 payment receipt details correctly', (tester) async {
      final receiptPayment = PaymentEntity(
        paymentId: 'RCPT-100234',
        applicationId: 'APP-ICEM-777',
        studentId: 'STU-999',
        studentName: 'Yash Kacholiya',
        routeId: 'ROUTE-01',
        routeName: 'Route 1 - Nigdi to ICEM',
        amount: 4500.0,
        currency: 'INR',
        paymentStatus: 'paid',
        paymentMethod: 'UPI / Razorpay',
        razorpayPaymentId: 'pay_test_887766',
        receiptId: 'RCPT-100234',
        createdAt: DateTime(2026, 9, 28, 14, 30),
        paidAt: DateTime(2026, 9, 28, 14, 32),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PaymentReceiptScreen(
            paymentId: 'RCPT-100234',
            initialPayment: receiptPayment,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Section 13 elements
      expect(find.text('ICEM'), findsOneWidget);
      expect(find.text('Bus Pass Payment Receipt'), findsOneWidget);
      expect(find.text('Yash Kacholiya'), findsOneWidget);
      expect(find.text('APP-ICEM-777'), findsOneWidget);
      expect(find.text('Route 1 - Nigdi to ICEM'), findsOneWidget);
      expect(find.text('₹4,500'), findsWidgets);
      expect(find.text('UPI / Razorpay'), findsOneWidget);
      expect(find.text('pay_test_887766'), findsOneWidget);
      expect(find.text('PAID / VERIFIED'), findsWidgets);
      expect(find.text('RCPT-100234'), findsOneWidget);
    });
  });
}



================================================
FILE: test/settings_widget_test.dart
================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_settings_tab.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_settings_screen.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_dashboard.dart';
import 'package:icem_bus/features/admin/domain/admin_providers.dart';
import 'package:icem_bus/features/auth/domain/entities/user_entity.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_state.dart';
import 'package:icem_bus/services/storage/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAuthController extends AuthController {
  @override
  AuthState build() {
    return AuthState(
      user: UserEntity(
        uid: 'admin123',
        fullName: 'Test Admin',
        email: 'testadmin@icem.edu',
        role: 'Administrator',
        isEmailVerified: true,
        createdAt: DateTime(2026, 1, 15),
        updatedAt: DateTime(2026, 9, 12),
      ),
    );
  }

  @override
  Future<bool> updateProfile({
    required String fullName,
    String? mobile,
    String? department,
  }) async {
    state = state.copyWith(
      user: UserEntity(
        uid: 'admin123',
        fullName: fullName,
        email: 'testadmin@icem.edu',
        role: 'Administrator',
        isEmailVerified: true,
        mobile: mobile,
        department: department,
        createdAt: DateTime(2026, 1, 15),
        updatedAt: DateTime.now(),
      ),
    );
    return true;
  }
}

void main() {
  testWidgets('AdminSettingsTab renders all modules and profile correctly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;

    SharedPreferences.setMockInitialValues({'language': 'english'});
    final sharedPreferences = await SharedPreferences.getInstance();
    final storageService = StorageService(sharedPreferences);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storageService),
          authControllerProvider.overrideWith(() => FakeAuthController()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AdminSettingsTab(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Console Settings'), findsOneWidget);

    // 1. Admin Profile
    expect(find.text('Admin Profile'), findsOneWidget);
    expect(find.text('Test Admin'), findsOneWidget);
    expect(find.text('testadmin@icem.edu'), findsOneWidget);
    expect(find.text('Administrator'), findsOneWidget);
    expect(find.text('Edit Profile Details'), findsOneWidget);

    // 2. Appearance
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Theme Mode'), findsOneWidget);
    expect(find.text('Compact UI Density'), findsOneWidget);

    // 3. Notification Settings
    expect(find.text('Notification Settings'), findsOneWidget);
    expect(find.text('Enable Notifications'), findsOneWidget);
    expect(find.text('Application Updates'), findsOneWidget);
    expect(find.text('New Bus Pass Applications'), findsOneWidget);
    expect(find.text('Payment Notifications'), findsOneWidget);

    // 4. Security
    expect(find.text('Security'), findsOneWidget);
    expect(find.text('Change Password'), findsOneWidget);
    expect(find.text('Password Reset Email'), findsOneWidget);

    // 5. Session / Login Security
    expect(find.text('Session & Login Security'), findsOneWidget);
    expect(find.text('Last Sign-In Timestamp'), findsOneWidget);

    // 6. Application Settings (scroll into view)
    await tester.scrollUntilVisible(find.text('Application Settings'), 300);
    expect(find.text('Application Settings'), findsOneWidget);
    expect(find.text('ICEM Smart Bus Pass'), findsWidgets);
    expect(find.text('Clear Local Cache'), findsOneWidget);

    // 7. System Status
    await tester.scrollUntilVisible(find.text('System Status'), 300);
    expect(find.text('System Status'), findsOneWidget);
    expect(find.text('Firebase Authentication'), findsOneWidget);
    expect(find.text('Cloud Firestore'), findsOneWidget);

    // 8. Admin Data Management
    await tester.scrollUntilVisible(find.text('Admin Data Management'), 300);
    expect(find.text('Admin Data Management'), findsOneWidget);
    expect(find.text('Refresh Data'), findsOneWidget);

    // 9. About ICEM
    await tester.scrollUntilVisible(find.text('About ICEM'), 300);
    expect(find.text('About ICEM'), findsOneWidget);
    expect(find.text('Indira College of Engineering & Management'), findsOneWidget);

    // 10. Help & Support
    await tester.scrollUntilVisible(find.text('Help & Support'), 300);
    expect(find.text('Help & Support'), findsOneWidget);
    expect(find.text('Report an Issue'), findsOneWidget);
    expect(find.text('Admin FAQ'), findsOneWidget);

    // 11. Danger Zone
    await tester.scrollUntilVisible(find.text('Danger Zone'), 300);
    expect(find.text('Danger Zone'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
    expect(find.text('Delete Account'), findsOneWidget);

    // Scroll back to top to test Edit Profile Dialog trigger
    await tester.scrollUntilVisible(find.text('Edit Profile Details'), -100);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Profile Details'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Administrator Profile'), findsOneWidget);

    // Reset physical size after test
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('AdminSettingsScreen renders correctly with AppBar and AdminSettingsTab', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;

    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();
    final storageService = StorageService(sharedPreferences);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storageService),
          authControllerProvider.overrideWith(() => FakeAuthController()),
        ],
        child: const MaterialApp(
          home: AdminSettingsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Console Settings'), findsOneWidget);
    expect(find.text('Test Admin'), findsOneWidget);

    // Reset physical size after test
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('Theme switching changes global settings and persists to StorageService', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1.0;

    SharedPreferences.setMockInitialValues({'theme_mode': 'system'});
    final sharedPreferences = await SharedPreferences.getInstance();
    final storageService = StorageService(sharedPreferences);

    late WidgetRef capturedRef;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storageService),
          authControllerProvider.overrideWith(() => FakeAuthController()),
        ],
        child: Consumer(
          builder: (context, ref, child) {
            capturedRef = ref;
            final settings = ref.watch(settingsNotifierProvider);
            return MaterialApp(
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),
              themeMode: settings.themeMode,
              home: const Scaffold(
                body: AdminSettingsTab(),
              ),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Initial state should be System
    expect(capturedRef.read(settingsNotifierProvider).themeMode, equals(ThemeMode.system));

    // Tap "Dark" pill
    final darkPillFinder = find.widgetWithText(InkWell, 'Dark');
    expect(darkPillFinder, findsOneWidget);
    await tester.tap(darkPillFinder);
    await tester.pumpAndSettle();

    // Verify Riverpod state updated to Dark
    expect(capturedRef.read(settingsNotifierProvider).themeMode, equals(ThemeMode.dark));
    // Verify persisted in storage
    expect(storageService.getString('themeMode'), equals('dark'));

    // Tap "Light" pill
    final lightPillFinder = find.widgetWithText(InkWell, 'Light');
    expect(lightPillFinder, findsOneWidget);
    await tester.tap(lightPillFinder);
    await tester.pumpAndSettle();

    // Verify Riverpod state updated to Light
    expect(capturedRef.read(settingsNotifierProvider).themeMode, equals(ThemeMode.light));
    // Verify persisted in storage
    expect(storageService.getString('themeMode'), equals('light'));

    // Tap "System" pill
    final systemPillFinder = find.widgetWithText(InkWell, 'System');
    expect(systemPillFinder, findsOneWidget);
    await tester.tap(systemPillFinder);
    await tester.pumpAndSettle();

    // Verify Riverpod state updated to System
    expect(capturedRef.read(settingsNotifierProvider).themeMode, equals(ThemeMode.system));
    // Verify persisted in storage
    expect(storageService.getString('themeMode'), equals('system'));

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('AdminSettingsTab scrolls smoothly from top to bottom and back on mobile screen size', (WidgetTester tester) async {
    // Physical size corresponding to Realme 15 (1280x2800 at density 476 / ratio 2.975 -> ~430x941)
    tester.view.physicalSize = const Size(430, 941);
    tester.view.devicePixelRatio = 1.0;

    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();
    final storageService = StorageService(sharedPreferences);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storageService),
          authControllerProvider.overrideWith(() => FakeAuthController()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AdminSettingsTab(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Console Settings'), findsOneWidget);

    // Verify sections reachable in order from top to bottom
    await tester.scrollUntilVisible(find.text('Admin Profile'), 200);
    expect(find.text('Admin Profile'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Appearance'), 200);
    expect(find.text('Appearance'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Notification Settings'), 200);
    expect(find.text('Notification Settings'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Security'), 200);
    expect(find.text('Security'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Session & Login Security'), 200);
    expect(find.text('Session & Login Security'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Application Settings'), 200);
    expect(find.text('Application Settings'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('System Status'), 200);
    expect(find.text('System Status'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Admin Data Management'), 200);
    expect(find.text('Admin Data Management'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('About ICEM'), 200);
    expect(find.text('About ICEM'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Help & Support'), 200);
    expect(find.text('Help & Support'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Danger Zone'), 200);
    expect(find.text('Danger Zone'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
    expect(find.text('Delete Account'), findsOneWidget);

    // Scroll back from BOTTOM to TOP
    await tester.scrollUntilVisible(find.text('Console Settings'), -200);
    expect(find.text('Console Settings'), findsOneWidget);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('AdminDashboardScreen tab 8 renders and scrolls completely on Realme 15 dimensions', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 941);
    tester.view.devicePixelRatio = 1.0;

    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();
    final storageService = StorageService(sharedPreferences);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storageService),
          authControllerProvider.overrideWith(() => FakeAdminDashboardAuthController()),
          adminTabProvider.overrideWith((ref) => 8),
        ],
        child: const MaterialApp(
          home: AdminDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Console Settings'), findsOneWidget);

    // Scroll to Danger Zone at the very bottom
    await tester.scrollUntilVisible(find.text('Danger Zone'), 200);
    expect(find.text('Danger Zone'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
    expect(find.text('Delete Account'), findsOneWidget);

    // Scroll back to top
    await tester.scrollUntilVisible(find.text('Console Settings'), -200);
    expect(find.text('Console Settings'), findsOneWidget);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}

class FakeAdminDashboardAuthController extends AuthController {
  @override
  AuthState build() {
    return AuthState(
      user: UserEntity(
        uid: 'admin123',
        fullName: 'Test Admin',
        email: 'testadmin@icem.edu',
        role: 'Admin',
        isEmailVerified: true,
        createdAt: DateTime(2026, 1, 15),
        updatedAt: DateTime(2026, 9, 12),
      ),
    );
  }
}





================================================
FILE: test/widget_test.dart
================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icem_bus/app/app.dart';
import 'package:icem_bus/services/storage/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App starts on Splash Screen and navigates to Onboarding Screen', (WidgetTester tester) async {
    // Setup Mock SharedPreferences for storage service
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();
    final storageService = StorageService(sharedPreferences);

    // Build the main app with Riverpod providers overridden for test environment
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storageService),
        ],
        child: const MyApp(),
      ),
    );

    // 1. Verify that the Splash Screen elements are rendered initially
    expect(find.text('ICEM SMART BUS'), findsOneWidget);
    expect(find.text('Pass Management System'), findsOneWidget);

    // 2. Advance the timer to let the splash navigation execute
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle(); // Wait for route transition animation

    // 3. Verify that we have automatically transitioned to the Onboarding Screen
    expect(find.text('Smart Digital Pass'), findsOneWidget);
    expect(find.text('Next Route'), findsOneWidget);
  });
}



================================================
FILE: web/index.html
================================================
<!DOCTYPE html>
<html>
<head>
  <!--
    If you are serving your web app in a path other than the root, change the
    href value below to reflect the base path you are serving from.

    The path provided below has to start and end with a slash "/" in order for
    it to work correctly.

    For more details:
    * https://developer.mozilla.org/en-US/docs/Web/HTML/Element/base

    This is a placeholder for base href that will be replaced by the value of
    the `--base-href` argument provided to `flutter build`.
  -->
  <base href="$FLUTTER_BASE_HREF">

  <meta charset="UTF-8">
  <meta content="IE=Edge" http-equiv="X-UA-Compatible">
  <meta name="description" content="A new Flutter project.">

  <!-- iOS meta tags & icons -->
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black">
  <meta name="apple-mobile-web-app-title" content="icem_bus">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">

  <!-- Favicon -->
  <link rel="icon" type="image/png" href="favicon.png"/>

  <title>icem_bus</title>
  <link rel="manifest" href="manifest.json">
</head>
<body>
  <!--
    You can customize the "flutter_bootstrap.js" script.
    This is useful to provide a custom configuration to the Flutter loader
    or to give the user feedback during the initialization process.

    For more details:
    * https://docs.flutter.dev/platform-integration/web/initialization
  -->
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>



================================================
FILE: web/manifest.json
================================================
{
    "name": "icem_bus",
    "short_name": "icem_bus",
    "start_url": ".",
    "display": "standalone",
    "background_color": "#0175C2",
    "theme_color": "#0175C2",
    "description": "A new Flutter project.",
    "orientation": "portrait-primary",
    "prefer_related_applications": false,
    "icons": [
        {
            "src": "icons/Icon-192.png",
            "sizes": "192x192",
            "type": "image/png"
        },
        {
            "src": "icons/Icon-512.png",
            "sizes": "512x512",
            "type": "image/png"
        },
        {
            "src": "icons/Icon-maskable-192.png",
            "sizes": "192x192",
            "type": "image/png",
            "purpose": "maskable"
        },
        {
            "src": "icons/Icon-maskable-512.png",
            "sizes": "512x512",
            "type": "image/png",
            "purpose": "maskable"
        }
    ]
}



================================================
FILE: windows/CMakeLists.txt
================================================
# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(icem_bus LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "icem_bus")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)


# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)



================================================
FILE: windows/flutter/CMakeLists.txt
================================================
# This file controls Flutter-level build steps. It should not be edited.
cmake_minimum_required(VERSION 3.14)

set(EPHEMERAL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ephemeral")

# Configuration provided via flutter tool.
include(${EPHEMERAL_DIR}/generated_config.cmake)

# TODO: Move the rest of this into files in ephemeral. See
# https://github.com/flutter/flutter/issues/57146.
set(WRAPPER_ROOT "${EPHEMERAL_DIR}/cpp_client_wrapper")

# Set fallback configurations for older versions of the flutter tool.
if (NOT DEFINED FLUTTER_TARGET_PLATFORM)
  set(FLUTTER_TARGET_PLATFORM "windows-x64")
endif()

# === Flutter Library ===
set(FLUTTER_LIBRARY "${EPHEMERAL_DIR}/flutter_windows.dll")

# Published to parent scope for install step.
set(FLUTTER_LIBRARY ${FLUTTER_LIBRARY} PARENT_SCOPE)
set(FLUTTER_ICU_DATA_FILE "${EPHEMERAL_DIR}/icudtl.dat" PARENT_SCOPE)
set(PROJECT_BUILD_DIR "${PROJECT_DIR}/build/" PARENT_SCOPE)
set(AOT_LIBRARY "${PROJECT_DIR}/build/windows/app.so" PARENT_SCOPE)

list(APPEND FLUTTER_LIBRARY_HEADERS
  "flutter_export.h"
  "flutter_windows.h"
  "flutter_messenger.h"
  "flutter_plugin_registrar.h"
  "flutter_texture_registrar.h"
)
list(TRANSFORM FLUTTER_LIBRARY_HEADERS PREPEND "${EPHEMERAL_DIR}/")
add_library(flutter INTERFACE)
target_include_directories(flutter INTERFACE
  "${EPHEMERAL_DIR}"
)
target_link_libraries(flutter INTERFACE "${FLUTTER_LIBRARY}.lib")
add_dependencies(flutter flutter_assemble)

# === Wrapper ===
list(APPEND CPP_WRAPPER_SOURCES_CORE
  "core_implementations.cc"
  "standard_codec.cc"
)
list(TRANSFORM CPP_WRAPPER_SOURCES_CORE PREPEND "${WRAPPER_ROOT}/")
list(APPEND CPP_WRAPPER_SOURCES_PLUGIN
  "plugin_registrar.cc"
)
list(TRANSFORM CPP_WRAPPER_SOURCES_PLUGIN PREPEND "${WRAPPER_ROOT}/")
list(APPEND CPP_WRAPPER_SOURCES_APP
  "flutter_engine.cc"
  "flutter_view_controller.cc"
)
list(TRANSFORM CPP_WRAPPER_SOURCES_APP PREPEND "${WRAPPER_ROOT}/")

# Wrapper sources needed for a plugin.
add_library(flutter_wrapper_plugin STATIC
  ${CPP_WRAPPER_SOURCES_CORE}
  ${CPP_WRAPPER_SOURCES_PLUGIN}
)
apply_standard_settings(flutter_wrapper_plugin)
set_target_properties(flutter_wrapper_plugin PROPERTIES
  POSITION_INDEPENDENT_CODE ON)
set_target_properties(flutter_wrapper_plugin PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_link_libraries(flutter_wrapper_plugin PUBLIC flutter)
target_include_directories(flutter_wrapper_plugin PUBLIC
  "${WRAPPER_ROOT}/include"
)
add_dependencies(flutter_wrapper_plugin flutter_assemble)

# Wrapper sources needed for the runner.
add_library(flutter_wrapper_app STATIC
  ${CPP_WRAPPER_SOURCES_CORE}
  ${CPP_WRAPPER_SOURCES_APP}
)
apply_standard_settings(flutter_wrapper_app)
target_link_libraries(flutter_wrapper_app PUBLIC flutter)
target_include_directories(flutter_wrapper_app PUBLIC
  "${WRAPPER_ROOT}/include"
)
add_dependencies(flutter_wrapper_app flutter_assemble)

# === Flutter tool backend ===
# _phony_ is a non-existent file to force this command to run every time,
# since currently there's no way to get a full input/output list from the
# flutter tool.
set(PHONY_OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/_phony_")
set_source_files_properties("${PHONY_OUTPUT}" PROPERTIES SYMBOLIC TRUE)
add_custom_command(
  OUTPUT ${FLUTTER_LIBRARY} ${FLUTTER_LIBRARY_HEADERS}
    ${CPP_WRAPPER_SOURCES_CORE} ${CPP_WRAPPER_SOURCES_PLUGIN}
    ${CPP_WRAPPER_SOURCES_APP}
    ${PHONY_OUTPUT}
  COMMAND ${CMAKE_COMMAND} -E env
    ${FLUTTER_TOOL_ENVIRONMENT}
    "${FLUTTER_ROOT}/packages/flutter_tools/bin/tool_backend.bat"
      ${FLUTTER_TARGET_PLATFORM} $<CONFIG>
  VERBATIM
)
add_custom_target(flutter_assemble DEPENDS
  "${FLUTTER_LIBRARY}"
  ${FLUTTER_LIBRARY_HEADERS}
  ${CPP_WRAPPER_SOURCES_CORE}
  ${CPP_WRAPPER_SOURCES_PLUGIN}
  ${CPP_WRAPPER_SOURCES_APP}
)



================================================
FILE: windows/flutter/generated_plugin_registrant.cc
================================================
//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <cloud_firestore/cloud_firestore_plugin_c_api.h>
#include <file_selector_windows/file_selector_windows.h>
#include <firebase_auth/firebase_auth_plugin_c_api.h>
#include <firebase_core/firebase_core_plugin_c_api.h>
#include <firebase_storage/firebase_storage_plugin_c_api.h>
#include <permission_handler_windows/permission_handler_windows_plugin.h>
#include <share_plus/share_plus_windows_plugin_c_api.h>
#include <url_launcher_windows/url_launcher_windows.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  CloudFirestorePluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("CloudFirestorePluginCApi"));
  FileSelectorWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FileSelectorWindows"));
  FirebaseAuthPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FirebaseAuthPluginCApi"));
  FirebaseCorePluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FirebaseCorePluginCApi"));
  FirebaseStoragePluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FirebaseStoragePluginCApi"));
  PermissionHandlerWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("PermissionHandlerWindowsPlugin"));
  SharePlusWindowsPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("SharePlusWindowsPluginCApi"));
  UrlLauncherWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("UrlLauncherWindows"));
}



================================================
FILE: windows/flutter/generated_plugin_registrant.h
================================================
//
//  Generated file. Do not edit.
//

// clang-format off

#ifndef GENERATED_PLUGIN_REGISTRANT_
#define GENERATED_PLUGIN_REGISTRANT_

#include <flutter/plugin_registry.h>

// Registers Flutter plugins.
void RegisterPlugins(flutter::PluginRegistry* registry);

#endif  // GENERATED_PLUGIN_REGISTRANT_



================================================
FILE: windows/flutter/generated_plugins.cmake
================================================
#
# Generated file, do not edit.
#

list(APPEND FLUTTER_PLUGIN_LIST
  cloud_firestore
  file_selector_windows
  firebase_auth
  firebase_core
  firebase_storage
  permission_handler_windows
  share_plus
  url_launcher_windows
)

list(APPEND FLUTTER_FFI_PLUGIN_LIST
  jni
)

set(PLUGIN_BUNDLED_LIBRARIES)

foreach(plugin ${FLUTTER_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${plugin}/windows plugins/${plugin})
  target_link_libraries(${BINARY_NAME} PRIVATE ${plugin}_plugin)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES $<TARGET_FILE:${plugin}_plugin>)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${plugin}_bundled_libraries})
endforeach(plugin)

foreach(ffi_plugin ${FLUTTER_FFI_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${ffi_plugin}/windows plugins/${ffi_plugin})
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${ffi_plugin}_bundled_libraries})
endforeach(ffi_plugin)



================================================
FILE: windows/runner/CMakeLists.txt
================================================
cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)



================================================
FILE: windows/runner/flutter_window.cpp
================================================
#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}



================================================
FILE: windows/runner/flutter_window.h
================================================
#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_



================================================
FILE: windows/runner/main.cpp
================================================
#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"icem_bus", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}



================================================
FILE: windows/runner/resource.h
================================================
//{{NO_DEPENDENCIES}}
// Microsoft Visual C++ generated include file.
// Used by Runner.rc
//
#define IDI_APP_ICON                    101

// Next default values for new objects
//
#ifdef APSTUDIO_INVOKED
#ifndef APSTUDIO_READONLY_SYMBOLS
#define _APS_NEXT_RESOURCE_VALUE        102
#define _APS_NEXT_COMMAND_VALUE         40001
#define _APS_NEXT_CONTROL_VALUE         1001
#define _APS_NEXT_SYMED_VALUE           101
#endif
#endif



================================================
FILE: windows/runner/runner.exe.manifest
================================================
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
  <application xmlns="urn:schemas-microsoft-com:asm.v3">
    <windowsSettings>
      <dpiAwareness xmlns="http://schemas.microsoft.com/SMI/2016/WindowsSettings">PerMonitorV2</dpiAwareness>
    </windowsSettings>
  </application>
  <compatibility xmlns="urn:schemas-microsoft-com:compatibility.v1">
    <application>
      <!-- Windows 10 and Windows 11 -->
      <supportedOS Id="{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}"/>
    </application>
  </compatibility>
</assembly>



================================================
FILE: windows/runner/Runner.rc
================================================
// Microsoft Visual C++ generated resource script.
//
#pragma code_page(65001)
#include "resource.h"

#define APSTUDIO_READONLY_SYMBOLS
/////////////////////////////////////////////////////////////////////////////
//
// Generated from the TEXTINCLUDE 2 resource.
//
#include "winres.h"

/////////////////////////////////////////////////////////////////////////////
#undef APSTUDIO_READONLY_SYMBOLS

/////////////////////////////////////////////////////////////////////////////
// English (United States) resources

#if !defined(AFX_RESOURCE_DLL) || defined(AFX_TARG_ENU)
LANGUAGE LANG_ENGLISH, SUBLANG_ENGLISH_US

#ifdef APSTUDIO_INVOKED
/////////////////////////////////////////////////////////////////////////////
//
// TEXTINCLUDE
//

1 TEXTINCLUDE
BEGIN
    "resource.h\0"
END

2 TEXTINCLUDE
BEGIN
    "#include ""winres.h""\r\n"
    "\0"
END

3 TEXTINCLUDE
BEGIN
    "\r\n"
    "\0"
END

#endif    // APSTUDIO_INVOKED


/////////////////////////////////////////////////////////////////////////////
//
// Icon
//

// Icon with lowest ID value placed first to ensure application icon
// remains consistent on all systems.
IDI_APP_ICON            ICON                    "resources\\app_icon.ico"


/////////////////////////////////////////////////////////////////////////////
//
// Version
//

#if defined(FLUTTER_VERSION_MAJOR) && defined(FLUTTER_VERSION_MINOR) && defined(FLUTTER_VERSION_PATCH) && defined(FLUTTER_VERSION_BUILD)
#define VERSION_AS_NUMBER FLUTTER_VERSION_MAJOR,FLUTTER_VERSION_MINOR,FLUTTER_VERSION_PATCH,FLUTTER_VERSION_BUILD
#else
#define VERSION_AS_NUMBER 1,0,0,0
#endif

#if defined(FLUTTER_VERSION)
#define VERSION_AS_STRING FLUTTER_VERSION
#else
#define VERSION_AS_STRING "1.0.0"
#endif

VS_VERSION_INFO VERSIONINFO
 FILEVERSION VERSION_AS_NUMBER
 PRODUCTVERSION VERSION_AS_NUMBER
 FILEFLAGSMASK VS_FFI_FILEFLAGSMASK
#ifdef _DEBUG
 FILEFLAGS VS_FF_DEBUG
#else
 FILEFLAGS 0x0L
#endif
 FILEOS VOS__WINDOWS32
 FILETYPE VFT_APP
 FILESUBTYPE 0x0L
BEGIN
    BLOCK "StringFileInfo"
    BEGIN
        BLOCK "040904e4"
        BEGIN
            VALUE "CompanyName", "com.icem.bus" "\0"
            VALUE "FileDescription", "icem_bus" "\0"
            VALUE "FileVersion", VERSION_AS_STRING "\0"
            VALUE "InternalName", "icem_bus" "\0"
            VALUE "LegalCopyright", "Copyright (C) 2026 com.icem.bus. All rights reserved." "\0"
            VALUE "OriginalFilename", "icem_bus.exe" "\0"
            VALUE "ProductName", "icem_bus" "\0"
            VALUE "ProductVersion", VERSION_AS_STRING "\0"
        END
    END
    BLOCK "VarFileInfo"
    BEGIN
        VALUE "Translation", 0x409, 1252
    END
END

#endif    // English (United States) resources
/////////////////////////////////////////////////////////////////////////////



#ifndef APSTUDIO_INVOKED
/////////////////////////////////////////////////////////////////////////////
//
// Generated from the TEXTINCLUDE 3 resource.
//


/////////////////////////////////////////////////////////////////////////////
#endif    // not APSTUDIO_INVOKED



================================================
FILE: windows/runner/utils.cpp
================================================
#include "utils.h"

#include <flutter_windows.h>
#include <io.h>
#include <stdio.h>
#include <windows.h>

#include <iostream>

void CreateAndAttachConsole() {
  if (::AllocConsole()) {
    FILE *unused;
    if (freopen_s(&unused, "CONOUT$", "w", stdout)) {
      _dup2(_fileno(stdout), 1);
    }
    if (freopen_s(&unused, "CONOUT$", "w", stderr)) {
      _dup2(_fileno(stdout), 2);
    }
    std::ios::sync_with_stdio();
    FlutterDesktopResyncOutputStreams();
  }
}

std::vector<std::string> GetCommandLineArguments() {
  // Convert the UTF-16 command line arguments to UTF-8 for the Engine to use.
  int argc;
  wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv == nullptr) {
    return std::vector<std::string>();
  }

  std::vector<std::string> command_line_arguments;

  // Skip the first argument as it's the binary name.
  for (int i = 1; i < argc; i++) {
    command_line_arguments.push_back(Utf8FromUtf16(argv[i]));
  }

  ::LocalFree(argv);

  return command_line_arguments;
}

std::string Utf8FromUtf16(const wchar_t* utf16_string) {
  if (utf16_string == nullptr) {
    return std::string();
  }
  // First, find the length of the string with a safe upper bound (CWE-126).
  // UNICODE_STRING_MAX_CHARS (32767) is the maximum length of a UNICODE_STRING.
  int input_length = static_cast<int>(wcsnlen(utf16_string, UNICODE_STRING_MAX_CHARS));
  // Now use that bounded length to determine the required buffer size.
  // When an explicit length is passed, WideCharToMultiByte does not include
  // the null terminator in its returned size.
  int target_length = ::WideCharToMultiByte(
      CP_UTF8, WC_ERR_INVALID_CHARS, utf16_string,
      input_length, nullptr, 0, nullptr, nullptr);
  std::string utf8_string;
  if (target_length == 0 || static_cast<size_t>(target_length) > utf8_string.max_size()) {
    return utf8_string;
  }
  utf8_string.resize(target_length);
  int converted_length = ::WideCharToMultiByte(
      CP_UTF8, WC_ERR_INVALID_CHARS, utf16_string,
      input_length, utf8_string.data(), target_length, nullptr, nullptr);
  if (converted_length == 0) {
    return std::string();
  }
  return utf8_string;
}



================================================
FILE: windows/runner/utils.h
================================================
#ifndef RUNNER_UTILS_H_
#define RUNNER_UTILS_H_

#include <string>
#include <vector>

// Creates a console for the process, and redirects stdout and stderr to
// it for both the runner and the Flutter library.
void CreateAndAttachConsole();

// Takes a null-terminated wchar_t* encoded in UTF-16 and returns a std::string
// encoded in UTF-8. Returns an empty std::string on failure.
std::string Utf8FromUtf16(const wchar_t* utf16_string);

// Gets the command line arguments passed in as a std::vector<std::string>,
// encoded in UTF-8. Returns an empty std::vector<std::string> on failure.
std::vector<std::string> GetCommandLineArguments();

#endif  // RUNNER_UTILS_H_



================================================
FILE: windows/runner/win32_window.cpp
================================================
#include "win32_window.h"

#include <dwmapi.h>
#include <flutter_windows.h>

#include "resource.h"

namespace {

/// Window attribute that enables dark mode window decorations.
///
/// Redefined in case the developer's machine has a Windows SDK older than
/// version 10.0.22000.0.
/// See: https://docs.microsoft.com/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

/// Registry key for app theme preference.
///
/// A value of 0 indicates apps should use dark mode. A non-zero or missing
/// value indicates apps should use light mode.
constexpr const wchar_t kGetPreferredBrightnessRegKey[] =
  L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
constexpr const wchar_t kGetPreferredBrightnessRegValue[] = L"AppsUseLightTheme";

// The number of Win32Window objects that currently exist.
static int g_active_window_count = 0;

using EnableNonClientDpiScaling = BOOL __stdcall(HWND hwnd);

// Scale helper to convert logical scaler values to physical using passed in
// scale factor
int Scale(int source, double scale_factor) {
  return static_cast<int>(source * scale_factor);
}

// Dynamically loads the |EnableNonClientDpiScaling| from the User32 module.
// This API is only needed for PerMonitor V1 awareness mode.
void EnableFullDpiSupportIfAvailable(HWND hwnd) {
  HMODULE user32_module = LoadLibraryA("User32.dll");
  if (!user32_module) {
    return;
  }
  auto enable_non_client_dpi_scaling =
      reinterpret_cast<EnableNonClientDpiScaling*>(
          GetProcAddress(user32_module, "EnableNonClientDpiScaling"));
  if (enable_non_client_dpi_scaling != nullptr) {
    enable_non_client_dpi_scaling(hwnd);
  }
  FreeLibrary(user32_module);
}

}  // namespace

// Manages the Win32Window's window class registration.
class WindowClassRegistrar {
 public:
  ~WindowClassRegistrar() = default;

  // Returns the singleton registrar instance.
  static WindowClassRegistrar* GetInstance() {
    if (!instance_) {
      instance_ = new WindowClassRegistrar();
    }
    return instance_;
  }

  // Returns the name of the window class, registering the class if it hasn't
  // previously been registered.
  const wchar_t* GetWindowClass();

  // Unregisters the window class. Should only be called if there are no
  // instances of the window.
  void UnregisterWindowClass();

 private:
  WindowClassRegistrar() = default;

  static WindowClassRegistrar* instance_;

  bool class_registered_ = false;
};

WindowClassRegistrar* WindowClassRegistrar::instance_ = nullptr;

const wchar_t* WindowClassRegistrar::GetWindowClass() {
  if (!class_registered_) {
    WNDCLASS window_class{};
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.lpszClassName = kWindowClassName;
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.cbClsExtra = 0;
    window_class.cbWndExtra = 0;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.hIcon =
        LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
    window_class.hbrBackground = 0;
    window_class.lpszMenuName = nullptr;
    window_class.lpfnWndProc = Win32Window::WndProc;
    RegisterClass(&window_class);
    class_registered_ = true;
  }
  return kWindowClassName;
}

void WindowClassRegistrar::UnregisterWindowClass() {
  UnregisterClass(kWindowClassName, nullptr);
  class_registered_ = false;
}

Win32Window::Win32Window() {
  ++g_active_window_count;
}

Win32Window::~Win32Window() {
  --g_active_window_count;
  Destroy();
}

bool Win32Window::Create(const std::wstring& title,
                         const Point& origin,
                         const Size& size) {
  Destroy();

  const wchar_t* window_class =
      WindowClassRegistrar::GetInstance()->GetWindowClass();

  const POINT target_point = {static_cast<LONG>(origin.x),
                              static_cast<LONG>(origin.y)};
  HMONITOR monitor = MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);
  UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  double scale_factor = dpi / 96.0;

  HWND window = CreateWindow(
      window_class, title.c_str(), WS_OVERLAPPEDWINDOW,
      Scale(origin.x, scale_factor), Scale(origin.y, scale_factor),
      Scale(size.width, scale_factor), Scale(size.height, scale_factor),
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  if (!window) {
    return false;
  }

  UpdateTheme(window);

  return OnCreate();
}

bool Win32Window::Show() {
  return ShowWindow(window_handle_, SW_SHOWNORMAL);
}

// static
LRESULT CALLBACK Win32Window::WndProc(HWND const window,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto window_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(window_struct->lpCreateParams));

    auto that = static_cast<Win32Window*>(window_struct->lpCreateParams);
    EnableFullDpiSupportIfAvailable(window);
    that->window_handle_ = window;
  } else if (Win32Window* that = GetThisFromHandle(window)) {
    return that->MessageHandler(window, message, wparam, lparam);
  }

  return DefWindowProc(window, message, wparam, lparam);
}

LRESULT
Win32Window::MessageHandler(HWND hwnd,
                            UINT const message,
                            WPARAM const wparam,
                            LPARAM const lparam) noexcept {
  switch (message) {
    case WM_DESTROY:
      window_handle_ = nullptr;
      Destroy();
      if (quit_on_close_) {
        PostQuitMessage(0);
      }
      return 0;

    case WM_DPICHANGED: {
      auto newRectSize = reinterpret_cast<RECT*>(lparam);
      LONG newWidth = newRectSize->right - newRectSize->left;
      LONG newHeight = newRectSize->bottom - newRectSize->top;

      SetWindowPos(hwnd, nullptr, newRectSize->left, newRectSize->top, newWidth,
                   newHeight, SWP_NOZORDER | SWP_NOACTIVATE);

      return 0;
    }
    case WM_SIZE: {
      RECT rect = GetClientArea();
      if (child_content_ != nullptr) {
        // Size and position the child window.
        MoveWindow(child_content_, rect.left, rect.top, rect.right - rect.left,
                   rect.bottom - rect.top, TRUE);
      }
      return 0;
    }

    case WM_ACTIVATE:
      if (child_content_ != nullptr) {
        SetFocus(child_content_);
      }
      return 0;

    case WM_DWMCOLORIZATIONCOLORCHANGED:
      UpdateTheme(hwnd);
      return 0;
  }

  return DefWindowProc(window_handle_, message, wparam, lparam);
}

void Win32Window::Destroy() {
  OnDestroy();

  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
  if (g_active_window_count == 0) {
    WindowClassRegistrar::GetInstance()->UnregisterWindowClass();
  }
}

Win32Window* Win32Window::GetThisFromHandle(HWND const window) noexcept {
  return reinterpret_cast<Win32Window*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  SetParent(content, window_handle_);
  RECT frame = GetClientArea();

  MoveWindow(content, frame.left, frame.top, frame.right - frame.left,
             frame.bottom - frame.top, true);

  SetFocus(child_content_);
}

RECT Win32Window::GetClientArea() {
  RECT frame;
  GetClientRect(window_handle_, &frame);
  return frame;
}

HWND Win32Window::GetHandle() {
  return window_handle_;
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

bool Win32Window::OnCreate() {
  // No-op; provided for subclasses.
  return true;
}

void Win32Window::OnDestroy() {
  // No-op; provided for subclasses.
}

void Win32Window::UpdateTheme(HWND const window) {
  DWORD light_mode;
  DWORD light_mode_size = sizeof(light_mode);
  LSTATUS result = RegGetValue(HKEY_CURRENT_USER, kGetPreferredBrightnessRegKey,
                               kGetPreferredBrightnessRegValue,
                               RRF_RT_REG_DWORD, nullptr, &light_mode,
                               &light_mode_size);

  if (result == ERROR_SUCCESS) {
    BOOL enable_dark_mode = light_mode == 0;
    DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE,
                          &enable_dark_mode, sizeof(enable_dark_mode));
  }
}



================================================
FILE: windows/runner/win32_window.h
================================================
#ifndef RUNNER_WIN32_WINDOW_H_
#define RUNNER_WIN32_WINDOW_H_

#include <windows.h>

#include <functional>
#include <memory>
#include <string>

// A class abstraction for a high DPI-aware Win32 Window. Intended to be
// inherited from by classes that wish to specialize with custom
// rendering and input handling
class Win32Window {
 public:
  struct Point {
    unsigned int x;
    unsigned int y;
    Point(unsigned int x, unsigned int y) : x(x), y(y) {}
  };

  struct Size {
    unsigned int width;
    unsigned int height;
    Size(unsigned int width, unsigned int height)
        : width(width), height(height) {}
  };

  Win32Window();
  virtual ~Win32Window();

  // Creates a win32 window with |title| that is positioned and sized using
  // |origin| and |size|. New windows are created on the default monitor. Window
  // sizes are specified to the OS in physical pixels, hence to ensure a
  // consistent size this function will scale the inputted width and height as
  // as appropriate for the default monitor. The window is invisible until
  // |Show| is called. Returns true if the window was created successfully.
  bool Create(const std::wstring& title, const Point& origin, const Size& size);

  // Show the current window. Returns true if the window was successfully shown.
  bool Show();

  // Release OS resources associated with window.
  void Destroy();

  // Inserts |content| into the window tree.
  void SetChildContent(HWND content);

  // Returns the backing Window handle to enable clients to set icon and other
  // window properties. Returns nullptr if the window has been destroyed.
  HWND GetHandle();

  // If true, closing this window will quit the application.
  void SetQuitOnClose(bool quit_on_close);

  // Return a RECT representing the bounds of the current client area.
  RECT GetClientArea();

 protected:
  // Processes and route salient window messages for mouse handling,
  // size change and DPI. Delegates handling of these to member overloads that
  // inheriting classes can handle.
  virtual LRESULT MessageHandler(HWND window,
                                 UINT const message,
                                 WPARAM const wparam,
                                 LPARAM const lparam) noexcept;

  // Called when CreateAndShow is called, allowing subclass window-related
  // setup. Subclasses should return false if setup fails.
  virtual bool OnCreate();

  // Called when Destroy is called.
  virtual void OnDestroy();

 private:
  friend class WindowClassRegistrar;

  // OS callback called by message pump. Handles the WM_NCCREATE message which
  // is passed when the non-client area is being created and enables automatic
  // non-client DPI scaling so that the non-client area automatically
  // responds to changes in DPI. All other messages are handled by
  // MessageHandler.
  static LRESULT CALLBACK WndProc(HWND const window,
                                  UINT const message,
                                  WPARAM const wparam,
                                  LPARAM const lparam) noexcept;

  // Retrieves a class instance pointer for |window|
  static Win32Window* GetThisFromHandle(HWND const window) noexcept;

  // Update the window frame's theme to match the system theme.
  static void UpdateTheme(HWND const window);

  bool quit_on_close_ = false;

  // window handle for top level window.
  HWND window_handle_ = nullptr;

  // window handle for hosted content.
  HWND child_content_ = nullptr;
};

#endif  // RUNNER_WIN32_WINDOW_H_

---

# Bug Fixes and Project Updates

This section documents the resolved issues, their root causes, and the concrete changes made across the codebase in response to the user's reported bug list.

---

## 1. Admin Section

### A) Overview / Dashboard

#### 1. Total Student Section "+12 this month"
- **Issue:** In the total students card, the UI displayed `+12 this month` even though only eight students existed in total.
- **Cause:** Hardcoded string parameter `subtitle: '+12 this month'` in `_buildStatCard()`.
- **Fix:** In `lib/features/admin/presentation/views/admin_overview_tab.dart`, removed the hardcoded string and passed `subtitle: null`.
- **Files Modified:**
  - `lib/features/admin/presentation/views/admin_overview_tab.dart`

#### 2. Mobility Overview Sections Clickable
- **Issue:** The mobility overview stat cards (Total Students, Active Passes, Active Routes, Fleet Active / Drivers) were non-interactive.
- **Cause:** Stat cards were static `_buildStatCard()` widgets without tap handlers.
- **Fix:** In `lib/features/admin/presentation/views/admin_overview_tab.dart`, wrapped each card in a `GestureDetector`:
  - **Total Students:** Switches `adminTabProvider` to index `2` (Students tab).
  - **Active Passes:** Switches `adminTabProvider` to index `1` (Bus Passes tab).
  - **Active Routes:** Switches `adminTabProvider` to index `3` (Routes tab).
  - **Fleet Active / Drivers:** Navigates via `context.push(AppRoutes.driverManagement)`.
- **Files Modified:**
  - `lib/features/admin/presentation/views/admin_overview_tab.dart`

#### 3. Back Key Closing Application on Quick Shortcuts / Navigation
- **Issue:** Tapping any tab or shortcut in the admin dashboard and pressing the Android physical back key exited the app completely instead of returning to the Overview tab.
- **Cause:** `AdminDashboardScreen` lacked back button interception via `PopScope`.
- **Fix:** In `lib/features/admin/presentation/views/admin_dashboard.dart`, wrapped the `Scaffold` in `PopScope(canPop: currentTab == 0, onPopInvokedWithResult: (didPop, result) { if (!didPop) ref.read(adminTabProvider.notifier).state = 0; })`. Pressing back from any sub-tab returns smoothly to Overview.
- **Files Modified:**
  - `lib/features/admin/presentation/views/admin_dashboard.dart`

#### 4. Pending Tab in Bottom Section Showing Nothing
- **Issue:** Clicking the "Pending" tab under Recent Applications displayed an empty list even when pending applications existed in Firestore.
- **Cause:** Filter check in `_buildRecentApplications` looked strictly for `'pending'`, while Firestore records stored status as `'Payment Pending'`, `'Pending Approval'`, or `'Pending Payment'`.
- **Fix:** Updated the filter in `lib/features/admin/presentation/views/admin_overview_tab.dart` to match case-insensitively across all pending statuses: `'Pending'`, `'Payment Pending'`, `'Pending Approval'`, and `'Pending Payment'`.
- **Files Modified:**
  - `lib/features/admin/presentation/views/admin_overview_tab.dart`

---

### B) Operations / Payments

#### 1. Missing Metrics & Data (Total, Today's, Monthly Revenue, Pending Verification, Paid Pass Holders)
- **Issue:** Financial metrics displayed ₹0.00 / 0 counts, and payment lists did not reliably display records.
- **Cause:**
  - Payment records existed across multiple Firestore collections (`payments`, `receipts`, and embedded inside `bus_pass_applications` and `bus_passes`), with varying key names (`fare`, `amount`, `passFee`, `totalAmount`, `paymentDate`, `paidAt`, `createdAt`).
  - Provider only read from a single collection (`payments`) with strict filtering.
  - Payment status checks were case-sensitive.
- **Fix:**
  - In `lib/features/admin/domain/admin_providers.dart`, updated `paymentsListStreamProvider` to merge documents from `payments`, `receipts`, `bus_pass_applications` (having amount/fare), and `bus_passes`, normalizing timestamps and identifiers.
  - In `lib/features/admin/presentation/views/admin_payments_tab.dart`:
    - Updated payment status validation to be case-insensitive (`'paid'`, `'success'`, `'successful'`, `'completed'`).
    - Handled fallback field accessors for amounts (`amount`, `fare`, `passFee`, `totalAmount`) and dates (`paymentDate`, `createdAt`, `timestamp`, `paidAt`).
    - Calculated accurate metrics: Total Revenue, Today's Revenue (matching current day), Monthly Revenue (matching current calendar month), Pending Verification count, and Paid Pass Holders count.
- **Files Modified:**
  - `lib/features/admin/domain/admin_providers.dart`
  - `lib/features/admin/presentation/views/admin_payments_tab.dart`

---

### C) Buses & Drivers Section

#### 1. Buses Tab Dark Mode
- **Issue:** Hardcoded light background colors (`0xFF0F172A`, `0xFF64748B`, `0xFFE2E8F0`, `0xFFF1F5F9`, `Colors.white`) rendered poorly in dark mode, causing unreadable text, bright white container blocks, and low contrast borders.
- **Fix:** In `lib/features/admin/presentation/views/admin_buses_tab.dart`, refactored all widgets (`_BusCard`, `_BusFormSheet`, status badges, filter chips, and empty states) to use dynamic theme attributes: `theme.colorScheme.onSurface`, `theme.colorScheme.onSurfaceVariant`, `theme.colorScheme.surface`, `theme.colorScheme.outlineVariant`, and `theme.dividerColor`.
- **Files Modified:**
  - `lib/features/admin/presentation/views/admin_buses_tab.dart`

#### 2. Drivers Section Dark Mode & "Add Driver" Button Position
- **Issue:** Hardcoded light colors in Driver Management broke dark mode, and the "Add Driver" action was placed in the top AppBar actions rather than at the bottom.
- **Fix:** In `lib/features/driver/presentation/views/driver_management_screen.dart`:
  - Removed "Add Driver" button from AppBar actions and added a bottom `FloatingActionButton.extended`.
  - Replaced hardcoded slate/white colors with dynamic `theme.colorScheme` and `theme.dividerColor` across Scaffold, AppBar, `_DriverCard`, `_DriverDetailsSheet`, and `_DriverFormSheet`.
- **Files Modified:**
  - `lib/features/driver/presentation/views/driver_management_screen.dart`

---

### D) Admin Notifications Section

#### 1. Admin Notifications Dark Mode
- **Issue:** Admin notifications tab used hardcoded white container backgrounds and dark slate text, making search inputs and compose sheets illegible in dark mode.
- **Fix:** In `lib/features/admin/presentation/views/admin_notifications_tab.dart`:
  - Search container, notification cards, student picker sheet, and notification compose sheet refactored to use `theme.colorScheme.surface`, `surfaceContainerHighest`, and `outlineVariant`.
  - Input decorations and labels updated to use theme-aware colors for full dark mode support.
- **Files Modified:**
  - `lib/features/admin/presentation/views/admin_notifications_tab.dart`

---

## 2. Student Section

### A) Notification Dot Disappearing After Viewing
- **Issue:** After viewing new notifications, the red indicator dot on the notification icon remained visible.
- **Cause:** The dot was statically rendered whenever notifications existed, without tracking view state.
- **Fix:** In `lib/features/student/presentation/views/student_dashboard.dart`:
  - Added `_hasUnreadNotifications` state tracking.
  - Cleared `_hasUnreadNotifications = false` whenever the student navigates to the Alerts/Notifications tab (index 3) via the AppBar icon, bottom navigation bar, or quick action tile.
  - Dynamically rendered the badge dot only when `_hasUnreadNotifications` is true.
- **Files Modified:**
  - `lib/features/student/presentation/views/student_dashboard.dart`

### B) Fee Payments Section Error
- **Issue:** Fee Payments screen failed with a missing Firestore index error: `The query requires an index. You can create it here: https://console.firebase.google.com/...`. Additionally, back navigation from payment history redirected to `context.go(AppRoutes.studentDashboard)`, resetting navigation hierarchy.
- **Cause:** Firestore stream ordered by `'paymentDate'` descending alongside equality filter on `'studentId'`/`'uid'`, requiring a composite index.
- **Fix:** In `lib/features/student/presentation/views/student_sub_screens.dart` (`PaymentHistoryScreen`):
  - Removed `.orderBy('paymentDate', descending: true)` from the Firestore stream.
  - Applied in-memory sorting over the returned docs based on `paymentDate` / `createdAt` / `timestamp`.
  - Replaced hardcoded navigation with `if (context.canPop()) context.pop() else context.go(AppRoutes.studentDashboard)`.
- **Files Modified:**
  - `lib/features/student/presentation/views/student_sub_screens.dart`

### C) Pass History Dark Mode
- **Issue:** In `student_pass_history_screen.dart`, text colors were hardcoded to `AppColors.slate900`, `AppColors.slate800`, `AppColors.slate500`, and `AppColors.slate600` on dark card surfaces, rendering text nearly invisible in dark mode.
- **Fix:** In `lib/features/student/presentation/views/student_pass_history_screen.dart`:
  - Replaced hardcoded background colors with `theme.scaffoldBackgroundColor` and `theme.colorScheme.surface`.
  - Replaced hardcoded text and icon colors with `theme.colorScheme.onSurface` and `theme.colorScheme.onSurfaceVariant`.
  - Set card borders to `theme.colorScheme.outlineVariant`.
- **Files Modified:**
  - `lib/features/student/presentation/views/student_pass_history_screen.dart`

### D) Back Button Closes App from Quick Actions
- **Issue:** After opening any quick action tab (Apply Pass, Payment, Alert, History) and pressing the physical back key on mobile, the entire app closed.
- **Cause:** `StudentDashboardScreen` did not handle back-press events via `PopScope`.
- **Fix:** In `lib/features/student/presentation/views/student_dashboard.dart`, wrapped `Scaffold` in `PopScope(canPop: _currentTabIndex == 0, onPopInvokedWithResult: (didPop, result) { if (!didPop) setState(() => _currentTabIndex = 0); })`.
- **Files Modified:**
  - `lib/features/student/presentation/views/student_dashboard.dart`

---

## 3. Common Fix: Text Visibility in Dark Mode
- **Issue:** Hardcoded dark text colors (`AppColors.slate900`, `AppColors.slate800`, `const Color(0xFF0F172A)`, `const Color(0xFF1E293B)`, `const Color(0xFF64748B)`) were used in various screens, leading to poor contrast against dark backgrounds.
- **Fix:**
  - Audited and updated screens across both admin and student modules (`admin_overview_tab.dart`, `admin_payments_tab.dart`, `admin_buses_tab.dart`, `driver_management_screen.dart`, `admin_notifications_tab.dart`, `student_dashboard.dart`, `student_pass_history_screen.dart`, `student_pass_detail_screen.dart`).
  - Switched text and border stylings to dynamically reference `Theme.of(context).colorScheme.onSurface`, `onSurfaceVariant`, `surface`, `outlineVariant`, and `dividerColor`.
  - Used `Builder` widgets where necessary to supply current `BuildContext` to helper methods without breaking signatures.
- **Files Modified:**
  - `lib/features/admin/presentation/views/admin_overview_tab.dart`
  - `lib/features/admin/presentation/views/admin_payments_tab.dart`
  - `lib/features/admin/presentation/views/admin_buses_tab.dart`
  - `lib/features/driver/presentation/views/driver_management_screen.dart`
  - `lib/features/admin/presentation/views/admin_notifications_tab.dart`
  - `lib/features/student/presentation/views/student_dashboard.dart`
  - `lib/features/student/presentation/views/student_pass_history_screen.dart`
  - `lib/features/student/presentation/views/student_pass_detail_screen.dart`

