# Source release — 0.5.0

Vernier is an experimental native Mac app and working project name. This repository publishes source, synthetic showcase data, tests and documentation under MIT. There is no production, notarized binary release yet.

## Build and try

`./Scripts/build-app.sh` creates `build/Vernier.app` with a generated caliper icon and ad-hoc local signature. `./Scripts/showcase.sh` opens it with separate preferences and in-memory synthetic records. Showcase never opens the personal archive, starts a connector or registers a login item.

For a normal local installation, Quit an existing instance and run `./Scripts/install-local.sh`. It installs at `~/Applications/Vernier.app`, backs up the previous same-ID bundle under the ignored `.context/` directory, and does not replace unrelated applications. Open from Finder or `open "$HOME/Applications/Vernier.app"`. Source builds require macOS and Swift 6+; macOS 14 is the deployment target rather than a completed compatibility-test claim.

## Permissions and lifecycle

Metadata/content capture, the floating pill and native Open at login are separate choices. Normal launches honor saved settings. SMAppService reports actual OS login eligibility; no daemon or user-Quit override is installed. Before uninstalling, disable Open at login, Quit, then remove the app and optional local records/preferences described in [privacy](PRIVACY.md).

Development launch flags `--connect-codex`, `--enable-conversation-memory`, `--enable-login` and `--show-pill` change those respective settings. Use them only when the person using the Mac has requested those actions. The public showcase uses none of them and runs isolated.

## Recent implementation checkpoints

- **0.4.0:** bounded menu-bar view, quiet hover pill, explicit capture controls, exact archive inventory, readable session labels and conversation navigation.
- **0.4.1:** persistent native hover tracking, canceled/delayed exit validation, stable resize targets and conditional unminimizing.
- **0.4.2:** native in-place play/pause, separate from click-to-open.
- **0.4.3:** public documentation, MIT license, isolated synthetic showcase and reproducible CI/checks.

SQLite schema v3 separates session/turn metadata, notes, change log, sync state, messages, safe agent signals and conversation progress. UI changes preserve records and existing consent. See [validation and pending acceptance work](VALIDATION.md).

A DMG, Developer ID signature, notarization, secure updater, clean-Mac distribution, universal binary and crash-relaunch service are not implemented.

- **0.5.0:** Human-agency direction made explicit; intent/steering/understanding review and a bounded prompt trail; capture inventory folded into details. One requested UI surface prevents quick-view/dashboard stacking. A quiet 28-point circle replaces the idle checkmark; body click pins controls, capture toggles in place, and only the separate arrow opens the dashboard. No new source or macOS observation permission.
