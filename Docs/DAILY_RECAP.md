# A daily picture of the human side

The main view now asks **how did I work with AI today?**, rather than leading with the agent's latest next step. The compact view and dashboard share a day-level projection. Conversation readings and maps remain available underneath it.

## What the numbers mean

The denominator is **recorded human follow-ups after an agent reply**, within the chosen local calendar day. Each saved human message counts separately, including several human contributions within one provider turn. It is not the number of tasks, the percentage completed by AI, time spent thinking, a cognitive score or a grade of prompt quality.

Five mutually exclusive wording categories form the breakdown:

- **Handed back:** recognizable brief assent or continuation with no added requirement. A bare answer to an agent's clarification question is guarded. This is a narrow proxy, not all delegation.
- **Added direction:** recognizable constraints, choices or corrections.
- **Asked to check:** requests for tests, explanations, comparisons or evidence. Negated instructions such as “do not test” do not count as check requests. Asking is distinct from performing the check.
- **Reported a result:** a recognizable first-person attempt or outcome report. The app does not verify the report.
- **Other / unclear:** other wording, brief repair requests, known copied agent text, clipped human messages or language the rules do not resolve.

The rules run locally and match a limited set of English expressions. They hide recognizable app-added context and check known reuse of earlier agent wording within the loaded conversation. They can miss typos, languages, implicit direction and context. These counts are not model judgments about mental effort. A short approval can follow careful thought; a long question can be unnecessary or valuable.

A conversation with an initial request and agent replies but no saved follow-up appears separately, outside that percentage. It may be fully delegated, still in progress or reviewed elsewhere. A provider conversation and a workspace can each contain several human tasks.

## The useful part

An active-hour chart shows counts, not time on task or fatigue. Gaps between shown active hours are omitted. A continuation stretch is counted within one conversation; it does not assert a shared task or missing thought. Brief repair requests are a wording pattern, not proof that the same bug returned. The recap offers a concrete exchange to revisit: what caused the change, why was that approach chosen, and what observable behavior would show it worked?

Selecting a number filters its original follow-ups. Each follow-up opens its exact original record. Selecting a pattern opens its own source anchor and surrounding map; it does not expand an unavailable model reading. Workspace groups show a representative conversation goal, rather than pretending the group is a single feature. The existing optional local model can help interpret a particular exchange; the daily percentages do not depend on its classifications.

An optional **check-in** records the person's own clarity, energy and short note for that date. These are self-reports, not inferred health or understanding measurements. They are kept separately from generated readings.

## During the day and the next morning

Today updates from the existing saved-history sync. Previous-day controls provide a recap for the morning and dates within retention. No additional daemon, timer, external provider or inference schedule is added. Vernier and capture rest during system sleep; after wake, history that the provider saved can fill in. This does not observe sleep or establish what happened while away from the machine.

The projection uses up to 4,000 dated messages from the day, clipped to 4,096 characters each, from the SQLite archive rather than its 300-message resident preview. A bounded preceding message preserves the link when the first reply crosses midnight. Unknown source times stay unassigned; observation time never moves an old message into today. Caps, clipping and incomplete history are disclosed. A busy day beyond the cap is a partial recent window.

Calendar days use the current local time zone and respect daylight-saving changes. A check-in's date key includes its time zone. Changing zones can therefore expose a separate check-in for the same printed date.

Schema v6 adds a source-time index and a separate daily-reflection table, preserving existing sessions, messages, notes and readings. Counts are recomputed in memory. Check-ins are included in local export, age out with retention, and are removed by conversation-memory erasure and full deletion. In-flight results are invalidated on erasure; a generation guard prevents an old check-in save from resurrecting after erasure.

This is a first descriptive daily recap. Validated prompt-quality scores, task/subfield percentages, learning gains, independently demonstrated understanding, all-day cognitive-health measurements and cross-tool coverage are not implemented.
