# SRISHTI 2.7 — System Architecture

**Document:** System Architecture & Technical Design  
**Project:** SRISHTI 2.7 Volunteer Attendance & Check-in System  
**Version:** 1.0  
**Status:** Proposed Architecture  
**Last Updated:** 2026-10-01

---

## 1. Purpose

This document defines the technical architecture for the SRISHTI 2.7 fest ecosystem.

The system consists of:

1. **SRISHTI Supabase Backend**: Central PostgreSQL database hosting the normalized festival schema, Supabase Auth, Row Level Security (RLS), and serverless Edge Functions.
2. **Volunteer Flutter Mobile App** (`flutter-app`): Used on-ground by coordinators for festival arrival check-in, event attendance scanning, and spot registrations.
3. **FEST Website & Admin Dashboard** (`https://github.com/Knightopp/TrialRun2.git` / `website`): Developed by Abhiram as the unified source of truth for both the public festival portal and the administrative command center (`/admin`).

---

# 2. System Scope

## 2.1 In Scope

### Volunteer Flutter App

The mobile application allows authorized volunteers to:

- Log in via username/password (backed by `coordinator-login` Edge Function).
- View role-based dashboards (`admin`, `registration`, `event_staff`).
- Scan participant QR badges (`SRI27-XXXX` format).
- Search participants manually.
- Perform festival arrival check-in.
- Record event attendance with duplicate prevention.
- Execute on-ground Spot Registration via atomic `spot-register` Edge Function.
- View recent check-in/attendance history.

### Admin Dashboard (Abhiram)

Hosted within the official web repository (`TrialRun2` at `/admin`):

- Authenticate via Supabase Auth (`signInWithPassword`) with active admin volunteer role validation.
- View live festival metrics (Total Participants, Events, Arrivals, Registrations, Revenue).
- Interactive attendance and check-in analytics graphs.
- Festival Event management (CRUD, team/solo classification, capacity, fees).
- Participant & Volunteer Staff management (browsing, badge preview, quick registration, role management).
- Audit logs and database explorer.

### Backend (Supabase PostgreSQL)

The backend provides:

- 7 core production tables: `participants`, `events`, `registrations`, `volunteers`, `arrival_checkins`, `event_attendance`, `event_staff`.
- RLS policies ensuring secure anonymous read-only access for public events, while protecting PII, check-in, and volunteer data.
- Serverless Edge Functions: `coordinator-login`, `spot-register`, `participant-profile`, `web-register`.
- PostgreSQL sequences and stored procedures (`participant_code_seq`, `fn_generate_participant_code`, `fn_create_spot_registration`).

---

# 3. Source of Truth & Component Boundaries

The official repository `https://github.com/Knightopp/TrialRun2.git` serves as the **source of truth for both the public FEST website and its admin dashboard**.

All clients (Mobile App, FEST Website, Admin Dashboard) communicate directly with the central **SRISHTI Supabase** backend, sharing identical data structures, sequences, and security contracts.

---

# 4. High-Level Architecture

```text
                    ┌──────────────────────┐
                    │   SRISHTI Supabase   │
                    │      PostgreSQL       │
                    │   Auth + RLS + APIs   │
                    └──────────┬───────────┘
                               │
                 ┌─────────────┼─────────────┐
                 │             │             │
                 ▼             ▼             ▼
          Flutter Volunteer   FEST Website   Admin Dashboard
               App             (Abhiram)       (Abhiram)
```

The Supabase PostgreSQL database is the single central source of truth. All three clients operate against the same unified database instance and adhere to the normalized schema.

---

# 5. Proposed Technology Stack

## 5.1 Volunteer Mobile Application

| Component | Technology |
|---|---|
| Framework | Flutter |
| Language | Dart |
| Platform | Android |
| QR Scanner | Flutter-compatible QR/barcode scanning package |
| Backend SDK | Supabase Flutter SDK |
| Authentication | Supabase Auth |
| Database | PostgreSQL through Supabase |
| State Management | To be selected during implementation |
| Navigation | To be selected during implementation |

The primary target is Android because volunteers will use Android phones during the fest.

---

## 5.2 Admin Dashboard

| Component | Technology |
|---|---|
| Framework | React |
| Build Tool | Vite |
| Language | TypeScript |
| Backend SDK | Supabase JavaScript client |
| Authentication | Supabase Auth |
| Database | PostgreSQL through Supabase |
| Hosting | Vercel or equivalent |

The dashboard will be browser-based.

---

## 5.3 Backend

| Component | Technology |
|---|---|
| Backend Platform | Supabase |
| Database | PostgreSQL |
| Authentication | Supabase Auth |
| Authorization | PostgreSQL Row Level Security |
| Server-side Logic | Supabase Edge Functions where required |
| Storage | Supabase Storage only if required later |

Supabase is the proposed backend for the project.

---

# 6. Core System Components

## 6.1 Public Registration Website

The public website is developed separately.

Its responsibilities include:

1. Displaying SRISHTI information.
2. Displaying events.
3. Allowing participants to register.
4. Creating/updating participant registration records.
5. Generating or displaying the participant QR code.
6. Providing the participant with their registration information.

It should write registration information into the shared backend using an approved integration method.

---

## 6.2 Flutter Volunteer Application

The Flutter application is used during the physical fest.

Main screens:

```text
Login
  │
  ▼
Home Dashboard
  │
  ├── Scan QR
  │     └── Participant Details
  │             └── Check-in / Event Attendance
  │
  ├── Search Participant
  │     └── Participant Details
  │
  ├── Events
  │
  ├── My Activity
  │
  └── Profile / Logout
```

---

## 6.3 Admin Dashboard

Main dashboard structure:

```text
Admin Login
    │
    ▼
Dashboard
    │
    ├── Overview
    ├── Participants
    ├── Events
    ├── Attendance
    ├── Volunteers
    ├── Reports
    └── Settings
```

---

# 7. Database Architecture

The database will use PostgreSQL.

The following tables are proposed.

```text
participants
     │
     ├────────────── registrations ────────────── events
     │
     ├────────────── arrival_checkins
     │
     └────────────── event_attendance ─────────── events

volunteers
     │
     ├────────────── arrival_checkins
     │
     └────────────── event_attendance
```

---

# 8. Database Tables

## 8.1 participants

Stores the main participant record.

| Field | Type | Description |
|---|---|---|
| id | UUID | Internal database ID |
| participant_code | TEXT | Public participant ID, e.g. SRI27-0001 |
| name | TEXT | Participant name |
| email | TEXT | Participant email |
| phone | TEXT | Participant phone |
| college | TEXT | College/institution |
| department | TEXT | Department |
| year | TEXT | Academic year |
| created_at | TIMESTAMP | Record creation time |
| updated_at | TIMESTAMP | Last update |

### Constraints

`participant_code` must be unique.

The participant code is the identifier used by the QR system.

---

# 9. events

Stores SRISHTI events.

| Field | Type | Description |
|---|---|---|
| id | UUID | Internal event ID |
| event_code | TEXT | Stable event identifier |
| name | TEXT | Event name |
| category | TEXT | Event category |
| date | DATE | Event date |
| start_time | TIME | Start time |
| end_time | TIME | End time |
| venue | TEXT | Event venue |
| capacity | INTEGER | Optional capacity |
| status | TEXT | Scheduled/active/completed |
| created_at | TIMESTAMP | Creation time |

`event_code` must remain stable after integration with the public website.

---

# 10. registrations

Connects participants with events.

| Field | Type | Description |
|---|---|---|
| id | UUID | Registration ID |
| participant_id | UUID | Participant |
| event_id | UUID | Registered event |
| status | TEXT | Registered/cancelled/etc. |
| registered_at | TIMESTAMP | Registration time |

### Important Constraint

A participant should not have duplicate registrations for the same event.

Recommended unique constraint:

```text
UNIQUE(participant_id, event_id)
```

---

# 11. volunteers

Stores authorized volunteer information.

| Field | Type | Description |
|---|---|---|
| id | UUID | Volunteer ID |
| auth_user_id | UUID | Supabase Auth user ID |
| name | TEXT | Volunteer name |
| email | TEXT | Volunteer email |
| role | TEXT | volunteer/admin |
| status | TEXT | active/inactive |
| created_at | TIMESTAMP | Creation time |

The user's authentication identity and application role must be linked.

The role must **not** be trusted solely from Flutter client-side code.

---

# 12. arrival_checkins

Stores festival entry/check-in.

This represents:

> "This participant has arrived at SRISHTI."

| Field | Type | Description |
|---|---|---|
| id | UUID | Check-in ID |
| participant_id | UUID | Participant |
| checked_in_by | UUID | Volunteer |
| checked_in_at | TIMESTAMP | Check-in time |
| source | TEXT | qr/manual |
| device_info | TEXT | Optional |
| notes | TEXT | Optional |

### Important Constraint

A participant should normally have only one active festival arrival check-in.

Recommended:

```text
UNIQUE(participant_id)
```

This prevents multiple volunteers from creating duplicate arrival records.

---

# 13. event_attendance

Stores attendance for individual events.

This represents:

> "This participant attended this particular event."

| Field | Type | Description |
|---|---|---|
| id | UUID | Attendance ID |
| participant_id | UUID | Participant |
| event_id | UUID | Event |
| marked_by | UUID | Volunteer |
| marked_at | TIMESTAMP | Attendance time |
| source | TEXT | qr/manual |
| notes | TEXT | Optional |

### Important Constraint

A participant should have only one attendance record per event.

```text
UNIQUE(participant_id, event_id)
```

This is important for duplicate scan protection.

---

# 14. QR Code Architecture

The QR code should contain a minimal identifier rather than complete personal information.

Recommended MVP payload:

```text
SRI27-0001
```

Example:

```text
QR
 │
 ▼
SRI27-0001
 │
 ▼
Flutter App
 │
 ▼
Authenticated Backend Request
 │
 ▼
participants table
 │
 ▼
Participant Information
```

The QR code should **not** contain:

- Phone number
- Email
- Full participant profile
- Password
- Authentication token
- Sensitive personal information

---

# 15. QR Scan Flow

## 15.1 Successful Scan

```text
Volunteer opens scanner
        │
        ▼
Camera detects QR
        │
        ▼
Extract participant_code
        │
        ▼
Validate format
        │
        ▼
Request participant from backend
        │
        ▼
Participant found?
     /          \
   Yes           No
   │              │
   ▼              ▼
Show details   Invalid QR
   │
   ▼
Check registration/check-in status
   │
   ▼
Volunteer confirms action
   │
   ▼
Backend creates attendance/check-in
   │
   ▼
Success message
```

---

# 16. Duplicate Check-in Handling

Duplicate protection must exist at the database level.

The app should provide a friendly message such as:

```text
Already checked in

This participant was checked in at 10:42 AM.
```

The database must still reject duplicate records even if:

- Two volunteers scan at the same time.
- The user taps the button twice.
- The application sends the request twice.
- The network retries a request.

Client-side checks alone are not sufficient.

---

# 17. Invalid QR Handling

If the QR does not contain a valid participant identifier:

```text
Invalid QR Code
```

If the identifier is valid but no participant exists:

```text
Participant Not Found
```

The app must not crash.

The volunteer should be able to return to the scanner or use manual search.

---

# 18. Manual Participant Search

The volunteer app should support searching by approved fields.

Possible search fields:

- Participant code
- Name
- Phone

The initial search should be limited to authenticated users and should return only the minimum information required.

Example:

```text
Search: SRI27-0001

Result:
Name: Example Participant
College: Example College
Registered Events: 3
Check-in: Not checked in
```

---

# 19. Participant Detail Screen

The participant screen should show:

- Participant code
- Name
- College
- Department/year where appropriate
- Registered events
- Festival check-in status
- Event attendance status

Example:

```text
Participant

SRI27-0001
John Example

Example College
Computer Science

Festival Check-in
Not Checked In

Registered Events
✓ Web Design
✓ Hackathon
○ Robotics
```

The exact UI will be decided during implementation.

---

# 20. Authentication Architecture

Authentication will use Supabase Auth.

## Volunteer

Volunteer:

```text
Login
  ↓
Supabase Auth
  ↓
Authenticated session
  ↓
Role verification
  ↓
Volunteer dashboard
```

## Admin

Admin:

```text
Login
  ↓
Supabase Auth
  ↓
Authenticated session
  ↓
Admin role verification
  ↓
Admin dashboard
```

The frontend must not decide that a user is an admin simply because a local variable says so.

Authorization must be enforced by the backend/database.

---

# 21. Authorization Roles

Initial roles:

### Volunteer

Can:

- Read necessary participant information.
- Read event information.
- Read registration information.
- Create arrival check-ins.
- Create event attendance.
- View their own activity.

Should not:

- Delete participants.
- Change event configuration.
- Change other volunteers' roles.
- Access unrestricted administrative data.

### Admin

Can:

- View system-wide data.
- Manage events.
- View participants.
- View attendance.
- View volunteer activity.
- Manage volunteer access where implemented.
- Generate reports.

---

# 22. Row Level Security

PostgreSQL Row Level Security (RLS) should be enabled on all sensitive tables.

The general principle is:

```text
No authentication
       │
       ▼
   No protected data

Authenticated Volunteer
       │
       ▼
Only permitted operations

Authenticated Admin
       │
       ▼
Administrative operations
```

Policies must be tested independently of the UI.

---

# 23. Backend Security Rules

## Never put the following in the Flutter app or public frontend:

```text
SUPABASE_SERVICE_ROLE_KEY
```

The service-role key has elevated permissions and must remain server-side.

The mobile app and dashboard should use the public/publishable Supabase client configuration together with database security policies.

Sensitive privileged operations should use secure server-side functions when necessary.

---

# 24. Attendance Transaction Safety

Attendance operations should be designed to be atomic.

For example:

```text
Volunteer presses "Check In"
        │
        ▼
Backend verifies user
        │
        ▼
Backend verifies participant
        │
        ▼
Backend verifies event/registration if required
        │
        ▼
Backend attempts attendance insert
        │
        ├── Success → Attendance recorded
        │
        └── Duplicate → Already recorded
```

The database constraint is the final protection against duplicate records.

---

# 25. Overall Festival Check-in vs Event Attendance

These are separate concepts.

## Festival Arrival Check-in

Answers:

> Has the participant arrived at SRISHTI?

Stored in:

```text
arrival_checkins
```

## Event Attendance

Answers:

> Did the participant attend this specific event?

Stored in:

```text
event_attendance
```

This separation makes reporting clearer.

---

# 26. Data Flow — Registration

```text
Participant
    │
    ▼
Abhiram's Registration Website
    │
    ▼
Registration Backend/API
    │
    ▼
participants
    │
    ├── registrations
    │
    └── QR participant_code
```

The exact method used by Abhiram's website to write data must be agreed upon before integration.

---

# 27. Data Flow — Festival Check-in

```text
Participant QR
      │
      ▼
Flutter Scanner
      │
      ▼
participant_code
      │
      ▼
Supabase
      │
      ▼
Participant lookup
      │
      ▼
Volunteer confirms
      │
      ▼
arrival_checkins
      │
      ▼
Success
```

---

# 28. Data Flow — Event Attendance

```text
Participant QR
      │
      ▼
Flutter Scanner
      │
      ▼
Participant
      │
      ▼
Select Event / Current Event
      │
      ▼
Check registration/status
      │
      ▼
event_attendance
      │
      ▼
Success / Already Recorded
```

---

# 29. Data Flow — Admin Dashboard

```text
Admin
  │
  ▼
React Dashboard
  │
  ▼
Supabase Auth
  │
  ▼
Authorized Database Requests
  │
  ├── Participants
  ├── Events
  ├── Registrations
  ├── Check-ins
  ├── Attendance
  └── Volunteers
```

---

# 30. Dashboard Statistics

The admin dashboard may display:

- Total registered participants
- Total festival check-ins
- Total participants not checked in
- Total events
- Total event registrations
- Total event attendance
- Attendance by event
- Recent check-ins
- Recent attendance
- Volunteer activity

Statistics should be calculated from the backend data rather than stored as manually editable numbers.

---

# 31. Reporting

Reports may include:

### Participant Report

```text
Participant Code
Name
College
Registration Count
Festival Check-in
```

### Event Attendance Report

```text
Event
Participant
Participant Code
Attendance Time
Volunteer
```

### Volunteer Activity

```text
Volunteer
Total Check-ins
Total Event Attendance
Last Activity
```

Export formats can initially include CSV.

PDF export can be added later if required.

---

# 32. Integration Contract With Abhiram

Before connecting the systems, both developers must agree on the following.

## Participant Identifier

Example:

```text
SRI27-0001
```

Requirements:

- Unique
- Stable
- Never reused
- Same identifier in the QR
- Same identifier in the database

## Event Identifier

Example:

```text
HACK-001
WEB-001
ROB-001
```

The exact format is flexible, but it must be stable.

## Participant Fields

Minimum shared fields:

```text
participant_code
name
email
phone
college
department
year
```

## Registration Fields

Minimum:

```text
participant_code
event_code
registration_status
registered_at
```

## QR Contract

The QR should resolve to or contain the agreed participant identifier.

Both systems must use exactly the same identifier format.

---

# 33. Registration Updates

The architecture must support changes such as:

- Participant changes event registration.
- Participant cancels registration.
- Event is cancelled.
- Event details change.
- Participant information is corrected.

The database must remain the source of truth.

The Flutter app should retrieve current information rather than relying on old locally cached participant data.

---

# 34. Offline Strategy

## MVP

The first version should assume an internet connection.

If the connection is unavailable, the app should clearly show:

```text
No Internet Connection
Please reconnect and try again.
```

The app should not silently claim that attendance was recorded when the backend did not confirm it.

## Future Version

Offline attendance can later use:

```text
Local Pending Queue
       ↓
Connection Restored
       ↓
Sync
       ↓
Backend Validation
       ↓
Confirmed
```

Offline mode should not be implemented until its synchronization rules are designed carefully.

---

# 35. Flutter Application Structure

Proposed structure:

```text
flutter-app/
│
├── android/
├── ios/
├── lib/
│   ├── main.dart
│   │
│   ├── core/
│   │   ├── constants/
│   │   ├── theme/
│   │   ├── router/
│   │   └── utils/
│   │
│   ├── models/
│   │   ├── participant.dart
│   │   ├── event.dart
│   │   ├── registration.dart
│   │   ├── attendance.dart
│   │   └── volunteer.dart
│   │
│   ├── services/
│   │   ├── auth_service.dart
│   │   ├── participant_service.dart
│   │   ├── attendance_service.dart
│   │   └── event_service.dart
│   │
│   ├── features/
│   │   ├── auth/
│   │   ├── home/
│   │   ├── scanner/
│   │   ├── participants/
│   │   ├── attendance/
│   │   ├── events/
│   │   └── profile/
│   │
│   └── widgets/
│
├── test/
└── pubspec.yaml
```

The exact structure can be adjusted during implementation.

---

# 36. Admin Dashboard Structure

Proposed structure:

```text
admin-dashboard/
│
├── src/
│   ├── components/
│   ├── layouts/
│   ├── pages/
│   │   ├── Login/
│   │   ├── Dashboard/
│   │   ├── Participants/
│   │   ├── Events/
│   │   ├── Attendance/
│   │   ├── Volunteers/
│   │   └── Reports/
│   │
│   ├── services/
│   │   ├── supabase.ts
│   │   ├── participantService.ts
│   │   ├── eventService.ts
│   │   └── attendanceService.ts
│   │
│   ├── types/
│   ├── hooks/
│   └── utils/
│
├── public/
├── package.json
└── vite.config.ts
```

---

# 37. Environment Configuration

Environment variables should be used.

Example Flutter configuration:

```text
SUPABASE_URL
SUPABASE_ANON_KEY
```

Example admin dashboard configuration:

```text
VITE_SUPABASE_URL
VITE_SUPABASE_ANON_KEY
```

The exact configuration mechanism will be selected during implementation.

Never commit private service-role credentials to Git.

---

# 38. Git Repository Structure

Recommended project structure:

```text
SRISHTI2.7/
│
├── docs/
│   ├── PRD.md
│   └── SYSTEM_ARCHITECTURE.md
│
├── flutter-app/
│
├── admin-dashboard/
│
└── website/
```

`website/` is maintained by Abhiram.

The volunteer application and admin dashboard should have clear ownership boundaries.

---

# 39. Development Workflow

Development should happen in this order.

## Phase 1 — Documentation

- PRD
- System Architecture
- Database Design
- Integration Contract

## Phase 2 — Backend

- Create Supabase project
- Create PostgreSQL tables
- Add constraints
- Add authentication
- Add RLS policies
- Add test data

## Phase 3 — Flutter Foundation

- Remove default demo UI
- Create app theme
- Create navigation
- Create login
- Connect Supabase
- Create dashboard

## Phase 4 — QR and Attendance

- Camera permission
- QR scanner
- Participant lookup
- Participant details
- Festival check-in
- Event attendance
- Duplicate protection
- Invalid QR handling
- Manual search

## Phase 5 — Admin Dashboard

- React/Vite setup
- Authentication
- Dashboard
- Participants
- Events
- Attendance
- Volunteers
- Reports

## Phase 6 — Integration

- Connect Abhiram's registration system
- Test participant creation
- Test event registration
- Test QR generation
- Test synchronization

## Phase 7 — Testing

- Unit tests
- Widget tests
- Integration tests
- Security tests
- Duplicate scan tests
- Network failure tests
- Multiple-volunteer tests

## Phase 8 — Deployment

- Production Supabase
- Admin dashboard deployment
- Android release build
- Volunteer installation
- Final production testing

---

# 40. Testing Requirements

## QR Tests

Test:

- Valid QR
- Invalid QR
- Empty QR
- Unknown participant
- Repeated QR
- Damaged/unreadable QR

## Attendance Tests

Test:

- First check-in
- Duplicate check-in
- Two volunteers scanning simultaneously
- Event attendance
- Non-registered participant
- Cancelled registration

## Authentication Tests

Test:

- Valid login
- Invalid login
- Logout
- Volunteer access
- Admin access
- Unauthorized database access

## Network Tests

Test:

- Normal connection
- Slow connection
- No connection
- Connection restored during operation
- Request timeout

---

# 41. Security Requirements

The system must:

1. Require authentication for volunteer/admin operations.
2. Use database-level authorization.
3. Enable RLS.
4. Never expose the service-role key to clients.
5. Store only required participant information.
6. Avoid personal information inside QR codes.
7. Prevent duplicate attendance using database constraints.
8. Validate all backend operations.
9. Restrict admin functionality to authorized users.
10. Avoid trusting client-provided roles.
11. Use HTTPS for deployed services.
12. Keep secrets out of source control.

---

# 42. Performance Requirements

The volunteer app should prioritize speed because it will be used during a live event.

Target experience:

```text
Scan QR
   ↓
Participant lookup
   ↓
Details appear quickly
   ↓
Check-in
   ↓
Confirmation
```

The interface should avoid unnecessary animations or network requests during scanning.

Participant search should be optimized for common fields.

The scanner should be able to return to scanning quickly after a successful operation.

---

# 43. Error Handling

All network/backend errors should produce understandable messages.

Examples:

```text
Unable to connect to server.
Please check your internet connection.
```

```text
Participant not found.
Please verify the QR code.
```

```text
This participant has already checked in.
```

```text
You do not have permission to perform this action.
```

```text
Something went wrong.
Please try again.
```

Technical error details may be logged for developers but should not be unnecessarily shown to volunteers.

---

# 44. Logging and Auditability

Attendance records should preserve:

- Who performed the action.
- When it happened.
- What participant was affected.
- Which event was affected where applicable.
- Whether the source was QR or manual.

This allows administrators to investigate attendance records after the event.

---

# 45. Important Design Principle

The system should follow:

```text
UI
 ↓
Application Logic
 ↓
Backend
 ↓
Database
```

The Flutter app and admin dashboard must not directly manipulate data in ways that bypass authorization.

The database is the final source of truth.

---

# 46. Production Architecture

Final production system:

```text
                         INTERNET
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
          ▼                  ▼                  ▼
   Public Website      Flutter App       Admin Dashboard
    (Abhiram)           Volunteers            Admins
          │                  │                  │
          └──────────────────┼──────────────────┘
                             ▼
                       ┌────────────┐
                       │  Supabase  │
                       ├────────────┤
                       │ Auth       │
                       │ PostgreSQL │
                       │ RLS        │
                       │ Functions  │
                       └────────────┘
```

---

# 47. Decisions That Must Be Confirmed Before Coding

The following decisions should be finalized before implementation.

### 1. Backend

Proposed:

```text
Supabase
```

### 2. Participant ID

Proposed:

```text
SRI27-0001
```

### 3. Event ID

A stable event-code format must be agreed upon with Abhiram.

### 4. QR ownership

Decide whether the public website generates the QR or whether the backend provides the QR data.

### 5. Registration integration

Decide how Abhiram's website writes registration data.

Preferred approach:

```text
Shared Supabase backend
```

with appropriate security controls.

### 6. Volunteer authentication

Initial proposal:

```text
Email + Password
```

### 7. Festival arrival check-in

Confirm whether every participant requires one overall arrival check-in.

### 8. Event attendance

Confirm whether volunteers select an event before scanning or whether the app operates in an event-specific scanning mode.

### 9. Offline operation

MVP proposal:

```text
Online only
```

Offline synchronization can be added later.

### 10. Admin roles

Initial proposal:

```text
Admin
Volunteer
```

Additional roles can be added later.

---

# 48. MVP Definition

The first usable version should contain only the features required to run the event.

## Required

### Flutter

- Login
- Dashboard
- QR scanning
- Participant lookup
- Participant details
- Festival check-in
- Event attendance
- Duplicate protection
- Invalid QR handling
- Manual search
- Logout

### Admin

- Login
- Dashboard statistics
- Participant list/search
- Event list
- Attendance records
- Check-in records
- Volunteer activity

### Backend

- Authentication
- Participants
- Events
- Registrations
- Volunteers
- Arrival check-ins
- Event attendance
- RLS/security
- Duplicate constraints

---

# 49. Future Features

These can be considered after the MVP:

- Offline attendance queue
- Automatic synchronization
- Push notifications
- Advanced analytics
- Live event capacity tracking
- Participant self-service portal
- Digital certificates
- Automated email/SMS
- Advanced role permissions
- Audit log dashboard
- QR regeneration
- Device management
- Multiple fest editions

These should not delay the MVP.

---

# 50. Definition of Done

The SRISHTI attendance system is considered ready when:

- A volunteer can authenticate.
- A volunteer can scan a valid participant QR.
- The participant is retrieved from the backend.
- Participant information is displayed correctly.
- Festival check-in can be recorded.
- Event attendance can be recorded.
- Duplicate attendance is prevented.
- Invalid QR codes are handled safely.
- Manual participant search works.
- Admins can view attendance.
- Admins can view participants.
- Admins can view events.
- Volunteer activity is recorded.
- Abhiram's registration system successfully creates usable participant records.
- QR identifiers match the shared participant IDs.
- RLS prevents unauthorized operations.
- No private service credentials are present in client applications.
- The system survives realistic event-day testing.

---

# 51. Final Architecture Summary

SRISHTI 2.7 will use a shared backend architecture:

```text
                    ┌───────────────────────┐
                    │ Abhiram's Website     │
                    │ Registration          │
                    └───────────┬───────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │       SUPABASE        │
                    │                       │
                    │ Authentication       │
                    │ PostgreSQL            │
                    │ RLS                   │
                    │ Server Functions      │
                    └───────────┬───────────┘
                                │
                    ┌───────────┴───────────┐
                    │                       │
                    ▼                       ▼
          ┌──────────────────┐   ┌──────────────────┐
          │ Flutter          │   │ React Admin      │
          │ Volunteer App    │   │ Dashboard        │
          │                  │   │                  │
          │ QR Scanner       │   │ Analytics        │
          │ Check-in         │   │ Participants     │
          │ Attendance       │   │ Attendance       │
          │ Search           │   │ Reports          │
          └──────────────────┘   └──────────────────┘
```

The key architectural principle is:

> **One shared backend, one source of truth, multiple clients.**

The Flutter app handles volunteer operations.  
The admin dashboard handles administration and reporting.  
Abhiram's website handles public registration.  
Supabase connects and coordinates the system.

---

# 52. Next Document

After this architecture is approved, the next technical document should be:

```text
DATABASE_DESIGN.md
```

That document will define the exact PostgreSQL tables, columns, relationships, primary keys, foreign keys, unique constraints, indexes, and RLS policy requirements.

Only after the database design is finalized should implementation begin.
