# Magic Charger

A lightweight native macOS accessory battery notifier built with Swift, AppKit, IOKit and UserNotifications. No third-party dependencies. Requires macOS 14 or later.

## Local preview

Run `sh build-app.sh`, then open `build/Magic Charger.app`. The script uses the active Xcode selection; an explicit `DEVELOPER_DIR` can select another installed Xcode without changing system settings. Run `swift test` for deterministic simulated checks.

Launching or reopening the app opens diagnostics, notification permission and Quit controls. Closing the window keeps monitoring. The app has no permanent Dock icon. It requests notification permission only when Enable Notifications is clicked. No login item, persistent background job, external publication or automatic power cutoff is installed.

## Charging evidence

A narrow compatibility profile recognizes vendor 76/product 803 Magic Mouse services reporting Bluetooth on macOS 27.2.x: raw flag 3 indicates charging below 100%, flag 4 indicates not charging, and all other values remain unknown. This profile is based on controlled cable transitions, not a documented universal flag specification. Flag 3 at full charge or with missing/invalid percentage remains unknown. Keyboard and other model/OS flag profiles remain unvalidated and unknown. Recognized explicit charging Booleans can also provide evidence; contradictory properties remain unknown. Conflicting observations sharing a strong device identity are suppressed. A successful build is not proof of reliable charging detection on every device or OS. Hardware-specific decoders require controlled connect/disconnect validation; USB presence alone is insufficient. At full charge, accepting current versus externally powered must not be assumed.

Registry matching/termination callbacks handle arrivals and removals. General-interest notifications are hints, backed by a 30-second idle/unknown poll and a 10-second charging poll. Polling improves responsiveness but cannot make driver telemetry fresher or guarantee an exact alert percentage. A fast jump across both thresholds emits only the 80% alert. Sleep clears menu items; wake resamples and rejects results from before sleep. Property reads run on a utility queue.

A supported device's address, when available, is read in memory to derive an installation-keyed digest. Only that digest and session data are persisted locally; raw addresses, serials and personalized device names are not stored or logged. If the address is absent, identity is limited to the current registry service and reliable cross-reconnect deduplication is unavailable. Devices are never merged by matching name, model or percentage alone.

## Alert sessions

Alerts use actual threshold crossings from a fresh observed baseline, at most once per threshold per device session. Initial readings or observations after a gap of 90 seconds already above a threshold do not trigger historical alerts. Explicit idle ends a session; unknown states, disconnects, sleep and restart preserve deduplication conservatively. A persisted five-minute cooldown protects against state flapping. History is bounded to 30 days. An entire disconnect/charge/disconnect cycle while the app is absent cannot be reconstructed reliably from a single later reading.

Threshold observations are consumed even when notification permission is denied, preventing historical alert replay if permission is later enabled. macOS delivery remains subject to user authorization, Focus and notification settings. Delivery errors appear in diagnostics. Notifications are advisory: no precise time-to-80 or guaranteed battery-health improvement is claimed.

## Hardware validation

For each model and OS separately:

1. With its cable unplugged, record only generic model, vendor/product IDs, transport, percentage, charging fields, raw battery flags and observation time. Do not record raw addresses, serials or personalized names.
2. Plug the accessory into the Mac using a known charging cable. Confirm the physical action; take narrow snapshots immediately and after a percentage update. Compare charging fields and flags, without using USB presence as proof.
3. Unplug once and verify the reverse transition, status-item disappearance and continued background monitoring. Reconnect and confirm the private identity remains the same without exposing it.
4. Repeat at relevant battery levels. Validate keyboard separately. Treat full charge and unknown/stale states separately. Real 78/80 notification delivery requires permission and real crossings; deterministic tests cover skipped values without charging hardware artificially.

## Implementation references

Public registry notification mechanisms: [IOKit](https://developer.apple.com/documentation/iokit), [Apple notification source](https://github.com/apple-oss-distributions/IOKitUser/blob/main/ionotifyCB.c). Accessory-specific IOPowerSources functions in [IOPowerSourcesPrivate.h](https://github.com/apple-oss-distributions/IOKitUser/blob/main/ps.subproj/IOPowerSourcesPrivate.h) are private and are not used. UI uses [NSStatusBar](https://developer.apple.com/documentation/appkit/nsstatusbar) and [LSUIElement](https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement). Use an installed compatible [Swift toolchain](https://www.swift.org/install/macos/).

No third-party implementation was copied. An open-source license must be selected before public distribution.
