# SRISHTI 2.7 — Volunteer Attendance App
## Product Requirements Document (PRD)

**Project:** SRISHTI 2.7 Volunteer Attendance & Event Check-in App  
**Platform:** Android  
**Technology:** Flutter + Dart  
**Primary users:** SRISHTI volunteers

## 1. Project Overview

The SRISHTI 2.7 Volunteer Attendance & Event Check-in App is an Android application for SRISHTI volunteers. Its purpose is to provide a fast and reliable way to identify registered participants using QR codes and record attendance/check-in for SRISHTI events.

The app communicates with a shared backend/database. The public participant registration website is being developed separately by Abhiram and is outside the scope of this Flutter app.

## 2. Project Scope

### We are building

- Flutter Android volunteer application
- Volunteer authentication
- QR code scanner
- Participant identification
- Overall check-in
- Event-specific attendance
- Participant search
- Attendance statistics
- Duplicate/invalid scan handling
- Volunteer profile/settings

### We are NOT building

- Public SRISHTI registration website
- Public event website
- Participant registration UI
- Ticket-selling/payment system

These parts are being developed separately by Abhiram.

## 3. Main User

### Volunteer

A volunteer should be able to:

1. Log in.
2. See their dashboard.
3. Scan a participant's QR code.
4. View participant information.
5. Check the participant in.
6. Record attendance for a specific event.
7. Search for a participant manually if QR scanning fails.
8. See basic attendance information.

## 4. QR System

Each participant should have a unique identifier, for example:

- `SRI27-0001`
- `SRI27-0002`
- `SRI27-0003`

The QR code should contain the participant ID rather than unnecessary personal information.

Flow:

`QR → Participant ID → Backend lookup → Participant information`

## 5. Participant Information

After scanning, the volunteer should see relevant information such as:

- Name
- Participant ID
- College
- Department
- Year
- Registered events

The app should not expose unnecessary personal information.

## 6. Check-in Flow

Normal flow:

`Volunteer Login → Home → Scan QR → Backend lookup → Participant found → Show details → Confirm check-in → Attendance recorded → Success`

## 7. Duplicate Check-in

If a participant has already checked in, the app must not create another attendance record.

Show:

- Participant name
- Previous check-in time
- Volunteer who checked them in, if permitted

Display a clear message such as:

`Already Checked In`

## 8. Invalid QR

If the QR does not belong to a registered SRISHTI participant, display a clear error such as:

`Invalid QR Code — This participant could not be found.`

The app must not crash and should allow the volunteer to return to scanning.

## 9. Manual Search

Volunteers should be able to search using:

- Participant ID
- Name
- Phone number

Example result:

`Rahul — SRI27-0001 — ABC College`

with an available Check In action.

## 10. Event Attendance

SRISHTI may contain multiple events. Attendance should be associated with the specific event.

Example:

- Coding — Attended
- Quiz — Attended
- Gaming — Not attended

The final event list and event IDs will be supplied/confirmed during backend integration.

## 11. Home Dashboard

The home screen should provide quick access to:

- Welcome/volunteer identity
- Today's check-ins
- Scan QR
- Search participant
- Events
- Recent check-ins

The scanner should be easily accessible because it is the primary operation.

## 12. Authentication and Roles

### Volunteer

Can:

- Scan QR codes
- Search participants
- Check in participants
- View permitted attendance information

### Admin

Administrative functionality should be handled through the separate admin dashboard.

Permissions must be enforced by the backend, not only by hiding UI elements.

## 13. Backend

The Flutter app must not contain unrestricted database credentials.

The backend should handle:

- Authentication
- Participants
- Events
- Registrations
- Attendance
- Volunteers
- Permissions

A likely backend choice is Supabase/PostgreSQL. This will be finalized during the architecture phase.

## 14. Core Database Entities

### Participants

- participant_id
- name
- email
- phone
- college
- department
- year

### Events

- event_id
- name
- category
- date
- time
- venue

### Registrations

- registration_id
- participant_id
- event_id

### Attendance

- attendance_id
- participant_id
- event_id
- volunteer_id
- check_in_time

### Volunteers

- volunteer_id
- name
- email
- role

The exact database schema will be finalized before backend integration.

## 15. Error Handling

The application must gracefully handle:

- Invalid QR
- Participant not found
- Duplicate check-in
- Network unavailable
- Server error
- Camera permission denied
- Authentication failure
- Session expiration

Messages should be understandable to volunteers rather than exposing technical errors.

## 16. UI Requirements

The design should be:

- Clean
- Fast
- Mobile-first
- Easy to operate during an event
- Large touch targets
- Minimal unnecessary animations
- Clear success/error states
- SRISHTI branded

Kerala/SRISHTI cultural elements may be incorporated where appropriate without reducing usability.

## 17. Security Requirements

The application should:

- Require volunteer authentication.
- Use secure communication with the backend.
- Avoid storing unnecessary participant information locally.
- Prevent unauthorized attendance modification.
- Prevent duplicate attendance records.
- Use backend authorization.
- Keep admin functionality separate from normal volunteer permissions.

## 18. Performance Requirements

QR scanning should be fast.

Target workflow:

`Scan → Lookup → Participant displayed → Check-in → Ready for next scan`

The volunteer should not need to navigate through many screens for a normal check-in.

## 19. Future Features

These are not required for the first production version, but the architecture should allow room for:

- Offline check-in queue
- Automatic synchronization
- Push notifications
- Volunteer activity logs
- Advanced attendance reports
- Event capacity tracking
- Multiple organizer roles
- Attendance export
- Real-time dashboard statistics

## 20. Definition of Success

The first production-ready version is successful when a volunteer can:

`Login → Scan participant QR → Identify participant → Select/confirm event → Record attendance → Prevent duplicate check-in → Continue scanning`

and organizers can view the resulting attendance through the separate admin system.

## 21. Development Principle

Build the smallest reliable version first.

Development stages:

`PRD → Architecture → UI structure → Authentication → QR scanner → Participant lookup → Check-in → Event attendance → Backend integration → Admin dashboard → Testing → Deployment`

## 22. Important Project Boundary

This Flutter application is only the **SRISHTI volunteer attendance/check-in app**.

The public registration website is a separate project being developed by Abhiram.

The two systems will eventually communicate through an agreed shared backend/data contract.

---

**Document status:** Initial PRD  
**Next document:** System Architecture & Technical Design
