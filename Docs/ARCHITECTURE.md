# Resident app, incremental storage, conversation memory

SwiftUI views live inside an AppKit coordinator owning the native status item, anchored popover, Studio and optional nonactivating panel. The panel follows ordinary desktop Spaces and excludes full-screen Spaces. Native semantic text, adaptive colors and source-triggered motion preserve accessibility. The app icon is generated from the same vector caliper mark with AppKit, not a remote asset.

SMAppService.mainApp provides opt-in login registration. Its actual enabled/approval/unavailable state is displayed; no helper/daemon or user-Quit override exists. Login launch detection checks the documented open-application Apple-event property. NSWorkspace's notification center handles sleep/wake and active/inactive user sessions independently so waking a still-inactive session does not reopen capture. Interactive activation coalesces refresh requests. User Pause survives system wake. Real reboot/full-screen/multi-monitor QA remains pending.

SyncCadence schedules foreground/background/quiet/low-power/retry intervals. The private stdio Codex client uses bounded pages, responses and a 20-second budget; it never starts, resumes or controls a thread. Metadata reads use useStateDbOnly and notLoaded items. Conversation reads are issued only with separate consent, using thread/items/list and, for unsupported older storage, full thread/turns/list. No model request is issued.

Metadata normalization is allowlisted. Conversation normalization accepts only user text and visible assistant phases, redacts credential patterns before storage, excludes tool bodies and annotates clipping/attachment omission. Agent tool signals retain only safe kind/outcome/count fields. A prompt is provider-recorded text, not evidence of the human's keystrokes or understanding.

Newest conversation pages and older ascending backfill have separate durable cursors. Recent pages stop at known records; old history advances independently. A bounded number of sessions advance per refresh. Unsupported/truncated histories remain partial. Source timestamps can be item milliseconds or older turn-boundary seconds; missing timestamps and approximate order are disclosed.

SessionStore is an actor over system SQLite3, with transactional v1→v2→v3→v4 migrations, WAL, foreign keys, parameter binding, secure_delete and restrictive file permissions. Sessions/turns are snapshots; change_log records actual metadata changes only. sync_state holds successful check/reconciliation times. messages, agent_signals and memory_progress form a separately consented content layer. Unchanged upserts have predicates excluding observation time, avoiding full-history rewrites. The UI reads a bounded 300-message preview; local search queries the full archive; explicit export loads all stored messages.

ObservationGate holds a synchronous generation and separate content permission through the storage transaction. Pause, disconnect, system rest and content revocation invalidate in-flight results. UI projection rechecks the generation after actor suspensions. Pause suspends synchronization, and a later resume can import provider history created while paused; per-session exclusions are not implemented.

The product’s ambition is an instrument for understanding human agency in AI-mediated work. Observable conversation/tool events, deterministic wording flags, user-authored takeaways and future independently measured capabilities must remain separate. There is no numerical cognitive-health/readiness score and no inference that tab switches prove reading. Optional local semantic briefs are interpretations with source references; cross-tool memory, review/comprehension measurements and validated probes remain future work.

## Native interaction update — 0.4.0

Quick view uses a 356-point fixed width and a screen-aware height capped at 414 points. An explicit hosting size prevents content changes from resizing the popover; AppKit's final window frame, including its chrome, is constrained to the status item's display visible frame after presentation. Header/footer actions remain pinned around a scrolling center.

PillPresentation separates hidden, compact (28×28), and hover-expanded (232×48) states. Studio focus, an open quick view, and system rest suppress the panel. Expanded-anchor coordinates preserve the center during resizing and dragging; user placement remains bounded across display changes. The panel remains nonactivating, with a native context menu. CapturePhase gives all surfaces explicit paused/checking/current/error/disconnected semantics. A spinner appears only during an actual check, with reduced-motion/low-power alternatives.

Session digests query exact per-session archive counts and a bounded excerpt of the earliest saved user message. Notes take title precedence; known injected context is removed; date fallback avoids exposing hashed IDs. No generated summary or new source read is required. The schema remains v3; an idempotent signal-session index supports these counts. Memory navigation carries an optional session filter; raw activity is collapsed behind conversation access and a user-authored reflection.

Pill hover ownership lives on the persistent native hosting view, outside SwiftUI layout branches. A 200 ms cancelable exit checks the current own-window hit region; a resize-related exit cannot dismiss a panel that still contains the pointer. Dragging holds hover until mouse-up. Target-frame caching avoids restarting a resize on unrelated model updates.

## One requested surface and interaction review — 0.5.0

The coordinator tracks ambient, quick view, Studio and welcome as mutually exclusive requested surfaces. Quick view orders Studio out without releasing it. Open dashboard sets its intention before dismissing the popover, so delayed close notifications cannot override the dashboard. Reopen while quick view is active does not create a second surface; delayed Studio key notifications are rejected when a different surface is requested.

The circle body pins/unpins capture controls, and separate native capture/dashboard buttons own distinct hit regions. A latched drag threshold prevents mouse jitter or a drag returned to its origin from invoking click behavior. Pinning is transient; opening a primary surface clears it.

The dashboard emphasizes intent, steering and understanding. Session review reuses the local session-scoped search (latest 100 saved messages) and displays at most six recent user-side prompt excerpts in approximate time order, with no semantic quality classification. User reflection remains separately labeled. This is a review scaffold, not an automatic measurement of interaction quality or cognitive condition.

## Measurement-layer boundaries — proposed design

Current schema v4 stores observation records, user-authored notes and derived session briefs. It contains no probe attempts, study enrollment, randomization, intervention assignments or validated capability scores.

Future designs should preserve separate contracts for source observations, user reports, probe attempts/assessments and study assignments/outcomes. Each needs provenance, time/coverage context and its own applicable consent and retention rules. A task/decision contract must be defined before cross-session interpretation is implemented; a provider turn is not automatically a human task boundary.

A future probe record needs task/version, domain/difficulty, prior familiarity, allowed assistance, response and rubric/evaluator provenance. A future experiment additionally needs enrollment, assignment, exposure and outcome timing. Do not silently reuse content consent as permission to run an exercise, alter a prompt or enroll a person in a study. These are design requirements, not implemented tables or APIs. See [the research framework](RESEARCH.md).

## On-device session interpretation — 0.6.0

`BriefWindow` constructs an ordered, bounded opening/recent excerpt from canonical saved messages. Transient M-labels keep raw identifiers out of the model prompt. `LocalBriefGenerator` serializes generation with Apple Foundation Models, a dynamic output schema and exact token counting. The default on-device model has no tools or cloud fallback; availability is gated to macOS 26.4+ and a compatible SDK. Builds on older SDKs retain the reader and show an unavailable reason.

The app copies quotes from selected source records, resolves references and checks minimum evidence structure before projection. This does not validate the interpretation itself. `WorkBrief` separates model prose from literal evidence, coverage, clipping, unknown source times and engine provenance. UI supports source-scoped search and dismissal; it never claims daily rates or cognitive scores.

Schema v4 adds `work_briefs`, one JSON payload per session with an ON DELETE CASCADE foreign key. Derived-cache decoding failures do not prevent canonical history from loading. Source/content/analysis consent and generation are checked atomically through `ObservationGate.captureBrief`; actor-resumed UI changes recheck cancellation/generation. Erasure removes the cache. The previous source schema and notes survive migration.

Generation is opt-in, debounced to five minutes automatically and cancelable with a 90-second UI deadline. Only the selected/latest session is scheduled; it is not a full-day or all-session batch assessment. No model calls run in showcase or normal CI; a separate explicit `--brief-model-probe` uses invented data on compatible hardware.
