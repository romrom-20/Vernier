# Earlier participation readings — 0.9.0

Version 0.10 replaces the primary template readings below with a [revisable local reasoning loop](REASONING.md). This file documents the retained earlier rules, not the current model’s accuracy.

Vernier starts with a human action in context. A person should be able to recognize what they contributed and read the exchange behind the explanation. Workspace counts, wording categories, generated session labels and inventory totals no longer lead the menu-bar view or dashboard.

## The small view

One reading, a short explanation and the person's literal words. Examples include asking for a concrete check, making a requirement explicit, returning to a reported problem, asking for an explanation, or letting the agent continue. “Why this matters” opens that reading in Studio. Capture controls stay pinned in the header, and the dashboard and archive remain available below.

The isolated `--showcase --quick-preview` mode hosts the exact menu-bar content in a standard native window for visual QA. It does not open a personal archive or connector. The public quick-view image comes from this host; actual popover geometry and routing are covered separately by native regression checks.

## The explanation

A short sequence shows the earlier user request when applicable, the preceding agent reply, the person's next instruction and an available later agent report. A separate “Why this may matter” paragraph describes the possible significance. Selecting another moment changes the explanation; opening the surrounding exchange selects its exact message in its own conversation map. Original messages remain available in session-scoped Memory.

Sources are copied from actual saved messages. Known injected blocks are stripped for display, and any focused quote must remain a contiguous substring of its source. Relevant build/test progress is preserved separately when a substantive agent reply would otherwise hide it. A later reply remains an agent report, not proof that a requirement passed or that the person understood it.

## How readings are constructed

`ParticipationReview` uses explicit wording within an ordered, bounded conversation excerpt. No model generates this layer. It requires a preceding agent reply before calling something an intervention; an initial request remains an initial request. A returning-problem reading additionally requires recurrence wording and at least two shared nontrivial terms with the earlier user request. Singular/plural normalization is approximate. It does not identify canonical bugs or merge tasks across threads.

Other rules recognize requests to test/reproduce/compare a result, requests for explanation, explicit constraints, and strict short continuation wording. The precedence is recurring problem, requested evidence, explanation, constraint, continuation, then ordinary instruction. Some negations are handled; quotations, typos, language differences, negation and app-added text can still mislead the rules. Generic prose is template-based, so readings can sound similar across different tasks. Sources let the person judge the fit.

Candidate readings are ordered by evidence/check and recurring-issue wording, then constraints/explanations, then continuation or other requests, with recency within each group. This order does not measure importance, attention, cognitive effort, comprehension or success. The interface does not describe an explanation request as demonstrated understanding or a short continuation as disengagement.

Optional on-device AI briefs remain a separate, explicitly enabled session interpretation. They are available in the source inspector and do not silently generate these readings or reason across all projects.

## The circle and background memory

The circle is a visible control for the resident collector. Collection does not depend on hovering it, opening the dashboard, or keeping it visible. The connected source currently supplies saved Codex prompts, visible replies and allowlisted activity in Conductor workspaces. The circle is not a global mouse, screen, browser or reading monitor.

After successful background synchronization, the app prepares the bounded recent-work projection. Stable source keys reuse it between unchanged checks, with a five-minute time bucket advancing the rolling window. Opening a view can also read the existing archive. Sleep, Pause, content consent, source consent, retention and Quit retain their existing meanings; resuming may import provider history from the paused interval.

The new readings add no source permissions, cloud calls, database schema or persistent derived tables. They inherit the recent-work sample limit of 24 conversations × 100 messages × 4,096 characters, including workspace-balanced selection. Dated user requests must fall within the past 24 hours. Provider history may still be filling. Coverage and the method are available in a disclosure; erasure clears the readings and invalidates pending reads.

## Remaining product work

This is an exchange-level foundation for the person's understanding of their own participation. It does not establish how much they used their brain, whether they understood or reviewed elsewhere, verified outcomes, personal baselines, or whether they were being steered overall. Richer reasoning, user corrections and connected decisions/outcomes across sessions still need implementation and evaluation. The intended experience should help the person become oriented without overwhelming them with instrumentation.
