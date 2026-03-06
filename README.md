# Skincare Routine Tracker

A SwiftUI iOS app for tracking your skincare products, routines, and schedules.

## Requirements

- Xcode 15+
- iOS 17+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (optional, for project generation)

## Setup

### Option 1: Using XcodeGen (recommended)

```bash
brew install xcodegen
xcodegen generate
open SkincareTracker.xcodeproj
```

### Option 2: Manual Xcode project

1. Create a new iOS App project in Xcode
2. Add all Swift files from the `SkincareTracker/` folder
3. Set deployment target to iOS 17
4. Add the Info.plist entries for notifications and calendar usage

## Features

- **Products** – Add skincare products with names and ingredients
- **Routines** – Configure morning and night routines with application order
- **Today** – See today’s products and “put off” items (with optional frequency update)
- **Schedule** – View your routine for the next 14 days
- **Reminders** – Set morning/night reminder times

## Project Structure

```
SkincareTracker/
├── SkincareTrackerApp.swift    # App entry point
├── Models/                     # Product, Routine, ScheduleItem, ReminderConfig
├── AppState/                   # AppStore (central state)
├── Views/
│   ├── ContentView.swift       # Tab navigation
│   ├── Products/               # Product list, add, edit, detail
│   ├── Routines/               # Routine list, edit (order)
│   ├── Today/                  # Today’s products, put-off flow
│   ├── Schedule/               # Future schedule visualization
│   └── Reminders/              # Morning/night reminder config
└── Assets.xcassets/
```
