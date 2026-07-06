# SmartCity LPWAN — Flutter App Setup Guide

## 🚀 Quick Start (Mock Data Mode — No Firebase Needed)

The app runs immediately in mock data mode. Just open in Android Studio and run!

```
lib/providers/dashboard_provider.dart
→ bool useMockData = true;  ← already set, app works out of the box
```

---

## 📁 Project Structure

```
lib/
├── main.dart                          # App entry point
├── app.dart                           # MaterialApp root
├── core/
│   ├── theme/
│   │   ├── app_colors.dart            # All color constants
│   │   └── app_theme.dart             # Material 3 dark theme
│   ├── constants/
│   │   └── firebase_paths.dart        # Firebase path constants
│   └── widgets/
│       ├── glass_card.dart            # Glassmorphism card
│       ├── status_chip.dart           # Animated status indicator
│       ├── sensor_gauge.dart          # Circular & linear gauges
│       ├── battery_indicator.dart     # Battery level widget
│       ├── alert_banner.dart          # Colored alert banners
│       └── section_title.dart        # Section headers
├── models/
│   ├── node_status.dart               # Base node model (RSSI, SNR, battery)
│   ├── building_model.dart            # Building+Irrigation data model
│   ├── bridge_model.dart              # Bridge/Road data model
│   ├── water_model.dart               # Water Network data model
│   ├── gateway_model.dart             # Gateway + NodeHealth models
│   └── alert_model.dart              # Alert model + mock data
├── services/
│   └── firebase_service.dart         # Firebase Realtime Database streams
├── providers/
│   └── dashboard_provider.dart       # State management (Provider)
└── screens/
    ├── splash_screen.dart             # Animated LoRa wave splash
    ├── login_screen.dart              # Login + Demo mode
    ├── home_dashboard_screen.dart     # Main 4-domain dashboard
    ├── building_screen.dart           # Building & Irrigation details
    ├── bridge_screen.dart             # Bridge / Road details
    ├── water_screen.dart              # Water Network details
    ├── gateway_screen.dart            # Gateway Health + topology
    ├── alerts_screen.dart             # All system alerts
    └── settings_screen.dart          # App settings + mock toggle
```

---

## 📦 Dependencies (pubspec.yaml)

```yaml
dependencies:
  firebase_core: ^2.27.0
  firebase_database: ^10.4.9
  firebase_auth: ^4.19.2
  provider: ^6.1.2
  google_fonts: ^6.2.1
  fl_chart: ^0.67.0
  percent_indicator: ^4.2.3
  intl: ^0.19.0
  shared_preferences: ^2.2.3
```

---

## 🔥 Firebase Setup (When Ready)

### Step 1: Create Firebase Project
1. Go to https://console.firebase.google.com
2. Create a new project: "SmartCity-LPWAN"
3. Enable Realtime Database
4. Enable Authentication (Email/Password)

### Step 2: Add Android App
1. Register app with package name: `com.smartcity.lpwan`
2. Download `google-services.json`
3. Place in: `android/app/google-services.json`

### Step 3: Add to build.gradle files
```groovy
// android/build.gradle — in dependencies:
classpath 'com.google.gms:google-services:4.4.1'

// android/app/build.gradle — at bottom:
apply plugin: 'com.google.gms.google-services'
```

### Step 4: Enable Firebase in main.dart
```dart
// Uncomment these lines in main.dart:
import 'package:firebase_core/firebase_core.dart';

await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

### Step 5: Set useMockData = false
```dart
// lib/providers/dashboard_provider.dart
bool useMockData = false;
```

### Step 6: Import Sample Data
Import `firebase_sample_data.json` into your Firebase Realtime Database
via the Import JSON option in the Firebase console.

---

## 🔧 Firebase Security Rules (for development)

```json
{
  "rules": {
    ".read": "auth != null",
    ".write": "auth != null"
  }
}
```

---

## 📡 ESP32 Gateway Data Format

The ESP32 gateway should write to Firebase at this path:
`smart_city/nodes/{building|bridge|water}/`

Example Firebase write from ESP32 (Arduino):
```cpp
// After receiving LoRa packet and parsing:
FirebaseJson json;
json.set("online", true);
json.set("alert", false);
json.set("rssi", rssi);
json.set("snr", snr);
json.set("seq", seqNum);
json.set("lastUpdate", timestamp);
json.set("values/temperature", temperature);
json.set("values/humidity", humidity);
// ... etc
Firebase.RTDB.setJSON(&fbdo, "/smart_city/nodes/building", &json);
```

---

## 🎨 Design System

| Token | Value |
|---|---|
| Background | #07111F |
| Card Glass | #0D1B2E |
| Neon Blue | #00D1FF |
| Success Green | #2DFF88 |
| Warning Orange | #FFB020 |
| Danger Red | #FF3B5F |
| Gateway Purple | #BF7FFF |
| Font | Inter (Google Fonts) |
| Border Radius | 12–20px |

---

## ✅ Features Implemented

- [x] Animated Splash Screen with LoRa wave rings
- [x] Firebase Auth login + Demo mode
- [x] Home Dashboard with 4 animated domain cards
- [x] City-wide status (SAFE / WARNING / CRITICAL)
- [x] Building & Irrigation screen with all sensors + gauges
- [x] Bridge / Road screen with car counter, gates, danger switches
- [x] Water Network screen with animated tank visualization
- [x] Gateway Health screen with network topology diagram
- [x] Alerts screen with tab filter (All / Active / Resolved)
- [x] Settings screen with Mock Data toggle
- [x] Glassmorphism cards throughout
- [x] Animated status chips (pulsing LED effect)
- [x] Battery indicators on all nodes
- [x] Mock data streams (refreshes every 5 seconds)
- [x] Provider-based state management
- [x] Firebase Realtime Database streams ready
- [x] Dark futuristic Material 3 theme
- [x] Neon blue / green / orange / red accent system
- [x] Responsive layout with SafeArea

---

## 🎓 Graduation Project Notes

This app demonstrates:
- **IoT System Design**: LPWAN (LoRa) sensor network with gateway
- **Real-time Data**: Firebase Realtime Database streaming
- **Mobile Development**: Flutter with Provider state management
- **UI/UX Engineering**: Professional dark dashboard design
- **Clean Architecture**: Separated models, services, screens, providers
- **Smart City Domains**: Environmental, Traffic, Water, Network health
