# Improving the observer, with evidence

The observer should interpret human contributions in context and retain mixed signals. It should not learn private intentions from prompt length or treat its own output as ground truth. Changes must improve specific behavior without expanding the claims about a person.

## Current implementation

This is an off-by-default experiment. No tested configuration met the interpretation-quality gate; default wording counts and the existing goal reader remain. The switch gates both extra inference and the category projection.

`contribution-1` asks the local model four independent questions about a target human reply: does it ask AI to proceed, add direction, ask for evidence/explanation, or report an actual attempt/observation? Multiple answers can be true. The app copies an exact, model-selected witness span from that human source. It organizes the main role in this order: reported attempt, direction, check, continuation; additional acts remain visible. This ordering organizes already interpreted acts, rather than matching the first English keyword.

A second pass challenges the proposed acts. The host checks actor attribution, exact source spans, duplicates, schema, source length and fingerprints. Agreement by the same model is not independent confirmation. Wrong relationships and semantic mistakes can survive these checks. Unsupported readings are withheld; unread replies are not silently assigned old rule labels.

Readings are optional fields on existing decision revisions, covered by their dependency invalidation, stale-write guard, export, retention and erasure. SQLite remains schema v6. The source day determines where a reply appears, separately from its later interpretation time. A newer withheld interpretation supersedes an older accepted label for the same unchanged message.

The existing serial review cycle starts at most once per two minutes after 15 seconds of quiet. Each cycle classifies up to four unread targets in the bounded conversation packet, reuses unchanged attempted labels, and revisits incomplete packets. It does not promise to classify the whole archive. Daily lookup is bounded to 200 related saved revisions; revision history is bounded per conversation. Pending, copied, clipped and unclear sources remain visible. Pause, suspension, Low Power Mode and the existing content/analysis choices apply. There is no new capture source or cloud fallback.

## Evaluation discipline

Use invented or separately authorized evaluation data. Keep authoring/development cases separate from additional examples not consulted during prompt edits. Compare final main-role labels against the actual wording pipeline; evaluate additional signals separately, since the old pipeline did not support them. Include deliberate delegation, clarification answers, typos, mixed requests, negation, hypothetical/future checks, actual results and known copied claims.

Inspect wrong accepted labels, withholding, missing secondary signals and batch latency, not only a combined score. A synthetic regression improvement does not validate agency, comprehension, prediction of capability, all-day resource cost or usefulness to real people. Version every protocol, preserve failure reports locally and publish clean aggregate results. Do not rebuild an executable mapped by an ongoing probe; use a copied, isolated probe binary. Unknown probe flags refuse normal app startup.

No model trains itself on these interpretations. A future prompt or weight change requires another evaluation. Human perspectives remain human reports, not automatic training labels.

## What weight-space programming would add

The [weight-space experiments](https://rikiyat.github.io/blog/weight-space-programming/) include genuine weight inspection/editing. Their sycophancy comparison needed attention information after weights-only attempts failed. The Qwen edit addressed a specific looping failure; the ordinary-reasoning Gemma experiment did not establish a useful gain. Neither result proves that editing our observer will improve intent classification.

The [released artifacts](https://github.com/RikiyaT/lm_understand-logs) support a separate reproducibility experiment. Applying their Qwen patch would test that published edit on its original model, not repair our Gemma model or establish human steering detection. A useful Vernier weight experiment needs a reproducible failure, editable checkpoint, controlled intervention, untouched comparison examples and checks for regressions outside that failure. A toy edit without downstream benefit is not a product improvement.

Our initial contribution failures were misattribution, missing mixed acts and confusion between asking and reporting. We changed the task representation and checked source spans first. We have not identified a component-level weight defect, inspected private model reasoning, edited production weights or trained on personal conversations. We can pursue a bounded weight experiment if a specific failure and reliable evaluation justify it; it is not an automatic background activity.
