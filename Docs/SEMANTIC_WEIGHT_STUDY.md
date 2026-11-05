# Testing a source-derived weight edit

Historical experiment report. Its candidate remains experimental; see
[current model and memory status](MODEL_STATUS.md) for the active reader.

The owner requested one more focused investigation into whether direct weight inspection can improve recognition of human choices, deliberate delegation, reported results and uncertainty. This study tests an existing source-dependent feature contrast rather than directly removing a Boolean `false` direction. It is isolated research, not a live model update.

## Observed result

The reserved semantic task matched **40/48** for the original quantized model, conversion-only sham, new source-derived edit, random edit, generic-true control and reversed edit. Their predicted Boolean fields were identical. The source-derived edit did not repair any reserved case. Each had five unsupported act claims, one missed supported act and three uncertainty errors. Development selection also showed no gain: all tested doses/controls matched 22/36. The candidate failed its development and reserved quality gates.

The **previous Boolean-direction patch fell from 40/48 to 33/48** on this new, paired semantic comparison. Unsupported act claims increased from five to ten, with eight complete-outcome regressions and one gain. It called execution of an already chosen migration a delegated choice, and sometimes added a separate human choice to genuine delegation. This does not erase its earlier two-case proposal gain, but it demonstrates that the gain did not establish a broadly useful repair. The old patch should remain disabled.

The observed source-state path was real but insufficient: block 9 had positive mean reciprocal donor effects for all four diagnostic distinctions and 21/24 directional effects above 0.01. Mean donor effect was 1.126 Boolean logit-margin units, versus 0.645 mean absolute shift from same-label donors. Those donors still differ lexically and contextually; this is not identification of a pure agency circuit. Sampled source edits at blocks 14, 19, 24, 29 and 34 had zero later-decision effect, consistent with the checkpoint's KV-sharing topology.

The baseline had no missed supported acts on the 24 diagnostic replies; its errors there concerned unsupported additions and uncertainty calibration. Amplifying a positive source contrast therefore targeted the wrong failure type on that diagnostic. Nulling the update against negative source states also deliberately limits its ability to repair wrong predictions at those same states. This failure rejects this specific amplification recipe and budget, not every possible weight edit.

The saved edit changes block 9's 1,536-by-6,144 MLP output matrix in 512 columns, through a rank-four source-derived basis, at selected dose 0.5: about 0.25% relative matrix Frobenius change. Independent reload confirms other columns are exactly unchanged, the saved matrix matches the stored delta addition to 2.91e-6 relative error, and the basis is nearly orthonormal. CPU float64 recomputation differs from the stored GPU-calculated formula by 0.0392%, failing the initial strict 0.01% audit threshold. That discrepancy is recorded rather than silently relaxing the check; the saved GPU calculation replays exactly; separate matrix-product and norm-reduction checks characterize the discrepancy against float64. These failed candidates do not qualify for use regardless.

## What the app can currently express

The production contribution proposal has four Boolean fields: continuing an agreed plan, adding direction, asking for a check and reporting an attempt. `ContributionGenerator.swift` shares the actual task/schema with the isolated packet exporter; `ContributionReading.swift` checks exact source ownership and known copied claims. Neither a witness ID nor valid JSON establishes that an interpretation is right.

Handing a choice to AI is not a separate field in that schema. Executing a previously approved plan and authorizing AI to choose an approach are different decisions, so this study uses a separate diagnostic schema: `choiceMade`, `choiceDelegated`, `attemptReported`, and `uncertain`. It also measures the fixed edit on the existing production-shaped proposal task. A gain on this new diagnostic alone would not establish an app improvement.

Labels concern observable statements. A personal report is not independent proof that an event happened. Delegation is not evidence of disengagement; choosing is not evidence of understanding. The study does not use psychological assessments, infer feelings or measure cognitive health.

## Frozen evidence and controls

`Tests/Fixtures/observer-semantic-cases.json` contains 24 diagnostic replies in twelve matched pairs, twelve additional development-selection replies, 48 newly reserved replies and eight small unrelated controls. Reserved cases cover future/negated acts, mixed roles, ambiguous attribution, broad delegation, quoted assistant claims, instruction-like quoted text, longer contexts and several languages. These are small invented excerpts, not representative live histories.

All labels and their decision rules were authored by the coding agent. The owner declined separate human adjudication and asked the agent to judge from the evidence. This does not make the labels independent. The eight optional blind-check examples were not human-adjudicated. No personal archive, saved owner conversation, capture source or external inference service is used.

The complete corpus, plan, source snapshot, prior patch identity and production-shaped transfer packets are frozen before tracing. Layer and dose selection uses development only. Every fixed variant is evaluated once on reserved cases; inspected examples then become regression material. Even a numerical pass cannot promote the candidate without independent labels and the actual app pipeline.

## From actual states to numerical weights

1. Generate the untouched model's native JSON. Put the diagnostic field first among Booleans to avoid earlier-answer differences. Replay its real prefix, verify both bare and leading-space Boolean token boundaries, and require the native greedy decision to reproduce.
2. Capture actual MLP input features and output vectors at two positions: the end of the quoted human source and the later Boolean decision. Across seven prespecified layers, reciprocally substitute present/absent paired states. This tests whether a state carries information affecting the later decision; it is not itself a saved weight edit.
3. Select a source-position layer from development patch effects, then measure a same-label donor control. Check that replacing a last-layer source MLP output cannot influence a later token. The single source endpoint and coarse layer grid do not exhaust the model's information pathways.
4. Inspect the selected MLP output matrix `W`. Derive four mean feature contrasts from matched source states, choose 512 substantial contrast columns, and remove components in the development negative-state span. Take an orthonormal basis `Q` of the remaining contrasts. No Boolean readout vector enters this candidate.
5. Directly amplify the component the existing matrix already writes from that feature subspace: `delta[:, S] = (W[:, S] Q) Qᵀ`. Scale the update to 0.5% of the full matrix Frobenius norm at unit dose. Other columns remain unchanged. Two fixed doses, 0.5 and 1.0, are selected using full development replies, protecting against unsupported act claims before counting complete matches.
6. Compare the original quantized checkpoint, conversion-only FP32 sham, selected edit, equal-norm random edit on the same columns, equal-norm generic-true readout edit, reversed edit, and the previously frozen Boolean projection. The generic-true control tests the possibility of a broad positive-answer shift. Measure production-shaped transfer and unrelated controls separately.

This is an analytically computed, data-dependent matrix edit. It uses matched examples to identify contrasts and calibrate a dose, without gradients, an optimizer, a learned adapter, output-logit rewriting or a changed live prompt. The basis does not establish that a neuron or subspace literally means agency. Amplifying it can amplify lexical, syntactic or task-specific artifacts.

The existing production-shaped regression replay remained **11/32** for the untouched, conversion-only, new edit, random and generic-true variants. The prior Boolean patch reproduced **13/32**, with missed acts falling from 27 to 23 and no unsupported added acts on that older set. Its poor new semantic transfer is therefore compatible with a reproducible but narrow old gain. No production host validator, same-model critic or Ollama grammar was used in this replay.

All six variants measured on the eight unrelated controls matched 7/8, with the same fenced-JSON formatting failure. The reversed variant was measured on semantic development/test but not the unrelated or proposal controls. These controls do not establish broad capability preservation. The main experiment completed 384 forced-prefix forwards and 816 generation packets in 822.5 seconds, at 4.06 GB peak MLX allocation. Additional tensor-only audits loaded no model and generated no replies; they are outside those counters.

## Why source location matters in this checkpoint

The isolated MLX Gemma checkpoint has 35 blocks and 20 KV-sharing layers. Blocks 0–14 compute keys and values; later sliding-attention layers reuse block 13's KV and later full-attention layers reuse block 14's KV. An MLP edit at source position after the last KV-producing attention cannot propagate from that position to a later output token through subsequent attention. An edit at a decision position can still change its answer.

The local implementation was checked in the installed `mlx_lm/models/gemma4_text.py` and downloaded configuration. This architectural constraint limits interpretation of a late Boolean-direction edit: it may change output-side computation without changing how source evidence is represented for later tokens. It does not prove the late layers are useless or that an earlier edit will be correct.

## Quality and reproducibility

The semantic numerical gate requires at least 41/48 complete reserved outcomes, at least six additional complete matches, no additional unsupported acts, a development gain and no unrelated-control regression. Transfer must also be reviewed. Independent semantic labels, production host validation/critic, Ollama compatibility, broader capability checks and sustained resource measurements remain separate requirements.

Use `Scripts/observer-semantic-contrast.py` with `Scripts/observer-semantic-contrast-plan.json`, the existing isolated MLX environment/checkpoint and a new ignored run directory. Copy the invented fixture to `cases.json`; copy the actual exported invented transfer packets to `transfer-packets.json`. Supply an exact, hashed `prior-patch.json`, `source-used.py` and the local checkpoint path in the run's plan. The script refuses an existing frozen run or overwritten report. It runs offline under background task policy and reduced CPU priority. Model inference is not part of `verify-background.sh`.

The configured run limit is 1,800 seconds, 700 forced-prefix forwards, 1,000 generation packets and a 10 GiB MLX allocation guideline. That guideline is not a hard cap on total Mac memory. The checkpoint and deployed Ollama blobs stay separate; saved tensors are not Ollama-ready artifacts. No foreground window, pointer or native focus test is performed.

## Research relation

The study follows the inspect–hypothesize–intervene–control pattern of [Sparks of Weight-Space Programming](https://rikiyat.github.io/blog/weight-space-programming/). Source-state tracing and matrix geometry also draw on [ROME's causal tracing and rank-one editing work](https://rome.baulab.info/), while using a different, non-optimized contrast-amplification update. [Activation-patching methodology research](https://arxiv.org/abs/2309.16042) motivates explicit metric, donor and location controls. This is not a reproduction of those papers or evidence that their results transfer to human-agency interpretation.
