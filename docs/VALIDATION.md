# Validation

## Current evidence

This is an early source preview, not a signed consumer release. On macOS 27.2, user-confirmed cable transitions informed separate Magic Mouse and Magic Keyboard flag profiles. The mouse has user-confirmed charging display, automatic menu-bar appearance/removal, and charging-start notification receipt. A user-triggered test notification also has confirmed receipt. Notification Center receipt does not establish desktop banner presentation.

Deterministic tests cover decoder boundaries, conflicting observations, stable identity, charging-start continuity, skipped thresholds, full-charge eligibility, alert preferences and menu display preferences. They use synthetic fixtures, not fabricated live readings.

## Checks needing physical observation

- Live simultaneous keyboard/mouse charging and independent removal.
- Real 78%, 80% and 100% alert crossings, full-but-connected behavior, and keyboard charging UI.
- Sleep/wake, reconnect, stale driver data and unsupported hardware/OS behavior over extended use.
- Banner presentation with Focus and screen-sharing policy accounted for.
- Longer idle/charging performance measurements on an optimized build.
- Minimum deployment target, Intel architecture, accessibility and all appearance states on additional systems.

A build or successful notification submission is not proof of these behaviors. Driver observation time is not a driver freshness guarantee.

## Hardware validation checklist

Use one model and OS version per report. Observe a normal charging session; do not cycle a battery just to reach a threshold. Record the date, generic model family, macOS version, app commit or version, and whether each result came from a physical action, a device observation, or a visible app/notification result. A test notification proves delivery of that test only.

| Check | Expected result | Record |
| --- | --- | --- |
| Connected, unplugged | No charging menu item; controls can still open | Relevant percentage and charging properties, including unknown or missing values |
| Plug in below 100% | A menu item appears only after supported charging evidence; an observed idle-to-charging transition may send Charging Started if enabled | Physical plug time, observed state, menu result and any notification receipt |
| Unplug, then reconnect | Item disappears when charging evidence ends; reconnect without a fresh observed idle-to-charging transition does not replay Charging Started | Both transitions and whether each was observed in the same running process |
| Sleep and wake | Stale status is removed during sleep; wake rechecks before showing charging | Whether the device remained connected and the first fresh result |
| Two accessories, or duplicate transports | Each verified accessory behaves independently; conflicting readings do not create a charging item | Generic model families and any disagreement, without identifiers |
| Natural 78%, 80% or 100% crossing | At most once per enabled milestone per device session; one reading crossing multiple milestones selects only the highest enabled eligible alert | Before/after percentages, alert settings, Notification Center receipt and banner appearance separately |

For each check, mark **pass**, **fail**, or **not observed** and describe expected versus actual behavior. Do not infer charging from USB presence, a rising percentage or a nonzero flag alone. Observation time is not proof that the driver value is fresh. Do not include addresses, serials, personalized names, screenshots containing personal data or broad registry dumps in public reports. Share only the relevant model family, vendor/product IDs, transport, percentage and charging properties after redaction.

The macOS 27.2 mouse menu behavior, charging-start receipt and test-notification receipt are separate user-confirmed observations. No physical 78%/80%/100% crossing or threshold-alert delivery has been recorded yet; the threshold tests above use synthetic readings. Simultaneous charging, keyboard live UI, sleep/wake and banner presentation also await direct observation.

Run `swift test` for simulation checks and `sh build-app.sh` for the local preview. CI runs those commands, verifies ad-hoc bundle integrity and checks the bundled license. CI does not test physical devices or visible notifications.
