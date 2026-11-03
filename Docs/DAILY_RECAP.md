# Read the daily picture

The dashboard opens with category cards, the hourly chart and a reflection panel. Selecting a category or hour opens its matching saved replies. The contextual goal/outcome reading remains below this visual overview. The compact panel focuses on a current goal, reported evidence and one useful checkpoint, with exact sources available.

## Two category modes

**Default: wording categories.** These use local English rules, not the model. The first matching rule wins: personal attempt → question/check → condition/choice → continuation → unclear. Copied agent text, clipped messages, negated checks and clarification answers have separate guards. Mixed requests and implied intent can be missed. “Why this was counted” exposes the actual rule.

**Experimental model categories: off initially.** In Local model and review settings, this switch lets the selected local model interpret human replies using surrounding messages. It asks independently whether a reply requests execution, adds a requirement, requests evidence/explanation, or reports an actual attempt. Several acts can be retained. The app organizes the main role as report, direction, check, continuation; additional signals stay visible with the reply. The model chooses from exact human-source spans, a second pass challenges the acts, and the host checks source/actor validity. This is not independent semantic verification. The tested configurations did not meet the quality gate, so model categories do not replace the stable default automatically.

In experimental mode, unread or unsupported replies stay **Unclear / unread**. The screen shows interpretation coverage rather than silently filling gaps with rules. Each source explanation includes the model, review time, exact evidence and a wording-only comparison. Short approvals may be deliberate delegation; requests for an explanation do not establish understanding. [Evaluation and failures](MODEL_EVALUATION.md) · [Improvement design](MODEL_IMPROVEMENT.md).

## What the counts mean

Each item is one dated human follow-up after an agent reply in the same conversation. Multiple contributions in one provider turn count separately. Initial requests are outside this denominator. The main categories are mutually exclusive even when the model retains secondary signals. These are not task percentages, time spent thinking, learning scores or grades of human agency.

Asked AI to continue describes an execution/continuation request; Added direction describes a requirement, choice or correction; Asked to check describes evidence, explanation or verification requests; Reported a result describes a self-reported attempt/observation. The app does not verify the report. Unclear sources include unknown meaning, known copied text, clipped records and—in experimental mode—unread or withheld interpretations.

The hour chart counts replies, not time on task or fatigue. Category/hour selections open exact matching sources; repeated selections navigate again. Selecting an hour clears the category filter. Changing day or erasing clears the filters. Gaps between active hours are omitted. A continuation stretch does not prove a shared task or missing thought; brief repair wording does not prove the same bug returned.

## Review coverage and history

Automatic review waits for 15 seconds of quiet and starts at most once per two minutes, one conversation at a time. It rests during Pause, sleep/session suspension and Low Power Mode. When experimental categories are enabled, each cycle attempts up to four unread replies in its bounded conversation packet, then catches up within that packet. It does not promise to classify the entire archive. Turning the experiment off stops its extra inference while preserving capture consent and normal goal readings.

Daily source loading is bounded to 4,000 messages and 4,096 characters each; source dates, not observation dates, determine the day. Undated messages stay unassigned. Model labels use at most 200 related saved revisions and bounded per-conversation history. Editing a dependency invalidates its saved interpretations. A later classification can appear on its message's original day, with the later review time visible.

The contextual goal card uses a separate rule: up to 200 readings created on the selected day, latest per active conversation. Historical goal cards describe what was saved then; they are not backdated reconstructions. That is different from classifying the wording of an old reply later. Neither view is an exhaustive task ledger.

The compact panel can retain yesterday's fuller recap while today begins, names the date and opens that date. A fresh contextual reading of delegated activity can take priority with zero follow-up replies. Its source button opens the exact reading; its footer opens the full recap. Agent replies are attributed reports, not verified results.

## Your check-in and direct access

Optional clarity/energy check-ins are human reports, separate from observation and model interpretation. They are not a validated workload or cognitive-health score. All derived records remain subject to local retention, export and erasure. SQLite stays schema v6; the experiment adds optional payload fields rather than another capture source.

Control–Option–Command–V opens the compact recap while Vernier runs. The app icon also opens that compact entry; its footer opens the dashboard. The shortcut registers only that combination and does not monitor general typing. The app rests when the Mac sleeps; it does not measure sleep.

Disclosure headers are full-width Show/Hide buttons. Across your work stays expanded through projection refreshes and resets on day selection or erasure. Physical focus and mouse delivery require an owner or separate-desktop check; offscreen previews alone do not establish them.
