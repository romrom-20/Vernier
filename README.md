# Vernier

**Keep the context. Make your own call.**

[![Build and core checks](https://github.com/romrom-20/Vernier/actions/workflows/ci.yml/badge.svg)](https://github.com/romrom-20/Vernier/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Native macOS](https://img.shields.io/badge/native-macOS%2014%2B-black)
![Swift 6](https://img.shields.io/badge/Swift-6-orange)

Vernier is an experimental, local-first Mac app for understanding work done with AI agents. It lives in the menu bar, keeps a searchable memory of explicitly connected sessions, and gives you a place to record what you actually checked.

**The ambition is to make human judgment visible as agents do more of the work.** The current release provides capture, memory and reflection. It does not yet determine whether you understood a change or independently verified an outcome.

![Vernier Studio showing explicitly labeled synthetic session data](Docs/images/overview.png)

*Actual native app, using the isolated showcase mode. Every session, message and count in this image is synthetic.*

## Why build this?

An agent can finish responding while the important questions remain open: What changed? Why was that approach chosen? What did a person challenge? Which result still needs checking?

Most usage dashboards count activity. Those counts cannot distinguish effective delegation from uncritical acceptance. A short “build this” prompt might be followed by careful product testing; a long conversation might still leave a consequential assumption unchecked.

Vernier explores a more useful record: **intent → agent work → evidence → your decision → what happened next**. Today, the session history and user-authored reflection are implemented. Automatic decision/outcome linking and evidence-backed reviews are research and engineering work ahead.

[Read the product thesis](Docs/PRODUCT.md) · [Roadmap](Docs/ROADMAP.md) · [Architecture](Docs/ARCHITECTURE.md)

## What works today

- **Native presence:** SwiftUI inside AppKit, a bounded menu-bar quick view, and an optional draggable, nonactivating pill.
- **Direct capture controls:** hover to expand; play/pause changes capture in place; click elsewhere to open Studio. The pill hides while Studio is focused or quick view is open.
- **Codex in Conductor:** read-only local history access, scoped to Conductor workspaces. No agent is started, resumed or controlled.
- **Separate permissions:** session metadata and conversation text are distinct opt-ins, both off for new installations.
- **Local conversation memory:** available prompts, visible assistant replies, and allowlisted agent activity metadata. Search and export include the retained archive; incomplete histories stay labeled.
- **User-owned storage:** SQLite, incremental backfill, retention, export, conversation erasure and full local deletion.
- **Reflection:** readable session labels, direct conversation navigation, and a separate note for your expectation, checked evidence and assumptions.
- **Resident lifecycle:** optional native login registration, adaptive sync cadence, rest during sleep/inactive sessions, and preserved Pause across wake.

## What it cannot tell you

Vernier does not measure comprehension, fatigue, attention, intelligence, or cognitive decline. It has no strain/readiness score. Short continuation wording is only a literal text flag.

It does not record global mouse movements, screens, keystrokes, browser tabs or reading behavior. **The pill's mouse interactions are tested; your other mouse activity is not collected.** Even opening a diff would not prove that you understood it.

Only Codex history under `~/conductor/workspaces/<repository>/<workspace>` is currently supported. Claude Code, Cursor, ordinary ChatGPT chats, Perplexity and other agents are not connected. A provider's “completed” response is not proof of correctness, review or shipping.

## Try it without connecting anything

Requires a Mac, Swift 6+, and Apple Command Line Tools or Xcode. macOS 14 is the deployment target; cross-version compatibility is still being tested.

```sh
git clone https://github.com/romrom-20/Vernier.git
cd Vernier
./Scripts/showcase.sh
```

Showcase uses labeled, in-memory synthetic sessions and a separate preferences domain. It opens no personal archive, starts no connector, and cannot register a login item. Try hover, drag, play/pause and the native context menu. Quit from the menu bar when finished.

## Build and install locally

```sh
# Quit any running copy before updating.
./Scripts/install-local.sh
open "$HOME/Applications/Vernier.app"
```

The installer creates `~/Applications/Vernier.app` and preserves previous local app bundles. Closing Studio leaves the menu-bar app running. Enable sources in Connections, text capture separately in Memory, and optional login/pill behavior in Privacy. Quit is always available.

This is a source release with an ad-hoc local build. A notarized download, DMG and automatic updater are not available yet. No Vernier cloud account, backend, separate API key or model inference is required. A live connector requires Conductor's installed Codex binary and available local history.

## Privacy and data boundaries

The app stores records at `~/Library/Application Support/local.vernier.instrument.dev/sessions.sqlite` with private directory/file permissions; it does not encrypt the database. Metadata uses salted identifiers. Conversation capture excludes private reasoning, attachments and raw tool/file output; credential redaction is best effort and private details may remain.

Default retention is 30 days by session update time. Pause suspends synchronization; resuming can import provider history created while paused. Turning text capture off keeps the existing archive until erased or removed by retention. Exported conversations are sensitive.

[Privacy details](Docs/PRIVACY.md) · [Connector coverage and bounds](Docs/CONNECTOR_COVERAGE.md)

## Verify the implementation

```sh
./Scripts/verify.sh       # Core checks, bundle build, plists and signature
./Scripts/verify.sh --ui  # Adds isolated native checks; needs an interactive Mac session
```

The shared checks also run through `swift test` with full Xcode. GitHub Actions runs core checks, XCTest and the bundle build on macOS; it does not claim physical mouse or sleep/wake testing.

Native regressions cover stationary hover during resizing, canceled exit on re-entry, direct play/pause without opening Studio, nonactivation, bounded popover placement and pause preservation. Storage/protocol checks cover deduplication, migration, consent revocation, redaction, search, export, retention and read-only requests.

![Synthetic session library](Docs/images/sessions.png)

[Interaction specification and manual mouse checklist](Docs/INTERACTIONS.md) · [Executed validation and remaining gaps](Docs/VALIDATION.md)

## Contribute

Useful contributions include reproducing native interaction issues, improving source adapters, testing lifecycle/accessibility, and helping validate whether a session review is actually useful. Use synthetic reproductions in public issues.

[Contributing](CONTRIBUTING.md) · [Report a bug](https://github.com/romrom-20/Vernier/issues/new/choose) · [Security reporting](SECURITY.md)

Built by [romrom-20](https://github.com/romrom-20), with AI coding assistance. [MIT licensed](LICENSE). Vernier is a working project name and an early experiment.
