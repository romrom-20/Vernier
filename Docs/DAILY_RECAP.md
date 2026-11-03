# A useful way back into your work

The dashboard opens with the visual overview: category cards, the hourly chart and a reflection panel, all visible without expanding a section. Selecting a category or hour opens its matching evidence. A contextual reading follows beneath that overview; the compact panel and expanded pill retain their focused reading when one is available: **what you were trying to achieve, what kind of result is in the record, and one useful next step**. For example, an AI saying the project builds does not establish that a double import avoids duplicates. The next step can connect that build to the original interaction, rather than asking for more prompts generally.

The compact card opens its exact reading and sources; its footer opens the full recap. Other active conversations are available in the dashboard. Today's changed sources withhold old readings until reconsidered. A missing model reading falls back to saved exchanges and an explicit unavailable state, rather than inventing a takeaway. The visible breakdown describes the recorded words; the contextual reading adds a likely goal and checkpoint. Neither is a judgment of thought or capability.

A day uses up to 200 saved readings created that day, latest per active conversation. It is not all tasks or all work done. An old day shows interpretations saved then, not a retrospective model reconstruction. With no current reading and few new replies, the compact panel can retain yesterday's fuller recap; it names that date and opens that date. A fresh reading of delegated work can take priority even without a human follow-up. [Source and model boundaries](REASONING.md).

## What the numbers mean

The denominator is **recorded human follow-ups after an agent reply**, within the chosen local calendar day. Each saved human message counts separately, including several human contributions within one provider turn. It is not the number of tasks, the percentage completed by AI, time spent thinking, a cognitive score or a grade of prompt quality.

Five mutually exclusive wording categories form the breakdown:

- **Asked AI to continue:** recognizable brief assent or continuation with no added requirement. A bare answer to an agent's clarification question is guarded. This is a narrow proxy, not all delegation.
- **Added direction:** recognizable constraints, choices or corrections.
- **Asked to check:** requests for tests, explanations, comparisons or evidence. Negated instructions such as “do not test” do not count as check requests. Asking is distinct from performing the check.
- **Reported a result:** a recognizable first-person attempt or outcome report. The app does not verify the report.
- **Other / unclear:** other wording, brief repair requests, known copied agent text, clipped human messages or language the rules do not resolve.

The rules run locally and match a limited set of English expressions. They hide recognizable app-added context and check known reuse of earlier agent wording within the loaded conversation. They can miss typos, languages, implicit direction and context. These counts are not model judgments about mental effort. A short approval can follow careful thought; a long question can be unnecessary or valuable.

A conversation with an initial request and agent replies but no saved follow-up appears separately, outside that percentage. It may be fully delegated, still in progress or reviewed elsewhere. A provider conversation and a workspace can each contain several human tasks.

## The useful part

An active-hour chart shows counts, not time on task or fatigue. Every shown hour is a button that opens that hour’s source replies. A visible legend, symbols and accessible count labels accompany color. Selecting an hour clears the category filter; choosing a category shows that category across the selected day. Re-selecting the same category still returns to its evidence. Changing the day or erasing memory clears both filters. Gaps between shown active hours are omitted. A continuation stretch is counted within one conversation; it does not assert a shared task or missing thought. Brief repair requests are a wording pattern, not proof that the same bug returned. The recap offers a concrete exchange to revisit: what caused the change, why was that approach chosen, and what observable behavior would show it worked?

Selecting any of the five named counts opens matching replies in **What happened when**, with source times, a conversation label and **Why this was counted**. The explanation names the actual matched wording or the copied-text, clipping or clarification guard. It is a rule explanation, not a contextual judgment about intent. Replies appear latest first, with a small initial preview and a Show more control that can reach all loaded matches. Each reply opens its exact original record or its surrounding exchange. Selecting a pattern opens its own source anchor and surrounding map; it does not expand an unavailable model reading. Workspace groups show a representative conversation goal, rather than pretending the group is a single feature. The existing optional local model can help interpret a particular exchange; the daily percentages do not depend on its classifications.

An optional **check-in** records the person's own clarity, energy and short note for that date. These are self-reports, not inferred health or understanding measurements. They are kept separately from generated readings.

## During the day and the next morning

Today updates from the existing saved-history sync. In 0.12.1, the compact panel uses yesterday when today has no recorded replies, and keeps a fuller yesterday (at least three replies) visible until today has three replies. Both the shown day and today’s small count are labeled; counts from the days are never combined. The main button selects the same day in Studio. This is a presentation rule, not a threshold for adequate thought or prompt quality. A loading, disabled, disconnected or failed read has its own explicit message rather than introductory copy. Previous-day controls provide a recap for the morning and dates within retention. No additional daemon, timer, external provider or inference schedule is added. Vernier and capture rest during system sleep; after wake, history that the provider saved can fill in. This does not observe sleep or establish what happened while away from the machine.

The projection uses up to 4,000 dated messages from the day, clipped to 4,096 characters each, from the SQLite archive rather than its 300-message resident preview. A bounded preceding message preserves the link when the first reply crosses midnight. Unknown source times stay unassigned; observation time never moves an old message into today. Caps, clipping and incomplete history are disclosed. A busy day beyond the cap is a partial recent window.

Calendar days use the current local time zone and respect daylight-saving changes. A check-in's date key includes its time zone. Changing zones can therefore expose a separate check-in for the same printed date.

Schema v6 adds a source-time index and a separate daily-reflection table, preserving existing sessions, messages, notes and readings. Counts are recomputed in memory. Check-ins are included in local export, age out with retention, and are removed by conversation-memory erasure and full deletion. In-flight results are invalidated on erasure; a generation guard prevents an old check-in save from resurrecting after erasure.

This is a first descriptive daily recap. Validated prompt-quality scores, task/subfield percentages, learning gains, independently demonstrated understanding, all-day cognitive-health measurements and cross-tool coverage are not implemented.


## Two layers, explained in the screen — 0.12.2

**How Vernier reads your work** explains that daily counts use wording rules while contextual conversation review is separate. It reports the current review mode and the latest available saved review time, explicitly warning that the review may belong to another day or conversation. The existing local reader, prompt, schedule and schema are unchanged. There is no new cognitive or prompt-quality score.

The sidebar names the capture state, says whether saved chats or metadata are being collected, and opens connection settings. Running in the background means Vernier stays open while the Mac is awake; it rests during sleep. Open at login means macOS starts it at sign-in, not that it runs while the machine is off.


## A useful compact view — 0.12.3

The menu-bar panel now pairs a pattern with its source: **what you asked, when, and what AI replied**. The generic reflection box has been replaced by short, clearly attributed excerpts and **Open this exchange**. A build claim or success report stays visibly an AI reply; the panel does not certify an outcome. If no following reply exists in the loaded day, it says that rather than borrowing an earlier reply or guessing. The selected request comes from the stated continuation stretch, repair pattern or most frequent meaningful wording category (ties prefer check requests). Counts themselves are unchanged.

Responses come only from the immediately following agent stretch in the same loaded conversation/day. A final-answer message is preferred; otherwise the first visible reply is used. Consecutive human messages before that stretch can share its response. The excerpt may not answer the request and source timing/order can be approximate. Replies after midnight, outside the day cap or not yet synced may be absent. The UI says **some history is missing** in plain words when coverage is limited.

The source card selects the displayed day (including yesterday’s morning fallback), then focuses its own saved request in the conversation map. It rejects a source card no longer present in the current compact report. The footer still opens the named day’s full recap. No inference call, capture source, database table or consent change is added.


## Reach it without the dashboard

**Control–Option–Command–V (⌃⌥⌘V)** opens the compact menu-bar recap from another app while Vernier is running. It presents the recap instead of toggling it closed if already visible. The existing footer opens the named day’s full recap; its source card opens its own exchange. Capture Pause is independent. The expanded floating pill now names the day and the same brief pattern (for example, “3 check requests”). Pause, rest, missing consent and connection errors take priority over cached recap text. The idle circle stays small.

The shortcut uses the macOS Carbon hot-key API to register one combination, with exclusive registration to catch collisions with another app. It does not monitor general typing or request Accessibility permission. It unregisters at Quit. Isolated state checks, model probes and showcase rendering do not register it. If registration fails, the app shows a message in its residency/connection settings. The shortcut hint is visible in the compact footer and the native app menu.


## How a reply enters one box

These boxes do not use the local language model. After source-date, speaker and attribution guards, the first matching wording rule wins: personal attempt → question/explanation/check → condition/choice → brief continuation → unclear. For example, “I tested the import” is a self-reported attempt; “why does this happen?” is a check/explanation request; “keep it offline” is direction; “go ahead” can be continuation. A mixed request such as “keep it offline and explain the tradeoff” can land in Asked to check because that rule runs earlier. The single category does not capture everything in the message. Negated checks, brief generic repair requests, copied text, clipped records and clarification answers have separate guards. Open **Why this was counted** for the actual rule and source wording.

In 0.13.2 disclosure headers are full-width buttons with a 44-point minimum height and visible Show/Hide text. The dashboard accepts the first mouse click on returning to its window. Across your work retains its expansion during daily projection refreshes and resets on day selection or erasure. Hidden/state checks do not establish physical mouse delivery on every Mac.
