# Privacy

Magic Charger uses local IOKit accessory metadata: supported device family/vendor/product, transport, percentage and charging evidence. It does not capture keyboard input or mouse events, request serials, send telemetry or use a backend.

A supported accessory address may be read transiently in memory. An installation-specific random key and HMAC produce a local digest for session identity. The key, digest, preferences and bounded notification history are persisted in the app's local UserDefaults domain. Raw addresses and personalized names are not stored or logged. Digest identity is pseudonymous local state, not anonymous data suitable for public sharing.

Session history is bounded to 30 days. Registry-lifetime identity is used when a stable address is unavailable and cannot guarantee reconnect deduplication. Notification Center retains delivered notifications according to macOS/user policy. Quit the app before removing its preferences; removing identity/session data resets deduplication. No automated reset is performed.

Technical Details is intended for local troubleshooting. Review and redact it before sharing; never attach broad registry dumps.
