# Validation

## Current evidence

This is an early source preview, not a signed consumer release. Controlled cable transitions informed separate Magic Mouse and Magic Keyboard profiles. The mouse has user-confirmed charging display, automatic menu-bar appearance/removal, and charging-start notification receipt. A user-triggered test notification also has confirmed receipt. Notification Center receipt does not establish desktop banner presentation.

Deterministic tests cover decoder boundaries, conflicting observations, stable identity, charging-start continuity, skipped thresholds, full-charge eligibility, alert preferences and menu display preferences. They use synthetic fixtures, not fabricated live readings.

## Still to verify

- Live simultaneous keyboard/mouse charging and independent removal.
- Real 78%, 80% and 100% alert crossings, full-but-connected behavior, and keyboard charging UI.
- Sleep/wake, reconnect, stale driver data and unsupported hardware/OS behavior over extended use.
- Banner presentation with Focus and screen-sharing policy accounted for.
- Longer idle/charging performance measurements on an optimized build.
- Minimum deployment target, Intel architecture, accessibility and all appearance states on additional systems.

A build or successful notification submission is not proof of these behaviors. Driver observation time is not a driver freshness guarantee.

## Hardware procedure

For each model/OS, confirm unplugged, plugged below target, unplugged again, and reconnect. Compare only relevant model family, vendor/product IDs, transport, percentage and charging properties. Never include addresses, serials or personalized names in reports. Confirm physical actions separately from tool observations. USB presence alone is not charging proof. Do not cycle batteries unnecessarily to reach milestones.

Run `swift test` for simulation checks and `sh build-app.sh` for the local preview. CI runs those commands, verifies ad-hoc bundle integrity and checks the bundled license. CI does not test physical devices or visible notifications.
