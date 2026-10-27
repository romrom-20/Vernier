# Coverage — Codex in Conductor first

Codex in Conductor is the first implemented source. The adapter supports local **session metadata snapshots** and separately consented conversation history. It does not subscribe to runtime agent events.

## Verified API surface

Official source: [Codex App Server](https://learn.chatgpt.com/docs/app-server). The installed Conductor Codex 0.164.0 generated schemas were checked locally for `ThreadListParams`, `ThreadTurnsListParams` and `ThreadTurnsListResponse`. Thread/turn timestamps are Unix seconds. The command is marked experimental by Codex and may need adapter updates; no experimental API capability is requested.

Metadata-only mode issues `initialize`, the `initialized` notification, `thread/list` and `thread/turns/list` over a private stdio pipe to a disposable process. `thread/list` requests `useStateDbOnly=true`; turn reads request `itemsView=notLoaded`. No thread is started, resumed, subscribed, interrupted, archived or deleted. Unsolicited tool requests are rejected. Provider errors are not logged or copied into UI messages.

The connector discovers installed versioned Conductor Codex executables under the app's user Application Support binary directory. It does not inspect Conductor's private database, copy credentials or edit any settings. A local verification reached the current workspace's real session through the documented API.

## Scope and limitations

The 300 most recently updated main Codex session summaries are checked, including `cli`, `vscode`, `exec`, `appServer` and `unknown` source labels. Only normalized paths under `~/conductor/workspaces/<repository>/<workspace>` are kept. Sibling-prefix and traversal paths are rejected. This grouping establishes a Conductor workspace location; it cannot prove which client originally created a thread. Custom Conductor workspace roots are not configurable yet.

Up to 20 changed session histories are requested per refresh, with two pages of 50 recent turns per session. Unchanged fetched histories reuse local data. An unavailable, timed-out or capped history stays partial. Session-list truncation is also surfaced. Counts cover only stored/returned metadata, not all AI use. Unknown turn counts display a dash when no turn history was available.

A separate app-server process cannot establish the runtime state of sessions running in another process, so runtime status from summaries is deliberately discarded. Recorded `completed`, `interrupted`, `failed` and `inProgress` outcomes describe provider history, not current activity, correctness or review. Missing/future outcome values remain unknown. Metadata may lag while Conductor is working.

## Metadata-only storage boundary

Stored: salted session/workspace/turn identifiers, source label allowlist, provider creation/update/start/completion times, local observation time, recorded turn outcome and history completeness. User-authored takeaway notes are explicitly marked user reported.

Excluded: raw IDs/paths, session names/previews, git URLs, prompts, responses, model traces, item content, errors, tool inputs/outputs, commands and file names/contents. The provider may send a preview in a summary; it is discarded at the normalization boundary and never logged. Metadata-only mode cannot generate content-based briefs. It does not detect human review or understanding.

Claude Code and Cursor remain disconnected. Ordinary ChatGPT conversations, Perplexity, personal agents, remote/cloud sessions and non-Conductor workspaces are not covered. Their interaction and outcome semantics need separate adapters and explicit permissions. Conductor's official [workspace documentation](https://conductor.build/docs/concepts/workspaces-and-branches) describes its isolated workspace model; no global Conductor agent control API is assumed.

## Resident update and separately authorized content memory

Conversation memory is a separate opt-in. Metadata and content access are both off for new installations. With content consent, the same read-only client additionally pages `thread/items/list`; unsupported older storage falls back to `thread/turns/list` with full items. Only user text, visible assistant text and allowlisted tool outcome/count metadata enter local storage. Internal reasoning, images/attachments and raw tool/command/file payloads remain excluded. Secret redaction is best-effort. The connector performs no model summarization or provider control. A separate local-analysis opt-in can produce Apple on-device briefs from already saved text, with source/coverage labels; this adds no provider calls or capture sources.

Conversation paging is independent from the 100-turn metadata cap and can backfill older available text incrementally. At most eight histories advance per refresh; each advances one recent and one old page. Missing provider history, per-message length caps and omitted content are disclosed. A complete pagination pass means available provider text was traversed, not that all human interactions were captured. User messages may include app-added context; item timestamps may be missing or approximate in legacy data.

New metadata checks use updated-time overlap and bounded index pages; unchanged history/text is not re-fetched during normal checks. A bounded metadata reconciliation runs about every six hours or after scope changes. Checks slow when quiet, in Low Power Mode and after failures. Data and actual OS login approval are visible in the app. No general screen, browser-tab, reading, comprehension, fatigue or cognitive-performance observation exists.
