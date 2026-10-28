# Reading work across sessions — 0.8.0

This documents the earlier statistics-first interface. Version 0.9 leads with [your participation in an exchange](PARTICIPATION.md); the bounded source projection and sampling limits below remain in use.

The overview and menu-bar quick view start with recent Codex work across Conductor workspaces. A busy conversation should not stand in for the rest of the person's work. Session maps remain available as a source drill-down.

## What the overview answers

- Which recently updated sessions are represented, and how much saved conversation is loaded?
- Which requests contain simple go-aheads, opening task instructions, questions/checks, or constraints/corrections?
- Where did the agent reply last in the loaded history? Where did the latest recorded turn fail?
- What exactly was said in one of those exchanges?

Select a wording category to see up to five recent source requests. Select an example or thread to open its conversation map and comparison. The app preserves the selected session and message instead of redirecting to the newest thread.

These cues provide a starting point for reflection. They do not answer whether the person understood, approved, read, accepted or independently verified the work. An agent-last reply may have been reviewed elsewhere. A provider-reported failed turn does not establish a broken repository, and a successful turn does not establish a correct feature.

## The wording rules

Each nonempty user-side message with a source time in the trailing 24-hour window receives one category, in this order:

1. **Go-ahead only:** the existing strict short continuation rule, such as “Please proceed.”
2. **Questions & checks:** a question mark or words such as test, verify, explain, why, how, understand, compare or reproduce.
3. **Constraints & corrections:** wording such as only, must, should, instead, don't, keep, stop, wrong, still or again.
4. **Task-first wording:** an opening task verb such as build, make, implement, add, fix or refactor, optionally after please/can you/could you/let's.
5. **Other wording:** everything unmatched.

The top-level go-ahead count uses only the strict short continuation rule. Questions/checks and constraints/corrections form the specific-input count. Delegating and steering can coexist; these are not opposing fractions of work. This compares observable wording in a sample; it is not the fraction of all work delegated, nor a validated classification of the person's intention. Mixed prompts receive one category, so “Build this and verify rollback” appears with checks. Language outside these English rules can be missed. Quoted text and app-added instructions not removed by the known-block filter can affect results.

No model runs for this overview. Optional on-device AI still interprets only a bounded excerpt of a selected session. It does not reason across all projects or establish daily habits.

## Coverage

The projection considers sessions updated within the past 24 hours, capped at 24. It gives each workspace a slot before filling remaining slots by recency. If more than 24 workspaces qualify, the most recently updated workspace representatives take the slots. It reads at most the latest 100 saved messages per selected session, with a 4,096-character excerpt cap per message at the database query. The original archive is unchanged.

Request counts exclude missing source times and messages outside the time window. Loaded/stored message totals describe the sampled sessions, including any older messages in their recent-message slices. Provider history can still be filling, and unimported history is not included in the saved total. Unknown request coverage shows a dash instead of a misleading zero. Memory coverage, missing dates and sampling limits remain visible.

Workspace identifiers are the existing salted local identities. Repository names and paths are not newly collected. Several Conductor workspaces can belong to one repository. Thread titles are existing user notes or prompt excerpts, not new inferred project identities.

The projection is transient and local. It adds no source permissions, network calls, mouse/reading capture, database tables or persistent derived records. Memory erasure clears it and invalidates pending reads. Existing consent and pause behavior are unchanged; inspecting an already saved archive remains possible while capture is paused.

## What still needs building

A meaningful personal account needs task and decision boundaries across sessions, outcome evidence and user corrections. The current overview does not merge related features, determine what remains unreviewed, identify over-questioning or measure cognitive effort. A useful evaluation is whether people can find a consequential exchange across their work and choose one check that could settle it, with manageable false positives. Richer semantic interpretation requires its own evaluation before stronger claims.
