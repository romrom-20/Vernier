# Privacy update — 0.11

The new goal/check reader uses the same separately consented Codex conversation archive and local inference choice. Source-backed literal boundary questions can run without inference; inferred goals and checkpoints use the selected local provider. No new capture source, screenshot, browser, global mouse or keystroke access is added. Quiet cues use only Vernier's own circle/menu bar, with no system-notification permission or agent-control action.

Choice responses are saved as separate human perspectives and are scoped to the actual requirement/proposal fingerprints. Conversation selection is a local preference. Erasure clears the displayed readings, source dependencies, responses and selected conversation; source invalidation cascades to dependent reports. A user-initiated Copy this check writes only that visible suggestion to the Mac clipboard. Nothing is sent to a coding agent automatically.

Automatic reviewing has a visible status and independent switch. It runs serially at most once per two minutes after fifteen seconds of source quiet, rests in Low Power Mode, and honors pause, opt-out, rest and erasure gates. Literal questions and model interpretations have separate provenance. No model weights are trained on personal sessions.

The existing capture/storage/export/redaction boundaries below remain in force. Historical release sections describe earlier reader behavior.

---

# Local data and consent

Vernier has two distinct Codex permissions: metadata access and conversation memory. Both are off on a fresh install. No screen, browser content, microphone, Accessibility or general app-usage permission is requested.

Metadata stores salted IDs, provider timestamps/source labels, recorded outcomes and coverage. Conversation memory additionally stores provider-recorded user text and visible agent replies, with best-effort credential redaction. Messages can contain app-added context or other private material. Agent file-change counts/command exit outcomes are separate observations; raw commands, tool arguments/output, diffs, file bodies, attachments and reasoning items are dropped. Conversation text is capped at 256 KiB per message with a visible truncation flag. Future/unknown agent-message phases are not captured.

Redaction handles recognizable bearer tokens, common key formats, quoted/JSON key/password assignments and private-key blocks, including unfinished/truncated blocks. It is not a promise that every secret or private fact is detected. The UI discloses this before content capture is enabled. No captured text is sent to a cloud model or cloud service by Vernier. A third, separate opt-in enables local inference over saved conversation excerpts: a selected Ollama model through 127.0.0.1:11434, or Apple’s on-device model. It is off for new installations. No API key, agent invocation, tools or cloud fallback is used.

Storage is SQLite in `~/Library/Application Support/local.vernier.instrument.dev/`, directory 0700 and database/sidecars 0600. No custom database encryption is claimed. Raw provider pagination cursors are private connector state; normalized record IDs are salted hashes. Pagination state is excluded from the content export. Successful-check timestamps are stored separately from actual metadata changes; unchanged content is not rewritten. The change log is capped at 10,000 entries and follows retention.

Pause/disconnect immediately invalidate a generation gate. A response already in flight may finish reading but cannot persist after revocation. Conversation consent is also checked inside the storage transaction; metadata consent alone cannot authorize text. Sleep/inactive-session suspension closes the same gate. Wake does not override user Pause.

Resume imports the provider's current historical snapshot; activity generated while paused may be included after resume. The provider records its own history independently, and there is no Vernier event backlog. This is synchronization suspension, not a provider-history exclusion mechanism. Per-session exclusion is not implemented yet.

Turning conversation capture off retains saved text until the user chooses Erase conversation memory or retention removes its parent session. Memory erasure clears messages, agent signals, capture progress and cached AI briefs, decision revisions and saved perspectives, without removing metadata/notes or provider history. Complete local deletion disconnects, clears source records/cursors/checkpoints, checkpoints WAL and vacuums. Explicitly reconnecting can import available history again. SSD-level forensic erasure is not claimed.

Retention defaults to sessions updated within 30 days, cascading to notes, turns, conversation messages, signals, AI briefs, decision revisions and saved perspectives. Alternatives are 90 days, a year, and no time limit until user deletion. JSON export includes the entire stored archive, despite the bounded UI preview, with a private-data warning and an explicit save destination. The export is 0600; it is never uploaded.

The connector starts a disposable local Codex app-server with analytics disabled and issues read-only history requests. It does not copy provider credentials or change Codex/Conductor settings. Codex otherwise retains its own configuration; its startup network behavior is not represented as Vernier-owned telemetry. The Codex connector issues no model requests. Optional inference is a separate local operation; the Codex connector does not invoke your coding agent.

Login registration is optional through Apple's SMAppService; OS approval state is visible. Quit is respected; no keepalive daemon relaunches after a user Quit. Before uninstalling, disable Open at login, Quit, then remove the app, Application Support records and optionally preferences (`defaults delete local.vernier.instrument.dev`). No hooks need restoration. Development-app backups in workspace `.context/previous-install.*` contain application code/resources, not the database.

Session display labels derive locally from saved notes or an excerpt of already-consented user text; known app-injected context blocks are removed from the excerpt. Date-based labels are used when no suitable text exists. These labels are literal text, not generated summaries. Overview counts include the complete retained archive, independent of bounded message/signal UI previews. The interaction update adds no source or capture permissions.

## Current reasoning loop — 0.10.0

The new primary reading uses observable-action extraction, source selection and a challenge from one selected local model, with host-composed visible language and source validation. Ollama requests use only a fixed loopback URL, an ephemeral HTTP session, no cookies/cache and no followed redirects. The model allowlist contains local model tags, not cloud endpoints; there is no provider/account fallback. Models are installed separately. Ollama itself has its own configuration and lifecycle; Vernier does not expose its server on the network or install a launch daemon.

Revisions, short source quotes, engine/prompt version and human perspectives are private derived content in schema v5. Export includes them. Up to 40 readings per conversation are retained, plus readings with attached perspectives. Analysis off retains old content; erase and retention remove it. A source edit/deletion invalidates dependent readings, including retrieved-context dependencies. User-authored perspectives are explicit reports, not passive observation.

Automatic reviews require their own switch, initially off. They wait for 45 seconds of source quiet, rest in Low Power Mode, and run serially over changed, recently active conversations, at most once per five minutes, with a five-minute retry interval for each conversation. Changed messages, retrieved-context counts and perspectives can trigger a revision. Unchanged evidence reuses the prior account. Pause, disconnect, content/analysis revocation, sleep, inactivity and Quit invalidate pending result persistence. Underlying local computation may not stop immediately. Ollama requests have bounded request/resource timeouts and unload weights after 30 idle seconds. CPU, memory and energy vary by model; all-day battery impact is not yet measured.

No screen, mouse, keystroke, browser or other source is added by reasoning. [Exact retrieval, clipping, attribution and correction limits](REASONING.md).

## Legacy on-device work briefs — 0.6.0

The following describes the older brief implementation, retained for compatibility. It is no longer the main dashboard, compact view or automatic reasoning scheduler.

Briefs use an opening user request and up to 18 recent nonempty messages, initially capped at 1,200 characters per user message and 350 per assistant reply. The latest two user messages are retained even when many agent progress replies follow. Exact model token counting can narrow/shorten the excerpt further. Known app-injected context blocks are removed; this is best-effort input preparation, not an assurance that all text is human-authored. No additional screen, mouse, browser or keyboard source is captured.

The model returns a working goal, candidate patterns, source references and a suggested next step. Source IDs must resolve within the reviewed excerpt; displayed quotations are copied from the actual saved message. Repeated-repair and handoff candidates require two distinct user messages. These checks establish citation integrity and minimum source structure, **not semantic correctness**. A model may misread a goal or relationship. Known unsupported personal judgments are filtered, but a keyword filter cannot guarantee model behavior. Inspect the sources and dismiss incorrect interpretations.

One derived brief per session is cached in the same private SQLite database, including short source quotes, engine version, generation time and excerpt coverage. Export includes it. Dismissal of the same observation persists across refreshes. Turning analysis off cancels pending results and retains existing briefs; memory erasure/full deletion removes them, and session retention cascades to them.

Automatic generation applies only to the selected/latest session, only after a source update or stored-message-count change, at most once per five minutes. Manual refresh bypasses that interval. Pause, source/content/analysis revocation, sleep and user-session inactivity invalidate in-flight persistence. Cancellation may not instantly stop underlying on-device computation, but no stale result can be saved. A 90-second deadline bounds the waiting interface. No active probes, prompt edits, provider control or research enrollment are introduced.

## Visual projection — 0.7.0

The conversation map reads at most 500 already saved messages for one session into an in-memory projection. It does not observe additional activity. Role/sequence counts apply to the loaded window; AI interpretations retain their separate reviewed-message coverage. Erase conversation memory and full deletion clear the projection and invalidate pending reads. No new table or consent is introduced.
