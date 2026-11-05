# Current memory improvement — work-15, 2026-11-05

The installed improvement is source-linked context retrieval and a local
cross-conversation casebook. Original Gemma weights and category settings remain.
Two retrieval drafts failed development; one invented an unrelated direction
conflict and was rejected. The fixed third method matches 6/8 reserved long
histories versus 3/8 without recall, retaining all existing 51/60 successes.
This includes deterministic historical quotation; it is not a neural reasoning
or weight-training result. Two cases still miss important detail, and some
passing checks are generic. [Mechanism, evaluation and limits](CONVERSATION_MEMORY.md).

Next research should use newly authored naturalistic paraphrases and corrections,
require concrete acceptance checks, and keep coding and personal-assistant
validation separate. Do not select more changes using the inspected sixteen long
examples as if they were new validation. The casebook has integrity tests but no
claimed cross-thread semantic accuracy or automatic task/permission merging.

---

# Current reader improvement — 2026-11-05

`work-14` is installed with the original Gemma weights. Development moved from
failed broad extraction prompts to source-linked reports, preservation of cited
human goals and narrower recurrence admission. A matched host comparison preserves
all earlier successes; the final new goal screen still misses one of four cases.
No model upgrade qualifies. [Results and remaining uncertainty](DOMAIN_READER.md).

Future experiments must preserve each actor's evidence, distinguish first failures
from repeated reports and evaluate the actual read/critic/source-validation path.
A decreasing training loss, convincing intermediate explanation or a small passing
speaker screen cannot substitute for that path or for separately evaluated
personal-assistant conversations. Inspected cases remain regression material.
Keep experimental weights and prompt variants disabled until their own declared
quality and source-preservation checks pass.

---

# Improving the observer, with evidence

The observer should interpret human contributions in context and retain mixed signals. It should not learn private intentions from prompt length or treat its own output as ground truth. Changes must improve specific behavior without expanding the claims about a person.

The latest [quantized-adapter study](MODEL_SOURCE_SUPERVISION.md) produced a narrow semantic gain but failed category and unsupported-claim gates. The source-facts training variant did not beat label-only. Three adapters are retained locally for audit and none is selected in production. A training-output key-order contradiction was corrected for future preparation; its effect has not been measured.

The newer [assistant-context study](DOMAIN_READER.md) trains separate coding and
personal distinctions plus actual goal-reader supervision. The trained export
fails transfer and adds personal unsupported claims despite narrow matched-base
gains. A larger 9B comparison also fails fresh profiles and goals. The installed
`work-13` source-reading corrections retain the original Gemma model and category
default; no failed learned weights are promoted.

## Current implementation

This is an off-by-default experiment. No tested configuration met the interpretation-quality gate; default wording counts and the existing goal reader remain. The switch gates both extra inference and the category projection.

`contribution-1` asks the local model four independent questions about a target human reply: does it ask AI to proceed, add direction, ask for evidence/explanation, or report an actual attempt/observation? Multiple answers can be true. The app copies an exact, model-selected witness span from that human source. It organizes the main role in this order: reported attempt, direction, check, continuation; additional acts remain visible. This ordering organizes already interpreted acts, rather than matching the first English keyword.

A second pass challenges the proposed acts. The host checks actor attribution, exact source spans, duplicates, schema, source length and fingerprints. Agreement by the same model is not independent confirmation. Wrong relationships and semantic mistakes can survive these checks. Unsupported readings are withheld; unread replies are not silently assigned old rule labels.

Readings are optional fields on existing decision revisions, covered by their dependency invalidation, stale-write guard, export, retention and erasure. SQLite remains schema v6. The source day determines where a reply appears, separately from its later interpretation time. A newer withheld interpretation supersedes an older accepted label for the same unchanged message.

The existing serial review cycle starts at most once per two minutes after 15 seconds of quiet. Each cycle classifies up to four unread targets in the bounded conversation packet, reuses unchanged attempted labels, and revisits incomplete packets. It does not promise to classify the whole archive. Daily lookup is bounded to 200 related saved revisions; revision history is bounded per conversation. Pending, copied, clipped and unclear sources remain visible. Pause, suspension, Low Power Mode and the existing content/analysis choices apply. There is no new capture source or cloud fallback.

## First learned-weight experiment

A separate QLoRA adapter has now been trained on invented recipes and compared with its untouched MLX base. Complete proposal outcomes improved from 7/24 to 15/24 on a reserved, agent-authored test, but the declared quality gate failed. The adapter remains separate; no live weights or model selection changed. This is supervised fine-tuning, not the paper's direct weight editing. [Training, failures and reproduction](MODEL_TRAINING.md).

## Direct component inspection and editing

A later experiment inspected actual head activations and output matrices and directly ablated one head without gradients. It failed its declared gate and did not establish the proposed mechanism. The patch is retained separately for audit, with the live model unchanged. [Direct edit and controls](DIRECT_WEIGHT_EDIT.md).

## Sign-selective weight-space projection

A later approach traced actual native decisions, inspected MLP columns and directly removed a selected direction without training. A broader edit gained two complete outcomes on a new 32-case test but failed the declared quality gate. Its native-token and actual-sign audits are necessary corrections to the earlier diagnostic drafts. [Reasoning, controls and results](WEIGHT_SPACE_APPROACH.md).

## Source meaning versus Boolean bias

The follow-up direct weight study tested a source-derived feature edit against equal-size random and generic-true controls. It produced no semantic gain, while the older Boolean patch caused regressions on that new task. Late output-side gains are insufficient evidence that the observer interprets choices and provenance better. The existing proposal schema also lacks a separate delegated-choice field. [Source trace, negative result and current limits](SEMANTIC_WEIGHT_STUDY.md).

## Supported thinking and concise evidence checks

Online research identified Gemma's supported native thinking control, which earlier local tests disabled. A controlled comparison of thinking/checklist settings found a category gain but semantic regressions, more unsupported claims and substantially higher latency. It remains disabled. Short supervised source-fact annotations are the next proposed learned approach; that follow-up has not been run. [Research sources, inference results and proposed training](OBSERVER_REASONING_RESEARCH.md).

## Evaluation discipline

Use invented or separately authorized evaluation data. Keep authoring/development cases separate from additional examples not consulted during prompt edits. Compare final main-role labels against the actual wording pipeline; evaluate additional signals separately, since the old pipeline did not support them. Include deliberate delegation, clarification answers, typos, mixed requests, negation, hypothetical/future checks, actual results and known copied claims.

Inspect wrong accepted labels, withholding, missing secondary signals and batch latency, not only a combined score. A synthetic regression improvement does not validate agency, comprehension, prediction of capability, all-day resource cost or usefulness to real people. Version every protocol, preserve failure reports locally and publish clean aggregate results. Do not rebuild an executable mapped by an ongoing probe; use a copied, isolated probe binary. Unknown probe flags refuse normal app startup.

No model trains itself on these interpretations. A future prompt or weight change requires another evaluation. Human perspectives remain human reports, not automatic training labels.

## What weight-space programming would add

The [weight-space experiments](https://rikiyat.github.io/blog/weight-space-programming/) include genuine weight inspection/editing. Their sycophancy comparison needed attention information after weights-only attempts failed. The Qwen edit addressed a specific looping failure; the ordinary-reasoning Gemma experiment did not establish a useful gain. Neither result proves that editing our observer will improve intent classification.

The [released artifacts](https://github.com/RikiyaT/lm_understand-logs) support a separate reproducibility experiment. Applying their Qwen patch would test that published edit on its original model, not repair our Gemma model or establish human steering detection. A useful Vernier weight experiment needs a reproducible failure, editable checkpoint, controlled intervention, untouched comparison examples and checks for regressions outside that failure. A toy edit without downstream benefit is not a product improvement.

Our initial contribution failures were misattribution, missing mixed acts and confusion between asking and reporting. We changed the task representation and checked source spans first. We have not identified a component-level weight defect, inspected private model reasoning, edited production weights or trained on personal conversations. The separate supervised adapter trial is recorded above; it is not an automatic background activity or evidence of a diagnosed component-level defect.

## Repeatable contribution probes

The evidence-selection trial was rolled back after failing its declared gate. See [results and limitations](MODEL_EVALUATION.md). The retained probe changes improve auditability, not semantic interpretation.

Run checks first, then copy the built executable into a new ignored folder. Keep model runs serial and never rebuild an executable being used by a probe. This command invokes only invented fixtures, isolated preferences and a process prohibited from activation:

```sh
set -euo pipefail
./Scripts/verify-background.sh
run_dir="$(mktemp -d "$PWD/.context/observer-eval.XXXXXX")"
cp build/Vernier.app/Contents/MacOS/Vernier "$run_dir/Vernier-probe"
nice -n 10 "$run_dir/Vernier-probe" --contribution-model-probe \
  --model gemma4:e2b-it-qat \
  --cases Tests/Fixtures/contribution-batches.json \
  --report "$run_dir/batch.json" > "$run_dir/batch.log" 2>&1
python3 Scripts/summarize-contribution-probe.py \
  --run batch "$run_dir/batch.json" Tests/Fixtures/contribution-batches.json \
  > "$run_dir/summary.json"
```

The summarizer reads saved reports only; it makes no model calls. Repeat `--run LABEL REPORT FIXTURES` to compare runs. It separates complete outcomes, main-role matches, actual wording matches, accepted incorrect interpretations, accepted clear readings, withholding, missing targets and per-act true/false positives and misses. Precision/recall are null where no denominator exists. Latency uses nearest-rank quantiles across whole packets, including failures; a four-target packet duration is not single-target latency. Complete expected unclear/copied outcomes can count as matches without becoming accepted clear readings.

A batch fixture supplies `targets`, one entry per expected target, with the original zero-based `messageIndex`, `primary` and `additional` acts. It must cover exactly the current up-to-four target batch; the top-level label must agree with the anchor's label. Single-target fixtures keep their existing format. A final-target match alone cannot make a batch pass. Atomic progress reports can exist before a run finishes; the summarizer refuses a report missing any fixture.

`contribution-evidence-dev.json` and `contribution-evidence-validation.json` were authored before the evidence-selection edit. Their labels were not independently reviewed, and both sets have now been inspected. `contribution-batches.json` is a later stress/regression fixture. None is an untouched test set. Preserve a failed experiment's source patch and immutable executable locally along with runtime/model digests, settings, fixture hashes and reports. Report-version-2 probes additionally preserve structured proposal/challenge JSON and the invented witness packet; earlier reports only retained compiled drafts and supported IDs.
