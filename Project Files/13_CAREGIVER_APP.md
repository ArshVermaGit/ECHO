# 13 — Caregiver App
## ECHO AAC | Companion Portal for Caregivers

---

## Overview

The caregiver app is the same Flutter codebase with a different login role. When a caregiver logs in, they see a completely different set of screens from the patient.

## Caregiver Dashboard

```dart
// CaregiverDashboardScreen shows:
// - Patient status card (is ECHO active? face detected? last active time?)
// - Recent messages panel (last 5 messages patient sent, with timestamps)
// - Communication stats (messages today, avg response time)
// - Quick actions: schedule event, add phrase board, view analytics

// The caregiver cannot control the patient's device — only view and configure
```

## Analytics Screen (fl_chart)

```dart
// LineChart: messages per day over 30 days
// Shows declining engagement early warning
// Gaze accuracy trend over 2 weeks
// Most-used phrases (bar chart)
// Hours of peak activity (heat map)
```

## Schedule Integration

```dart
// Caregiver adds: "Doctor appointment tomorrow 2pm"
// ECHO reads schedule from Supabase
// 15 minutes before → surface Medical phrase board automatically
// Send caregiver notification when emergency triggered
```

## 🤖 AI IDE Prompt — Caregiver App

```
Build the caregiver companion portal for ECHO.

1. Role-based routing: caregivers see CaregiverDashboardScreen, 
   patients see MainCommunicationScreen

2. CaregiverDashboardScreen:
   - Patient status card (last active, tracking active, battery)
   - Recent messages (last 5 from Supabase communication_history)
   - Stats: messages today, words today

3. AnalyticsScreen with fl_chart:
   - 30-day line chart of daily message count
   - 2-week gaze accuracy trend line

4. ScheduleScreen: add/edit/delete appointments, 
   stored in Supabase, ECHO reads them for context

5. Realtime: caregiver app receives push notification when 
   emergency triggered by patient
```
