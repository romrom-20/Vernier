# Vernier

**Understand how you steer AI-assisted work.**

[![Build and core checks](https://github.com/romrom-20/Vernier/actions/workflows/ci.yml/badge.svg)](https://github.com/romrom-20/Vernier/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Native macOS](https://img.shields.io/badge/native-macOS%2014%2B-black)
![Swift 6](https://img.shields.io/badge/Swift-6-orange)

A coding session can produce a working feature and a long conversation. Reconstructing how you got there is harder: which requirement kept returning, where you changed direction, what evidence the agent offered, and what still needs checking.

Vernier is an experimental Mac app for making that process visible. It turns consented **Codex history from Conductor workspaces** into an interactive conversation map, source comparisons and optional on-device AI interpretations. The aim is to help you recover the intent and reasoning behind the work, then choose a useful next check.

The broader question is **human agency in AI-mediated work**: when does delegation expand what you can do, and what remains within your ability to understand, redirect and recover?

**Current version: 0.7.0.** Visual session review works today. AI interpretations are experimental. Daily cognitive scores, personal baselines and validated capability assessments are not implemented.

![Vernier's native session perspective using an invented coding conversation](Docs/images/overview.png)

*Actual app, isolated showcase mode. The conversation, counts and fixed example interpretations are synthetic. This image demonstrates the interface, not measured AI accuracy.*

## A concrete example

Imagine building a CSV importer:

1. You specify that importing the same file twice must not create duplicate contacts.
2. The agent reports an implementation. You try again and report duplicates.
3. After another update and a successful build, you ask for the same file to be imported twice, with before-and-after counts.

The useful story is the relationship between those events. A requirement returned after a completion claim. You made the acceptance check more specific. The blank-email case still needs evidence.

Vernier helps reconstruct that sequence. A possible repair loop links back to its messages; selecting a point compares the preceding agent reply with your next instruction. Repeated questions can represent careful oversight. Their number alone cannot tell us whether the delegation was appropriate or what you understood.

![Conversation map comparing the agent's update with a more specific user acceptance check](Docs/images/session-map.png)

*The same invented session. Green points identify user-side directions; purple points identify agent reply stretches. The curve follows reading order.*

## How to read it

- **The record:** the map shows saved messages from one session. Select a point, compare neighboring exchanges, and open the exact source. Counts apply to the loaded window, capped at the latest 500 saved messages. They describe recorded activity.
- **The interpretation:** optional on-device AI suggests a working goal, possible loops, steering and alternatives. Each pattern has source messages and can be dismissed. Its reviewed excerpt may be smaller than the map; both show their coverage. Sources can be valid while the interpretation is wrong.
- **The next check:** a review suggestion helps turn an unresolved requirement into an observable test. It does not establish that the work passed, that you reviewed it, or that a mistake was yours.

The diagram's height identifies the speaker. It does not encode attention, elapsed time or cognitive strain. A provider session can contain several features; it is not automatically one human task.

[Walk through a session](Docs/READING_A_SESSION.md) · [Map semantics and design rationale](Docs/VISUAL_REVIEW.md)

## What works today

- **Visual review:** interactive speaker lanes, before-and-after comparisons, source-linked AI markers, illustrated pattern cards and a suggested next check.
- **Quiet Mac presence:** native SwiftUI/AppKit, menu-bar quick view, optional draggable circle/pill and short, reduced-motion-aware transitions. Pause works in place; Explore full story opens Studio.
- **Codex in Conductor:** read-only local history access. Vernier never starts, resumes or controls an agent.
- **Local memory:** available prompts, visible replies, allowlisted agent activity metadata, your notes, archive search and export. Coverage and missing history stay visible.
- **Separate choices:** metadata, conversation capture and local AI interpretation are distinct opt-ins, off on a fresh install.
- **User-owned storage:** SQLite, incremental backfill, retention, conversation erasure and full local deletion. Optional login registration and adaptive sync support resident use; Quit is respected.

## Try the synthetic showcase

Requires a Mac, Swift 6+, and Apple Command Line Tools or Xcode. macOS 14 is the deployment target; cross-version compatibility is still being tested.

```sh
git clone https://github.com/romrom-20/Vernier.git
cd Vernier
./Scripts/showcase.sh
```

The showcase uses invented, in-memory records and separate preferences. It opens no personal archive, starts no connector or model, and cannot register a login item. Select map points, inspect sources, and try the pill's hover, drag and pause controls. Quit from the menu bar when finished.

## Install on your Mac

```sh
# Quit any running copy before updating.
./Scripts/install-local.sh
open "$HOME/Applications/Vernier.app"
```

This installs a local development app at `~/Applications/Vernier.app` and preserves the previous same-ID bundle. Enable sources in Connections, conversation capture in Memory, and optional login/pill behavior in Privacy. Closing Studio leaves the menu-bar app running.

**Local AI is optional.** It requires macOS 26.4+, an eligible Mac with Apple Intelligence ready, and a build with the Foundation Models SDK. Enable it in the AI brief details or Privacy. The reader and map work without it. No Vernier account, backend or separate API key is required.

A live connector requires Conductor's installed Codex binary and available local history. This is a source release with an ad-hoc signature; a notarized download, DMG and automatic updater are not available.

## Privacy and scope

Personal records stay in a private Application Support directory on your Mac. The SQLite database is not encrypted. Credential redaction is best effort; conversations and exports can still contain sensitive material. No captured conversation is sent to a cloud model by Vernier.

Only Codex history under `~/conductor/workspaces/<repository>/<workspace>` is currently connected. Claude Code, Cursor, ordinary ChatGPT chats, Perplexity and other agents are not connected. Vernier does not collect global mouse movements, screens, keystrokes, browser tabs or reading behavior.

Default retention is 30 days by session update time. Pause suspends synchronization; resuming can import provider history created while paused. Turning capture or analysis off retains existing records until erased or removed by retention. Memory erasure also clears derived briefs and the in-memory map.

**This repository contains source, tests, documentation and reviewed synthetic images. Personal conversations, databases, exports, local settings and workspace attachments are excluded.** Publication checks reject private artifact paths and unreviewed or changed image bytes; human review remains necessary.

[Privacy details](Docs/PRIVACY.md) · [Connector coverage](Docs/CONNECTOR_COVERAGE.md) · [Publication boundary and audit](Docs/PUBLICATION.md)

## The research direction

The ambition is an instrument for understanding human agency, with three separate evidence layers: **passive observations today, separately consented capability probes proposed, and longitudinal experiments proposed**. The framework keeps prior independent ability, AI-assisted performance, later unaided ability and Vernier's own effects separate.

The critical test is whether richer interaction history predicts independent understanding or recoverability better than task difficulty, prior skill and simple usage counts. A useful recovery tool would still be valuable if that measurement hypothesis fails. No comprehension, fatigue, attention, intelligence, cognitive-decline, agency or readiness score is claimed today.

[Product thesis](Docs/PRODUCT.md) · [Measurement framework](Docs/RESEARCH.md) · [Roadmap](Docs/ROADMAP.md) · [Architecture](Docs/ARCHITECTURE.md)

## Verify and contribute

```sh
./Scripts/verify.sh       # Core checks, bundle build, plists and signature
./Scripts/verify.sh --ui  # Adds isolated native checks; interactive Mac required
python3 Scripts/test-public-content.py
python3 Scripts/check-public-content.py
```

GitHub Actions runs the shared core checks, XCTest, bundle build and publication checks on macOS. Native regressions exercise hover, pause, window routing, source navigation and projection lifecycle. These checks do not establish physical mouse, hardware sleep/wake or cognitive-measurement validity.

[Executed validation and remaining gaps](Docs/VALIDATION.md) · [Interaction checklist](Docs/INTERACTIONS.md) · [Contributing](CONTRIBUTING.md) · [Report a bug](https://github.com/romrom-20/Vernier/issues/new/choose) · [Security reporting](SECURITY.md)

Built by [romrom-20](https://github.com/romrom-20), with AI coding assistance. [MIT licensed](LICENSE). Vernier is a working project name and an early experiment.
