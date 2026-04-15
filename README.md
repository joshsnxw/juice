# Juice

A lightweight macOS menu bar app that monitors your battery level and shows a large centered overlay when it drops below a threshold you choose.

## Requirements

- macOS 13 Ventura or later
- Xcode Command Line Tools (`xcode-select --install`)

## Build & Run

```bash
swiftc -parse-as-library \
  -framework Cocoa \
  -framework IOKit \
  -framework SwiftUI \
  Juice.swift -o Juice

./Juice
```

The app appears in your menu bar as a drop icon. It has no Dock icon.

## Usage

- **Menu bar icon** — glanceable battery state:
  - `drop.fill` — normal
  - `drop.halffull` — getting close to your threshold
  - `drop.triangle.fill` — at or below threshold

- **Click the icon** to open the menu:
  - Current battery percentage and power source
  - **Alert at** slider — drag to set your threshold (5–50%, default 20%)
  - The threshold is saved across relaunches

- **Alert overlay** — when the battery hits your threshold while on battery power, a large overlay appears in the center of your screen. It auto-dismisses after 10 seconds or tap Dismiss.

## Notes

- No special permissions required. IOKit battery access is available to all user-space apps.
- The overlay is a standard `NSPanel` (not a system notification), so no notification permission prompt.
- Polling intervals adapt to battery level: every 60 min above 30%, 30 min from 10–30%, 5 min below 10%. This keeps CPU/battery impact negligible.
- To launch at login, drag `Juice` to **System Settings → General → Login Items**.
