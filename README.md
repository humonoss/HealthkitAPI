<div align="center">
  <img src="HealthkitAPI Watch App/Assets.xcassets/AppIcon.appiconset/humono.png" alt="Humono Logo" width="120" />
  <h1>HealthKit Sync for watchOS</h1>
  <p><strong>Real-time HealthKit data synchronization.</strong></p>
</div>

---

## Overview

This watchOS application seamlessly syncs health metrics from Apple HealthKit to a cloud database. It features a polished, Apple-native design with real-time dashboards, historical charts, and a robust offline queuing system.

**Key Features:**
*   **Real-time Vitals:** Live streaming of Heart Rate, HRV, Blood Oxygen, and Respiratory Rate.
*   **Activity Tracking:** Daily aggregations for Steps, Distance, Active Energy, and Flights Climbed.
*   **Interactive Charts:** Detailed graphs with historical data trends (last 4 hours).
*   **Reliable Sync:** Background delivery and offline support with automatic retries.
*   **Battery Efficient:** Optimized for minimal impact (~5-10% drain/hour).

## Screenshots

<div align="center">
  <!-- Replace these paths with your actual screenshot files -->
  <img src="docs/screenshots/dashboard.png" alt="Dashboard View" width="200" style="margin: 10px;" />
  <img src="docs/screenshots/charts.png" alt="Chart Detail" width="200" style="margin: 10px;" />
  <img src="docs/screenshots/sync.png" alt="Sync Status" width="200" style="margin: 10px;" />
</div>

> *Note: Please add your app screenshots to a `docs/screenshots/` folder.*

## Setup Guide

Follow these steps to get the app running on your Apple Watch.

### 1. Prerequisites
*   Mac running macOS Sonoma or later.
*   Xcode 15.0 or later.
*   A physical Apple Watch (HealthKit data is limited on simulators).
*   A Firebase project.

### 2. Firebase Configuration
1.  Go to the [Firebase Console](https://console.firebase.google.com).
2.  Create a new project.
3.  Navigate to **Build > Realtime Database** and create a database (start in **Test Mode** for development).
4.  Navigate to **Build > Authentication** and enable **Anonymous** sign-in.
5.  Go to **Project Settings**, download `GoogleService-Info.plist`, and place it in the `HealthkitAPI Watch App/` folder.

### 3. Installation
1.  Open `HealthkitAPI.xcodeproj` in Xcode.
2.  Wait for Swift Package Manager to resolve dependencies (Firebase SDK).
3.  Select your Development Team in **Signing & Capabilities**.
4.  Connect your iPhone and paired Apple Watch.
5.  Select the **HealthkitAPI Watch App** target and your Watch device.
6.  Click **Run** (Cmd+R).

### 4. Permissions
1.  On the Watch, tap **Request Access** on the Settings screen.
2.  Allow access to all requested health data types.
3.  Tap **Start Collecting** to begin data sync.

---

## SDK & Data Access

Retrieve your health data programmatically using our Python SDK or standard HTTP requests.

### Base URL
`https://YOUR_DATABASE_URL.firebaseio.com`

### 🐍 Python SDK

A dedicated Python client is available in `HealthkitAPI/SDK/Python`.

**Installation:**
```bash
cd HealthkitAPI/SDK/Python
pip install -r requirements.txt
```

**Usage:**
```python
from healthkit_api import HealthKitClient

# Initialize with your User ID (visible in the Watch App Sync tab)
client = HealthKitClient(user_id="YOUR_USER_ID")

# Get real-time heart rate
latest_hr = client.get_realtime_metric("heartRate", limit=1)
print(f"Heart Rate: {latest_hr[0]['value']} bpm")

# Get daily activity summary
summary = client.get_daily_summary()
print(f"Steps Today: {summary.get('steps', {}).get('total', 0)}")
```

### 🌐 HTTP / cURL

Fetch data directly from the terminal:

**Get Latest Heart Rate:**
```bash
curl "https://YOUR_DATABASE_URL.firebaseio.com/users/YOUR_USER_ID/healthData/realtime/heartRate.json?orderBy=\"key\"&limitToLast=1"
```

**Get Daily Summary:**
```bash
curl "https://YOUR_DATABASE_URL.firebaseio.com/users/YOUR_USER_ID/healthData/aggregated/daily/2026-02-04.json"
```

---

## Data Structure

Your data is organized in Firebase as follows:

*   **Real-time:** `users/{uid}/healthData/realtime/{metric_type}/{push_id}`
    *   Contains `value`, `unit`, and `timestamp`.
*   **Aggregated:** `users/{uid}/healthData/aggregated/daily/{YYYY-MM-DD}`
    *   Contains totals for `steps`, `distance`, `activeEnergy`, etc.

## Troubleshooting

*   **No Data?** Ensure you have authorized HealthKit permissions on the Watch.
*   **Sync Issues?** Check your internet connection and verify `GoogleService-Info.plist` is correct.
*   **Simulator?** Physical devices are required for accurate sensor data.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Built with SwiftUI & Firebase**