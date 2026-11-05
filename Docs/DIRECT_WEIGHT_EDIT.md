# A direct weight-edit experiment

Historical experiment report. Its candidate remains experimental; see
[current model and memory status](MODEL_STATUS.md) for the active reader.

The owner asked why we used fine-tuning instead of the paper's method. We then ran an **actual gradient-free component-inspection and weight-intervention experiment** on the separate Gemma checkpoint. No adapter, optimizer or backward pass was used.

The edit did not meet its quality gate. It matched **7/24** fresh invented proposal outcomes against the untouched base's **6/24**. The targeted-head diagnosis was not supported by the development and control results. The failed patch remains isolated and is not active in Vernier.

## Later diagnostic audit

The next iteration found a tokenization confound: this trial compared bare `true`/`false` tokens, while native Gemma JSON commonly uses distinct leading-space token IDs. Its full generated-proposal scores remain observed results, but the component nomination and forced-prefix mechanism claims have this additional limitation. The [subsequent approach](WEIGHT_SPACE_APPROACH.md) replays actual generated prefixes, scores both token forms and verifies native decision agreement before tracing components.

## Relationship to the paper

The [released 25-pass Qwen intervention](https://raw.githubusercontent.com/RikiyaT/lm_understand-logs/main/exp8_math/runs/p25c/final_answer.md) disabled one attention head after localizing its role in repetitive reasoning. The [50-pass intervention](https://raw.githubusercontent.com/RikiyaT/lm_understand-logs/main/exp8_math/runs/p50c/final_answer.md) removed measured repetition directions from selected MLP outputs. Both used causal controls; neither supplies a ready patch for Gemma's interpretation errors.

Our related hypothesis concerned excessive support for literal `false` when an explicit human act was present. We inspected Gemma's actual attention-head activations and output matrices, nominated components with approximate direct logit attribution, and tested direct edits with a same-layer control and dose changes. This is an adaptation of the inspection/intervention approach to a different model and task, not reproduction of the published Qwen result or evidence that a specific semantic defect has been found.

## What was inspected and edited

The untouched base was the existing `mlx-community/gemma-4-e2b-it-4bit` checkpoint at revision `238767527555cb75a05732a84dff5d6ba0dd6809`. This is separate from the live Ollama QAT artifact and the earlier trained adapter. Its Gemma license, original source and base hash are recorded in [the training notes](MODEL_TRAINING.md).

Sixteen balanced development probes used known Boolean-answer prefixes. The script captured each of 35 blocks' actual head outputs and examined dequantized attention-output matrices. It estimated each head's contribution along the `false` versus `true` readout direction. This is a nomination heuristic: it accounts for the current attention normalization but not the later nonlinear transformations, so it is not itself causal evidence or a complete explanation of a head.

Two nominated heads were tested by causal ablation. Selection between them used development binary log-loss before full proposal validation or fresh-test generation. The selected head was **zero-based layer 19, head 6**. Its input columns `[3072, 3584)` in the attention-output projection were zeroed: 786,432 effective weight positions.

Because this checkpoint is affine-quantized, the script directly zeroed the aligned groups' stored scales and quantization biases. That makes the represented output-weight columns exactly zero without requantizing the rest of the matrix. It verified that all outside columns and packed weight codes were unchanged, and saved the numerical patch plus original quantization parameters for rollback. This is an edit to the model's effective internal weights, not a change to its prompt or a final-logit bias.

## What the controls showed

On the sixteen forced-prefix diagnostic decisions, lower binary log-loss is better:

- Untouched base: **2.588**, 9/16 decisions.
- Selected head removed: **2.697**, 9/16.
- Same head halved: **2.491**, 9/16.
- Same head amplified to 1.5 times: **2.921**, 9/16.
- Adjacent control head removed: **1.535**, 11/16.
- Identity edit: reproduced the base margins within the declared tolerance.

The selected full ablation worsened this diagnostic; the control did better. Those results do not support calling the nominated head the cause of the interpretation failure. The weaker half-dose result is insufficient to rescue the diagnosis. The control was not promoted or retrospectively chosen using test outcomes.

Unconstrained complete proposal outcomes were **6/16** for the base, **5/16** for the selected edit and **9/16** for the control edit on development examples. The control also added four unsupported acts, compared with zero for the base. Higher recall alone is not a trustworthy interpretation improvement.

On 24 fresh, reserved invented examples, the selected edit matched **7/24**, versus **6/24** for the base. Missing acts fell from 22 to twenty; neither accepted an unsupported added act under this scorer. Both matched four basic arithmetic/fact/format controls. Both met schema and target-witness checks on all fresh examples, despite poor semantic outcomes. The 20/24 and minimum-four-gain research gates failed. These fresh examples are now regression material, not an untouched future test set.

All labels were agent-authored, without independent human adjudication. Evaluation used the same proposal-only MLX task and Python scorer as the earlier adapter experiment, not the production Swift validator or model critic. This fresh set differs from the adapter's test; their scores cannot be compared directly.

## Reproduce and audit

`Scripts/observer-direct-edit.py` uses `Scripts/observer-weight-experiment.py` only for the shared proposal prompt, gold-prefix construction, source-aware scoring and hashing. It loads the untouched base with no adapter and uses no training functions. `Scripts/observer-direct-edit-plan.json` fixes the hypothesis, diagnostics, selection, doses and resource bounds. The code refuses overwriting an existing run.

Create a new ignored run directory, copy that plan and set its `modelPath` to the existing isolated MLX checkpoint directory. Export `Tests/Fixtures/direct-weight-edit-cases.json` as `test-packets.json` through the isolated packet-only probe. Use `valid-packets.json` from the invented curriculum as `development-packets.json`, and the earlier fixed four `controls.json` prompts. Copy the public test fixture to `test-cases.json` in the run directory before starting. [Packet-export and environment setup](MODEL_TRAINING.md#reproduce-safely).

```sh
/usr/sbin/taskpolicy -b nice -n 10 .context/observer-training-venv/bin/python \
  Scripts/observer-direct-edit.py "$run_dir" > "$run_dir/experiment.log" 2>&1
```

The completed run preserved input hashes, raw activations, all attribution scores, diagnostic margins, dose/control outputs, raw proposal generations and a patch manifest. It used **112 forced-prefix forward requests and 104 generation requests** in 151 seconds, with 3.94 GB peak MLX allocation. A generation request contains many token steps; these counts are not the paper's batch/pass budget or all-day resource validation. The base file still matched its original hash afterwards. No production weights, preferences or private conversations were involved.

The failed patch is kept locally, outside git. Normal capture, category defaults and the work-12 goal reader do not load it. More components or a different direct intervention might help, but this bounded experiment did not establish a useful repair or validate a method for measuring human agency.
