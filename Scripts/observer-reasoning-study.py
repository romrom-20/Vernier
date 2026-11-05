#!/usr/bin/env python3
"""Offline, bounded thinking/checklist comparison on invented observer tasks.

No training, weight changes, personal records, Ollama requests or app setting writes.
"""
import argparse
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import shutil
import signal
import statistics
import subprocess
import time


def read(path):
    return json.loads(Path(path).read_text())


def write(path, value):
    path = Path(path)
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n')
    temporary.replace(path)


def digest(path):
    sha = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(8 * 1024 * 1024), b''):
            sha.update(chunk)
    return sha.hexdigest()


def load_module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def final_payload(raw, finish_reason):
    """Only a completed final channel may be scored; never rescue a thought JSON."""
    if finish_reason != 'stop':
        raise ValueError('Generation did not complete before its limit')
    text = raw.strip()
    thought = ''
    if text.startswith('<|channel>thought'):
        body = text[len('<|channel>thought'):]
        if body.count('<channel|>') != 1:
            raise ValueError('Missing or repeated thought boundary')
        thought, text = body.split('<channel|>', 1)
        text = text.strip()
    if '<|channel>' in text or '<channel|>' in text or '<|think|>' in text:
        raise ValueError('Unexpected channel marker in final response')
    if not text:
        raise ValueError('Empty final response')
    return text, thought


def eligible_candidate(reference, candidate):
    return all(candidate[task]['metrics']['parseFailures']==0
               and candidate[task]['metrics']['schemaFailures']==0
               and candidate[task]['metrics']['falseClaims']<=reference[task]['metrics']['falseClaims']
               and candidate[task]['metrics']['passed']>=reference[task]['metrics']['passed']
               for task in reference)


def request_turns(turns, variant, checklist, observer_task=True):
    prepared = [dict(turn) for turn in turns]
    if variant['checklist'] and observer_task:
        prepared[0]['content'] += '\n'+checklist
    return prepared


def parser_checks():
    # Correctly formed JSON in a truncated thought must never become a success.
    valid = [('{"ok":true}', 'stop', '{"ok":true}'),
             ('<|channel>thought\n{"wrong":true}\n<channel|>{"ok":true}', 'stop', '{"ok":true}'),
             ('<|channel>thought\n<channel|> 43 ', 'stop', '43')]
    for raw, reason, expected in valid:
        assert final_payload(raw, reason)[0] == expected
    invalid = [('{"ok":true}', 'length'),
               ('<|channel>thought\n{"ok":true}', 'stop'),
               ('<|channel>thought\n{"ok":true}<channel|>', 'stop'),
               ('<|channel>thought\nx<channel|><channel|>{"ok":true}', 'stop'),
               ('preface <|channel>thought x<channel|>{"ok":true}', 'stop'),
               ('<|channel>final\n{"ok":true}', 'stop'), ('', 'stop')]
    for raw, reason in invalid:
        try:
            final_payload(raw, reason)
        except ValueError:
            continue
        raise AssertionError('Unsafe envelope accepted')
    reference={task:dict(metrics=dict(parseFailures=0,schemaFailures=0,falseClaims=1,passed=6))
               for task in ['semantic','category']}
    good={task:dict(metrics=dict(parseFailures=0,schemaFailures=0,falseClaims=0,passed=7))
          for task in reference}
    assert eligible_candidate(reference,good)
    for key,value in [('parseFailures',1),('schemaFailures',1),('falseClaims',2),('passed',5)]:
        broken=json.loads(json.dumps(good))
        broken['category']['metrics'][key]=value
        assert not eligible_candidate(reference,broken)
    original=[dict(role='system',content='Follow the user.'),dict(role='user',content='Reply 43.')]
    variant=dict(checklist=True)
    assert request_turns(original,variant,'JSON observer check')[0]['content'].endswith('JSON observer check')
    assert request_turns(original,variant,'JSON observer check',False)==original
    assert original[0]['content']=='Follow the user.'
    return dict(passed=len(valid)+len(invalid)+8,total=len(valid)+len(invalid)+8,
                envelopeCases=len(valid)+len(invalid),eligibilityCases=5,promptScopeCases=3)


def prepare(run, model_path):
    root = Path(__file__).resolve().parent.parent
    if run.exists():
        raise ValueError('Preparation requires a new run directory')
    run.mkdir(parents=True)
    plan = read(root/'Scripts/observer-reasoning-plan.json')
    plan['modelPath'] = str(model_path.resolve())
    if digest(model_path/'model.safetensors') != plan['modelSHA256']:
        raise ValueError('Unexpected local checkpoint')
    fixture = read(root/'Tests/Fixtures/observer-reasoning-cases.json')
    if fixture.get('syntheticOnly') is not True:
        raise ValueError('Requires explicit invented fixtures')
    old_sem = read(root/'Tests/Fixtures/observer-semantic-cases.json')
    old_category = read(root/'Tests/Fixtures/weight-projection-coverage-cases.json')
    semantic_index = {x['id']:x for split in ['development','calibration','test'] for x in old_sem[split]}
    category_index = {x['id']:x for x in old_category}
    semantic = dict(development=[semantic_index[i] for i in fixture['development']['semanticIDs']], test=fixture['semantic'])
    category = dict(development=[category_index[i] for i in fixture['development']['categoryIDs']], test=fixture['category'])
    write(run/'plan.json', plan)
    write(run/'fixture.json', fixture)
    write(run/'semantic.json', semantic)
    write(run/'controls.json', old_sem['controls'])
    exporter = run/'Vernier-packet-exporter'
    shutil.copy2(root/'build/Vernier.app/Contents/MacOS/Vernier', exporter)
    for split, cases in category.items():
        source = run/(split+'-category-cases.json')
        write(source, cases)
        result = subprocess.run([str(exporter),'--contribution-model-probe','--export-packets-only',
                      '--cases',str(source),'--report',str(run/(split+'-category.json'))],
                      stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=90)
        (run/(split+'-export.log')).write_text(result.stdout)
        result.check_returncode()
        packet = read(run/(split+'-category.json'))
        if not packet.get('syntheticOnly') or not packet.get('packetExportOnly') or len(packet['cases']) != len(cases):
            raise ValueError('Invalid isolated packet export')
    scripts = ['observer-reasoning-study.py','observer-semantic-contrast.py','observer-weight-experiment.py']
    for script in scripts:
        shutil.copy(root/'Scripts'/script, run/script)
    frozen_names = ['plan.json','fixture.json','semantic.json','controls.json','development-category.json',
                    'test-category.json',*scripts]
    write(run/'frozen-inputs.json', {name:digest(run/name) for name in frozen_names})
    write(run/'parser-checks.json', parser_checks())
    print(run, flush=True)


def execute(run):
    import mlx.core as mx
    from mlx_lm import load, stream_generate
    from mlx_lm.sample_utils import make_sampler
    from mlx.utils import tree_flatten

    if (run/'started.json').exists():
        raise ValueError('Use a new run; refusing to repeat reserved comparisons')
    plan = read(run/'plan.json')
    frozen = read(run/'frozen-inputs.json')
    for name, value in frozen.items():
        if digest(run/name) != value:
            raise ValueError('Frozen input changed: '+name)
    write(run/'started.json', dict(at=time.time(), parserChecks=parser_checks()))
    began = time.monotonic()
    def timeout(signum, frame):
        raise TimeoutError('Bounded study wall time exhausted')
    signal.signal(signal.SIGALRM, timeout)
    signal.alarm(plan['limits']['wallSeconds'])
    mx.set_memory_limit(plan['limits']['mlxMemoryGuidelineBytes'])
    mx.set_cache_limit(256*1024*1024)
    mx.random.seed(42)
    model, tokenizer = load(plan['modelPath'], adapter_path=None, trust_remote_code=False)
    if any('lora_' in key for key, _ in tree_flatten(model.parameters())):
        raise ValueError('Unexpected learned adapter')
    helpers = dict(semantic=load_module(run/'observer-semantic-contrast.py','semantic_protocol'),
                   category=load_module(run/'observer-weight-experiment.py','category_protocol'))
    counters = dict(generationPackets=0,totalGeneratedTokens=0)
    def infer(turns, variant, max_tokens=None, observer_task=True):
        counters['generationPackets'] += 1
        if counters['generationPackets'] > plan['limits']['generationPackets']:
            raise RuntimeError('Request budget exhausted')
        turns = request_turns(turns,variant,plan['checklist'],observer_task)
        prompt = tokenizer.apply_chat_template(turns, tokenize=False, add_generation_prompt=True,
                                               enable_thinking=variant['thinking'])
        # Verify the actual template control, not merely a Boolean configuration field.
        if prompt.count('<|think|>') != int(variant['thinking']):
            raise ValueError('Native thinking control did not match requested mode')
        prompt_ids = tokenizer.encode(prompt, add_special_tokens=False)
        if len(prompt_ids) > 4096:
            raise ValueError('Invented request unexpectedly exceeds fixed context bound')
        tokens, response = [], None
        start = time.monotonic()
        for response in stream_generate(model, tokenizer, prompt=prompt_ids,
                     max_tokens=max_tokens or variant['maxTokens'], sampler=make_sampler(temp=0)):
            tokens.append(response.token)
            counters['totalGeneratedTokens'] += 1
            if counters['totalGeneratedTokens'] > plan['limits']['totalGeneratedTokens']:
                raise RuntimeError('Generated-token budget exhausted')
            if mx.get_peak_memory() > plan['limits']['mlxMemoryGuidelineBytes']:
                raise MemoryError('MLX allocation guideline exceeded')
        elapsed = time.monotonic()-start
        if response is None:
            raise ValueError('Empty generation stream')
        if response.finish_reason == 'stop' and tokens[-1] in tokenizer.eos_token_ids:
            tokens.pop()
        raw = tokenizer.decode(tokens, skip_special_tokens=False)
        error = None
        try:
            final, thought = final_payload(raw, response.finish_reason)
        except ValueError as exc:
            final, thought, error = '', '', str(exc)
        result = dict(raw=raw,final=final,seconds=elapsed,finishReason=response.finish_reason,
                      promptTokens=len(prompt_ids),generatedTokens=response.generation_tokens,
                      thoughtTokens=len(tokenizer.encode(thought,add_special_tokens=False)) if thought else 0,
                      nativeThoughtObserved=raw.lstrip().startswith('<|channel>thought'),parseError=error,
                      promptSHA256=hashlib.sha256(prompt.encode()).hexdigest())
        mx.clear_cache()
        return result
    def assessment(case, task, final, error):
        if task == 'semantic':
            value = helpers[task].score(case, final)
            return dict(passed=value['passed'] and error is None,falseClaims=value['falseClaims'],
                        missedClaims=value['missedClaims'],uncertaintyErrors=int(value['uncertaintyError']),
                        schemaValid=value['schemaValid'],details=value)
        targets = helpers[task].score(case, final)
        return dict(passed=all(t['passOutcome'] for t in targets) and error is None,
                    falseClaims=[x for t in targets for x in t['falseActs']],
                    missedClaims=[x for t in targets for x in t['missedActs']],uncertaintyErrors=0,
                    schemaValid=all(t['schemaValid'] and t['witnessValid'] for t in targets),details=targets)
    def measure(label, cases, task, variant):
        path = run/(label+'.json')
        if path.exists():
            raise ValueError('Refusing to overwrite outcome report')
        rows = []
        for case in cases:
            generated = infer(helpers[task].messages(case), variant)
            rows.append(dict(id=case['id'],**generated,score=assessment(case,task,generated['final'],generated['parseError'])))
            result = dict(completed=len(rows)==len(cases),task=task,variant=variant,metrics=aggregate(rows),cases=rows)
            write(path,result)
        print('OUTCOMES',label,result['metrics'],flush=True)
        return result
    semantic = read(run/'semantic.json')
    category_dev = read(run/'development-category.json')['cases']
    development = {}
    for variant in plan['variants']:
        development[variant['id']] = {task:measure(variant['id']+'-development-'+task,cases,task,variant)
                    for task,cases in [('semantic',semantic['development']),('category',category_dev)]}
        write(run/'development-summary.json',{key:{t:r['metrics'] for t,r in val.items()} for key,val in development.items()})
    def rank(variant):
        m = [r['metrics'] for r in development[variant['id']].values()]
        return (sum(r['falseClaims'] for r in m),-sum(r['passed'] for r in m),
                sum(r['missedClaims'] for r in m),sum(r['uncertaintyErrors'] for r in m),
                sum(r['generatedTokens'] for r in m),variant['id'])
    base = development['direct']
    eligibility = {}
    for variant in plan['variants']:
        if variant['id']=='direct':
            continue
        eligibility[variant['id']] = eligible_candidate(base,development[variant['id']])
    eligible = [v for v in plan['variants'] if eligibility.get(v['id'],False)]
    # A fallback comparison is explicitly a failed-development experiment, not a promotion.
    pool = eligible or [v for v in plan['variants'] if v['id']!='direct']
    chosen = min(pool,key=rank)
    selected = development[chosen['id']]
    dev_gate = (eligibility[chosen['id']]
                and sum(selected[t]['metrics']['passed']-base[t]['metrics']['passed'] for t in base)>=2
                and all(selected[t]['metrics']['falseClaims']<=base[t]['metrics']['falseClaims']
                        and selected[t]['metrics']['passed']>=base[t]['metrics']['passed']
                        and selected[t]['metrics']['parseFailures']==0
                        and selected[t]['metrics']['schemaFailures']==0 for t in base))
    write(run/'selection-before-test.json',dict(chosen=chosen,developmentGateMet=dev_gate,
              eligibility=eligibility,eligiblePoolUsed=bool(eligible),rank=list(rank(chosen)),frozenInputs=frozen,at=time.time()))
    test_category = read(run/'test-category.json')['cases']
    test_results, controls = {}, {}
    for variant in [plan['variants'][0],chosen]:
        test_results[variant['id']]={task:measure(variant['id']+'-test-'+task,cases,task,variant)
                   for task,cases in [('semantic',semantic['test']),('category',test_category)]}
        rows=[]
        for case in read(run/'controls.json'):
            generated=infer([dict(role='system',content='Follow the user instruction.'),dict(role='user',content=case['prompt'])],variant,observer_task=False)
            rows.append(dict(id=case['id'],expected=case['expected'],**generated,
                             passed=generated['parseError'] is None and generated['final'].strip()==case['expected']))
        controls[variant['id']]=dict(passed=sum(r['passed'] for r in rows),total=len(rows),cases=rows)
        write(run/(variant['id']+'-controls.json'),controls[variant['id']])
    b=test_results['direct']; e=test_results[chosen['id']]
    gates=dict(development=dev_gate,semanticMinimum=e['semantic']['metrics']['passed']>=plan['gate']['minimumSemantic'],
               categoryMinimum=e['category']['metrics']['passed']>=plan['gate']['minimumCategory'],
               totalGain=sum(e[t]['metrics']['passed']-b[t]['metrics']['passed'] for t in b)>=plan['gate']['minimumAdditionalTotal'],
               noAddedUnsupportedClaims=all(e[t]['metrics']['falseClaims']<=b[t]['metrics']['falseClaims'] for t in b),
               completeOutputs=all(e[t]['metrics']['parseFailures']==0 and e[t]['metrics']['schemaFailures']==0 for t in b),
               noControlRegression=all(x['passed'] or not y['passed'] for x,y in zip(controls[chosen['id']]['cases'],controls['direct']['cases'])))
    for name,value in frozen.items():
        if digest(run/name)!=value:
            raise ValueError('Frozen input changed during inference')
    if digest(Path(plan['modelPath'])/'model.safetensors')!=plan['modelSHA256']:
        raise ValueError('Checkpoint changed')
    write(run/'completion.json',dict(completed=True,chosen=chosen,numericalGates=gates,passedAllNumericalGates=all(gates.values()),
          testMetrics={v:{task:r['metrics'] for task,r in results.items()} for v,results in test_results.items()},
          elapsedSeconds=time.monotonic()-began,mlxPeakBytes=mx.get_peak_memory(),counters=counters,
          noWeightChanges=True,noTraining=True,baseFileUnchanged=True,qualifiedForProduction=False,
          limitations='Agent-authored examples; MLX proposal only; no production critic/host validator/Ollama grammar, independent labels or live deployment.'))
    signal.alarm(0)


def aggregate(rows):
    times=sorted(r['seconds'] for r in rows)
    return dict(passed=sum(r['score']['passed'] for r in rows),total=len(rows),
                falseClaims=sum(len(r['score']['falseClaims']) for r in rows),
                missedClaims=sum(len(r['score']['missedClaims']) for r in rows),
                uncertaintyErrors=sum(r['score']['uncertaintyErrors'] for r in rows),
                parseFailures=sum(r['parseError'] is not None for r in rows),
                schemaFailures=sum(not r['score']['schemaValid'] for r in rows),
                generatedTokens=sum(r['generatedTokens'] for r in rows),thoughtTokens=sum(r['thoughtTokens'] for r in rows),
                nativeThoughtReplies=sum(r['nativeThoughtObserved'] for r in rows),
                latencySeconds=dict(p50=statistics.median(times),p95=times[math.ceil(.95*len(times))-1]))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command',choices=['prepare','run','parser-checks'])
    parser.add_argument('directory',type=Path,nargs='?')
    parser.add_argument('--model-path',type=Path)
    args=parser.parse_args()
    if args.command=='parser-checks':
        print(json.dumps(parser_checks()))
        return
    if args.directory is None:
        parser.error('directory is required')
    if args.command=='prepare':
        if args.model_path is None:
            parser.error('--model-path is required')
        prepare(args.directory.resolve(),args.model_path.resolve())
        return
    for key,value in dict(HF_HUB_OFFLINE='1',TRANSFORMERS_OFFLINE='1',HF_HUB_DISABLE_TELEMETRY='1',HF_HUB_DISABLE_IMPLICIT_TOKEN='1',TOKENIZERS_PARALLELISM='false').items():
        os.environ[key]=value
    execute(args.directory.resolve())


if __name__=='__main__':
    main()
