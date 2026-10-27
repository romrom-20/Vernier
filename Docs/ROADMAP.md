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

- [x] Bounded, on-device session interpretation with exact source references, visible coverage and user dismissal.
- [ ] Define shared task/decision boundaries and provenance contracts before cross-session detection.
- [ ] Link initial intent, agent proposals, human interventions, evidence and follow-up across sessions.
- [ ] Keep agent claims, observed artifacts and user reports distinct and correctable.
- [x] Label excerpt limits, clipping and missing source times; never infer absent review from missing evidence.
- [ ] Evaluate whether a review helps users reconstruct or recover a concrete piece of work.
- [ ] Establish context before interpreting repeated repair/continuation requests.

**Gate:** users recognize the record as accurate and can resolve a concrete open question; attribution errors and false positives are documented.

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
