# A local, learned observer adapter

Historical experiment report. Its candidate remains experimental; see
[current model and memory status](MODEL_STATUS.md) for the active reader.

The first weight-training experiment produced a real Gemma 4 E2B LoRA adapter. On 24 reserved invented examples, complete proposal outcomes improved from **7/24 to 15/24** against the identical untouched MLX checkpoint. This missed the predeclared 20/24 gate. The adapter is retained as a separate research artifact; Vernier's live Ollama model, work-12 reader and off-by-default category experiment are unchanged.

This is supervised QLoRA fine-tuning, supported by [MLX LM](https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/LORA.md). It is not the paper's gradient-free, direct tensor-editing method. Weight editing is not required to run the existing model, and neither method guarantees useful interpretation of human choices.

## What actually changed

The isolated base is [`mlx-community/gemma-4-e2b-it-4bit`](https://huggingface.co/mlx-community/gemma-4-e2b-it-4bit), revision `238767527555cb75a05732a84dff5d6ba0dd6809`, a Gemma-licensed conversion of `google/gemma-4-E2B-it` at source revision `70af34e20bd4b7a91f0de6b22675850c43922a03`. Its downloaded weight file is 3,550,670,554 bytes, SHA-256 `038e39a37a7667373d2c3991375446b10c96ae1d717a68674870343db376b76e`.

This affine 4-bit MLX artifact differs from the deployed Ollama `gemma4:e2b-it-qat` artifact. The paired comparison isolates the adapter on the same MLX base; its scores cannot be compared causally to earlier Ollama scores.

Training changed 32 low-rank matrices: rank-8 adapters on query and attention-output projections in the last eight blocks, about 524,000 trainable parameters. The B matrices began at zero and acquired nonzero values; every adapter tensor changed. The base file still matched its downloaded hash afterwards. No deployed Ollama blob was overwritten or fused, and no owner preference changed.

The fixed run used MLX LM 0.32.2, Python 3.12, seed 42, AdamW at 0.0001, batch one, answer-only loss, gradient checkpointing and 120 updates. Maximum sequence length was 1,536; all examples fit without truncation. The final adapter was selected in advance, not by its test score. The exact plan lives in `Scripts/observer-training-plan.json`; run artifacts also contain a dependency lock and hashes.

## Data and evidence boundaries

`build-observer-training-fixtures.py` constructs 128 single-target examples from 32 recipes across four domains, plus 32 four-target packets. These 160 training packets are **not 160 independent semantic examples**. Validation uses 16 separately worded examples; the reserved test uses 24. All labels were authored by the coding agent from explicit recipes, not taken from observer guesses or personal sessions. They are not independently adjudicated human labels. Split hashes were frozen before training, and the test was run once per base/final-adapter variant. All inspected sets are now regression material.

The app's isolated `--export-packets-only` mode supplies its actual bounded witness packets, task instructions and JSON schema without inference. Export must accompany `--contribution-model-probe`; the standalone flag refuses normal app launch. Training loads only the train and validation completions. No test completions are supplied to the optimizer.

Evaluation is **proposal-only**: greedy local generation, up to 512 output tokens, with the same prompt/schema in both variants. A small Python scorer checks target keys, Boolean fields, target-owned witnesses, known copied text, main-role order and complete act sets. It does not run the production Swift validator or the model critic. It also does not enforce Ollama's output grammar. These scores do not establish an end-to-end app improvement, meaningful agency detection or better work-12 explanations.

## What improved and what failed

- Reserved test: **7/24 → 15/24** complete outcomes. Missing acts fell from 23 to nine, but unsupported added acts increased from zero to two.
- Validation: **6/16 → 10/16**. Existing twenty-example regression: **6/20 → 12/20**, in this separate MLX proposal-only evaluation.
- Four-target stress packet: both variants matched **3/4 targets**, so both whole packets failed. The base called the final clarification an actual report; the adapter missed a check in a mixed request.
- Four basic controls: **4/4 for both**. This tiny arithmetic/fact/format set does not establish that unrelated capabilities are preserved.
- The reserved copied-text and instruction-like-source cases matched in both variants. Every reserved-test response had valid schema fields and a target-owned witness, including the wrong interpretations. Exact evidence does not establish semantic correctness.

The adapter still missed clear privacy constraints, preserving history, changing one's mind, some observed results and the Spanish mixed request. It also treated a future personal inspection as a request for an AI check, and added a check to a report-plus-direction reply. It therefore fails the declared interpretation-quality gate despite the measured improvement on this synthetic subtask.

On the M5/24 GB test Mac, the bounded training completed in 119 seconds with 5.66 GB peak MLX allocation. The memory setting is an allocator guideline, with a stop check after reports; it is not a strict total process/GPU cap. Reserved single-target proposal p50/p95 latency was about 1.05/1.17 seconds for the base and 1.06/1.18 for the adapter. These measurements came from an active Mac and do not validate all-day energy, total system memory or native interaction behavior.

## Reproduce safely

Use a new ignored directory, a copied executable and the separate Python environment. Never run two training/model comparisons concurrently. No training or inference runs as part of normal verification. With `uv` available (the current workspace has an isolated copy under `.context/weight-training-tools/bin/uv`):

```sh
set -euo pipefail
run_dir="$(mktemp -d "$PWD/.context/observer-weights.XXXXXX")"
uv venv --python 3.12 "$run_dir/venv"
uv pip install --python "$run_dir/venv/bin/python" 'mlx-lm[train]==0.32.2'
cp Scripts/observer-training-plan.json "$run_dir/plan.json"
./Scripts/verify-background.sh
cp build/Vernier.app/Contents/MacOS/Vernier "$run_dir/Vernier-packet-exporter"
python3 Scripts/build-observer-training-fixtures.py "$run_dir/corpus"
for split in train valid test; do
  nice -n 10 "$run_dir/Vernier-packet-exporter" --contribution-model-probe \
    --export-packets-only --cases "$run_dir/corpus/$split-cases.json" \
    --report "$run_dir/corpus/$split-packets.json"
done
HF_HUB_DISABLE_TELEMETRY=1 HF_HUB_DISABLE_IMPLICIT_TOKEN=1 HF_HUB_DISABLE_XET=1 \
  "$run_dir/venv/bin/python" - "$run_dir" <<'PY'
import json, sys
from pathlib import Path
from huggingface_hub import snapshot_download
run = Path(sys.argv[1])
plan = json.loads((run / 'plan.json').read_text())
snapshot_download(plan['model'], revision=plan['revision'], local_dir=run / 'base-model',
                  allow_patterns=['*.json', '*.safetensors', '*.jinja', 'README.md'], max_workers=2)
PY
"$run_dir/venv/bin/python" Scripts/observer-weight-experiment.py prepare "$run_dir"
/usr/sbin/taskpolicy -b nice -n 10 "$run_dir/venv/bin/python" \
  Scripts/observer-weight-experiment.py train "$run_dir" > "$run_dir/train.log" 2>&1
for variant in base adapted; do
  for split in valid test controls; do
    /usr/sbin/taskpolicy -b nice -n 10 "$run_dir/venv/bin/python" \
      Scripts/observer-weight-experiment.py evaluate "$run_dir" \
      --variant "$variant" --split "$split" > "$run_dir/$variant-$split.log" 2>&1
  done
done
```

The run refuses changed frozen packets/data, oversized examples, an existing trained adapter or overwriting comparison reports. The training callback records losses and verifies that only adapter matrices are trainable. Loading uses local paths with remote code disabled, and training/evaluation set Hub and Transformers offline modes. Downloading the public checkpoint is the only necessary model-network step; no artifact upload or remote inference is configured.

The completed experiment also exported the two old fixture files as `regression-packets.json` and `contribution-batches.json` as `batch-packets.json` before freezing. When those comparisons are present, the runner's `summarize` command writes per-act precision/recall, missing/unsupported acts, packet/target totals and nearest-rank latency quantiles. Preserve `plan.json`, `frozen-data.json`, `metadata.json`, raw reports, `initial-adapter.safetensors`, `adapter/`, `weight-changes.json` and the dependency lock locally. Do not commit them or personal records.

Promotion requires independent label review, a fresh evaluation, the actual production source/critic path, runtime conversion/compatibility checks and broader resource/capability testing. The current adapter remains experimental. This run does not demonstrate the paper's direct weight intervention or any ability to measure comprehension or cognitive health.
