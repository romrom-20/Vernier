# Measurement framework and proposed experiments

**Status: research design, not implemented results.** The current release implements a subset of passive history capture and self-report. It has no capability probe engine, intervention system, experiment enrollment or validated predictor.

Local observer experiments and their negative results are documented separately in [source-fact supervision](MODEL_SOURCE_SUPERVISION.md). Those experiments do not implement or validate the measurement framework below. The compact day overview describes saved contribution patterns and does not turn them into an agency or ability score.

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

## Verified sources and what we take from them

[Weight-space programming — Takehi and colleagues](https://rikiyat.github.io/blog/weight-space-programming/) is an experimental blog report about models reading and editing neural-network weights. It reports improvements for some targeted failures, but not meaningful improvement of ordinary arithmetic/reasoning errors in its small Gemma experiment. It does not validate a measure of human strain or promise that our Gemma model can repair itself. We use its hypothesis → targeted change → behavioral evaluation approach. The running app does not edit weights or train on private sessions. A separate [supervised adapter trial](MODEL_TRAINING.md) changed learned weights on invented data; it did not reproduce the paper’s direct-edit method.

[NASA Task Load Index](https://www.nasa.gov/human-systems-integration-division/nasa-task-load-index-tlx/) measures **subjective workload** across mental demand, physical demand, time pressure, performance, effort and frustration. A future opt-in workload check-in could follow its actual protocol. The current clarity/energy check-in is not NASA-TLX and must not inherit its validity. Workload and cognitive dysfunction are different constructs.

[Lee and colleagues, CHI 2025](https://www.microsoft.com/en-us/research/publication/the-impact-of-generative-ai-on-critical-thinking-self-reported-reductions-in-cognitive-effort-and-confidence-effects-from-a-survey-of-knowledge-workers/) surveyed knowledge workers about effort and confidence. Its self-reported associations and discussion of verification/integration motivate attention to the work surrounding a generated answer. They cannot establish cognitive decline or an individual's effort from their chat trace.

[Risko and Gilbert, Cognitive Offloading (2016)](https://doi.org/10.1016/j.tics.2016.07.002) reviews how external actions can reduce cognitive demands. Delegation can be useful. A count of offloaded actions does not by itself establish harm; goals, context and independent outcomes matter.

[Anthropic's coding-skill experiment (2026)](https://www.anthropic.com/research/AI-assistance-coding-skills) studied developers learning an unfamiliar Python library, with a later quiz. It motivates measuring assisted completion separately from later independent understanding. Its qualitative interaction clusters are not causal evidence that more explanation requests improve learning, nor a calibrated classifier for our users. We have not reproduced the study.

[Basner and Dinges, PVT and sleep loss (2011)](https://pubmed.ncbi.nlm.nih.gov/21532951/) studied behavioral alertness in controlled sleep-loss experiments using a timed vigilance task. Such a test measures a different outcome from coding understanding. A casual click counter or short generic reaction game is not that validated protocol. No PVT, sleep measurement or clinical assessment is implemented in Vernier.

[Addy Osmani's cognitive-surrender essay](https://addyosmani.com/blog/cognitive-surrender/) remains a design influence about independent judgment, not a validation study for Vernier.

## Product decisions from this reading

**Implemented:** show a likely goal, distinguish who reported which outcome, expose the exact source and offer one task-specific checkpoint. Keep historical readings, deterministic observations and human self-reports separate. Never infer thought from a long prompt, map opening, short approval or missing review message.

**Proposed:** an occasional voluntary recovery exercise with a rubric fixed in advance: predict an edge case, explain one decision, find a failing part or make a small independent change. Track the actual attempt and its conditions; a request for an explanation is not a passed exercise. Workload self-report would be separate from performance. These require their own consent and validation, not a universal strain number added to current logs.

**Unvalidated:** whether these readings improve oversight, whether a pattern predicts later recovery, and whether repeated use changes capability. The experiments above remain necessary. Public synthetic regression improvements do not answer those questions.

## Privacy and participation

Future probes and studies require a separate consent contract, local data/retention design, explicit assistance conditions and a withdrawal path. No research upload, random assignment, grading call or extra observation is enabled by this document. Keep synthetic public examples separate from private participant records. Any future export of study data needs its own clearly scoped authorization.


A later [direct-head experiment](DIRECT_WEIGHT_EDIT.md) used actual activation/weight inspection and a gradient-free attention-output edit on the separate Gemma copy. Its controls did not establish the proposed diagnosis and its quality gate failed. It is not a reproduction of the paper's published Qwen intervention and is not active in Vernier.


The subsequent [weight-column projection approach](WEIGHT_SPACE_APPROACH.md) inspected actual model features and weights, verified native Boolean-token replay, and tested a small direct projection against conversion-only, random and reversed controls. It observed a limited 11/32 to 13/32 gain on a new invented proposal test, below its declared gate. This does not validate human-agency measurement or reproduce the paper's published benchmark.

The later [semantic weight study](SEMANTIC_WEIGHT_STUDY.md) found no gain from a source-derived feature edit and regressions from the earlier Boolean patch on a new semantic task. This limits the interpretation of the older small gain; none of these studies reproduces the paper’s result or validates human-agency inference.

The [research-guided reasoning comparison](OBSERVER_REASONING_RESEARCH.md) reviews official Gemma thinking support, rationale supervision, small-model limits, self-correction and REdit. Testing native thinking plus a checklist improved category recall but worsened semantic judgments and added unsupported acts. The method remains isolated; the proposed short evidence-supervision training has not been run.
