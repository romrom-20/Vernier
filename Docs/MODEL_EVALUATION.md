# Local model evaluation

The reasoning loop is implemented, but **no completed configuration met our interpretation-quality gate**. Model agreement and valid references do not establish semantic correctness. Automatic revisiting has a separate switch, off initially. Start with manual readings and compare their sources.

## Cost and the current default

Apple's on-device framework is the default experimental provider on an eligible Mac. Vernier uses its existing system model, requires no paid API subscription and downloads no separate weights for that provider. It is not a claim that this is the most accurate model, or that model inference has no memory or battery cost. If the framework is unavailable, the app says so and retains the source reader and map; it does not fall back to a cloud service.

**Gemma 4 E2B QAT was the strongest completed manual-review experiment: 33/40 expected labels. It still missed the gate.** It is available as an optional experimental engine, not a dependable detector of steering or comprehension. Its [exact Ollama tag](https://ollama.com/library/gemma4:e2b-it-qat) has a 4.3 GB download. The E2B name means effective parameters, not a 2 GB installation. It has no per-request API fee; total process memory and all-day energy were not validated. Keep automatic review off while checking whether its readings are useful for your work.

The optional Ollama path binds requests to `127.0.0.1:11434`. Its non-thinking Qwen2.5 7B configuration has no per-request API fee, but a [4.7 GB Q4_K_M download](https://ollama.com/library/qwen2.5:7b) and approximately 5.1 GB loaded GPU memory were observed on this test Mac with the 8,192-token context. It did not improve this test enough to justify choosing it as the default. Models and runtimes are separate installations; their licenses are separate from Vernier's MIT source license. There is no claim to have found the globally cheapest or smallest capable model.

For an optional local experiment, install Ollama from its official site and run:

```sh
ollama pull gemma4:e2b-it-qat
```

Then select that engine in Overview's local reasoning disclosure and use **Check local engine**. Availability checks establish installation, not interpretation quality. Experimental weights downloaded during development were removed when not needed; they are never bundled or committed.

## Test protocol

The fixtures contain **40 invented exchanges**: 24 in `decision-model-cases.json`, eight in `decision-model-holdout.json`, and eight in `decision-release-cases.json`. Despite their original filenames/split labels, all have now been inspected or used while developing this feature. They are **synthetic regression cases, not a blind validation set or an estimate of real-world accuracy**.

Cases cover scope boundaries, evidence and explanation requests, deliberate delegation, new agent proposals, actual versus hypothetical returning failures, same-topic success, unrelated topics, copied plans, corrections, reported outcomes, unsupported personal judgments and source injection. The engineering gate used for this release requires at least 20/24 main labels and 7/8 in each additional file, plus inspection for unsupported claims and attribution errors. Passing would still not validate an agency, fatigue or comprehension measurement. None of the completed configurations passed.

The explicit `--decision-model-probe` calls the production generator and validator with in-memory synthetic packets. First the model extracts overlapping observable acts as Boolean fields. The host determines the primary action, a second pass selects source IDs, the host composes restrained visible prose, and a third pass challenges that exact account. The host validates the source structure and can withhold a reading as uncertain. The same model performs all passes, so the challenge is not independent adjudication. Generated free prose is not used as the main interpretation or recommendation.

Correct labels can accompany wrong explanations; incorrect labels can be withheld safely or can survive the critic. Reports therefore include actions, source selections, critic results, visible text and runtimes. Generation errors count as failures. Context retrieval, stale-write rejection, migration and erasure are tested separately by shared core checks.

## Completed final-protocol results

On macOS 26.6.2, Apple M5, 24 GB RAM, Swift 6.3.1 and Ollama 0.40.9, with prompt `decision-2`:

- **Gemma 4 E2B QAT (`gemma4:e2b-it-qat`, digest prefix `07ea59a47401`):** 21/24 main, 6/8 release, 6/8 additional; **33/40** total. Median complete three-pass runtimes were approximately 3.2, 3.3 and 3.5 seconds. Temperature 0, seed 42, 8,192-token context, 800 output tokens per pass, thinking disabled and schema-constrained JSON. It missed returning-failure reports, over-withheld some valid acts, treated an ambiguous “do it” as delegation and accepted an unsupported interpretation request as direction. The controlled presentation did not repeat the requested capability claim, but the action reading was wrong.
- **Apple on-device:** 20/24 main, 5/8 release, 5/8 additional; **30/40** total. Median complete three-pass runtimes were approximately 3.8, 3.0 and 3.0 seconds respectively. The framework does not expose generated-token usage here; a diagnostic zero is not a claim of zero computation.
- **Qwen2.5 7B:** 17/24 main, 5/8 release, 6/8 additional; **28/40** total. Corresponding median runtimes were approximately 7.4, 11.5 and 11.3 seconds. Temperature 0, seed 42, 8,192-token context, 800 output tokens per pass and schema-constrained JSON.
- **Qwen3 1.7B thinking adapter:** stopped after ten failures in ten attempted main cases. This diagnostic run used a 16,384-token context, up to 4,096 generated tokens, temperature 0.6, top-p 0.95, top-k 20 and no grammar constraint on thinking. It rejected missing fields and malformed final objects rather than repairing their meaning. This is an unsuccessful runtime/protocol experiment, not a comparable 40-case score or proof about the model's general capability.

Observed failures include accepting a new agent proposal as a fresh human choice, describing a concrete verification request as a result report, missing a returning fault, over-withholding simple assent, and a critic treating an agent's build claim as evidence of resolution. The visible prose stays narrower than the critic's free-text reasoning, but a wrong action can still produce a misleading account. Read the exact sources; a critic does not make these deductions reliable.

Earlier experiments included Qwen3 0.6B/1.7B/4B, Qwen3.5 0.8B, Qwen2.5 1.5B/3B and Apple. Prompts, schemas and runtime handling changed between them; their old scores are not comparable or independent tests. Some Qwen3 paths returned thinking text in the content field or failed structured output. The adapter discards a completed documented thought envelope and accepts only a whole final JSON object; model thought text is never saved or displayed. Missing fields, truncation and malformed output fail without saving a reading. The 3B Qwen2.5 variant also has a different model license from the Apache-licensed 7B variant.

## Reproduce

```sh
swift build --product Vernier
.build/debug/Vernier --decision-model-probe \
  --model apple \
  --cases Tests/Fixtures/decision-model-cases.json \
  --report /tmp/vernier-synthetic-model-report.json
```

Run each of the other two fixture files separately and use distinct report paths. Substitute `gemma4:e2b-it-qat` for the strongest tested Ollama manual-review configuration, or `qwen2.5:7b` for the other completed alternative. Probes do not open the personal store, start a connector, register login or read real chats. Normal CI and showcase do not invoke models. Hardware, system model assets and mutable Ollama tags can change output; record runtime, prompt and model digest when comparing runs.

## Resource and trust boundaries

Reviews are serial, wait for 45 seconds of source quiet and run automatically at most once per five minutes, only when that option is enabled. Automatic inference rests in Low Power Mode; manual review is still possible. Capture remains independent. Unchanged evidence is reused. Ollama requests use an ephemeral session, no tools, cookies, cache or redirects, bounded timeouts, and `keep_alive: 30s` so weights can unload after idle. See the [official API contract](https://docs.ollama.com/api/chat) and [structured-output guidance](https://docs.ollama.com/capabilities/structured-outputs).

The next useful evaluation needs newly written, independently adjudicated exchanges and natural long-conversation review. Broader projects/languages, useful guidance, independent capability and all-day energy remain unverified. No new cloud inference provider is configured, no paid request was purchased, and no personal archive was used for these model experiments.
