# Signal opportunities for Vernier

Research checkpoint: 27 October 2026. These are integration opportunities, not enabled collectors. Current code, generated schemas for the installed Codex 0.164.0, and the primary documentation linked below were inspected. No provider settings, hooks, browser extensions or capture permissions were changed. No personal conversation or checkpoint payload was inspected for this review.

## First: preserve provenance already exposed by Codex

The installed protocol schema includes command `source` values `agent`, `userShell`, `unifiedExecStartup` and `unifiedExecInteraction`, plus command status/duration, context-compaction items, review-mode items and subagent relationships. These are static schema capabilities; availability in a particular persisted session remains to be tested with synthetic fixtures and a separately scoped live check.

Vernier’s `ConversationBoundary.signal` currently keeps file-change counts and coarse command exit outcomes, dropping command source and other item types. Consequently it cannot distinguish these command channels. Retaining an allowlisted reported source would improve attribution before adding more counters. Missing/legacy provenance must remain unknown. A user-shell channel does not by itself authenticate a human operator.

Keep compaction and tool failure context alongside a repeated repair request. Their temporal proximity can help reconstruct what happened; it does not establish why the person repeated themselves. Parent/subagent links can help reconstruct delegation without collecting subagent prompts or private reasoning.

Source: [Codex App Server](https://learn.chatgpt.com/docs/app-server), plus the locally generated installed-version schema. The public overview and local wire schema are not identical; validate exact field names/version behavior before implementation.

**Priority:** first, within the current Codex connector. Keep new text/tool payloads excluded; expose updated coverage and provenance. A safe migration/backfill plan is needed for old records that lack these fields.

## Runtime interruptions and explicit approval decisions

Current Codex documentation provides lifecycle hooks including prompt submission, interruption and tool/compaction boundaries. A small observe-only collector could preserve an interruption followed by a changed instruction. Tool-hook coverage has exceptions; missing events cannot mean no action occurred. Hooks must not alter context, tool input or permission decisions, and must not become hidden buffers while Vernier is paused.

Source: [Codex hooks](https://learn.chatgpt.com/docs/hooks).

Codex’s optional OpenTelemetry events document approval/denial provenance as configuration versus user. This offers a route to distinguishing an explicit recorded decision from an automatic policy result. It requires opt-in telemetry/export configuration; validate local-only collector behavior, payload filtering and Conductor-hosted compatibility. An event labeled user is a provider attribution, not proof of independent thought or a biological human operating the interface.

An automatically approving policy can produce no explicit approval opportunities. That is a configuration fact, not evidence that the user disengaged. Runtime request/tool durations could also help separate system waiting from elapsed session time; neither measures attention.

Source: [Agent approvals and security](https://learn.chatgpt.com/docs/agent-approvals-security).

Claude Code also documents prompt, tool and permission hooks, with event-specific coverage limits. It is a later adapter opportunity, not currently connected. A permission-request event records an opportunity or request, not necessarily the final person’s decision.

Source: [Claude Code hooks](https://code.claude.com/docs/en/hooks).

**Priority:** a small consented Codex pilot after checking the actual host configuration. Vernier’s separate history-reading app-server process must not be treated as a tap into another process’s live approval stream. Do not start/resume/control the user’s agent to obtain signals.

## Link a correction to an artifact and executed evidence

Conductor documents checkpoints as private Git refs spanning both user and AI changes between message boundaries. A read-only, opt-in adapter could associate a turn with an aggregate change and later persistence or reversion. Checkpoints do not establish who authored each edit, whether a diff was inspected, or whether anyone understood it. Internal ref encoding is version-sensitive; no local workspace-control API is assumed.

Source: [Conductor checkpoints](https://www.conductor.build/docs/reference/checkpoints).

GitHub check runs expose a result and commit identity. Linking the result to the exact tested revision gives stronger evidence than an agent’s prose claim. A passing check supports only what that check covers; its triggering account does not authenticate a human reviewer. Do not read private log bodies unless separately authorized.

Source: [GitHub check runs](https://docs.github.com/en/rest/checks/runs).

**Priority:** second, an evidence chain for one Conductor workspace: instruction/correction → turn → aggregate change → tested revision/result → later retained or reverted state. Temporal links and semantic interpretations must remain distinguishable. This does not causally prove that a correction produced a change.

## Browser interaction before submission and after an answer

A consented extension on explicitly selected AI sites could observe supported composer changes, submissions, selected UI actions and answer copy events. This could reveal draft revisions and adoption opportunities absent from provider transcripts. It requires a tested adapter for each site’s changing DOM; it is not an official consumer-chat history API integration.

Chrome content scripts can interact with page DOM using host permissions or user-triggered temporary `activeTab` access. Native messaging can pass minimized events to a local application. Temporary access is a good prototype boundary; continuous capture needs a distinct site permission/consent design.

Sources: [Content scripts](https://developer.chrome.com/docs/extensions/develop/concepts/content-scripts), [activeTab](https://developer.chrome.com/docs/extensions/develop/concepts/activeTab), [Native messaging](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging).

An observed copy is not proof of adoption or comprehension. Do not infer human operation from a DOM event’s `isTrusted` flag; browser/user-agent provenance is not a human identity guarantee. Avoid global clipboard polling and recording unrelated pages. Retaining draft text requires a separate sensitive-content choice; counts of edits cannot establish reasoning quality.

Sources: [DOM copy events](https://developer.mozilla.org/en-US/docs/Web/API/Element/copy_event), [Event.isTrusted](https://developer.mozilla.org/en-US/docs/Web/API/Event/isTrusted).

**Priority:** later, a one-site prototype. The promising question is how a prompt or artifact evolved around AI interaction, not how often someone moved a mouse. Linking a copied fragment to a later edit is an additional hypothesis requiring consented integration at both ends.

## Editor inspection opportunities and terminal execution

A VS Code extension can observe visible ranges, selection changes and document edits. Terminal completion events require shell integration; exit codes can be unknown. These can help locate an inspection opportunity or a completed command, but do not establish reading, authorship or review quality. An editor event can be programmatic. Conductor’s embedded UI is not automatically a VS Code extension host.

Source: [VS Code Extension API](https://code.visualstudio.com/api/references/vscode-api).

**Priority:** later, only for an editor the user actually uses. Prefer file/range identifiers and minimized event metadata to recording all text. Store observed channel and uncertain actor separately. A test launched through a particular terminal/control is not automatically a human-authored test.

## Signals that require an active probe

An optional sandbox exercise can create evidence that passive observation cannot: a prediction before an answer, a short independent explanation, a bounded bug diagnosis or a recovery modification with assistance conditions recorded. This is a proposed Vernier feature, not a newly discovered provider API.

Keep assisted performance, later unaided performance and intervention effects separate. Prompt wording can change visible behavior or the AI’s answer. A reminder that produces more verification language has not established improved independent capability. Follow the [research framework](RESEARCH.md), with separate consent and no interruption of real AI access.

## Important boundaries

- The documented [Conductor MCP server](https://www.conductor.build/docs/api/mcp) manages **cloud** workspaces. It is not a documented API for observing/control of the local Mac workspace UI.
- None of the above justifies a passive comprehension, fatigue or agency score by itself.
- Capture event time/precision, source, declared actor/channel, evidence kind, task/turn/artifact links, coverage and collection consent. Preserve uncertainty instead of inventing actor labels.
- Keep observed events, agent reports, user attestations and probe attempts separate. Adding another model to interpret text produces a hypothesis, not independent ground truth.
- Observer overhead and failures can change the interaction being measured. Benchmark latency/drop rates, keep output out of agent context, and honor Pause/revocation at ingestion.

## Recommended first implementation

Extend the current connector’s provenance envelope using only safe structured fields. Then validate one complete correction-to-artifact-to-check sequence in a synthetic Conductor workspace. After that, pilot runtime hooks/approval provenance with explicit consent. Browser/editor bridges and active probes remain separately scoped work.

A useful future account might say: “A completion claim was followed by your correction, another implementation change and a check on that revision.” It should show the source evidence and gaps rather than assert that you understood the change or that the correction caused the outcome.
