# Current model and memory status

Updated 5 November 2026. This page describes the current source branch; a source
update is separate from a packaged Mac release or a model-weight release.

## What is active

The latest measured local installation uses the original **`gemma4:e2b-it-qat`**
through Ollama on loopback, with reader protocol **`work-15`**. The memory
improvement changes retrieval and source validation; it does not modify Gemma's
weights. A fresh installation keeps local analysis off and initially selects the
Apple engine. Existing installations retain their saved engine and consent.

The contextual reader proposes a goal, reported outcome and next check. Another
pass of the same model challenges it, and Swift checks source support. The
category boxes are a separate feature: **wording rules remain the default**.
Experimental model categories remain off by default.

Memory has two bounded paths:

- **Within one conversation:** select up to four historical excerpts from a
  search of up to 240 human-role records. Preserve exact wording, source links,
  speaker, coverage and possible later updates. Historical reports cannot supply
  evidence of a new result.
- **Across conversations:** show up to two possible links among sixty earlier
  reviewed conversations in the same workspace, with original excerpts and the
  latest saved owner perspective. This casebook adds no inference, automatic
  task merging or cross-workspace preference profile.

The archive, recalled excerpts and tentative model readings remain distinct.
Existing retention, export and erasure apply. Read the
[memory walkthrough](CONVERSATION_MEMORY.md) for budgets and source checks.

## What the tests establish

On eight reserved invented long histories, complete composite matches improve
**3/8 without recall to 6/8 with recall**, preserving all three baseline successes.
The existing regression remains **51/60**, retaining all 51 previous successes.
All selected long-history reviews complete without generation errors; no old
test claim becomes a new result and no unsupported direction cue is added in
those cases. Two cases still fail, and some passing next checks remain generic.

The score uses focus, result status and shallow goal terms. Inputs and labels are
agent-authored, invented and structurally related. This is not an estimate of
natural-conversation accuracy, broad reasoning, personal-assistant readiness or
the owner's judgment. Quoting a historical choice is app-level source retrieval,
not proof of a newly learned neural capability.

Forty shared core check groups, isolated app-state checks and offscreen synthetic
renders pass. Local XCTest is skipped without full Xcode; CI uses Xcode. The
cross-conversation casebook has source, workspace, correction and erasure checks,
with no claimed semantic-accuracy score. Physical mouse/focus behavior requires
a separate agreed test session. See [validation](VALIDATION.md) and
[detailed model evaluation](MODEL_EVALUATION.md).

## What remains experimental

Separate local studies actually inspected activations, edited numerical weights,
trained adapters, tested native thinking and evaluated larger models. They did
not qualify for live model selection. A narrow score gain did not justify
deployment; some edits worsened transfer or added unsupported claims.

The public repository contains source, plans, invented fixtures and reports:

- [Learned adapter trial](MODEL_TRAINING.md)
- [Direct component edit](DIRECT_WEIGHT_EDIT.md) and
  [weight-space projection](WEIGHT_SPACE_APPROACH.md)
- [Semantic transfer failure](SEMANTIC_WEIGHT_STUDY.md)
- [Thinking/checklist study](OBSERVER_REASONING_RESEARCH.md)
- [Source-fact supervision](MODEL_SOURCE_SUPERVISION.md)
- [Coding/personal profiles and larger-model tests](DOMAIN_READER.md)

These are dated experiment records, not instructions to enable their candidates.
Model files, trained adapters, numerical patches, raw local runs and personal
records are excluded from GitHub. No automatic private-session training, model
upload or hosted-inference fallback is enabled.

## How updates should be published

1. Record the base model identity, reader version and planned comparison before
   inspecting new outcomes. Keep a candidate under a distinct local name and
   preserve the original model/settings for rollback.
2. Use invented development data to choose a method, then freeze it. Evaluate
   new cases plus previously passing regressions through the actual runtime,
   critic and source validator. Check unsupported claims and concrete next-step
   quality, separately for coding and personal-assistant tasks.
3. Keep failed candidates disabled. Inspected test cases become regressions;
   they cannot select another change and still count as fresh validation.
4. Publish the source, tests, plans, honest results and current status in a pull
   request. Run background verification, publication checks, secret scanning and
   documentation-link checks on the exact proposed source. Review synthetic
   images and pin their hashes. Never attach personal sessions or model files.
5. Change a selected model only after its declared gates and real runtime checks
   pass. Report remaining uncertainty, resource cost and rollback. Publishing
   source documentation alone does not promote a model or produce a notarized
   app release.

Use [the publication checklist](PUBLICATION.md) for GitHub changes and
[the improvement notes](MODEL_IMPROVEMENT.md) for the next evaluation.
