# Read a session, recover the thread

Choose a piece of work you want to revisit: a feature, bug or decision. In Overview, select its saved Codex conversation. One conversation can contain several tasks; Vernier does not know their boundaries automatically.

## Start with a reading you can challenge

Version 0.10 opens with a working interpretation of the latest saved human request. It separates:

- **The account:** a tentative description of the contribution in that message. You can delegate execution while choosing a boundary or asking for evidence.
- **The sources:** literal saved excerpts, labeled by speaker and known text reuse. Read original opens the exact canonical message by ID.
- **Another possible reading:** a reminder that the same words can reflect different circumstances.
- **Still unknown:** what the record cannot establish, such as whether a requested test passed or whether you reviewed the result yourself.

The experimental local model can get the action wrong. Source validation checks that references exist; it does not establish that the interpretation is correct. None of the tested configurations met the release's interpretation-quality gate. When no reading is available, the source reader and map still work.

## Follow a concrete exchange

The public showcase invents a CSV importer:

1. You require repeat imports without duplicate contacts.
2. The agent reports an implementation. You try again and report duplicates.
3. After another update and a build claim, you ask for repeat-import contact counts.
4. The agent reports zero new contacts, but says blank emails remain unchecked.
5. You ask for the blank-email case before shipping.

![Invented blank-email request, agent report and unresolved fact](images/overview.png)

The last request both leaves execution to the agent and names a check. It does not show that the check passed. An agent's result report and your own observation remain different evidence. Nothing here establishes that you lost control, understood the implementation or should have done the test without AI.

## Inspect the surrounding exchange

Use **See the surrounding exchange** to open the map at the request behind the reading. Green points represent user-side groups; purple points represent contiguous agent reply stretches, including progress updates. Select a point to compare it with the preceding group. Read source opens its exact original record.

![Synthetic source comparison in the conversation map](images/session-map.png)

The curve follows reading order. Its height identifies the speaker, not attention, time, strain or understanding. Unknown source times can make ordering approximate. Follow-up counts include corrections, new requirements, verification requests and simple continuations; they do not grade those acts. The map loads at most 500 saved messages, while Memory can search the older retained archive. Expand message coverage to see the limits.

## Add what the record misses

If the reading misrepresents your situation, use **Add my perspective**. For example: “I had already tested the normal case locally; I asked the agent to cover blank emails.” The editor names its target request and keeps that target if you select another reading or a background review arrives. The saved report stays separately labeled as yours and refers to that specific request and reading. Erasing or invalidating its parent reading also removes that attached report; use your notes/export for material you need to retain independently. It does not become proof of independent comprehension or an explanation for unrelated later messages.

Saving your perspective can trigger another local review when analysis and collection are enabled and not paused. **How this account has changed** opens earlier readings; **Return to latest account** restores the current one. **Revisit with latest evidence** reviews changed input; unchanged evidence and engine reuse the existing account. **Stop review** cancels pending persistence without stopping collection.

## Keep collection separate from inference

The floating circle controls capture. Its Pause button changes capture in place; the separate arrow opens the dashboard. Closing the dashboard leaves the app resident. The circle is not a comprehension or approval badge.

In the local reasoning disclosure, choose an experimental provider and use **Check local engine**. Manual review requires local analysis, Codex and conversation memory to be enabled, with collection unpaused. **Revisit changed work automatically** is a separate choice, initially off. When enabled, automatic inference waits for quiet, runs serially at most once per five minutes and rests in Low Power Mode. Collection and the map do not require a model to stay loaded.

## Choose one question the evidence could settle

For the invented importer, compare expected and observed contact counts using the same input twice, including the blank-email case. For your feature, identify the concrete requirement, the available result and the missing check. Vernier does not execute that check or verify the agent's work for you.

Today the source is saved Codex history from Conductor workspaces. Vernier cannot establish what you read or checked elsewhere. Short prompts and repeated questions can be appropriate. Daily fatigue, loss of ability, independent recoverability and the effects of Vernier's own interventions need other evidence. See the [reasoning method](REASONING.md), [model results](MODEL_EVALUATION.md) and [research framework](RESEARCH.md).
