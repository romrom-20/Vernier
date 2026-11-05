# How Vernier reads and remembers a conversation

Status: `work-15` is installed locally after passing its bounded source, storage
and model checks. This change uses the existing local model and
saved archive. It adds recall within a conversation and a casebook of possible
links across conversations in the same workspace.

## Three different things called memory

The **archive** contains the original saved conversation messages that the owner
has consented to capture. It lives in the existing local database and follows
its existing retention and erasure behavior.

**Recall** is a small selection of original earlier excerpts. Each excerpt keeps
its message identity, speaker, date when available, exact wording and a
fingerprint of the original. The selection is a possible source of context,
not a list of current requirements or independently verified events.

A **reading** is the model's tentative interpretation of a current question,
goal, reported outcome and useful next check. It can be wrong. An earlier model
reading remains an earlier hypothesis; repeating it does not turn it into fact.

No model weights are updated by saving a conversation, retrieving an excerpt,
or storing a reading. Each review explicitly constructs the context it sends to
the local model. Longer memory here comes from local records and retrieval.

## What happens during a review

1. **Find the current human message.** A long stream of AI progress updates must
   not replace the latest actual request. Saved app-injected context is filtered
   out of that choice. The canonical latest record is retained separately so a
   new arrival cannot make an in-flight review look current.
2. **Keep recent context.** Preserve recent human contributions, the preceding
   AI proposal, relevant earlier cited sources and the opening request. The
   ordinary primary packet stays bounded, rather than sending the entire archive.
3. **Look back through earlier statements.** Search up to 240 recent human-role
   records from this conversation, using up to the first 8,192 visible characters
   per record. Shared words such as “export,” “shortcut” and “keyboard” rank
   candidates. An explicit reminder request can retrieve earlier statements even
   with little shared wording. These are limited rules, not a learned semantic
   search model.
4. **Look for possible later changes.** Words such as “withdraw,” “instead” and
   “no longer” can bring a later statement alongside the earlier one even when it
   shares no topic words. This does not prove which earlier statement it changes.
   When room permits, include the original AI reply from the same earlier turn,
   with its speaker retained.
5. **Fit a few excerpts into the packet.** At most four recalled sources, each
   at most 360 characters, replace ordinary filler within the primary source
   budget. The normal primary bound remains eighteen sources. Separate existing
   related-conversation candidates and human perspectives have their own bounds.
6. **Ask the local model for a reading.** The model receives the current human
   anchor, bounded source quotations, source roles and explicit historical scope.
   It selects supplied witness identifiers; the app copies the saved wording.
7. **Challenge and validate it.** The same model checks its proposed account.
   Swift code checks source identity, quotation, ownership, temporal scope and
   result evidence. Same-model agreement is not independent verification.
8. **Save the reading with its receipts.** The owner can inspect “Earlier context
   considered” and open each original message. A withheld model reading can still
   retain that source trail without asserting the interpretation.

## Old information is not new authority

Suppose the earlier messages say:

> Human: “Keep the recordings on this machine.”
>
> Later human: “I withdraw that restriction.”

Finding the first message does not establish that the restriction is still
active. Recall attempts to retain possible revisions, and its coverage metadata
identifies omitted human context. A direction cue cannot rely on a recalled
boundary or on a gap that hides possible human updates. With recall present,
proposed comparisons also need limited topic overlap; this is a guard, not a
complete test of semantic compatibility.

Similarly, an old AI statement “I tested it and one panel opened” does not
establish that today's changed version passed. Recalled sources are excluded
from evidence of a new reported outcome. The original statement remains visible
as history. A genuine new human test report can still supply new evidence.

When the current request explicitly asks about an earlier requirement or choice,
the reader can display the cited statement under **Earlier statement you asked
about**, with an **Earlier:** prefix. A reminder can also quote one unambiguous
literal earlier “I choose…” statement from the selected human excerpts. This is
source retrieval, not proof of a current choice, permission to act or private
understanding. Multiple ambiguous declarations are not resolved by guessing.

If a model direction guess is explicitly rejected, one ordinary reading and
challenge can be tried instead, only for a recall context and within the bounded
fallback budget. The rejected frame and challenge are retained in probe reports.
A rejected direction guess must not force a warning to survive.

## Corrections, erasure and local scope

The fingerprint covers the full original message, even when only one small
excerpt is shown. Before saving, the store checks selected originals and
recomputes the bounded human index. An edited but omitted correction can reject
an in-flight result even if the latest message and message count are unchanged.

Indexed human messages are dependencies of the saved reading, alongside its
selected sources. Editing or deleting them invalidates the dependent reading
through the existing database triggers. Erasing conversation memory also erases
the stored recall and derived readings. No additional database schema, service,
capture source or retention extension is required.

The implementation also adds a read-only casebook across conversations, described
below. Neither type of recall establishes a shared task or merges projects into
a single personal profile. Personal-assistant examples can test retrieval
separately, but they do not validate the coding reader for bookings, messaging
or other personal actions.

The search window and excerpts are incomplete. It can miss a very old decision,
a correction phrased differently, a statement beyond the text budget, or a
relevant source it ranks poorly. The owner can inspect original messages and
correct an interpretation; no absence of a transcript report proves that an
outside review or action did not happen.

## A casebook across conversations

When a conversation is selected, Vernier considers the latest saved reading from
up to 60 other conversations **in the same workspace**. It compares the current
request's words with the earlier goal and original source excerpts. Two shared
nontrivial words are required, and only the two strongest candidates are shown.
These simple wording rules can miss a paraphrase or connect unrelated tasks.

Each candidate shows its earlier model goal as an **Earlier reading**, up to two
verified original excerpts, the words that linked it, and the owner's latest
saved perspective when present. A newer perspective is marked explicitly. If the
old source says “SQLite” and the newer perspective says “I changed to Postgres,”
both remain visible with their roles. The app does not silently rewrite the
history or treat the older choice as current permission.

This casebook is rebuilt from retained records, without another model call or
another stored summary. Saving a model interpretation does not recursively
schedule another interpretation of its summary. Original message fingerprints
are checked; changed sources invalidate dependent readings. Changing selection
or erasing memory clears the casebook and invalidates pending lookups. Capture,
analysis and pause controls also gate its display.

The existing model-facing retrieval of other conversations remains unconfirmed
source context. A conversation with any saved owner perspective is now excluded
from that older model-facing retrieval: it cannot provide stale raw excerpts
without its separately stored correction. Its source and correction can still
appear together in the new casebook. The casebook itself is for inspection; its
goal summaries are not fed back into the model as established facts.

There is no durable cross-workspace preference profile, automatic task merger,
semantic relationship model, or autonomous memory training in this version.

## What improved, and what failed

The selected method matched **6/8** reserved invented long-conversation outcomes,
compared with **3/8** without earlier recall. All three baseline successes were
preserved. The existing sixty-case regression matched **51/60**, preserving all
51 previously passing examples. Those reviews completed without generation
errors. The selected long-history cases added no unsupported direction cues and
did not promote historical test claims into current results.

Development went from **4/8** without recall to **7/8** for the selected method.
Two earlier drafts remained at 4/8; one also raised a false direction cue by
comparing an unrelated formatting requirement with a service proposal. Those
drafts were rejected. The selected method labels requested historical statements,
uses a limited topic guard, and allows one bounded normal-reading fallback after
an explicitly rejected direction guess.

Two reserved cases still fail. One produces a generic format explanation without
retaining the chosen NDJSON format. Another loses the revised plan and is
withheld. These outcomes were inspected after selection and did not select a
further model/prompt change. All inspected examples now serve as regressions.

The score checks focus, result status and shallow goal terms; it is not full
semantic accuracy. Inputs and labels are agent-authored, invented and structurally
related. Manual review also finds generic next checks in some passing cases;
passing the composite score does not guarantee an actionable explanation.
Historical quote display and the literal-choice reminder are app-level
source retrieval, not proof that the neural model acquired better reasoning.
The casebook passes source/scope/correction/erasure checks, but has no claimed
cross-conversation semantic-accuracy score. Natural use, multilingual memory,
independent human evaluation and personal-assistant integration remain unproven.

## Verification and source path

Background checks use invented data, isolated preferences and offscreen renders.
Model evaluations use separate invented long histories through the actual local
archive, context selection, read, challenge and source validator. Weights and
owner settings remain separate from those tests. Native mouse/focus behavior
requires a separate agreed test session.

The final background run passes all 40 core check groups, isolated model-state
checks and offscreen renders. XCTest is skipped because full Xcode is not
selected. The final app adds casebook/UI/state code after candidate selection;
its exported read/challenge packets and schemas match the qualified candidate
on all 76 original/development/validation examples. The inference and validation
source files are unchanged. This parity check makes no inference calls and is
not another stochastic model run. Installed binary and prompt resource match
the final frozen app, and the original model manifest and settings are preserved.

The implementation runs through [DecisionStore](../Sources/VernierCore/Storage/DecisionStore.swift),
[ConversationRecall](../Sources/VernierCore/ConversationRecall.swift),
[DecisionContext](../Sources/VernierCore/DecisionMemory.swift),
[WorkWitnessPacket](../Sources/VernierCore/WorkWitnesses.swift),
[DecisionGenerator](../Sources/VernierApp/App/DecisionGenerator.swift),
[WorkReading](../Sources/VernierCore/WorkReading.swift) and
[ConversationRecallView](../Sources/VernierApp/UI/ConversationRecallView.swift).
The cross-conversation path also uses
[RelatedConversationMemory](../Sources/VernierCore/RelatedConversationMemory.swift),
[DecisionModel](../Sources/VernierApp/App/DecisionModel.swift) and
[RelatedConversationMemoryView](../Sources/VernierApp/UI/RelatedConversationMemoryView.swift).

The local Floorplan's memory flow explains those connections in plain language.
It contains source code and invented examples, never the owner's private archive.

## Repeat the invented memory comparison

The public eight-case validation fixture is now an inspected regression, not a
fresh test. These optional serial probes contact only the selected local Ollama
model using invented temporary archives. They do not open a personal database,
change preferences or activate a window. Model inference still consumes local
CPU/GPU and memory; it is separate from normal background verification.

```sh
./Scripts/verify-background.sh
run_dir="$(mktemp -d "$PWD/.context/recall-comparison.XXXXXX")"
ditto build/Vernier.app "$run_dir/Reader.app"
nice -n 10 "$run_dir/Reader.app/Contents/MacOS/Vernier" \
  --work-model-probe --without-earlier-recall --model gemma4:e2b-it-qat \
  --cases Tests/Fixtures/work-recall-validation.json \
  --report "$run_dir/without-recall.json"
nice -n 10 "$run_dir/Reader.app/Contents/MacOS/Vernier" \
  --work-model-probe --model gemma4:e2b-it-qat \
  --cases Tests/Fixtures/work-recall-validation.json \
  --report "$run_dir/with-recall.json"
```

The model must already be available in Ollama. Keep each copied bundle immutable
through its comparison. Scores can vary across runs; inspect the raw proposals,
source quotations, challenges and failures. An export-only probe can compare
request packets without inference. See [model status](MODEL_STATUS.md) before
enabling any experimental model.
