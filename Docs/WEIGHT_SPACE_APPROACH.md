# Reasoning from weights to a testable edit

Historical experiment report. Its candidate remains experimental; see
[current model and memory status](MODEL_STATUS.md) for the active reader.

This iteration follows a more specific approach than deleting a whole attention head: **matched-pair causal tracing, inspection of MLP weight columns, then removal of one candidate output direction from selected columns**. It uses actual activations and numerical weights, without an optimizer, backward pass or learned adapter. It is an experiment, not an established repair.

## Later semantic transfer warning

A subsequent fixed comparison found that this archived Boolean patch worsened a newly reserved semantic task from **40/48 to 33/48**, increasing unsupported acts from five to ten. The new task separately distinguishes a human choice, delegated choice, reported attempt and ambiguity. This is paired evidence against broad transfer, not a comparison of unrelated headline accuracies. The separate source-derived edit also produced no gain. Read [the semantic weight study](SEMANTIC_WEIGHT_STUDY.md). Both patches remain disabled.

## Measured result

The broader, sign-correct 512-column edit improved a newly reserved invented test from **11/32 to 13/32** complete proposal outcomes. It recovered four missed acts across three replies, with two newly complete outcomes, no complete-outcome regressions and no newly unsupported acts on this set. The equal-norm random edit stayed at 11/32. The quantized and conversion-only baselines produced identical act sets, as did the baseline and random edit.

Two complete recoveries were recognizing both the local-only choice and explanation request in “Keep the photos local and explain the limitations,” and recognizing a Spanish self-reported attempt. A third reply gained its requested check but still missed its direction. These are invented source statements; interpreting a self-report does not verify a real-world result.

The candidate still failed the predeclared **27/32 and six-additional-match gates**. It remains an archived experimental patch, not Vernier's active model. The actual wording pipeline also matched 13/32 main roles; it does not predict secondary acts. These small agent-authored tests do not establish superiority to the default cards, reliable human-agency interpretation or an end-to-end work-12 improvement.

The selected edit is zero-based block 34's MLP output matrix, 512 columns, strength 1.0. Its scope covers 786,432 positions in a 1,536-by-12,288 matrix. Relative Frobenius change was 0.006108; perpendicular change fraction was 8.52e-7. Outside selected columns were unchanged compared with the FP32 sham. Embeddings and normalization weights were read for the analysis, not edited. No gradients, optimizer or learned adapter were used.

Development selection used sixteen original plus 32 explicitly retired examples. Complete outcomes: conversion-only baseline **20/48**, selected edit **23/48**, equal-norm random edit **20/48**, reversed edit **12/48**. The selected and baseline development variants each had one unsupported act; reversal had none but missed many more acts. The new test was fixed before selection and is now regression material. All labels were authored by this coding agent, without independent human adjudication.

All base/sham/edited variants matched four basic unrelated controls. These do not establish broad capability preservation. Evaluation was proposal-only MLX inference with the existing Python schema/witness/copied-text scorer, without the production Swift validator, model critic or Ollama grammar. Runtime conversion, long natural conversations, independent labels and sustained usefulness remain unproven.

The completed broader run used 112 forced-prefix forward requests and 476 generation packets in 774 seconds, with 5.50 GB peak MLX allocation. It reused a separately recorded causal block trace after validating identical development inputs, base identity and replayed margins. Those request counts exclude the earlier trace and aborted drafts. Allocation limits are guidelines, not strict system caps; active-Mac timings do not validate all-day energy. The original checkpoint hash remained unchanged. Background verification and hidden invented renders passed; full Xcode was not selected, so XCTest was skipped.

## Why this intervention

The existing failure is often an empty act proposal for an explicit human contribution. The model must distinguish “I tested it” from “I will test it,” and a request for evidence from a statement about later personal review. A general increase in `true` answers would recover some acts while inventing others.

Matched present/absent examples therefore come first. They hold much of the wording and task context constant while changing an observable act. The diagnostic prefix is copied from the untouched model’s actual generated JSON up to the field under investigation. Its earlier guesses are preserved. Fresh proposal generation receives no expected answer.

The model's MLPs transform internal features and write them back into the residual stream. Their output matrices expose the direction in which each feature writes. The hypothesis is that a small subset contributes excessive support for absence on explicit-act examples. This does not assume that a neuron literally means “human agency,” or that its contribution can be understood from one number.

## Native-token audit comes first

The first projection run was stopped before fresh-test generation after finding that bare `true`/`false` and space-prefixed ` true`/` false` have different token IDs. All sixteen native diagnostic decisions used the spaced forms. Comparing only bare tokens was therefore a poor surrogate for the decisions actually being made.

The corrected protocol replays the actual generated prefixes, verifies all native greedy Boolean choices, and computes Boolean likelihood over both valid one-token forms. Its weight-space readout uses the dominant native token pair. The aborted run and its original source are preserved separately; it is not presented as a successful mechanistic finding. This correction also limits the earlier head-edit trial’s forced-prefix interpretation, while leaving its complete generated-output counts unchanged.

## The causal and geometric checks

1. Capture actual feature activations and outputs in all 35 MLP blocks on eight present/absent pairs. Inspect every output matrix and its column geometry.
2. Bypass each MLP output in turn and rerun the sixteen diagnostic decisions. Nominate two blocks using balanced Boolean log-loss, first protecting against new wrong absent-act decisions. Bypassing a block is a localization probe, not the retained model edit.
3. In each nominated block, select 64 columns that actually write toward `false` on present-act examples. Rank their mean present-act contribution minus their mean absolute influence on absent-act examples; require a positive score.
4. Test three strengths of a selective direction removal. Select using complete development proposals, prioritizing unsupported acts, complete matches and missing acts. Freeze this choice before fresh-test generation.
5. Compare the fixed edit with the original quantized model, a conversion-only sham, an equal-norm random-direction edit on the same columns and a reversed edit. All outcomes are retained, including failures.

The candidate direction uses the model's actual native-space ` false` versus ` true` embedding/readout vectors, final normalization weights and the block's output-normalization weights. It is a **Boolean-output direction**, not an independently validated representation of human intent. Later nonlinear transformations can invalidate this approximation. That is why actual causal interventions and unconstrained proposals must test it.

For an output matrix `W`, unit direction `u`, selected column set `S` and strength `a`, the direct edit is:

```text
W[:, S] := W[:, S] - a * u * (uᵀ * W[:, S])
```

At strength one, the selected columns lose their component along `u`; their components perpendicular to it remain. Other columns remain unchanged. The script checks the actual numerical footprint and perpendicular change within floating-point tolerance. This changes a saved internal weight tensor, rather than adjusting the final logits or rewriting the prompt.

## Relative scores can select the wrong columns

A second development audit found that “more false relative to absent examples” is insufficient: a column can instead be writing toward `true`, just less strongly than in the absent example. Removing that useful component can hurt the model. In the native-prefix draft, 32/64 selected columns in block 34 and 33/64 in block 13 were actually writing toward `true` on present examples.

That draft was also stopped before any fresh test outcome. The selective protocol requires a positive actual mean false contribution on present cases and penalizes the mean absolute contribution on absent cases. The corrected run reuses only the already validated, unchanged block-localization results, checking identical development packets, base identity and replayed baseline margins. The weight-column selection is recomputed. The fresh test remained unused throughout both corrections.

## Conversion and controls matter

The base checkpoint is affine-quantized. An arbitrary projection cannot generally be represented by zeroing aligned scale groups as in the earlier head ablation. This trial replaces one isolated MLP output module with its dequantized FP32 linear matrix, and compares the edit with an identically converted but unchanged module. The original quantized model is measured separately. Any conversion effect must not be reported as an edit benefit.

The random control uses the same columns and Frobenius change norm, with a direction perpendicular to the candidate direction. The reversed control changes the same component with the opposite sign. Neither control is chosen to look bad on the fresh test. These checks distinguish a directional hypothesis from generic capacity damage or a broad shift toward positive labels.

## Scope and reproducibility

`Scripts/build-observer-projection-fixtures.py` creates sixteen development packets and 32 fresh reserved test packets. Labels are agent-authored recipe intentions, not independently adjudicated human judgments. `Scripts/observer-weight-projection-plan.json` fixes the method, selection, doses, resource budget and quality gate. Use the isolated packet exporter described in [the local training setup](MODEL_TRAINING.md#reproduce-safely) to produce exact source packets without inference.

`Scripts/observer-weight-projection.py` reuses the existing isolated Gemma checkpoint, with no LoRA loaded. It saves activations, all block-localization results, inspected column geometry, every candidate/control proposal, the frozen selection and the actual projected weight tensor. It runs offline at background task policy and reduced CPU priority. Base weights on disk and the live Ollama model remain separate.

The reserved test is run only after selection. A research retention gate requires at least 27/32 complete fresh outcomes, six additional matches over the conversion-only sham, no added unsupported acts, no copied/injection false report and no basic-control regression. Even passing these agent-authored checks would not establish dependable live goal readings, independent semantic validation, broad capability preservation or all-day resource cost.


## Coverage follow-up

The 64-column version had a direction-specific development gain: 6/16 complete replies for the conversion-only baseline, 8/16 for the selected edit, 6/16 for the equal-norm random edit and 5/16 for the reversed edit. All had one unsupported act. It did **not** transfer: all four variants matched 14/32 fresh replies with identical act sets, zero unsupported added acts and 22 missing acts. Basic controls remained 4/4. That patch was rejected.

A weight-space coverage audit then measured what the column budget captured: 64 columns contained 34.47% of the eligible positive contrast-score sum; 512 contained 81.32%. This is a linear proxy, not causal error coverage. It justified a separate broader experiment rather than calling the narrow edit a general repair.

The broader study selects strength using the original sixteen plus the now-retired 32 development examples. Its newly reserved 32-case set is `Tests/Fixtures/weight-projection-coverage-cases.json`. The selected 512 columns still satisfy actual positive false-writing and absent-influence constraints. Candidate choice is frozen before the new test. Its result must be compared with its own quantized and conversion-only baselines, not with another study's headline counts.

`Scripts/observer-weight-projection-resume.py` is only for completing an already frozen selection after interrupted footprint validation. It verifies the original selection rule, all frozen inputs, and the selected candidate's diagnostic margins before proceeding; it refuses to repeat existing comparison reports. In the narrow study, an MLX Boolean-indexing limitation interrupted the footprint check. A broadcast mask fixed that check, and all margins replayed before controls/test generation. This was not a reselection or a test-driven weight change.
