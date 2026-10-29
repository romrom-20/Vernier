# Source release — 0.12.0

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

SQLite schema v6 includes optional daily self-reports and source-time indexes. The existing tables separate session/turn metadata, notes, change log, sync state, messages, safe agent signals conversation progress cached derived briefs, revisable interpretations, human perspectives and source dependencies. UI changes preserve records and existing consent. See [validation and pending acceptance work](VALIDATION.md).

A DMG, Developer ID signature, notarization, secure updater, clean-Mac distribution, universal binary and crash-relaunch service are not implemented.

- **0.5.0:** Human-agency direction made explicit; intent/steering/understanding review and a bounded prompt trail; capture inventory folded into details. One requested UI surface prevents quick-view/dashboard stacking. A quiet 28-point circle replaces the idle checkmark; body click pins controls, capture toggles in place, and only the separate arrow opens the dashboard. No new source or macOS observation permission.

- **0.6.0:** Optional Apple on-device session briefs replace capture counts as the primary Overview/quick-view content. Working goal, possible interaction patterns, exact source links and a small next step; visible excerpt coverage and correctable interpretations. Schema v4 preserves existing records and adds derived-content erasure/retention/export. Fresh installations keep analysis off. Requires macOS 26.4+, Apple Intelligence ready, and a Foundation Models SDK build for generation; the history reader retains its older deployment target. No cloud inference or extra API account.

The additional development flag `--enable-local-insights` enables this local analysis setting only. Normal launches honor saved consent. `--brief-model-probe` runs an isolated hardware-dependent model check on invented conversations; it is not part of normal CI or showcase.

- **0.7.0:** Interactive native conversation map, compact recorded-activity data points, before/after source comparison, AI loop markers, illustrated interpretation cards and a review suggestion. Quick view is a visual entry point with pinned pause and Explore full story. The display-bounded Studio opens larger. No new capture source or schema change. [Map semantics and design rationale](VISUAL_REVIEW.md).


- **0.10.0:** Experimental local reasoning loop with an action reading, source selection, host-composed account, challenge and source checks, immutable revision history and separate human perspectives. New messages and possible related context can trigger another reading. Original exchanges stay inspectable; the source map no longer leads with older interpretation panels. Local Ollama inference is available alongside the experimental Apple alternative, without a cloud fallback. [Mechanism and bounds](REASONING.md) · [Model evaluation](MODEL_EVALUATION.md).

- **0.11.0:** Contextual goals and specific checkpoints replace latest-prompt classifications in the main view. Sources are collapsed, automatic/manual status is explicit, conversation selection persists, and bounded source-backed direction questions have quiet cues and intentional-choice responses. Five literal conflict families have separate provenance from model interpretation. Schema remains v5 and existing records/consent are preserved. No clinical, comprehension or agency verdict is claimed.

- **0.12.0:** Daily recap becomes the first layer in Studio and quick view: a named follow-up denominator, wording breakdown, active-hour pattern, exact-source drill-down, previous days and optional clarity/energy check-ins. Initial requests with agent replies but no follow-up are kept separate. Schema v5→v6 preserves canonical records. These are descriptive source patterns, not prompt-quality, task-completion or cognitive-health scores.
