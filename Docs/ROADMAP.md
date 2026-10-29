# Current daily baseline — 0.12

Daily and compact recaps now aggregate saved follow-up wording across connected workspaces, preserve source drill-downs and support past days and optional personal check-ins. The remaining goal is task-aware, contextual interpretation of delegation and outcomes: connected task boundaries, useful coding subfields, validated prompt-quality feedback and evidence of what a person can explain or recover. The current percentages do not measure those capabilities. [Implemented definitions](DAILY_RECAP.md).

---

# Roadmap: from Mac utility to agency instrument

This is a direction with evidence gates, not a release schedule. The three measurement layers remain separate throughout: passive observations, consented active probes and longitudinal experiments.

## 1. A dependable Mac utility — implemented foundation

- [x] Native menu bar, Studio and optional nonactivating circle/pill.
- [x] Stable hover, direct capture controls, explicit dashboard action and exclusive surface routing.
- [x] Read-only local Codex history scoped to Conductor workspaces.
- [x] Separate metadata/content consent and in-flight revocation gate.
- [x] SQLite migrations, incremental backfill, retention, search, export and deletion.
- [x] Source coverage, bounded prompt trail and user-authored review.
- [x] Isolated synthetic showcase, shared core checks and native regressions.

Reliability work remains: manual accessibility and mouse testing, real multi-display/full-screen/sleep/login checks, energy measurements and notarized distribution. See [validation](VALIDATION.md).

## 2. An evidence-grounded personal agency ledger — initial interpretation implemented

- [x] Human-facing exchange readings: requests for evidence/explanation, explicit constraints, reported recurring issues and continuation, with literal sources and an explanation of possible significance.
- [x] Recent-work source projection across workspaces: transparent wording cues, exact examples, agent-last and failed-turn threads with bounded coverage.
- [x] Bounded, on-device session interpretation with exact source references, visible coverage and user dismissal.
- [ ] Define shared task/decision boundaries and provenance contracts before cross-session detection.
- [ ] Link initial intent, agent proposals, human interventions, available outcome evidence and follow-up across sessions.
- [ ] Build personal recaps of supported changes in delegation, repair, scope and verification, with explicit task and coverage context.
- [ ] Establish a person-specific observational baseline before describing a pattern as unusual for them.
- [ ] Evaluate context-aware guidance that helps resolve one concrete uncertainty without routinely interrupting work.
- [x] Keep model interpretation, literal agent/user sources and explicit human perspectives distinct and correctable. Artifact verification remains limited to available recorded evidence.
- [x] Label excerpt limits, clipping and missing source times; never infer absent review from missing evidence.
- [ ] Evaluate whether a review helps users reconstruct or recover a concrete piece of work.
- [x] Initial local proposer/critic loop uses bounded context, known text reuse, original sources, unknowns and revision history; accuracy still needs broader evaluation.

**Gate:** users recognize the record as accurate and can resolve a concrete open question; attribution errors and false positives are documented.

### Implemented next step: revisable local readings

Version 0.10 adds a local proposer/challenge/source-check loop with immutable revisions and separate human perspectives. Bounded same-workspace retrieval supplies possible related context without asserting task identity. This is an initial reasoning mechanism, not a validated measure of agency. [Behavior and limits](REASONING.md).

### Next product milestone: a useful personal recap

The next substantial step is to connect a feature or decision across sessions. A person should be able to see the original goal, a returned requirement, the evidence offered since then and one unresolved check. A daily or weekly view could then describe supported interaction patterns in that context.

This is not a daily cognitive score. Before it can be useful, task boundaries, source coverage, attribution, timing and ambiguous follow-ups need to be handled explicitly. Personal recaps and adaptive guidance remain planned. Their first acceptance test is whether a builder recognizes the account as accurate and can use it to settle a concrete question; capability claims require the separate work below.

## 3. Narrow independent-capability probes — proposed

- [ ] Design separately consented, voluntary sandbox exercises for prediction, explanation, verification, challenge and independent recovery.
- [ ] Define domain, task difficulty, baseline familiarity, assistance conditions and rubrics.
- [ ] Distinguish assisted task performance from subsequent unaided performance.
- [ ] Establish scoring reliability and usefulness before presenting a result as a capability measure.

**Gate:** an attempt has an interpretable narrow outcome and a defensible rubric. A permanent or domain-general change is not inferred from it.

## 4. Validate the instrumentation — proposed

- [ ] Compare richer interaction features against a baseline of task difficulty, prior skill and AI-usage counts.
- [ ] Use held-out outcomes and participant/project-aware splits to avoid leakage.
- [ ] Prespecify meaningful improvements, uncertainty and failure conditions.
- [ ] Report negative results and narrow the product’s claims when the evidence warrants it.

**Gate:** interaction history adds practically useful out-of-sample predictive value. If it does not, focus on the demonstrated recovery/oversight value instead.

## 5. Test whether interventions help — proposed

- [ ] Randomize a small consented sandbox intervention while holding substantive AI output fixed in the primary comparison.
- [ ] Measure accepting correct and rejecting incorrect advice separately from verification language.
- [ ] Assess later independent performance and account for practice, carryover, exposure and attrition.
- [ ] Test deployment usefulness separately from laboratory validity.

**Gate:** an appropriately designed study supports the claimed effect. More visible verification or better AI output alone is not evidence of improved human capability.

## Coverage and trust

Configurable workspace roots, user-chosen project labels, additional source adapters and per-session historical import controls remain planned. Every source needs an explicit capability/consent contract. Broader observation is not automatically enabled by the research vision.

Employee monitoring, hidden screen capture, medical diagnosis and universal cognitive-decline claims are outside the project’s scope. There is no current agency, strain or readiness score.

See the [measurement framework and proposed experiments](RESEARCH.md).

## 0.11 checkpoint

Contextual goal/check readings, collapsed evidence, explicit automatic-review status and five narrow source-backed boundary-question families are implemented. Quiet cues and intentional-choice reports are available. Personal cognitive measurement, reliable general steering detection, broad cross-tool capture and a complete cross-session task graph remain unimplemented/unvalidated. The current small-model interpretation layer remains experimental.
