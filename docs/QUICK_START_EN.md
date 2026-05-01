# SerbTracker Client - Quick Start (One Page)

## 1) Sign In
- Open the app and enter **Username** and **Password**.
- Tap **Sign in**.

## 2) Main Navigation
- Bottom tabs:
  - **Services** (daily operations)
  - **Tracking**
  - **Settings**
- Top header shows your name and **Logout** button.

## 3) Services (Daily Workflow)
- Use filters: **All / Not started / In progress / Completed**.
- Use search to find orders by number, customer, reference, vehicle, or type.
- Open card and check details (time, customer, vehicle, Adults/Children, odometer).

## 4) Start Order
- Tap **Start**.
- Confirm start meter.
- Status becomes **In progress**.

## 5) End Order
- Tap **End**.
- Enter end meter.
- Rules:
  - End meter must be >= start meter.
  - Distance must be within allowed limit.
- Status becomes **Completed**.

## 6) Tracking
- Enable/disable tracking from **Tracking** tab.
- Use **Send location** when needed.
- Use **Show status** for diagnostics/logs.

### `flutter_background_geolocation` (used features)
- Background location tracking (even when app is not foregrounded).
- Start/stop tracking service directly from the app.
- Manual current-position send.
- Motion-state aware behavior (moving/stationary).
- Dynamic tracking config updates from Settings.
- Offline Support: if internet is unavailable 📵, data is buffered and sent when connection returns.
- Permission/battery-optimization handling prompts.
- Tracking service stops automatically on logout.

## 7) Settings
- Change:
  - **Language** (System / Arabic / English)
  - **Appearance** (System / Light / Dark)
  - Tracking settings (ID, URL, accuracy, intervals, etc.)

## 8) Logout
- Tap logout icon next to username.
- Session is cleared and tracking stops.

## Quick Troubleshooting
- **No services:** check internet, account, then tap **Retry**.
- **Cannot start/end:** verify odometer input and validation message.
- **Tracking issue:** grant location permission and disable battery optimization.
