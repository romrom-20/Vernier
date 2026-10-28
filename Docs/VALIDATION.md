# Validation and evidence

This document separates executed checks from remaining acceptance work. It contains no personal conversation records or workstation-specific session statistics.

## Executed locally

The native app compiled and linked with Swift 6.3.1 on Apple Silicon, macOS 26.6.2, using Apple Command Line Tools. `./Scripts/verify.sh --ui` built the bundle, validated its plists/ad-hoc signature, and passed the shared core groups plus native smoke checks. The public-source run passed 17/17 shared check groups and 40 native checks, including showcase isolation/search. The synthetic Overview and Sessions routes were also inspected through the installed native accessibility surface and captured for the README. Subsequent manual pill navigation was not established through that UI tool; the native regression results remain separate from the outstanding manual mouse matrix.

Shared checks exercise fixture identity/attribution, honest unknowns, persisted opt-out preferences, multi-display placement math, metadata normalization, read-only RPC sequencing, timeout behavior, 1,000-record deduplication, migrations preserving notes, consent revocation, retention/deletion, durable pagination, credential redaction, bounded previews with full-archive search/export, and independent backfill.

Native checks create actual AppKit windows in an isolated process/preferences domain. They exercise popover geometry, Studio lifecycle, nonactivating pill configuration, stable hover and direct capture actions. The regression checks inject an own-panel pointer location and call native handlers/button actions; no physical pointer automation is claimed. See [interaction specification](INTERACTIONS.md).

## Regressions that shaped the implementation

1. Bounded SwiftUI content alone did not keep popover chrome on screen. Tests reproduced an outer frame above the display; final native-window clamping handles the complete frame.
2. Hover attached to conditional SwiftUI content could exit when expansion replaced the subtree. Tracking now belongs to a persistent native host, with a cancelable, pointer-validated exit.
3. A sustained hover test exposed delayed Studio reappearance. Only actually minimized windows are now deminiaturized.
4. A pause-shaped status glyph opened Studio with the rest of the pill. It is now a separate native button with explicit hit routing and two-direction toggle checks.

An immediate focus assertion was also replaced with a bounded wait for real active/key-window state. Failed runs were used to diagnose issues; they were not reported as passes.

## Environment limits

Full Xcode is not installed on the local validation machine, so local XCTest is unavailable. The same shared checks execute through the dependency-free `VernierCoreChecks` executable; an XCTest wrapper and macOS GitHub Actions workflow are provided. CI results are visible in [Actions](https://github.com/romrom-20/Vernier/actions).

## Not yet verified

- Manual VoiceOver, keyboard-only navigation, larger text and contrast review.
- The full [manual mouse matrix](INTERACTIONS.md), crowded menu bars and actual multi-monitor/full-screen behavior.
- Actual hardware sleep/wake/reboot/login and clean-Mac installation.
- macOS 14/15 compatibility across supported hardware.
- Sustained CPU/memory/energy measurements and responsiveness targets.
- Developer ID signing, notarization, DMG and updater.
- Systematic validity/usefulness of AI session interpretations, comprehension measures or cognitive scores. An implemented local brief is not a validated assessment.

Live connector verification during development confirmed read-only local Codex history access. Reproducing it is optional and consented: `swift run VernierCoreChecks --codex-live` prints metadata counts only. Never attach real archives or personal provider data to a public issue.

## Exclusive surfaces and interaction focus — 0.5.0

Three supplied screenshots showed quick view layered over Studio, the menu surface opening independently, and an idle compact checkmark. All were inspected before editing. The capture status is now a quiet circular presence rather than a success/review mark. Body click pins controls; dedicated native capture and dashboard buttons have independent hit targets. Dashboard and quick view are mutually exclusive requested surfaces, including activation/reopen and late native callbacks.

`./Scripts/verify.sh --ui` passed **17 shared groups and 47 native checks**. New checks cover activation while quick view is open, dashboard replacing quick view, quick view hiding dashboard, four rapid transition cycles, body pinning without a dashboard, distinct dashboard hit testing, and only the dashboard arrow opening Studio. Existing hover, pause, source and storage checks remain green. No new ingestion permission or database schema was added.

The updated synthetic Overview was inspected through the native accessibility tree and visually captured for the README. It puts intent, steering and understanding before collapsed archive details. A later attempt to inspect quick view through the computer-use tool returned native timeout errors; reconnecting also timed out. That manual transition is not claimed as verified by the tool. The native in-process window checks above did verify the actual resulting window visibility and popover state. Manual physical mouse/full-screen/multi-monitor checks remain pending.

The prompt trail reuses the bounded session-scoped archive search, displays at most six user-side excerpts from the latest 100 saved messages, and labels approximate ordering and app-added context. It makes no automatic quality judgment. The human-agency research vision is now explicit in the product thesis/roadmap, with automated trajectory assessment and personal trends still unimplemented research/engineering work.

## On-device session briefs — 0.6.0

`./Scripts/verify.sh --ui` passed **20 shared groups and 52 native checks** on the local Mac. The new shared groups exercise source-reference integrity, fabricated-quote rejection, minimum distinct user evidence for loops, judgment filtering, excerpt coverage, token-budget narrowing with user-role preservation, contiguous source quotes after context removal, analysis consent/revocation, correction persistence, export/erasure, schema v3→v4 preservation and recovery from corrupt derived-cache payloads. Native additions verify opt-out defaults, isolation from model calls, cancellation generation, synthetic brief provenance and citation navigation. Full local XCTest remains unavailable without Xcode.

The optional `--brief-model-probe` successfully ran Apple’s actual on-device model on an invented seven-message interaction. It identified a recurring symptom after completion claims and an evidence request before acceptance; selected citations resolved to the synthetic source. This is a hardware integration/sanity check, not an accuracy benchmark or validated detector. Normal CI and showcase do not invoke the model.

The installed development app also generated a local brief from consented saved history; structural checks confirmed persistence and literal citation integrity, and the brief was inspected locally in the app. No personal transcript, model output or screenshot was published. Live checks exposed weak generic recommendations as well as agent progress replies crowding user intent; the prompt now asks for a concrete user action and does not recommend fewer questions, while excerpt selection now preserves the latest two user messages, allows longer user requests, and constrains generated references to the selected source IDs. Longer excerpts can still be narrowed to fit the on-device context, and interpretation can be wrong.

The synthetic Overview was inspected visually and through the native accessibility surface. “Why this appeared” revealed its literal quote; “Open source message” opened Memory with the matching session and query. The README image contains only the isolated synthetic showcase. Physical mouse, cross-version availability, energy, full-day pattern counts, longitudinal baselines and controlled usefulness/accuracy evaluations remain pending.

## Visual conversation review — 0.7.0

`./Scripts/verify.sh --ui` passed **21 shared groups and 57 native checks**. The new projection checks cover selected-session scope, user/agent counts, follow-ups, contiguous replies, separate user turns, stable ordering, missing timestamps, partial coverage, literal source navigation, AI-marker source resolution and deterministic invented presentation records. A progress-update regression verifies that the substantive final reply remains visible rather than being replaced by a later status update.

Native additions cover visual fixture loading, repeated focus of the same source, reuse of an unchanged projection, reload after source-coverage changes, and clearing/invalidation on memory erasure. Existing popover bounds, exclusive surfaces, hover/pause, storage and consent checks remain green.

The synthetic Overview and map comparison were inspected visually and through native accessibility. Selecting a node updated its before/after comparison. An interpretation action selected the cited instruction and scrolled the map into view. Read source opened Memory with the exact session and matching query. Quick View was opened through the app menu; its accessibility inspection timed out in the computer-use tool. Command-O then successfully restored the full dashboard. Full manual pointer testing of the new quick view is therefore not claimed; the native geometry/routing checks remain the evidence for that surface.

The two published screenshots use only the invented CSV-import showcase. The fixed synthetic interpretations demonstrate layout and interaction, not the local model's measured accuracy. No personal screenshot, transcript or derived interpretation was published. This is not a user study, usefulness benchmark, cognitive assessment or full-day trend implementation. See [visual review semantics and rationale](VISUAL_REVIEW.md).


## Work overview — 0.8.0

The shared suite now has 22 passing groups. The new group checks cross-workspace coverage, a quieter workspace surviving a busy neighbor, deterministic request ordering, mutually exclusive wording categories, exact source provenance, session/time caps, missing source times, partial memory and a newer undated turn superseding an older failure. Storage checks also verify SQL excerpt clipping marks truncation without changing searchable/exported originals.

The 60-check isolated native suite passes and adds overview fixture coverage, bounded projection reuse, source/session routing and erasure invalidation. Synthetic desktop inspection verified category selection exposes literal requests, request navigation selects its own session and map source, and the comparison scrolls visibly into view after loading. The current overview image uses three invented workspaces. No personal archive was used for these captures.

The native popover geometry/routing checks pass. The external UI tool still times out inspecting the quick-view popover, including screenshot capture; a manual visual sign-off for that surface is not claimed. Command-O successfully returned to Studio. Real-world comprehension, task outcomes, absent review and daily semantic patterns remain unvalidated.


## Participation readings — 0.9.0

The shared suite passes 23 groups, and the native suite passes 63 checks. New checks cover recurring-issue context, literal source/speaker/session integrity, test versus build evidence, explicit scope constraints, explanation versus demonstrated understanding, negated explanation requests, short continuation, initial instructions, determinism and the recent-time window. Native checks cover quick-view-to-reading navigation, exact source routing and erasure clearing readings.

Synthetic native inspection verified that the compact view fits its fixed content size, Why this matters opens the selected explanation, a returning-problem reading preserves both user requests and agent reports, and the source action selects the exact message in the conversation map. The quick-view screenshot uses the exact menu-bar component in an isolated standard-window host (`--showcase --quick-preview`) because external inspection of the real popover previously timed out. It is a visual content check; real popover sizing/routing retain separate native regression evidence. No personal archive is used in public captures.

Readings remain rule/template interpretations; these checks establish source integrity and routing, not semantic accuracy, comprehension, cognitive effort or outcome validity. Background energy, broader source capture and the existing hardware/manual accessibility matrix remain unverified.


## Revisiting reasoning — 0.10.0

On macOS 26.6.2, Apple M5 / 24 GB, Swift 6.3.1 and Ollama 0.40.9:

- `Scripts/verify.sh` passes 28 shared core groups, the native bundle build, plist/signature verification and 33 isolated application-state checks. Full XCTest cannot run with Command Line Tools alone. The published macOS GitHub run passed the shared groups, both XCTest wrappers, bundle build, state checks and publication checks.
- Core checks cover actual human anchors after long agent runs, known text reuse and short disagreements, exact source excerpts, supporting context, overlapping acts, corrections tied to their original request, same-topic success versus a returning failure, related-context limits, source/perspective invalidation, hidden canonical frontiers, stale writes, pause/opt-out, erasure/export and migration from schema v4 without losing memory or notes.
- State checks exercise conversation/history selection, return to latest, exact source IDs and repeat navigation, map focus, separate perspective persistence, a draft retaining its original target across selection/history changes, disabling automatic review, cancellation and erasure. Showcase cannot invoke inference, access the personal store or register login. These are application-state checks, not physical mouse automation.
- Synthetic probes through the signed app bundle generated and validated readings using Apple's local framework and Gemma through loopback HTTP. This checks production resources and both provider paths, not model accuracy.
- All three public images were rendered offscreen from actual SwiftUI components, visually inspected and hash-manifested. They use invented messages and hand-authored readings. They do not demonstrate model accuracy or capture a personal desktop.

The final native window attempt passes 26 checks, including popover bounds, in-place quick-view Pause, repeated quick-view/dashboard transitions, stationary hover through resize exits, pinning and both native pill Pause/Resume actions without opening Studio. The suite runs those controls before the unchanged Studio-focus assertion; it stops there. Later assertions are not reached. This session's desktop cannot activate Vernier (`NSApp.isActive=false`, no key Studio window); the final suite stops there. External native inspection also reports `cgWindowNotFound`. A complete final physical/button/focus acceptance is therefore **not claimed**. The isolated state checks and offscreen layout checks pass; focused-window suppression and the remaining real desktop matrix need an active graphical session.

Model interpretation remains experimental. None of the completed model configurations met the quality gate; see the exact synthetic results and known errors in [model evaluation](MODEL_EVALUATION.md). No personal cognitive, comprehension or agency metric is validated by these tests. All-day energy and natural-conversation usefulness remain unmeasured.

A normal installed 0.10 launch migrated the consenting local store from schema 4 to 5 while preserving its existing saved messages and session records. Private aggregate counts and schema were checked; those usage counts, personal records and readings are excluded from public assets and reports. Existing source/content/analysis choices were preserved, and automatic inference remains off until separately enabled.
