# Local data and consent

Vernier has two distinct Codex permissions: metadata access and conversation memory. Both are off on a fresh install. No screen, browser content, microphone, Accessibility or general app-usage permission is requested.

Metadata stores salted IDs, provider timestamps/source labels, recorded outcomes and coverage. Conversation memory additionally stores provider-recorded user text and visible agent replies, with best-effort credential redaction. Messages can contain app-added context or other private material. Agent file-change counts/command exit outcomes are separate observations; raw commands, tool arguments/output, diffs, file bodies, attachments and reasoning items are dropped. Conversation text is capped at 256 KiB per message with a visible truncation flag. Future/unknown agent-message phases are not captured.

Redaction handles recognizable bearer tokens, common key formats, quoted/JSON key/password assignments and private-key blocks, including unfinished/truncated blocks. It is not a promise that every secret or private fact is detected. The UI discloses this before content capture is enabled. No captured text is sent to a model or cloud service by Vernier.

Storage is SQLite in `~/Library/Application Support/local.vernier.instrument.dev/`, directory 0700 and database/sidecars 0600. No custom database encryption is claimed. Raw provider pagination cursors are private connector state; normalized record IDs are salted hashes. Pagination state is excluded from the content export. Successful-check timestamps are stored separately from actual metadata changes; unchanged content is not rewritten. The change log is capped at 10,000 entries and follows retention.

Pause/disconnect immediately invalidate a generation gate. A response already in flight may finish reading but cannot persist after revocation. Conversation consent is also checked inside the storage transaction; metadata consent alone cannot authorize text. Sleep/inactive-session suspension closes the same gate. Wake does not override user Pause.

Resume imports the provider's current historical snapshot; activity generated while paused may be included after resume. The provider records its own history independently, and there is no Vernier event backlog. This is synchronization suspension, not a provider-history exclusion mechanism. Per-session exclusion is not implemented yet.

Turning conversation capture off retains saved text until the user chooses Erase conversation memory or retention removes its parent session. Memory erasure clears messages, agent signals and capture progress, without removing metadata/notes or provider history. Complete local deletion disconnects, clears source records/cursors/checkpoints, checkpoints WAL and vacuums. Explicitly reconnecting can import available history again. SSD-level forensic erasure is not claimed.

Retention defaults to sessions updated within 30 days, cascading to notes, turns, conversation messages and signals. Alternatives are 90 days, a year, and no time limit until user deletion. JSON export includes the entire stored archive, despite the bounded UI preview, with a private-data warning and an explicit save destination. The export is 0600; it is never uploaded.

The connector starts a disposable local Codex app-server with analytics disabled and issues read-only history requests. It does not copy provider credentials or change Codex/Conductor settings. Codex otherwise retains its own configuration; its startup network behavior is not represented as Vernier-owned telemetry. No model requests are issued.

Login registration is optional through Apple's SMAppService; OS approval state is visible. Quit is respected; no keepalive daemon relaunches after a user Quit. Before uninstalling, disable Open at login, Quit, then remove the app, Application Support records and optionally preferences (`defaults delete local.vernier.instrument.dev`). No hooks need restoration. Development-app backups in workspace `.context/previous-install.*` contain application code/resources, not the database.

Session display labels derive locally from saved notes or an excerpt of already-consented user text; known app-injected context blocks are removed from the excerpt. Date-based labels are used when no suitable text exists. These labels are literal text, not generated summaries. Overview counts include the complete retained archive, independent of bounded message/signal UI previews. The interaction update adds no source or capture permissions.
