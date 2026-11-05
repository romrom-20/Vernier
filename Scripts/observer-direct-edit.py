#!/usr/bin/env python3
"""Bounded gradient-free Gemma head inspection and direct weight intervention.

Uses invented packets and an untouched local checkpoint. No LoRA, optimizers,
backward passes, uploads, production model writes or live-app activation.
"""
import argparse
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import signal
import time


def read(path):
    return json.loads(path.read_text())


def write(path, data):
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n')
    temporary.replace(path)


def support():
    spec = importlib.util.spec_from_file_location('observer_protocol', Path(__file__).with_name('observer-weight-experiment.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def run_experiment(run):
    import mlx.core as mx
    import mlx.nn as nn
    import numpy as np
    from mlx_lm import load, generate
    from mlx_lm.sample_utils import make_sampler
    from mlx.utils import tree_flatten

    plan = read(run / 'plan.json')
    protocol = support()
    began = time.monotonic()
    counters = dict(teacherForcedForwards=0, generationPackets=0)

    def budget(kind):
        counters[kind] += 1
        if counters[kind] > plan['limits'][kind]:
            raise RuntimeError('Forward budget exceeded: ' + kind)
        if time.monotonic() - began > plan['limits']['wallSeconds']:
            raise TimeoutError('Experiment wall-time budget exceeded')
        if mx.get_peak_memory() > plan['limits']['mlxMemoryGuidelineBytes']:
            raise MemoryError('MLX allocation exceeded the experiment budget')

    def timeout(signum, frame):
        raise TimeoutError('Experiment wall-time budget exhausted')

    signal.signal(signal.SIGALRM, timeout)
    signal.alarm(plan['limits']['wallSeconds'])
    mx.set_memory_limit(plan['limits']['mlxMemoryGuidelineBytes'])
    mx.set_cache_limit(256 * 1024 * 1024)
    mx.random.seed(42)
    frozen = {name: protocol.digest(run / name) for name in ['plan.json', 'development-packets.json', 'test-packets.json', 'controls.json', 'test-cases.json']}
    write(run / 'frozen-inputs.json', frozen)
    model, tokenizer = load(plan['modelPath'], adapter_path=None, trust_remote_code=False)
    if any('lora_' in name for name, _ in tree_flatten(model.parameters())):
        raise RuntimeError('Direct editing must start from the untouched base, without an adapter')
    layers = model.layers
    text_model = model.language_model.model
    true_ids = tokenizer.encode('true', add_special_tokens=False)
    false_ids = tokenizer.encode('false', add_special_tokens=False)
    if len(true_ids) != 1 or len(false_ids) != 1:
        raise ValueError('Boolean candidate words must be single tokens')
    true_id, false_id = true_ids[0], false_ids[0]
    embeddings = text_model.embed_tokens(mx.array([true_id, false_id])).astype(mx.float32)
    readout = (embeddings[1] - embeddings[0]) * text_model.norm.weight.astype(mx.float32)
    mx.eval(readout)
    development = read(run / 'development-packets.json')['cases']
    by_id = {case['id']: case for case in development}
    queries = []
    reverse_fields = {field: act for act, field in protocol.FIELDS.items()}
    for entry in plan['diagnostics']:
        case = by_id[entry['case']]
        target = case['expected'][0]
        gold = protocol.gold(case)
        marker = json.dumps(entry['field']) + ':'
        prefix = gold[:gold.index(marker) + len(marker)]
        messages = protocol.messages(case)
        rendered = tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=True, enable_thinking=False)
        token_prefix = tokenizer.encode(rendered + prefix, add_special_tokens=False)
        for word, token in [('true', true_id), ('false', false_id)]:
            if tokenizer.encode(rendered + prefix + word, add_special_tokens=False) != token_prefix + [token]:
                raise ValueError('Candidate token boundary differs from the forced prefix')
        queries.append(dict(case=case['id'], field=entry['field'], expected=reverse_fields[entry['field']] in target['acts'], tokens=token_prefix))
    write(run / 'diagnostic-queries.json', [{key: value for key, value in q.items() if key != 'tokens'} for q in queries])

    module_ids = {id(layer.self_attn.o_proj): i for i, layer in enumerate(layers)}
    captures = {}
    original_call = nn.QuantizedLinear.__call__

    def observed_call(module, x):
        y = original_call(module, x)
        if id(module) in module_ids:
            captures[module_ids[id(module)]] = (x[0, -1, :], y[0, -1, :])
        return y

    def forward(query):
        budget('teacherForcedForwards')
        logits = model(mx.array([query['tokens']]))[0, -1]
        margin = (logits[true_id] - logits[false_id]).item()
        signed = margin if query['expected'] else -margin
        loss = max(0, -signed) + math.log1p(math.exp(-abs(signed)))
        return dict(case=query['case'], field=query['field'], expected=query['expected'], trueMinusFalseLogit=margin,
                    correct=(margin > 0) == query['expected'], binaryLogLoss=loss)

    head_scores = {(i, h): dict(positive=[], negative=[]) for i, layer in enumerate(layers) for h in range(layer.self_attn.n_heads)}
    baseline = []
    try:
        nn.QuantizedLinear.__call__ = observed_call
        for qi, query in enumerate(queries):
            captures.clear()
            result = forward(query)
            baseline.append(result)
            tensors = {}
            for layer_index, (head_input, full_output) in captures.items():
                layer = layers[layer_index]
                attention = layer.self_attn
                module = attention.o_proj
                if module.mode != 'affine':
                    raise ValueError('Only inspected affine quantization is supported')
                weights = mx.dequantize(module.weight, module.scales, module.biases,
                                        group_size=module.group_size, bits=module.bits, mode=module.mode).astype(mx.float32)
                heads = head_input.astype(mx.float32).reshape(attention.n_heads, attention.head_dim)
                per_head_write = mx.einsum('hd,ohd->ho', heads, weights.reshape(weights.shape[0], attention.n_heads, attention.head_dim))
                # Approximate direct logit attribution: downstream nonlinear transformations are not modeled.
                normalization = layer.post_attention_layernorm.weight.astype(mx.float32) * mx.rsqrt(mx.mean(full_output.astype(mx.float32) ** 2) + layer.post_attention_layernorm.eps)
                contributions = (per_head_write * normalization * readout * layer.layer_scalar).sum(-1)
                mx.eval(contributions)
                for head, value in enumerate(contributions.tolist()):
                    head_scores[(layer_index, head)]['positive' if query['expected'] else 'negative'].append(value)
                tensors[f'layer_{layer_index}_head_inputs'] = head_input
                tensors[f'layer_{layer_index}_output'] = full_output
            mx.save_safetensors(str(run / f'activation-{qi:02d}.safetensors'), tensors)
            print('INSPECT', qi, result['case'], result['field'], result['correct'], flush=True)
            mx.clear_cache()
    finally:
        nn.QuantizedLinear.__call__ = original_call
    ranked = []
    for (layer, head), values in head_scores.items():
        positive = sum(values['positive']) / len(values['positive'])
        negative = sum(values['negative']) / len(values['negative'])
        ranked.append(dict(layer=layer, head=head, positiveFalseSupport=positive,
                           negativeFalseSupport=negative, score=positive - negative))
    ranked.sort(key=lambda x: x['score'], reverse=True)
    write(run / 'attribution.json', dict(approximateOnly=True, ranking=ranked, baseline=baseline))

    def state(layer_index):
        module = layers[layer_index].self_attn.o_proj
        return module.scales, module.biases

    def patch(layer_index, head, factor):
        module = layers[layer_index].self_attn.o_proj
        dim = layers[layer_index].self_attn.head_dim
        if dim % module.group_size != 0:
            raise ValueError('Head boundaries must align with quantization groups')
        scales, biases = state(layer_index)
        mask = mx.ones(scales.shape, dtype=scales.dtype)
        begin, end = head * dim // module.group_size, (head + 1) * dim // module.group_size
        mask[:, begin:end] = factor
        module.scales = scales * mask
        module.biases = biases * mask
        return scales, biases

    def restore(layer_index, original):
        module = layers[layer_index].self_attn.o_proj
        module.scales, module.biases = original

    def probe(layer_index=None, head=None, factor=1):
        original = patch(layer_index, head, factor) if layer_index is not None else None
        try:
            rows = [forward(q) for q in queries]
            return dict(layer=layer_index, head=head, factor=factor, binaryLogLoss=sum(r['binaryLogLoss'] for r in rows) / len(rows), correct=sum(r['correct'] for r in rows), total=len(rows), cases=rows)
        finally:
            if original is not None:
                restore(layer_index, original)
            mx.clear_cache()

    candidates = []
    for candidate in ranked[:plan['candidates']]:
        measured = probe(candidate['layer'], candidate['head'], factor=0)
        candidates.append(measured)
        print('CAUSAL CANDIDATE', measured['layer'], measured['head'], measured['binaryLogLoss'], measured['correct'], flush=True)
    chosen = min(candidates, key=lambda x: x['binaryLogLoss'])
    layer_index, head = chosen['layer'], chosen['head']
    control_head = (head + 1) % layers[layer_index].self_attn.n_heads
    interventions = dict(candidates=candidates, selected=dict(layer=layer_index, head=head, factor=0),
                         baseline=dict(binaryLogLoss=sum(r['binaryLogLoss'] for r in baseline) / len(baseline), correct=sum(r['correct'] for r in baseline), total=len(baseline)),
                         control=probe(layer_index, control_head, 0),
                         half=probe(layer_index, head, .5), amplified=probe(layer_index, head, 1.5),
                         identity=probe(layer_index, head, 1))
    for before, after in zip(baseline, interventions['identity']['cases']):
        if abs(before['trueMinusFalseLogit'] - after['trueMinusFalseLogit']) > .001:
            raise ValueError('Identity edit failed to reproduce the baseline logit margin')
    write(run / 'interventions.json', interventions)

    module = layers[layer_index].self_attn.o_proj
    original = state(layer_index)
    packed_before = np.array(module.weight).tobytes()
    before = mx.dequantize(module.weight, module.scales, module.biases, group_size=module.group_size, bits=module.bits, mode=module.mode)
    patch(layer_index, head, 0)
    after = mx.dequantize(module.weight, module.scales, module.biases, group_size=module.group_size, bits=module.bits, mode=module.mode)
    dim = layers[layer_index].self_attn.head_dim
    start, end = head * dim, (head + 1) * dim
    if mx.any(after[:, start:end] != 0).item() or mx.any(before[:, :start] != after[:, :start]).item() or mx.any(before[:, end:] != after[:, end:]).item():
        raise ValueError('Effective weight edit escaped its declared columns')
    if packed_before != np.array(module.weight).tobytes():
        raise ValueError('Packed weight codes changed unexpectedly')
    prefix = f'language_model.model.layers.{layer_index}.self_attn.o_proj'
    mx.save_safetensors(str(run / 'direct-patch.safetensors'), {prefix + '.scales': module.scales, prefix + '.biases': module.biases})
    mx.save_safetensors(str(run / 'original-quantization.safetensors'), {prefix + '.scales': original[0], prefix + '.biases': original[1]})
    write(run / 'patch-manifest.json', dict(method='Direct effective attention-head output weight ablation via aligned affine quantization scale/bias groups',
          layer=layer_index, head=head, zeroedInputColumns=[start, end], factor=0,
          effectiveWeightValues=before.shape[0] * dim, packedWeightCodesUnchanged=True,
          outsideColumnsUnchanged=True, schema='MLX isolated quantization-parameter patch; not an Ollama artifact',
          patchSHA256=protocol.digest(run / 'direct-patch.safetensors')))
    restore(layer_index, original)

    def generate_rows(label, cases, edit=None):
        saved = patch(*edit) if edit else None
        rows = []
        try:
            for case in cases:
                budget('generationPackets')
                prompt = tokenizer.apply_chat_template(protocol.messages(case), tokenize=False, add_generation_prompt=True, enable_thinking=False)
                start_time = time.monotonic()
                text = generate(model, tokenizer, prompt=prompt, sampler=make_sampler(temp=0), max_tokens=512, verbose=False)
                targets = protocol.score(case, text)
                rows.append(dict(id=case['id'], seconds=time.monotonic() - start_time, raw=text, targets=targets, passOutcome=all(t['passOutcome'] for t in targets)))
                write(run / (label + '.json'), dict(syntheticOnly=True, proposalOnly=True, productionHostValidation=False, noCritic=True,
                      completed=len(rows) == len(cases), total=len(rows), expectedTotal=len(cases), passed=sum(r['passOutcome'] for r in rows), cases=rows))
                print('GENERATE', label, case['id'], rows[-1]['passOutcome'], flush=True)
                mx.clear_cache()
        finally:
            if saved:
                restore(edit[0], saved)
        return rows

    # Freeze the chosen intervention before these unconstrained proposal generations.
    validation = {}
    for label, edit in [('base', None), ('edited', (layer_index, head, 0)), ('control', (layer_index, control_head, 0))]:
        validation[label] = generate_rows(label + '-development', development, edit)
    test = read(run / 'test-packets.json')['cases']
    for label, edit in [('base', None), ('edited', (layer_index, head, 0))]:
        generate_rows(label + '-test', test, edit)
    for label, edit in [('base', None), ('edited', (layer_index, head, 0))]:
        saved = patch(*edit) if edit else None
        try:
            rows = []
            for item in read(run / 'controls.json'):
                budget('generationPackets')
                prompt = tokenizer.apply_chat_template([dict(role='user', content=item['prompt'])], tokenize=False, add_generation_prompt=True, enable_thinking=False)
                output = generate(model, tokenizer, prompt=prompt, sampler=make_sampler(temp=0), max_tokens=64, verbose=False)
                rows.append(dict(id=item['id'], raw=output, expected=item['expected'], passOutcome=output.strip() == item['expected']))
            write(run / (label + '-controls.json'), dict(completed=True, total=len(rows), passed=sum(r['passOutcome'] for r in rows), cases=rows))
        finally:
            if saved:
                restore(edit[0], saved)
    for name, expected in frozen.items():
        if protocol.digest(run / name) != expected:
            raise ValueError('Frozen experiment input changed')
    if protocol.digest(Path(plan['modelPath']) / 'model.safetensors') != plan['modelSHA256']:
        raise ValueError('Base checkpoint file no longer matches the untouched model')
    write(run / 'completion.json', dict(completed=True, elapsedSeconds=time.monotonic() - began,
          mlxPeakBytes=mx.get_peak_memory(), counters=counters, baseFileUnchanged=True,
          noGradients=True, noOptimizer=True, noAdapter=True))
    signal.alarm(0)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('run', type=Path)
    args = parser.parse_args()
    run = args.run.resolve()
    run.relative_to((Path.cwd() / '.context').resolve())
    if (run / 'frozen-inputs.json').exists():
        raise ValueError('Refusing to overwrite an existing experiment')
    for key in ['HF_HUB_OFFLINE', 'TRANSFORMERS_OFFLINE', 'HF_HUB_DISABLE_TELEMETRY', 'HF_HUB_DISABLE_IMPLICIT_TOKEN']:
        os.environ[key] = '1'
    os.environ['TOKENIZERS_PARALLELISM'] = 'false'
    run_experiment(run)


if __name__ == '__main__':
    main()
