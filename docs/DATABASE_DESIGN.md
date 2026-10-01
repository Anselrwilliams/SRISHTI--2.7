# SRISHTI 2.7 — Database Design

**Document:** Database Design & Data Model  
**Project:** SRISHTI 2.7 Volunteer Attendance & Check-in System  
**Version:** 1.0  
**Status:** Proposed / Implementation Ready  
**Last Updated:** 2026-10-01

---

## 1. Purpose

This document defines the PostgreSQL database design for SRISHTI 2.7.

The database is the shared source of truth for:

- Abhiram's public registration website
- Flutter volunteer application
- Admin dashboard
- Participant registrations
- Festival check-ins
- Event attendance
- Volunteer activity

The proposed database platform is **Supabase PostgreSQL**.

---

# 2. Design Principles

The database must follow these principles:

1. One shared database for the complete system.
2. Every participant has one permanent unique participant code.
3. Every event has a stable event code.
4. Registration and attendance are separate concepts.
5. Festival arrival check-in and event attendance are separate records.
6. Duplicate attendance must be prevented at database level.
7. Authentication and authorization are separate from application UI.
8. Sensitive data must be protected using Row Level Security.
9. Client applications must never contain privileged database credentials.
10. Database relationships must use foreign keys.
11. Important searchable fields must be indexed.
12. The database must remain the source of truth.

---

# 3. Entity Relationship Overview

```text
                         ┌──────────────────┐
                         │   participants   │
                         ├──────────────────┤
                         │ id (PK)          │
                         │ participant_code │
                         │ name             │
                         │ email            │
                         │ phone            │
                         │ college          │
                         │ department       │
                         │ year             │
                         └────────┬─────────┘
                                  │
             ┌────────────────────┼────────────────────┐
             │                    │                    │
             ▼                    ▼                    ▼
     ┌───────────────┐   ┌─────────────────┐   ┌──────────────────┐
     │ registrations │   │arrival_checkins │   │event_attendance  │
     └───────┬───────┘   └────────┬────────┘   └─────────┬────────┘
             │                    │                      │
             │                    │                      │
             ▼                    ▼                      ▼
       ┌───────────┐        ┌────────────┐         ┌───────────┐
       │  events   │        │ volunteers │         │  events   │
       └───────────┘        └────────────┘         └───────────┘
                                  ▲                      ▲
                                  │                      │
                                  └──────────────────────┘
```

---

# 4. Tables

The initial production database contains these core tables:

```text
participants
events
registrations
volunteers
arrival_checkins
event_attendance
```

Supabase's internal authentication tables are managed by Supabase Auth and are not recreated manually.

---

# 5. participants

Stores the master record for every SRISHTI participant.

## Columns

| Column | Type | Required | Default | Description |
|---|---|---:|---|---|
| id | UUID | Yes | gen_random_uuid() | Internal primary key |
| participant_code | TEXT | Yes | — | Public unique participant ID |
| name | TEXT | Yes | — | Participant full name |
| email | TEXT | No | — | Email address |
| phone | TEXT | No | — | Phone number |
| college | TEXT | No | — | College/institution |
| department | TEXT | No | — | Department |
| year | TEXT | No | — | Academic year |
| created_at | TIMESTAMPTZ | Yes | now() | Creation time |
| updated_at | TIMESTAMPTZ | Yes | now() | Last update |

## Primary Key

```text
id
```

## Unique Constraint

```text
participant_code
```

The participant code must never be duplicated.

Example:

```text
SRI27-0001
SRI27-0002
SRI27-0003
```

---

# 6. Participant Code Rules

The participant code is the identifier used by the QR system.

Example:

```text
SRI27-0001
```

Rules:

- Must be unique.
- Must never be reused.
- Must not contain sensitive information.
- Should remain unchanged after registration.
- Should be short enough for QR usage.
- Must be shared between Abhiram's website and the attendance system.

The QR should contain this identifier or an approved equivalent.

---

# 7. events

Stores all SRISHTI events.

## Columns

| Column | Type | Required | Default | Description |
|---|---|---:|---|---|
| id | UUID | Yes | gen_random_uuid() | Primary key |
| event_code | TEXT | Yes | — | Stable event identifier |
| name | TEXT | Yes | — | Event name |
| category | TEXT | No | — | Event category |
| date | DATE | Yes | — | Event date |
| start_time | TIME | No | — | Event start |
| end_time | TIME | No | — | Event end |
| venue | TEXT | No | — | Event venue |
| capacity | INTEGER | No | — | Optional capacity |
| status | TEXT | Yes | 'scheduled' | Event status |
| created_at | TIMESTAMPTZ | Yes | now() | Creation time |
| updated_at | TIMESTAMPTZ | Yes | now() | Last update |

## Primary Key

```text
id
```

## Unique Constraint

```text
event_code
```

Example:

```text
HACK-001
WEB-001
ROB-001
```

---

# 8. Event Status

Allowed logical values:

```text
scheduled
active
completed
cancelled
```

The application should not rely only on the frontend to enforce valid statuses.

A database check constraint should be used where appropriate.

---

# 9. registrations

Connects participants to events.

This represents:

> "This participant registered for this event."

## Columns

| Column | Type | Required | Default | Description |
|---|---|---:|---|---|
| id | UUID | Yes | gen_random_uuid() | Primary key |
| participant_id | UUID | Yes | — | Participant FK |
| event_id | UUID | Yes | — | Event FK |
| status | TEXT | Yes | 'registered' | Registration status |
| registered_at | TIMESTAMPTZ | Yes | now() | Registration time |
| updated_at | TIMESTAMPTZ | Yes | now() | Last update |

## Foreign Keys

```text
participant_id → participants.id
event_id → events.id
```

## Unique Constraint

```text
UNIQUE(participant_id, event_id)
```

A participant cannot have two active registration rows for the same event.

---

# 10. Registration Status

Initial allowed values:

```text
registered
cancelled
waitlisted
```

The final list can be adjusted if the public registration system requires additional states.

---

# 11. volunteers

Stores authorized application users and their application roles.

Supabase Auth handles credentials.

This table stores application-specific information.

## Columns

| Column | Type | Required | Default | Description |
|---|---|---:|---|---|
| id | UUID | Yes | gen_random_uuid() | Primary key |
| auth_user_id | UUID | Yes | — | Supabase Auth user ID |
| name | TEXT | Yes | — | Volunteer/admin name |
| email | TEXT | Yes | — | Account email |
| role | TEXT | Yes | 'volunteer' | Application role |
| status | TEXT | Yes | 'active' | Account status |
| created_at | TIMESTAMPTZ | Yes | now() | Creation time |
| updated_at | TIMESTAMPTZ | Yes | now() | Last update |

## Foreign Key

Conceptually:

```text
auth_user_id → auth.users.id
```

This relationship should be implemented according to Supabase's recommended Auth/database pattern.

## Unique Constraint

```text
auth_user_id
```

---

# 12. Volunteer Roles

Initial roles:

```text
volunteer
admin
```

Future roles can include:

```text
super_admin
event_manager
```

Do not add extra roles until they are actually required.

---

# 13. Volunteer Status

Initial values:

```text
active
inactive
```

Inactive users must not be allowed to perform attendance operations.

---

# 14. arrival_checkins

Stores festival-wide participant arrival.

This represents:

> "The participant has arrived at SRISHTI."

## Columns

| Column | Type | Required | Default | Description |
|---|---|---:|---|---|
| id | UUID | Yes | gen_random_uuid() | Primary key |
| participant_id | UUID | Yes | — | Participant FK |
| checked_in_by | UUID | Yes | — | Volunteer FK |
| checked_in_at | TIMESTAMPTZ | Yes | now() | Check-in time |
| source | TEXT | Yes | 'qr' | qr/manual |
| notes | TEXT | No | — | Optional note |
| created_at | TIMESTAMPTZ | Yes | now() | Record creation |

## Foreign Keys

```text
participant_id → participants.id
checked_in_by → volunteers.id
```

## Unique Constraint

```text
UNIQUE(participant_id)
```

This prevents duplicate festival arrival check-ins.

---

# 15. event_attendance

Stores attendance for individual events.

This represents:

> "The participant attended this specific event."

## Columns

| Column | Type | Required | Default | Description |
|---|---|---:|---|---|
| id | UUID | Yes | gen_random_uuid() | Primary key |
| participant_id | UUID | Yes | — | Participant FK |
| event_id | UUID | Yes | — | Event FK |
| marked_by | UUID | Yes | — | Volunteer FK |
| marked_at | TIMESTAMPTZ | Yes | now() | Attendance time |
| source | TEXT | Yes | 'qr' | qr/manual |
| notes | TEXT | No | — | Optional note |
| created_at | TIMESTAMPTZ | Yes | now() | Record creation |

## Foreign Keys

```text
participant_id → participants.id
event_id → events.id
marked_by → volunteers.id
```

## Unique Constraint

```text
UNIQUE(participant_id, event_id)
```

This prevents the same participant from being counted twice for the same event.

---

# 16. Attendance Source

Initial values:

```text
qr
manual
```

This helps administrators understand how attendance was recorded.

Example:

```text
QR scan:
source = qr

Manual search:
source = manual
```

---

# 17. Complete Relationship Model

```text
participants
    │
    │ 1:N
    ▼
registrations
    │
    │ N:1
    ▼
events
```

```text
participants
    │
    │ 1:1
    ▼
arrival_checkins
    │
    │ N:1
    ▼
volunteers
```

```text
participants
    │
    │ 1:N
    ▼
event_attendance
    │
    ├────────── N:1 ──────────► events
    │
    └────────── N:1 ──────────► volunteers
```

---

# 18. Foreign Key Behavior

Recommended behavior:

### participants → registrations

Do not automatically delete participant registration history when a participant is removed.

For production, participant deletion should normally be restricted or handled through an administrative workflow.

### events → registrations

Deleting an event should normally be restricted if registration or attendance history exists.

Prefer marking the event:

```text
cancelled
```

instead of physically deleting it.

### participants → attendance

Attendance records should not disappear accidentally.

### volunteers → attendance

Volunteer identity must remain available for audit purposes.

---

# 19. Indexes

Indexes should be created for common queries.

Recommended indexes:

```text
participants(participant_code)
participants(phone)
participants(name)

events(event_code)
events(date)

registrations(participant_id)
registrations(event_id)

arrival_checkins(participant_id)
arrival_checkins(checked_in_by)
arrival_checkins(checked_in_at)

event_attendance(participant_id)
event_attendance(event_id)
event_attendance(marked_by)
event_attendance(marked_at)
```

Unique constraints will automatically provide indexes in PostgreSQL where applicable.

---

# 20. Search Strategy

The volunteer app will commonly search by:

1. Participant code
2. Name
3. Phone

Participant code should be the fastest and most reliable lookup.

Example:

```text
SRI27-0001
```

should directly identify one participant.

Name searches may return multiple results.

---

# 21. QR Lookup

QR scanning should follow:

```text
QR
 │
 ▼
participant_code
 │
 ▼
participants.participant_code
 │
 ▼
Participant
```

The QR should not directly expose database UUIDs unless there is a specific reason to do so.

---

# 22. Duplicate Protection

Duplicate protection exists at three levels.

## Level 1 — UI

The app should disable or prevent repeated submission while a request is processing.

## Level 2 — Backend

The backend should validate:

- User authentication
- User role
- Participant existence
- Event existence
- Registration status where required

## Level 3 — Database

Unique constraints provide final protection.

### Festival check-in

```text
UNIQUE(participant_id)
```

### Event attendance

```text
UNIQUE(participant_id, event_id)
```

The database is the final authority.

---

# 23. Concurrent Scan Protection

Example:

```text
Volunteer A scans SRI27-0001
Volunteer B scans SRI27-0001
        │
        ▼
Both requests reach database
        │
        ▼
One insert succeeds
        │
        ▼
Second insert violates unique constraint
        │
        ▼
App displays "Already checked in"
```

This protects against simultaneous scanning by multiple volunteers.

---

# 24. Data Validation

The application and backend should validate:

### participant_code

- Not empty
- Unique
- Valid format

### event_code

- Not empty
- Unique

### name

- Required for participant creation

### email

- Valid format when provided

### phone

- Valid expected format when provided

### event capacity

- Must not be negative

### status fields

- Must use approved values

---

# 25. Timestamps

Use PostgreSQL:

```text
TIMESTAMPTZ
```

rather than plain timestamps.

Recommended fields:

```text
created_at
updated_at
registered_at
checked_in_at
marked_at
```

The backend/database should generate timestamps whenever possible.

This prevents users from manipulating attendance time from the client.

---

# 26. Time Zone

The application is intended for SRISHTI operations in India.

Database timestamps should be stored using timezone-aware values.

Application display should use:

```text
Asia/Kolkata
```

for event-facing times.

The database should remain consistent even if the server infrastructure uses another timezone.

---

# 27. Security Model

The database must use Row Level Security (RLS).

General model:

```text
Anonymous
    │
    └── No protected participant/attendance access

Authenticated Volunteer
    │
    ├── Read permitted participant information
    ├── Read events
    ├── Read registrations needed for check-in
    ├── Create permitted check-ins
    └── Create permitted event attendance

Authenticated Admin
    │
    └── Administrative access according to policy
```

---

# 28. RLS Requirements

RLS must be enabled for:

```text
participants
events
registrations
volunteers
arrival_checkins
event_attendance
```

Policies should be based on the authenticated user's identity and application role.

Do not create a policy equivalent to:

```text
authenticated users can do everything
```

unless there is a documented reason.

---

# 29. Volunteer Read Permissions

A volunteer should be able to read only the participant information required for festival operations.

Possible fields:

```text
participant_code
name
college
department
year
registration status
event registrations
check-in status
attendance status
```

Sensitive fields should only be exposed when required.

---

# 30. Volunteer Write Permissions

A volunteer may create:

```text
arrival_checkins
event_attendance
```

subject to backend validation and RLS.

A volunteer should not directly edit:

```text
participant_code
event_code
volunteer role
registration ownership
```

---

# 31. Admin Permissions

Admins may be allowed to:

- Read all operational data.
- Create/update events.
- Manage volunteer records.
- View participant records.
- View attendance.
- View registrations.
- Generate reports.

Destructive actions should be restricted and preferably avoided in production.

---

# 32. Service Role Key

The Supabase service-role key must never appear in:

```text
Flutter source code
Flutter APK
React frontend
Browser JavaScript
Git repository
.env files committed to Git
```

The service-role key may only be used in trusted server-side environments where required.

---

# 33. Registration Website Integration

Abhiram's website must integrate with these database structures.

Participant creation:

```text
participants
```

Event registration:

```text
registrations
```

Event information:

```text
events
```

The website must not create a second participant database.

---

# 34. Integration Contract

The following values must match between systems.

### Participant

```text
participant_code
```

### Event

```text
event_code
```

### Registration

```text
participant_code
event_code
status
```

### QR

```text
participant_code
```

The same participant code must resolve to the same participant everywhere.

---

# 35. Example Participant

```json
{
  "participant_code": "SRI27-0001",
  "name": "Example Participant",
  "email": "participant@example.com",
  "phone": "9876543210",
  "college": "Example College",
  "department": "Computer Science",
  "year": "2"
}
```

---

# 36. Example Event

```json
{
  "event_code": "HACK-001",
  "name": "Hackathon",
  "category": "Technology",
  "date": "2026-11-10",
  "start_time": "09:00",
  "end_time": "17:00",
  "venue": "Main Block",
  "status": "scheduled"
}
```

---

# 37. Example Registration

```text
Participant:
SRI27-0001

Event:
HACK-001

Status:
registered
```

Database relationship:

```text
participants.id
      │
      ▼
registrations.participant_id

events.id
      │
      ▼
registrations.event_id
```

---

# 38. Example Festival Check-in

```text
Participant:
SRI27-0001

Volunteer:
VOL-001

Time:
2026-11-10 09:14:32+05:30

Source:
qr
```

---

# 39. Example Event Attendance

```text
Participant:
SRI27-0001

Event:
HACK-001

Volunteer:
VOL-001

Time:
2026-11-10 09:22:10+05:30

Source:
qr
```

---

# 40. Typical Database Queries

## Find participant by QR

```text
participants
WHERE participant_code = 'SRI27-0001'
```

## Find participant registrations

```text
registrations
WHERE participant_id = <participant_id>
```

## Check festival arrival

```text
arrival_checkins
WHERE participant_id = <participant_id>
```

## Check event attendance

```text
event_attendance
WHERE participant_id = <participant_id>
AND event_id = <event_id>
```

---

# 41. Attendance Rules

## Festival Check-in

A participant can have:

```text
0 or 1 arrival_checkins
```

## Event Attendance

A participant can have:

```text
0 or 1 attendance record per event
```

Example:

```text
Participant A
 ├── Hackathon ✓
 ├── Robotics ✓
 └── Web Design ✗
```

---

# 42. Registration vs Attendance

These must never be confused.

```text
Registration
=
Participant signed up for the event.

Attendance
=
Participant actually attended the event.
```

Example:

```text
Participant registered for Hackathon
        │
        ▼
registrations

Participant arrives at Hackathon
        │
        ▼
event_attendance
```

---

# 43. Festival Check-in vs Event Attendance

```text
arrival_checkins
=
Festival entry

event_attendance
=
Individual event attendance
```

A participant can be checked into the festival without yet attending an event.

---

# 44. Data Lifecycle

```text
Participant Registration
        │
        ▼
participants
        │
        ▼
Event Registration
        │
        ▼
registrations
        │
        ▼
Festival Arrival
        │
        ▼
arrival_checkins
        │
        ▼
Event Attendance
        │
        ▼
event_attendance
        │
        ▼
Admin Reports
```

---

# 45. Data Deletion Policy

The production system should avoid deleting operational history unnecessarily.

Prefer:

```text
status = cancelled
status = inactive
```

instead of deleting records.

For example:

```text
Event cancelled
```

should normally become:

```text
events.status = 'cancelled'
```

rather than deleting the event.

This preserves reporting history.

---

# 46. Backup and Recovery

Production database backups must be enabled according to the chosen Supabase plan and deployment configuration.

Before the fest:

- Verify backups.
- Test database restoration procedures.
- Export critical operational data if required.
- Keep an emergency copy of important reports.

Do not rely on a single local copy of attendance data.

---

# 47. Seed/Test Data

Development should use fake test participants.

Example:

```text
SRI27-TEST-001
SRI27-TEST-002
SRI27-TEST-003
```

Do not use real participant information during development unless necessary and authorized.

Test events should also be clearly marked.

---

# 48. Database Migration Strategy

Database changes should be versioned.

Do not manually make random production changes without recording them.

Recommended process:

```text
Design change
     ↓
Migration
     ↓
Development database
     ↓
Test
     ↓
Production
```

Every structural database change should be reproducible.

---

# 49. MVP Database

The minimum production schema is:

```text
participants
events
registrations
volunteers
arrival_checkins
event_attendance
```

No additional tables should be added merely for complexity.

---

# 50. Future Tables

Possible future tables:

```text
audit_logs
notifications
certificates
devices
attendance_sync_queue
event_staff
participant_documents
```

These are not required for the first MVP.

---

# 51. Database Implementation Order

When setting up Supabase, use this order:

```text
1. Create Supabase project
       ↓
2. Create participants
       ↓
3. Create events
       ↓
4. Create volunteers
       ↓
5. Create registrations
       ↓
6. Create arrival_checkins
       ↓
7. Create event_attendance
       ↓
8. Add constraints
       ↓
9. Add indexes
       ↓
10. Enable RLS
       ↓
11. Create policies
       ↓
12. Add test data
       ↓
13. Test from Flutter
       ↓
14. Test from admin dashboard
```

---

# 52. Acceptance Criteria

The database design is considered ready when:

- Every participant has a unique participant code.
- Every event has a unique event code.
- Participants can register for multiple events.
- Duplicate event registrations are prevented.
- A participant can have one festival arrival check-in.
- A participant can have one attendance record per event.
- Volunteer identity is recorded for attendance actions.
- Attendance timestamps are generated reliably.
- Foreign key relationships are enforced.
- Common queries are indexed.
- RLS is enabled.
- Volunteer and admin permissions are separated.
- Service-role credentials are never exposed to clients.
- Abhiram's website can use the agreed participant/event contract.
- Flutter can retrieve participants using QR identifiers.
- Admin dashboard can query attendance records.

---

# 53. Final Schema Summary

```text
┌─────────────────────────┐
│      participants       │
├─────────────────────────┤
│ id PK                   │
│ participant_code UNIQUE │
│ name                    │
│ email                   │
│ phone                   │
│ college                 │
│ department              │
│ year                    │
└────────────┬────────────┘
             │
      ┌──────┼───────────────┐
      │      │               │
      ▼      ▼               ▼
┌─────────┐ ┌──────────────┐ ┌──────────────────┐
│registr. │ │arrival_check │ │event_attendance  │
├─────────┤ ├──────────────┤ ├──────────────────┤
│id PK    │ │id PK         │ │id PK             │
│part FK  │ │part FK       │ │part FK           │
│event FK │ │volunteer FK  │ │event FK          │
│status   │ │checked_at    │ │volunteer FK      │
└────┬────┘ └──────────────┘ │marked_at         │
     │                        └────────┬─────────┘
     │                                 │
     ▼                                 ▼
┌───────────────┐                ┌───────────────┐
│    events     │                │    events     │
├───────────────┤                └───────────────┘
│id PK          │
│event_code UQ  │
│name           │
│category       │
│date           │
│start_time     │
│end_time       │
│venue          │
│capacity       │
│status         │
└───────────────┘

┌────────────────┐
│   volunteers   │
├────────────────┤
│ id PK          │
│ auth_user_id   │
│ name           │
│ email          │
│ role           │
│ status         │
└────────────────┘
```

---

# 54. Next Step

After this document is saved as:

```text
SRISHTI2.7/docs/DATABASE_DESIGN.md
```

the next step is **not coding the Flutter app yet**.

The next step is to create the actual **Supabase project and database** based on this design.

After the Supabase database is working, we can connect the existing Flutter project to it and replace the default Flutter demo screen with the SRISHTI application foundation.
