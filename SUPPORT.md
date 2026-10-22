# Support

Reopen Magic Charger from Finder or Spotlight to access settings or Quit when no menu item is visible. Closing the window keeps monitoring running. The app does not start automatically at login.

For missing alerts, check Notifications > Magic Charger in System Settings, the app's four alert switches, Focus, and the system's screen-sharing/mirroring notification policy. A Notification Center entry does not prove a banner appeared. Send Test is an explicit one-shot check; it does not simulate a charging transition. Settings changes remain your choice.

If you used a pre-release build with bundle ID `local.magiccharger.app`, the new `co.arshia.magiccharger` build starts with fresh notification permission, preferences and local session identity. Enable notifications again if wanted, review your alert/menu choices, and disable Launch at Login in the older preview before quitting it and opening the new build. If the old preview is unavailable, remove its entry in System Settings > General > Login Items. Quitting alone does not cancel its login registration. No previous settings or session history are imported or deleted.

Unknown charging state can mean unsupported telemetry, conflicting observations or stale data. It does not mean 0% battery or necessarily a permission problem. See README for current profiles and validation limits.

Report reproducible bugs through GitHub issues. Include build version, generic device family, macOS version, expected/actual behavior and whether the observation was simulated or physical. Redact identifiers and personal data. Use SECURITY.md for suspected vulnerabilities.
