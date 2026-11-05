# Source-fact supervision for the local observer

Historical experiment report. Its candidate remains experimental; see
[current model and memory status](MODEL_STATUS.md) for the active reader.

Status: three completed adapters remain outside live selection. The follow-up
improved a new semantic diagnostic from 14/20 to 18/20 complete outcomes, but
category outcomes reached only 12/20 versus the declared 17/20 minimum and added
an unsupported act. The current goal reader and default wording categories remain.

The initial 384-update comparison used old development examples only. The base
matched 11/16 semantic and 6/16 category outcomes. Label-only reached 14/16 and
9/16, while source-facts reached 11/16 and 9/16. Total unsupported acts were three,
one and six respectively. Label-only introduced a new category error despite its
lower overall error count; neither adapter qualified. Source-fact supervision did
not win this tested construction. This does not disprove rationale supervision in
other settings; answer-token counts, exact compute and task exposure were not equal.

A separately frozen follow-up broadened invented wording from 44 to 84 patterns
and trained label-only for 768 updates. It used 336 semantic cases, 335 category
packets and 24 goal-reader examples, totaling 1,454 rows after repetition and
retention examples. Both data and duration changed, so this is not a causal
ablation of either change. Development reached 12/16 semantic and 10/16 category
outcomes, still introducing an unsupported choice on an implementation request.
The fixed candidate's reserved test was completed as a negative-result check,
without treating failed development selection as promotion eligibility.

On the new test, semantic unsupported acts fell from three to zero and missed
acts from four to two. Category unsupported acts rose from zero to one; misses
fell from fifteen to eight. All responses completed with valid schemas. Two mixed
semantic replies lost one of their supported acts. The category reader still
missed clear requirements, implied check requests and actual attempts; it also
misread a request to preserve fields as a check request. These are substantive
meaning errors, not just formatting failures.

Twelve new general-instruction controls scored 11/12 base and 12/12 adapted, with
every base success retained. The base's failure added Markdown around an explicitly
requested JSON object. These controls are a narrow screen. On comparable main
category outcomes, wording rules matched 8/20 and the candidate 13/20; those counts
do not score secondary acts or establish live critic/host quality.

The three completed training processes took about 390, 411 and 977 seconds, with
at most 5.74 GB peak MLX allocation, excluding stopped preparation and evaluations.
Each learned 2,113,536 finite adapter values in 72 tensors from a zero-B start.
Production Ollama weights and model preferences were preserved. The trained
candidate was not fused, imported, or tested through the live category critic or
work-12 reader because the earlier quality gates failed. Those transfers remain
unproven. Base import preflights used invented readiness prompts only and their
temporary Ollama tags were removed.

The owner asked to improve the actual local model and try the research methods.
This experiment changes weights through LoRA training on a frozen four-bit model. It adapts the multi-task
label/rationale idea in [Distilling Step-by-Step](https://arxiv.org/abs/2305.02301)
and its [released implementation](https://github.com/google-research/distilling-step-by-step).
The auxiliary task teaches short, explicit source facts instead of long reasoning
traces. It is not a reproduction of that paper's T5 experiments or the original
[optimizer-free weight-programming experiments](https://github.com/RikiyaT/lm_understand-logs).
It does not establish a general improvement in reasoning or psychological insight.

Saved conversation text becomes a bounded witness packet. The model proposes a
goal reading and, optionally, category labels. The same model challenges those
proposals; Swift validates their source references before the dashboard uses
them. Better proposal labels alone do not establish better live readings. The
work-12 goal reader must retain its behavior and source attribution.

`Scripts/build-observer-supervision.py` creates 44 invented contrastive patterns
across four domains: 176 semantic cases, 165 category packets including 33
four-target batches, and 24 goal-reader examples. The semantic diagnostic separates
human choices, deliberate delegation, actual attempts and unresolved attribution.
The existing category ontology instead asks about continuation, direction, checks
and reported attempts. Cases that lack a clear category equivalent are omitted
from category training rather than forced into one.

`Scripts/observer-supervision.py` trains two rank-eight adapters on the last twelve
blocks' query, attention-output and MLP-output projections. Only 2,113,536 adapter
parameters are trainable. The frozen base is the previously downloaded local
Gemma 4 E2B affine-four-bit MLX checkpoint, not the installed Ollama QAT artifact.
The original checkpoint and production blobs are preserved.

Both variants use the same case pairs, 384 updates, seed and optimizer settings.
Label-only repeats the final label where source-facts teaches its auxiliary
response. Each has 794 rows, including 64 repetitions of eight general-instruction
retention examples. Maximum sequence length is 1,371 tokens within a 2,048-token
budget, with prompt loss masked. This matches update counts and underlying cases;
answer-token counts and exact compute differ. It is not an equal-compute ablation.

A preparation audit caught an assistant-denial/human-attribution error in sixteen
auxiliary rows including batches. That source-facts run was stopped before development or reserved
evaluation. The correction changes only auxiliary targets. The completed
label-only adapter was reused only after checking byte-identical training,
validation and plan files. The stopped run and correction record remain local.

A later preparation audit found that alphabetical semantic-target serialization
contradicted the prompt's requested key order. The evaluated adapters retain their
original frozen data and are not silently rerun. The public preparer now preserves
the requested order; all 336 follow-up semantic cases were checked against their
actual prompts without changing Boolean labels. Its accuracy effect is unmeasured
and requires a new training run and new evaluation material. Four fresh work-case
evidence values also needed the host enum spelling `no_result`; that encoding-only
correction was recorded before any work-model evaluation, which was not reached.

Selection uses sixteen previously inspected semantic examples and sixteen
production-shaped category examples. A candidate must complete valid responses,
add no unsupported claim to a development case and avoid per-task regression.
The selection is frozen before the models answer a new twenty-example semantic
set and twenty category packets. All labels are agent-authored and remain subject
to ambiguity and independent review; authored variants are not independent human
observations. Once inspected, evaluation sets become regression material.

The declared minimum is 18/20 semantic and 17/20 category complete outcomes, six
additional complete outcomes overall, no added unsupported claims and no unrelated
control regression. `Scripts/observer-supervision-controls.py` supplies twelve new
general-instruction checks separate from the rehearsed retention examples. These
are a narrow screen, not proof of preserved broad capability.

Deployment additionally requires checking adapter fusion, imported Ollama behavior,
the real category critic/validator, and existing plus fresh goal-reader cases.
`WorkModelProbe.swift` now includes expected evidence attribution and optional
result state in pass/fail; previously evidence mismatches were only reported.
Its goal-word check is still a weak screen and raw readings need review.

`Scripts/export-observer-ollama.py` prepares a separate Safetensors import directory.
MLX omits unused K/V projections in the final twenty KV-sharing layers, but the
installed Ollama loader requires those keys. The export copies missing tensors
from each layer's actual shared owner and preserves every existing weight tensor.
A loading preflight is insufficient to establish numerical or task parity.
Follow [Ollama's import workflow](https://docs.ollama.com/import) with a distinct
model tag; never overwrite the installed Gemma tag to hide a failed candidate.

The owner authorized a reversible local live trial after these checks. A passing
future candidate can be registered in the app, installed under a separate Ollama name,
and selected with the original app/model/preferences retained for rollback.
Failed candidates stay outside live selection. Independent semantic labels,
sustained operating cost and usefulness on personal-agent conversations remain
unproven even if the synthetic gate passes.

Use the existing local Python/MLX environment, offline flags and reduced-priority
serial model jobs. The plan bounds each training process to 1,800 seconds and each
proposal evaluation to 900 seconds, with a 10 GiB MLX allocation guideline. This is
not a hard system-memory cap. No private sessions are training data, no cloud
inference is used, and foreground desktop tests are excluded. Run
`Scripts/verify-background.sh` separately for isolated state and offscreen checks.
Keep models, raw runs, preferences and the handoff under ignored local storage.
