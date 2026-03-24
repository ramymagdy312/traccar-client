# User Guide - SerbTracker Client

This guide is for end users and explains how to use the app step by step.

---

## 1) Overview

`SerbTracker Client` is an operational app for drivers/representatives to:

- Sign in with account credentials.
- View daily `Service Orders`.
- Filter and search orders quickly.
- Start/End a service order with odometer validation.
- Send current location and monitor tracking status.
- Manage settings (language, appearance, tracking configuration).

---

## 2) First Launch

When opening the app for the first time:

1. The Login screen appears.
2. Enter:
   - Username
   - Password
3. Tap `Sign in`.
4. On success, the app opens the main screen directly (Service Orders).

> Note: The app keeps your session, so you usually do not need to sign in every time unless you log out.

---

## 3) Main Layout After Login

After login, you will see:

- A compact top header with:
  - Welcome text
  - Username
  - Logout button
- A bottom navigation bar with:
  - `Services`
  - `Tracking`
  - `Settings`

---

## 4) Service Orders Screen (Primary Daily Screen)

This is the main operational screen.

### 4.1 Title and Search

- The screen title is shown at the top.
- Search opens a modern bottom sheet.
- You can search by:
  - Order number
  - Customer name
  - Reference
  - Vehicle
  - Service type

### 4.2 Filters

Available status filters:

- `All`
- `Not started`
- `In progress`
- `Completed`

Each filter shows a **count badge** for matching orders.

### 4.3 Card Status and Visuals

Each service card shows status visually:

- Not started
- In progress
- Completed

And includes key information:

- Order number
- Time/date
- Customer and reference
- Vehicle
- Adults / Children
- Odometer

### 4.4 Start/End Button

- If status is `Not started`: `Start` button is shown.
- If status is `In progress`: `End` button is shown.
- If status is `Completed`: action button is hidden.

#### Button alignment behavior

- In Arabic UI: button is aligned to the left.
- In non-Arabic UI: button is aligned to the right.

---

## 5) Starting an Order

When you tap `Start`:

1. A confirmation dialog appears.
2. It shows:
   - Reference
   - Service type
   - Start meter
3. Tap `Start` to confirm.

After success:

- Status changes to `In progress`.
- A success message is shown.

---

## 6) Ending an Order

When you tap `End`:

1. End meter dialog appears.
2. Enter end odometer value.
3. The app validates:
   - Valid number
   - End meter >= start meter
   - Distance difference within allowed limit

After success:

- Status changes to `Completed`.
- A success message is shown.

---

## 7) Tracking Screen

From `Tracking` tab you can:

- Enable/disable tracking.
- Send current location manually.
- Open status/logs screen.

When enabling tracking, the app may request:

- Location permissions
- Battery optimization exemption (device dependent)

### 7.1 `flutter_background_geolocation` Features Used in This App

The app uses this package to provide stable, production-level background tracking. Active capabilities include:

- **Background tracking**: location updates continue even when the app is not foregrounded.
- **Service start/stop control**: tracking can be toggled directly from the app.
- **Manual location send**: on-demand current position submission when needed.
- **Motion-state awareness**: listens to moving/stationary transitions to improve tracking behavior.
- **Dynamic config updates**: tracking settings can be changed from Settings and applied immediately.
- **System-permission handling**: shows user guidance when location permission is denied/restricted.
- **Battery optimization flow**: prompts users to disable battery restrictions when required.
- **Offline Support**: if internet is unavailable 📵, tracking data is buffered and sent automatically once connection is back.
- **Stop on logout**: tracking service is explicitly stopped when user logs out.

---

## 8) Settings Screen

From `Settings` tab you can manage:

### 8.1 Language

- System default
- Arabic
- English

### 8.2 Appearance (Theme)

- System default
- Light
- Dark

### 8.3 Tracking Settings

- Device ID
- Server URL
- Accuracy
- Distance
- Intervals
- Advanced options (as needed)

### 8.4 QR Configuration

- Use QR button to apply configuration via QR code (if provided by admin).

---

## 9) Logout

Use the logout button next to your username:

- Session is cleared.
- Tracking is stopped.
- App returns to Login screen.

---

## 10) Common Issues and Quick Fixes

### Service orders are not shown

- Check internet connection.
- Verify account credentials.
- Tap `Retry`.

### Cannot start/end an order

- Ensure odometer input is valid.
- Check the on-screen validation/error message.

### Tracking does not work in background

- Grant location permission.
- Disable battery optimization for the app.

### Language or theme did not update

- Leave and re-enter the screen.
- Confirm your selection was saved in Settings.

---

## 11) Recommended Daily Workflow

1. Open app and ensure login is valid.
2. In `Services`, review filters and counts.
3. Start each order when actual movement begins.
4. End each order immediately after completion with correct odometer.
5. Use `Tracking` when manual location send is needed.
6. Log out at end of shift.

---

## 12) 5-Minute Demo Script

Use this script when introducing the app:

1. "This is the login screen; enter username and password."
2. "After login, you land on Service Orders."
3. "Here are filters and counts by status."
4. "Each card shows key operation details and status."
5. "Use Start for new orders and End for active ones."
6. "Tracking tab lets you toggle tracking and send location."
7. "Settings lets you change language, theme, and tracking options."
8. "Logout is next to the username at the top."

---

## 13) Notes for Admin/Support Teams

- User account mapping is critical for loading service orders.
- Representative ID (Rep ID) must exist and be valid.
- API errors are generally shown clearly in app messages.
- Keep users on the latest app version whenever possible.

