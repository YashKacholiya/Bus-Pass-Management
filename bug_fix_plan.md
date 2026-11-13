# Bug Fix Plan - Bus Pass Management App (Status: ALL RESOLVED)

## Bug List, Fix Strategy & Implementation Status

### Admin Section

#### A1. Remove "+12 this month" from Total Students card — [RESOLVED]
- **File**: `lib/features/admin/presentation/views/admin_overview_tab.dart`
- **Fix**: Removed `'+12 this month'` and passed `subtitle: null`.

#### A2. Make Mobility Overview stat cards clickable — [RESOLVED]
- **File**: `lib/features/admin/presentation/views/admin_overview_tab.dart`
- **Fix**: Wrapped stat cards in `GestureDetector` mapped to `adminTabProvider` and driver route.

#### A3. Back button closes app from Quick Shortcuts / tab navigation — [RESOLVED]
- **File**: `lib/features/admin/presentation/views/admin_dashboard.dart`
- **Fix**: Wrapped the Scaffold in `PopScope(canPop: currentTab == 0, onPopInvokedWithResult: ...)` to smoothly return to tab 0 (Overview) on back press.

#### A4. Pending tab in bottom overview section shows nothing — [RESOLVED]
- **File**: `lib/features/admin/presentation/views/admin_overview_tab.dart`
- **Fix**: Updated filter logic to match case-insensitively across `'Pending'`, `'Payment Pending'`, `'Pending Approval'`, and `'Pending Payment'`.

#### B1. Payments section — no data shown for revenue/counts — [RESOLVED]
- **Files**: `lib/features/admin/domain/admin_providers.dart` & `lib/features/admin/presentation/views/admin_payments_tab.dart`
- **Fix**: In `admin_providers.dart`, merged payment records across `payments`, `receipts`, `bus_pass_applications`, and `bus_passes`. In `admin_payments_tab.dart`, added case-insensitive status handling, multiple amount/timestamp key fallbacks, and accurate financial metric calculations.

#### C1. Dark mode broken in Buses tab — [RESOLVED]
- **File**: `lib/features/admin/presentation/views/admin_buses_tab.dart`
- **Fix**: Replaced hardcoded light colors (`0xFF0F172A`, `0xFF64748B`, `0xFFE2E8F0`, `0xFFF1F5F9`, `Colors.white`) with dynamic theme colors (`onSurface`, `onSurfaceVariant`, `surface`, `outlineVariant`, `dividerColor`).

#### C2. Driver management - dark mode broken + Add Driver button should be at bottom — [RESOLVED]
- **File**: `lib/features/driver/presentation/views/driver_management_screen.dart`
- **Fix**: Converted all hardcoded colors to theme-aware colors and moved "Add Driver" button from AppBar actions to a bottom `FloatingActionButton.extended`.

#### C3. Dark mode broken in Notifications tab (Admin) — [RESOLVED]
- **File**: `lib/features/admin/presentation/views/admin_notifications_tab.dart`
- **Fix**: Refactored cards, search input container, student picker, and compose sheets to use dynamic theme surfaces and text colors.

---

### Student Section

#### D1. Notification dot should disappear after viewing notifications — [RESOLVED]
- **File**: `lib/features/student/presentation/views/student_dashboard.dart`
- **Fix**: Added `_hasUnreadNotifications` state tracking; cleared to `false` when navigating to tab 3 (Alerts/Notifications), dynamically rendering the badge dot only when unread.

#### D2. Fee payments section throwing error — [RESOLVED]
- **File**: `lib/features/student/presentation/views/student_sub_screens.dart`
- **Fix**: Removed `.orderBy('paymentDate', descending: true)` from Firestore stream to prevent composite index requirement crashes; implemented in-memory sorting; used safe back-pop navigation (`if (context.canPop()) context.pop() else context.go(...)`).

#### D3. Dark mode broken in Pass History — [RESOLVED]
- **File**: `lib/features/student/presentation/views/student_pass_history_screen.dart`
- **Fix**: Replaced hardcoded slate and white colors with `Theme.of(context).scaffoldBackgroundColor`, `colorScheme.surface`, `colorScheme.onSurface`, `colorScheme.onSurfaceVariant`, and `outlineVariant`.

#### D4. Back button closes app from Quick Actions — [RESOLVED]
- **File**: `lib/features/student/presentation/views/student_dashboard.dart`
- **Fix**: Wrapped Scaffold in `PopScope(canPop: _currentTabIndex == 0, onPopInvokedWithResult: ...)` to return to tab 0 (Home) on back press instead of exiting app.

---

### Common Bug: Dark Mode Text Visibility — [RESOLVED]
- Audited and updated screens across both admin and student modules (`admin_overview_tab.dart`, `admin_payments_tab.dart`, `admin_buses_tab.dart`, `driver_management_screen.dart`, `admin_notifications_tab.dart`, `student_dashboard.dart`, `student_pass_history_screen.dart`, and `student_pass_detail_screen.dart`).
- Switched text and border stylings to dynamically reference `Theme.of(context).colorScheme.onSurface`, `onSurfaceVariant`, `surface`, `outlineVariant`, and `dividerColor`.

---

## Modified Files
1. `lib/features/admin/presentation/views/admin_overview_tab.dart`
2. `lib/features/admin/presentation/views/admin_dashboard.dart`
3. `lib/features/admin/domain/admin_providers.dart`
4. `lib/features/admin/presentation/views/admin_payments_tab.dart`
5. `lib/features/admin/presentation/views/admin_buses_tab.dart`
6. `lib/features/driver/presentation/views/driver_management_screen.dart`
7. `lib/features/admin/presentation/views/admin_notifications_tab.dart`
8. `lib/features/student/presentation/views/student_dashboard.dart`
9. `lib/features/student/presentation/views/student_sub_screens.dart`
10. `lib/features/student/presentation/views/student_pass_history_screen.dart`
11. `lib/features/student/presentation/views/student_pass_detail_screen.dart`
12. `bus_pass_manage.md`
