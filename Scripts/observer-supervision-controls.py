#!/usr/bin/env python3
"""Bounded fresh general-instruction checks; local MLX or loopback Ollama only.

These invented controls are separate from the eight rehearsed retention prompts.
They are a small regression screen, not a general reasoning benchmark.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import time
import urllib.request

CONTROLS = [
    ('sum', 'What is 28 plus 15? Reply with the number only.', '43'),
    ('subtract', 'What is 61 minus 24? Reply with the number only.', '37'),
    ('opposite', 'What is the opposite of south? Reply with one lowercase word.', 'north'),
    ('sort', 'Sort 9, 1, 4 in ascending order. Reply as comma-separated digits without spaces.', '1,4,9'),
    ('json', 'Return exactly this JSON object: {"count":3}', '{"count":3}'),
    ('extract', 'In "oak, pine, elm", what is the last word? Reply with that word only.', 'elm'),
    ('fact', 'What is the capital of Italy? Reply with the city name only.', 'Rome'),
    ('instruction', 'Reply with exactly the lowercase word prepared.', 'prepared'),
    ('negation', 'The lamp is not on. Is the lamp on? Reply with lowercase yes or no only.', 'no'),
    ('copy', 'Copy only the text between brackets: [mango]', 'mango'),
    ('length', 'How many letters are in the word "cat"? Reply with the number only.', '3'),
    ('condition', 'If 4 is smaller than 7 reply SMALL; otherwise reply LARGE. Output one word only.', 'SMALL'),
]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--model', required=True)
    p.add_argument('--adapter')
    p.add_argument('--ollama', action='store_true')
    p.add_argument('--report', required=True, type=Path)
    args = p.parse_args()
    if args.report.exists():
        raise ValueError('Refusing to replace a comparison')
    if args.ollama and args.adapter:
        p.error('An Ollama model must already contain the adapter')
    for k, v in dict(HF_HUB_OFFLINE='1', TRANSFORMERS_OFFLINE='1', HF_HUB_DISABLE_TELEMETRY='1', HF_HUB_DISABLE_IMPLICIT_TOKEN='1', TOKENIZERS_PARALLELISM='false').items():
        os.environ[k] = v
    def expired(a, b):
        raise TimeoutError('Control evaluation wall limit')
    signal.signal(signal.SIGALRM, expired)
    signal.alarm(300)
    if not args.ollama:
        import mlx.core as mx
        from mlx_lm import load, stream_generate
        from mlx_lm.sample_utils import make_sampler
        mx.set_memory_limit(10 * 1024**3)
        mx.set_cache_limit(256 * 1024**2)
        model, tok = load(args.model, adapter_path=args.adapter, trust_remote_code=False)
    rows = []
    for identifier, prompt, expected in CONTROLS:
        messages = [dict(role='system', content='Follow the user instruction.'), dict(role='user', content=prompt)]
        began = time.monotonic()
        if args.ollama:
            data = dict(model=args.model, messages=messages, stream=False, think=False, keep_alive=0, options=dict(temperature=0, num_predict=128, num_ctx=8192))
            req = urllib.request.Request('http://127.0.0.1:11434/api/chat', data=json.dumps(data).encode(), headers={'Content-Type': 'application/json'})
            # Do not permit redirects from the loopback-only inference endpoint.
            class NoRedirect(urllib.request.HTTPRedirectHandler):
                def redirect_request(self, *args, **kwargs):
                    raise RuntimeError('Redirect refused')
            with urllib.request.build_opener(NoRedirect).open(req, timeout=90) as response:
                value = json.load(response)
            raw = value['message']['content']
            finished = value.get('done') and value.get('done_reason') == 'stop'
        else:
            rendered = tok.apply_chat_template(messages, tokenize=False, add_generation_prompt=True, enable_thinking=False)
            tokens = []
            for last in stream_generate(model, tok, prompt=rendered, sampler=make_sampler(temp=0), max_tokens=128):
                tokens.append(last.token)
            if last.finish_reason == 'stop' and tokens[-1] in tok.eos_token_ids:
                tokens.pop()
            raw = tok.decode(tokens, skip_special_tokens=False)
            finished = last.finish_reason == 'stop'
            mx.clear_cache()
        rows.append(dict(id=identifier, prompt=prompt, expected=expected, raw=raw, completed=bool(finished), passed=bool(finished) and raw.strip() == expected, seconds=time.monotonic()-began))
    result = dict(syntheticOnly=True, model=args.model, adapter=args.adapter, backend='ollama' if args.ollama else 'mlx', sourceSHA256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), passed=sum(r['passed'] for r in rows), total=len(rows), cases=rows)
    args.report.write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ('backend','passed','total')}), flush=True)


if __name__ == '__main__':
    main()
