#!/usr/bin/env python3
"""Make a separate Gemma 4 E2B Safetensors import directory for local Ollama.

MLX omits unused K/V projections in the final KV-sharing layers. Ollama 0.40.9
requires those keys while loading. Copy each missing key from its actual shared
owner, preserving every existing tensor. This is a loader compatibility step,
not an accuracy intervention. Runtime quality/parity still requires evaluation.
Never writes the source checkpoint, Ollama blobs, preferences or the live app.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct


def digest(path):
    sha = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(8 * 1024**2), b''):
            sha.update(chunk)
    return sha.hexdigest()


def header(path):
    with path.open('rb') as stream:
        length = struct.unpack('<Q', stream.read(8))[0]
        if length > 64 * 1024**2:
            raise ValueError('Unexpected Safetensors header size')
        return json.loads(stream.read(length))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    source, output = args.source.resolve(), args.output.resolve()
    if output.exists():
        raise ValueError('Use a new import directory')
    config = json.loads((source/'config.json').read_text())
    text = config.get('text_config', {})
    if config.get('model_type') != 'gemma4' or text.get('num_hidden_layers') != 35 or text.get('num_kv_shared_layers') != 20:
        raise ValueError('This export has only been inspected for Gemma 4 E2B, 35 layers / 20 shared')
    kinds = text['layer_types']
    if len(kinds) != 35:
        raise ValueError('Missing layer kinds')
    index = json.loads((source/'model.safetensors.index.json').read_text())
    weights = index['weight_map']
    owners = {kind: max(i for i in range(15) if kinds[i] == kind) for kind in set(kinds)}
    suffixes = ['k_proj.weight','k_proj.scales','k_proj.biases','v_proj.weight','v_proj.scales','v_proj.biases','k_norm.weight']
    mapping = {}
    for layer in range(15,35):
        for suffix in suffixes:
            target = f'language_model.model.layers.{layer}.self_attn.{suffix}'
            owner = f'language_model.model.layers.{owners[kinds[layer]]}.self_attn.{suffix}'
            if target not in weights:
                if owner not in weights:
                    raise ValueError('Shared source is missing: '+owner)
                mapping[target] = owner
    output.mkdir(parents=True)
    original = {}
    for path in source.iterdir():
        if path.is_file() and path.suffix in ['.safetensors','.json','.jinja','.txt','.model','.md']:
            original[path.name] = digest(path)
            shutil.copyfile(path, output/path.name)
    added_bytes = 0
    if mapping:
        import mlx.core as mx
        mx.set_memory_limit(10 * 1024**3)
        tensors = {}
        for filename in sorted({weights[owner] for owner in mapping.values()}):
            values = mx.load(str(source/filename))
            entries = header(source/filename)
            for target, owner in mapping.items():
                if weights[owner] == filename:
                    tensors[target] = values[owner]
                    lo, hi = entries[owner]['data_offsets']
                    added_bytes += hi-lo
        mx.save_safetensors(str(output/'compat.safetensors'), tensors)
        for target in mapping:
            weights[target] = 'compat.safetensors'
        index.setdefault('metadata', {})['total_size'] = index.get('metadata', {}).get('total_size', 0)+added_bytes
        (output/'model.safetensors.index.json').write_text(json.dumps(index, indent=2)+'\n')
    # Source and every copied original weight shard must remain byte-identical.
    for name, expected in original.items():
        if digest(source/name) != expected or (name.endswith('.safetensors') and digest(output/name) != expected):
            raise ValueError('A source/copied shard changed: '+name)
    record = dict(source=str(source), originalSHA256=original, addedInactiveKVProjections=mapping, addedBytes=added_bytes, runtimeParity='Not established by export; compare real task outputs before selecting this model.')
    (output/'vernier-export-audit.json').write_text(json.dumps(record, indent=2)+'\n')
    output.with_suffix('.Modelfile').write_text(f'FROM {output}\nPARAMETER temperature 0\nPARAMETER num_ctx 8192\n')
    print(json.dumps(dict(addedTensors=len(mapping), addedBytes=added_bytes, output=str(output))), flush=True)


if __name__ == '__main__':
    main()
