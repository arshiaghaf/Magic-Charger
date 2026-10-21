# Magic Charger

A native macOS menu-bar utility for Magic Keyboard and Magic Mouse charging notifications. Built with Swift, AppKit, IOKit and UserNotifications, with no third-party dependencies.

**Early source preview.** Builds for macOS 14 or later; currently validated raw-flags profiles are limited to the model/OS combinations below. No downloadable release, Developer ID signature or notarization is provided.

## Build and Run

Requires macOS and an installed compatible Xcode/Swift 6.0-or-later toolchain.

```sh
git clone https://github.com/arshiaghaf/Magic-Charger.git
cd Magic-Charger
sh build-app.sh
open "build/Magic Charger.app"
```

The script uses an explicitly supplied `DEVELOPER_DIR`, otherwise `/Applications/Xcode.app` when installed, otherwise the active developer selection. It does not change global tooling. The bundle is locally ad-hoc signed. Use `CONFIGURATION=release sh build-app.sh` for an optimized local build; the default is debug. Run `swift test` with the same compatible developer directory for deterministic checks.

## Magic Charger

Each verified charging accessory gets its own menu-bar item. When none qualifies, the items disappear and lightweight monitoring continues. Reopen the app from Finder or Spotlight for controls and Quit. Closing the controls window keeps monitoring; no permanent Dock icon or login item is installed.

Choose **Enable Notifications** and answer the native macOS prompt to receive alerts. Monitoring remains available if you decline. **Notification Settings** opens System Settings; choose Notifications > Magic Charger to change permission or presentation. **Send Test** submits one clearly labeled test without changing battery or session state. Focus and screen-sharing/mirroring policy may suppress banners even when Notification Center receives an alert.

## Features

- Separate device glyph, exact battery percentage and vertical level bar for each charging device; no averages.
- Three saved menu-display choices, with at least one element visible. The monochrome native bar rounds down in 10% steps; it never draws full before actual 100%.
- Four saved independent alert switches: Charging Started, Unplug Soon (78%), Unplug Reminder (80%), Fully Charged (100%). All default on.
- Charging-start alerts show the actual current percentage after an observed fresh idle-to-charging transition.
- Once-per-session milestones, skipped-level handling and conservative reconnect/restart deduplication. Disabled events do not replay when re-enabled.
- Native accessory cards, About/version information, notification controls and secondary Technical Details.

The Magic Mouse glyph is Apple's runtime `magicmouse` SF Symbol representing the accessory. Apple symbol artwork is not bundled or licensed under this project's MIT license.

## Limitations

- Raw-flags profiles currently cover vendor 76/product 803 Magic Mouse and vendor 76/product 801 Magic Keyboard, reporting Bluetooth on macOS 27.2.x. Flag 3 below 100% is charging indication; flag 4 is not charging. Other values and unvalidated model/OS combinations stay unknown. These are observed compatibility profiles, not a universal documented specification.
- Recognized explicit Boolean charging properties can provide evidence. Conflicts, missing or stale observations remain unknown. USB presence alone is insufficient.
- At 100%, the menu item may disappear because active charging is uncertain. A supported full reading can still notify after continuous charging evidence; it does not prove that current stopped or that power bypasses the battery.
- Polling fallback is 30 seconds idle/unknown and 10 seconds charging, alongside registry event hints. Cached driver values can still be stale, and exact alert percentages are not guaranteed.
- Initial/recovered readings do not trigger historical alerts. An entire charging cycle while the app is absent cannot be reconstructed. Missing stable identity limits reconnect deduplication.
- Notifications are optional reminders. There is no automatic power cutoff, precise time-to-target estimate or guaranteed battery-health improvement.

See [Validation](docs/VALIDATION.md) for actual evidence and pending hardware checks. App Store sandbox compatibility, signed distribution and broader device/OS support remain unverified.

## Privacy and Security

The app has no network client, analytics, accounts or cloud service. It reads only relevant accessory telemetry and never captures input. A supported accessory address is read transiently to derive an installation-keyed HMAC identity; raw addresses, serials and personalized device names are not stored or logged. Local preferences, the identity key, digests and bounded notification-session history use UserDefaults.

Read the [privacy details](docs/PRIVACY.md), [support guidance](SUPPORT.md) and [security reporting policy](SECURITY.md). Public registry APIs are used; private accessory IOPowerSources APIs are not used. Undocumented registry property semantics remain a compatibility risk.

## Contributing

Start with [CONTRIBUTING.md](CONTRIBUTING.md). Keep changes focused, run the local checks and distinguish simulated tests from real hardware evidence. [Architecture](docs/ARCHITECTURE.md) describes the monitoring and notification paths. CI compiles, tests and validates bundle packaging; it cannot validate charging hardware.

## License

Magic Charger is licensed under the [MIT License](LICENSE).

Copyright (c) 2026 Arshia Ghaf.
