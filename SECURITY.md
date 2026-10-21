# Security

This early preview has no supported stable release or security-response SLA. Fixes target the current main branch.

Do not post secrets, hardware identifiers or exploitable private details in a public issue. Use GitHub's **Report a vulnerability** feature if available. If private reporting is unavailable, open a minimal issue requesting a private reporting channel without vulnerability details; do not attach dumps or credentials.

The app should read only supported-accessory telemetry, never input events. Raw identifiers must remain transient. It should not send network requests, alter system permissions or install persistent launchers. Report violations of these boundaries.
