# Measurement framework and proposed experiments

**Status: research design, not implemented results.** The current release implements a subset of passive history capture and self-report. It has no capability probe engine, intervention system, experiment enrollment or validated predictor.

## The construct

Human agency in AI-mediated work includes setting goals, making context-appropriate delegation decisions, evaluating evidence, redirecting a process and recovering work when circumstances change. No single activity counter is assumed to measure it.

Independent recoverability is a narrow candidate construct: the ability to understand or take over a particular task or artifact without the original assistant. Specify the domain, difficulty, prior familiarity, permitted resources and scoring rule for every assessment.

## Keep three layers separate

### Passive signals: records of interaction

Candidate observations include delegation, corrections, approvals, rejections and inspection opportunities, only when a source exposes them and the user consents. Current Codex capture supports messages and limited agent activity metadata, not this entire observation vocabulary.

Record source provenance, actor attribution, source/observation time, coverage, missingness and possible app-injected context. A completed response is not verified success. An inspection opportunity is not comprehension. Missing review evidence is unknown.

### Active probes: performance on an attempt

Candidate sandbox exercises include predicting behavior, explaining a tradeoff, finding an error, checking a claim, modifying a small implementation or producing a recovery/handoff plan. Record the task/version, allowed assistance, conditions, rubric, response and scoring provenance separately from the interaction history.

A post-task unaided exercise asks a different question from assisted task success. Repeated matched exercises with suitable delays could investigate retention; one result cannot establish permanent change or transfer to unrelated domains.

### Longitudinal experiments: effects of use or intervention

Experiments need separately consented participation, a defined comparison, assignment and exposure records, suitable controls and later outcomes. Passive collection never constitutes study enrollment. Ordinary product use must remain available without participation.

Predictions from observed patterns do not establish causal effects. A study of one domain, participant group or task condition cannot establish universal cognitive decline.

## Four outcomes to distinguish

- **Before:** baseline independent capability and relevant familiarity.
- **During:** assisted performance, including what the AI made possible.
- **After:** independent prediction, explanation, modification or recovery under defined conditions.
- **Intervention effect:** differences attributable to Vernier rather than task selection, practice, changing AI output or prior skill.

Track these as separate outcomes rather than collapsing them into one score.

## Experiment A: does richer instrumentation add predictive value?

**Question:** Does consented interaction history predict independent understanding or recovery better than task difficulty, prior skill and AI-usage counts?

1. Define narrow tasks and an independent outcome rubric before collecting evaluation outcomes.
2. Establish a baseline model from task difficulty, prior skill/familiarity and simple usage counts.
3. Compare it with a model that adds explicitly defined interaction features. Do not use probe answers or future outcomes as predictor inputs.
4. Evaluate on held-out participants/projects or an appropriate grouped temporal split. Repeated sessions from one person must not leak across a supposedly independent evaluation.
5. Prespecify meaningful improvement criteria, uncertainty estimates, missing-data handling and sample-size rationale. Inspect calibration and errors across relevant task/skill groups.
6. Publish negative and inconclusive results alongside useful findings, without retroactively redefining success.

**Failure condition:** If richer signals add no practically useful predictive value, narrow the product’s claims to capabilities that are supported, such as memory, recovery support and oversight. A null result is not proof that delegation has no effect; it constrains this measurement approach under the tested conditions.

## Experiment B: does a reminder change judgment or only the trace?

Use consented sandbox tasks with recommendations whose correctness can be defensibly assessed. Randomize a small wording/interface intervention and keep substantive AI output fixed in the primary comparison. Include both correct and incorrect advice.

Measure acceptance of correct advice and rejection of incorrect advice separately. Collect observable verification behavior as another outcome, then assess later independent performance with a matched exercise. More verification-related messages alone do not establish improved judgment.

An optional, separately analyzed arm could allow normal AI responses to change. That tests the intervention’s combined effect on the human–AI system. It must not be interpreted as a human learning effect without additional evidence.

Account for exposure, noncompliance, practice effects, order/carryover and attrition. Preregister hypotheses and analysis before examining outcomes. Keep safety-critical decisions and essential review checks outside this sandbox manipulation.

## Experiment C: can independent recovery be measured usefully?

Offer an occasional voluntary exercise using a synthetic or explicitly consented project artifact. Do not disconnect real providers or withhold a person’s working tools.

Possible tasks include locating a failing subsystem, explaining an architectural tradeoff, making a small modification, recovering from artifacts or preparing a developer handoff. Compare equivalent conditions and use a rubric appropriate to the task. Record evaluator provenance; if model-assisted grading is explored, evaluate it against a defensible independent standard rather than treating it as truth.

Check whether the exercise helps a user locate a concrete gap and take an effective next step. Predictive validity, usefulness and causal improvement are distinct success criteria.

## Research provenance

The project brief includes references to studies about prompting and unaided code evolution, but does not include identifiable paper citations for those claims. Their participant counts, effect sizes and conclusions are not repeated as established evidence here. A primary-source bibliography should be verified before making empirical claims or designing around a particular reported result.

[Addy Osmani’s cognitive-surrender essay](https://addyosmani.com/blog/cognitive-surrender/) is a design influence about retaining independent judgment. It is not a measurement validation study for Vernier.

## Privacy and participation

Future probes and studies require a separate consent contract, local data/retention design, explicit assistance conditions and a withdrawal path. No research upload, random assignment, grading call or extra observation is enabled by this document. Keep synthetic public examples separate from private participant records. Any future export of study data needs its own clearly scoped authorization.
