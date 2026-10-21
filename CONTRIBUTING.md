# Contributing

Open an issue describing the problem or proposed change before substantial work. Keep device reports anonymous: model family, OS version and relevant charging properties are enough. Do not post raw registry dumps, addresses, serials or personalized names.

Use an installed compatible Swift 6.0+ macOS toolchain. Run:

```sh
swift test
sh build-app.sh
codesign --verify --strict "build/Magic Charger.app"
```

Set `DEVELOPER_DIR` locally if needed; do not change global developer selection for the project. No third-party packages are required. Add focused tests for meaningful behavior changes. Simulated fixtures must never enter live UI or notifications.

Use short standard commit subjects such as `fix: preserve charging continuity`. Open a draft PR while work is in progress, with **Summary** and **Validation** sections. Record actual commands/results and distinguish deterministic, CI and hardware verification. Mark ready once the change is ready. Do not claim broader hardware support from a single model.

Contributions are licensed under MIT. Do not copy incompatible third-party implementation or distribute Apple SF Symbols as MIT assets. Keep build outputs and private local agent notes untracked.
