# Research-guided observer reasoning

Historical experiment report. Its candidate remains experimental; see
[current model and memory status](MODEL_STATUS.md) for the active reader.

The owner asked for online sources and a practical way to improve the local model's reasoning after direct weight edits failed to generalize. The next controlled study tests a supported model capability and a short source-evidence checklist. It uses the unchanged isolated MLX checkpoint, not an edited model or a trained adapter.

## Observed result

The frozen candidate was **native thinking plus the short evidence checklist**. On development it matched 12/16 complete replies versus 6/16 for direct inference, with unsupported claims falling from three to two. The checklist alone matched 9/16. Plain native thinking was ineligible because it truncated one category reply and added an unsupported category act. The selected combination passed the development preservation checks before reserved generation.

On the replacement reserved sets, category outcomes improved **10/32 → 19/32**, but semantic outcomes worsened **22/32 → 20/32**. Category unsupported acts increased from zero to two after copied-text withholding (three raw unsupported proposals before withholding). Semantic unsupported acts increased from five to ten. One selected category response hit the token limit and failed. Category median latency increased from 1.62 to 12.13 seconds; semantic median from 0.74 to 6.28 seconds on an active Mac. These are not sustained-runtime benchmarks.

The selected method gained twelve category outcomes and regressed on three; it gained five semantic outcomes and regressed on seven. It failed the 27/32 category and 28/32 semantic minima, unsupported-act and completion gates. The total seven-outcome gain across the two tasks does not make it a reliable general reasoning improvement. The actual wording pipeline matched 17/32 main categories; direct and selected models matched 11/32 and 20/32 main categories respectively. Main-category counts do not score secondary acts, and these invented sets do not establish model superiority over the default cards.

The error audit showed incorrect reasoning rather than only malformed final formatting: a settled choice was reinterpreted as an actual attempt, delegating a choice was double-counted as the human making the substantive choice, and an explicit denial of trying a control became an attempt report. A longer trace did not prevent those definition/attribution errors.

After correcting a control-prompt scope error, matched unrelated controls scored **7/8 direct and 8/8 thinking**. The original selected controls scored 0/8 because they accidentally inherited the observer's JSON-only instruction; those failures are preserved and are not evidence of lost general capability. All 192 observer prompt hashes replay unchanged under the scope correction. No observer outcome was rerun or reselected. The current public protocol 2.1 fixes control scope; the main study used its preserved protocol-2 snapshot.

The main run completed 208 generation packets and 55,304 generated tokens in 1,003.6 seconds, at 3.33 GB peak MLX allocation. A separate matched-control audit added sixteen requests, 246 tokens and 13.8 seconds. The stopped draft and other preparation/verification are outside those counters. Weights, adapter state and live preferences were unchanged. The approach remains an isolated failed candidate.

## What the research supports

- [Google's Gemma thinking documentation](https://ai.google.dev/gemma/docs/capabilities/thinking) describes a native thinking control for Gemma 4 E2B and requires separating the final answer from the thought channel. The installed template supports that control. Earlier MLX studies explicitly disabled it, and `DecisionGenerator.swift` currently requests thinking only for `qwen3:1.7b`, not Gemma. This makes thinking a concrete untested setting for this task; documentation alone does not establish an accuracy benefit.
- [Distilling Step-by-Step](https://arxiv.org/abs/2305.02301) trains small models with additional rationale supervision on NLP benchmarks. Its [released implementation](https://github.com/google-research/distilling-step-by-step) is a training method with an older T5 stack, not a drop-in Gemma repair. It motivates learning from concise, checked intermediate evidence if training becomes necessary; no such distillation is performed in this inference study.
- [Small Models Struggle to Learn from Strong Reasoners](https://arxiv.org/abs/2502.12143) finds that longer or stronger-teacher traces do not consistently help small students in its evaluated settings. That cautions against assuming more reasoning text guarantees improvement. It motivates measuring a brief checklist and its cost, not asserting that the paper validates our observer task.
- [Large Language Models Cannot Self-Correct Reasoning Yet](https://arxiv.org/abs/2310.01798) reports limitations of intrinsic correction without external feedback. A second model pass or longer explanation cannot be treated as independent confirmation. Our scoring remains tied to fixed source labels and exact target witnesses.
- [REdit](https://arxiv.org/abs/2603.06923) and its [released code](https://github.com/LzyFischer/REdit) target specific reasoning patterns while protecting other capabilities. Its reported experiments concern logic/math, and its method uses circuit attribution, gradient-based reshaping and LoRA. The appendix reports four A100 GPUs. This study does not reproduce it on a Mac or apply its method to human agency. Its distinction between targeted gains and collateral damage reinforces the separate semantic/proposal controls here.

These sources suggest testable directions, not a general recipe for understanding humans. No psychological assessment is used as a label oracle. Choices, authorization, reported attempts and ambiguity are interpretations of statements, not measurements of thought, feelings or ability.

## App path and the choice being tested

Saved, permitted conversation text becomes a bounded evidence packet. The local model proposes interpretations; host checks and a fallible same-model critic can withhold them before the dashboard uses them. Exact citations establish ownership of text, not semantic truth.

The existing contribution task asks about continuing a plan, adding direction, requesting a check and reporting an attempt. The separate semantic diagnostic asks whether a human made a choice, delegated a choice, reported an attempt or left relevant evidence ambiguous. Delegating implementation and delegating a choice stay distinct. Better diagnostic performance alone cannot establish a better live work-12 reader.

`Scripts/observer-reasoning-study.py` evaluates a two-by-two development comparison:

1. Existing direct response with native thinking off.
2. Direct response with a short actor/time/decision-object checklist.
3. Native thinking on, with the existing task unchanged.
4. Native thinking on with the same checklist.

All variants use greedy generation and identical final schemas. Thinking variants receive a 1,024-token completion ceiling, direct variants 512; this intentional extra-compute allowance must be reported with latency and completion rate. The checklist's request for brief thought is a soft instruction, not a hard thinking-token cap.

Sixteen previously inspected examples (eight per task) choose the best non-baseline method. Before ranking, a candidate must complete every reply with valid output, add no unsupported claims and cause no complete-outcome regression in either task. Eligible methods are then ranked by unsupported claims, complete outcomes and the fixed remaining criteria. The selected method is frozen before comparison with direct inference on 32 new invented semantic examples and 32 new invented production-shaped contribution examples. Even if the development gate fails, the fixed best non-baseline comparison is completed once as a prespecified negative-result check.

`Tests/Fixtures/observer-reasoning-cases.json` fixes examples and selection references; `Scripts/observer-reasoning-plan.json` fixes prompts, limits and gates. All labels are agent-authored, without independent human adjudication. Examples share authored archetypes and some cross-task wording; combined totals are not independent population samples. Inspected sets become regression material. No personal sessions or databases are used.

## Development protocol correction

Source audit found that the first draft ranked unsupported claims before requiring complete replies. A truncated output could therefore look attractive by making fewer claims, even though promotion gates would later reject it. That draft was stopped; the interrupt landed after baseline reserved generation had begun. No reserved outcome informed the correction. The entire original reserved corpus was retired and replaced, and protocol 2 froze the completion/per-task-preservation eligibility rule before new inference. The original source, raw development data, partial baseline report and stop audit are kept locally. Resource figures for the completed study exclude that draft.

## Parsing and evaluation boundaries

Unrelated controls receive matched general instructions with only thinking on/off; the observer-specific checklist is scoped to observer tasks. The runner verifies that the actual rendered prompt contains the native thinking control exactly when requested. It collects token IDs, preserves special tokens for parsing and scores only a completed final response. JSON inside an unfinished thought cannot become a successful outcome. Length-truncated responses fail. Ten envelope cases check complete finals, missing/repeated boundaries, unexpected channels and truncation. Five additional selection cases check eligibility, including incomplete output and a false-claim increase hidden by improvement in the other task. Three prompt-scope cases verify that unrelated controls do not inherit observer-only instructions and original messages are not mutated.

Scoring reuses the earlier semantic and proposal scorers. The category packets come from the actual isolated Swift packet exporter without model inference. Category scoring checks Boolean shape, target witness ownership, copied claims, complete act sets and primary order. It still omits the production Swift validation/critic and Ollama grammar. Known copied text is withheld by the existing scorer; the report also retains raw proposed acts so that withholding is not mistaken for correct model reasoning. The semantic witness is a single invented human span; it is not proof of broader provenance reasoning. Total generated-token counts include truncated replies; thought-token subtotals include only successfully separated channels and can undercount unfinished thought.

Retention requires at least 28/32 semantic and 27/32 category outcomes, at least six additional complete outcomes overall, no added unsupported claims in either task, valid complete responses and no unrelated-control regression. Independent labels, production runtime/host checks and sustained-resource testing remain necessary before deployment. The live model selection, weights, category defaults and work-12 reader are unchanged by this experiment.

## Next model-changing approach: short evidence supervision

The error audit supports testing a learned correction for narrow distinctions, rather than amplifying positive evidence or assuming a longer generated explanation is correct. A practical next experiment would pair the existing final-label task with a second supervised task that extracts concise source facts: who is speaking, whether the action is actual/future/hypothetical/denied, and whether the delegated object is a choice or an implementation. An exact source span should support each fact; it remains a statement, not proof of a real event.

Use invented contrastive pairs, including denial versus actual attempt, settled choice versus observed test, delegated decision versus execution, and ambiguous attribution versus explicit absence. Preserve the already-correct cases while correcting the wrong ones; protecting every negative state would also preserve some observed errors. Compare label-only adaptation with label-plus-facts adaptation under matched data and compute, freeze selection on development, then evaluate new cases, unrelated behavior and the actual production host/critic/runtime.

This is a proposed adaptation of the multi-task supervision idea in Distilling Step-by-Step, informed by REdit's emphasis on specificity and preservation. It would be gradient-based training, not the original paper's optimizer-free weight programming. It has **not** been implemented or evaluated in this inference study. General reasoning improvement, independent semantic labels and usefulness to the owner remain unproven. No personal conversation should become training data automatically.

## Reproduce without desktop testing

Use the existing isolated Python/MLX environment and unchanged checkpoint. With no model process already running:

```sh
PYTHONPYCACHEPREFIX="$PWD/.context/pycache" python3 Scripts/observer-reasoning-study.py parser-checks
# Choose a new, not-yet-created directory under .context/.
python Scripts/observer-reasoning-study.py prepare <new-ignored-run> --model-path <existing-local-mlx-checkpoint>
/usr/sbin/taskpolicy -b /usr/bin/nice -n 10 python Scripts/observer-reasoning-study.py run <new-ignored-run>
```

Preparation copies the built executable and uses its isolated packet-export mode, then freezes all inputs and helper source snapshots. Run with the environment's Python, not a system interpreter lacking MLX. The runner sets Hugging Face/Transformers offline flags, refuses frozen-input changes and repeated comparisons, and checks the checkpoint hash after inference. It neither calls Ollama nor changes app preferences.

The plan bounds the experiment to 1,800 seconds, 240 generation packets and 190,000 generated tokens with a 10 GiB MLX allocation guideline. These are experimental limits, not a hard cap on all Mac memory or evidence of all-day efficiency. `Scripts/verify-background.sh` checks the app separately without model inference, foreground windows, pointer actions or personal records.
