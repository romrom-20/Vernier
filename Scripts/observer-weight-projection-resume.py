#!/usr/bin/env python3
"""Finish controls/tests from a frozen projection selection after interrupted validation.
Never reselects weights or overwrites completed inference reports.
"""
import argparse
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import signal
import time


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('run',type=Path);args=parser.parse_args()
    run=args.run.resolve();run.relative_to((Path.cwd()/'.context').resolve())
    if (run/'completion.json').exists():raise ValueError('Experiment already completed')
    for key in ['HF_HUB_OFFLINE','TRANSFORMERS_OFFLINE','HF_HUB_DISABLE_TELEMETRY','HF_HUB_DISABLE_IMPLICIT_TOKEN']:os.environ[key]='1'
    os.environ['TOKENIZERS_PARALLELISM']='false'
    import mlx.core as mx
    import mlx.nn as nn
    import numpy as np
    from mlx_lm import load,generate
    from mlx_lm.sample_utils import make_sampler
    spec=importlib.util.spec_from_file_location('observer_protocol',Path(__file__).with_name('observer-weight-experiment.py'))
    helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)
    read,write=helper.read,helper.write
    plan=read(run/'plan.json');frozen=read(run/'frozen-inputs.json')
    for path,expected in frozen.items():
        if helper.digest(run/path)!=expected:raise ValueError('Frozen input changed: '+path)
    data=read(run/'candidate-results.json');choice=read(run/'selection-before-test.json')
    calculated=min(data['candidates'],key=lambda r:(r['generation']['falseActs'],-r['generation']['passed'],r['generation']['missedActs'],r['diagnostic']['loss']))
    if calculated!=choice['chosen']:raise ValueError('Frozen selection differs from declared rule')
    for name in ['quantized-test.json','sham-test.json','edited-test.json','random-test.json','random-development.json','reversed-development.json']:
        if (run/name).exists():raise ValueError('Refusing to rerun an existing comparison')
    previous_generations=len(read(run/'quantized-development.json')['cases'])+sum(v['generation']['total'] for v in data['shams'].values())+sum(v['generation']['total'] for v in data['candidates'])
    previous_forwards=read(run/'causal-localization.json')['baseline']['total']+sum(v['diagnostic']['total'] for v in data['shams'].values())+sum(v['diagnostic']['total'] for v in data['candidates'])
    counters=dict(teacherForcedForwards=previous_forwards,generationPackets=previous_generations)
    start= time.monotonic();prior_elapsed=time.time()-(run/'frozen-inputs.json').stat().st_mtime
    remaining=int(plan['limits']['wallSeconds']-prior_elapsed)
    if remaining<=0:raise TimeoutError('Original wall-time budget exhausted')
    def timeout(signum,frame):raise TimeoutError('Original bounded wall-time exhausted')
    signal.signal(signal.SIGALRM,timeout);signal.alarm(remaining)
    mx.set_memory_limit(plan['limits']['mlxMemoryGuidelineBytes']);mx.set_cache_limit(256*1024*1024);mx.random.seed(42)
    def budget(kind):
        counters[kind]+=1
        if counters[kind]>plan['limits'][kind] or mx.get_peak_memory()>plan['limits']['mlxMemoryGuidelineBytes']:raise RuntimeError('Original request/memory budget exceeded')
    model,tokenizer=load(plan['modelPath'],adapter_path=None,trust_remote_code=False)
    index,dose=choice['chosen']['layer'],choice['chosen']['dose'];layer=model.layers[index];original=layer.mlp.down_proj
    weights=mx.dequantize(original.weight,original.scales,original.biases,group_size=original.group_size,bits=original.bits,mode=original.mode).astype(mx.float32)
    audit=read(run/'tokenization-audit.json');pair=audit['tokenIDs'][audit['selectedReadoutVariant']]
    embedding=model.language_model.model.embed_tokens(mx.array(pair)).astype(mx.float32)
    u=(embedding[1]-embedding[0])*model.language_model.model.norm.weight.astype(mx.float32)*layer.post_feedforward_layernorm.weight.astype(mx.float32)*layer.layer_scalar
    u=u/mx.linalg.norm(u)
    geometry=read(run/'weight-geometry.json')[index];columns=geometry['selectedColumns']
    if len(columns)!=plan['columns'] or min(geometry['selectedPresentEffects'])<=0 or min(geometry['selectedScores'])<=0:raise ValueError('Frozen columns violate actual false-writing criterion')
    selected=weights[:,mx.array(columns)];component=u[:,None]*(u@selected)[None,:]
    delta=mx.zeros_like(weights);delta[:,mx.array(columns)]=component
    rng=np.random.default_rng(42);r=mx.array(rng.normal(size=u.shape).astype(np.float32));r=r-(r@u)*u;r=r/mx.linalg.norm(r)
    random_component=r[:,None]*(r@selected)[None,:];random_component*=mx.linalg.norm(delta)/mx.linalg.norm(random_component)
    random_delta=mx.zeros_like(weights);random_delta[:,mx.array(columns)]=random_component
    updated=weights-dose*delta;actual=weights-updated
    outside=mx.ones((weights.shape[1],),dtype=mx.bool_);outside[mx.array(columns)]=False
    if mx.any(actual*outside[None,:]!=0).item():raise ValueError('Weight edit escaped columns')
    norm=float(mx.linalg.norm(actual).item())
    orthogonal=actual-u[:,None]*(u@actual)[None,:]
    fraction=float(mx.linalg.norm(orthogonal).item())/norm
    if not math.isfinite(norm) or norm<=0 or fraction>1e-4:raise ValueError('Invalid projection footprint')
    prefix=f'language_model.model.layers.{index}.mlp.down_proj.weight'
    mx.save_safetensors(str(run/'projection-patch.safetensors'),{prefix:updated})
    mx.save_safetensors(str(run/'sham-dequantized.safetensors'),{prefix:weights})
    mx.save_safetensors(str(run/'projection-directions.safetensors'),dict(direction=u,randomDirection=r,delta=delta,randomDelta=random_delta))
    write(run/'patch-manifest.json',dict(layer=index,dose=dose,columns=columns,shape=list(updated.shape),effectivePositions=weights.shape[0]*len(columns),orthogonalChangeFraction=fraction,relativeFrobeniusChange=norm/float(mx.linalg.norm(weights).item()),patchSHA256=helper.digest(run/'projection-patch.safetensors'),replacement='Isolated nn.Linear fp32 output matrix; not an Ollama artifact.',randomNormRatio=float((mx.linalg.norm(random_delta)/mx.linalg.norm(delta)).item())))
    def replace(amount,random=False):
        module=nn.Linear(weights.shape[1],weights.shape[0],bias=False);module.weight=weights-amount*(random_delta if random else delta);layer.mlp.down_proj=module
    development=read(run/'corpus/development-packets.json')['cases'];native={row['id']:row['raw'] for row in read(run/'quantized-development.json')['cases']};case_map={c['id']:c for c in development}
    true_ids=mx.array([p[0] for p in audit['tokenIDs']]);false_ids=mx.array([p[1] for p in audit['tokenIDs']]);queries=[]
    for q in read(run/'corpus/diagnostics.json'):
        case=case_map[q['case']];raw=native[q['case']];source=case['expected'][0]['sourceID'];source_match=re.search(re.escape(json.dumps(source))+r'\s*:\s*{',raw)
        match=re.search(re.escape(json.dumps(q['field']))+r'\s*:',raw[source_match.end():]);prefix=raw[:source_match.end()+match.end()]
        prompt=tokenizer.apply_chat_template(helper.messages(case),tokenize=False,add_generation_prompt=True,enable_thinking=False)+prefix
        queries.append(dict(q,tokens=tokenizer.encode(prompt,add_special_tokens=False)))
    def probe():
        rows=[]
        for q in queries:
            budget('teacherForcedForwards');logits=model(mx.array([q['tokens']]))[0,-1];margin=(mx.logsumexp(logits[true_ids])-mx.logsumexp(logits[false_ids])).item();signed=margin if q['expected'] else -margin
            rows.append(dict(case=q['case'],field=q['field'],expected=q['expected'],margin=margin,correct=(margin>0)==q['expected'],loss=max(0,-signed)+math.log1p(math.exp(-abs(signed)))))
        return dict(loss=sum(r['loss'] for r in rows)/len(rows),correct=sum(r['correct'] for r in rows),wrongNegatives=sum(not r['correct'] and not r['expected'] for r in rows),total=len(rows),cases=rows)
    def generations(label,cases,amount=None,random=False):
        if amount is not None:replace(amount,random)
        rows=[]
        try:
            for case in cases:
                budget('generationPackets');began=time.monotonic();prompt=tokenizer.apply_chat_template(helper.messages(case),tokenize=False,add_generation_prompt=True,enable_thinking=False)
                text=generate(model,tokenizer,prompt=prompt,sampler=make_sampler(temp=0),max_tokens=512,verbose=False);targets=helper.score(case,text)
                rows.append(dict(id=case['id'],seconds=time.monotonic()-began,raw=text,targets=targets,passOutcome=all(t['passOutcome'] for t in targets)))
                write(run/(label+'.json'),dict(completed=len(rows)==len(cases),syntheticOnly=True,proposalOnly=True,noCritic=True,productionHostValidation=False,total=len(rows),expectedTotal=len(cases),passed=sum(r['passOutcome'] for r in rows),cases=rows));print('GENERATE',label,case['id'],rows[-1]['passOutcome'],flush=True);mx.clear_cache()
        finally:layer.mlp.down_proj=original
        targets=[t for row in rows for t in row['targets']]
        return dict(passed=sum(r['passOutcome'] for r in rows),total=len(rows),falseActs=sum(len(t['falseActs']) for t in targets),missedActs=sum(len(t['missedActs']) for t in targets))
    # Replay the fixed candidate's diagnostics before completing any comparisons.
    replace(dose)
    try:replayed=probe()
    finally:layer.mlp.down_proj=original
    for before,now in zip(choice['chosen']['diagnostic']['cases'],replayed['cases']):
        if abs(before['margin']-now['margin'])>.001:raise ValueError('Frozen projected candidate did not replay')
    write(run/'resume-audit.json',dict(reason='MLX Boolean indexing in a footprint check was unsupported; validation uses a broadcast mask instead.',selectionUnchanged=True,allCandidateMarginsReplayed=True))
    for name,amount,random in [('random',dose,True),('reversed',-dose,False)]:
        replace(amount,random)
        try:diagnostic=probe()
        finally:layer.mlp.down_proj=original
        write(run/(name+'-control-summary.json'),dict(diagnostic=diagnostic,generation=generations(name+'-development',development,amount,random)))
    fresh=read(run/'corpus/test-packets.json')['cases']
    for name,amount,random in [('quantized',None,False),('sham',0,False),('edited',dose,False),('random',dose,True)]:generations(name+'-test',fresh,amount,random)
    for name,amount in [('quantized',None),('sham',0),('edited',dose)]:
        if amount is not None:replace(amount)
        try:
            rows=[]
            for case in read(run/'controls.json'):
                budget('generationPackets');prompt=tokenizer.apply_chat_template([dict(role='user',content=case['prompt'])],tokenize=False,add_generation_prompt=True,enable_thinking=False)
                raw=generate(model,tokenizer,prompt=prompt,sampler=make_sampler(temp=0),max_tokens=64,verbose=False);rows.append(dict(id=case['id'],raw=raw,expected=case['expected'],passOutcome=raw.strip()==case['expected']))
            write(run/(name+'-controls.json'),dict(completed=True,passed=sum(r['passOutcome'] for r in rows),total=len(rows),cases=rows))
        finally:layer.mlp.down_proj=original
    for path,expected in frozen.items():
        if helper.digest(run/path)!=expected:raise ValueError('Frozen input changed')
    if helper.digest(Path(plan['modelPath'])/'model.safetensors')!=plan['modelSHA256']:raise ValueError('Base checkpoint changed')
    write(run/'completion.json',dict(completed=True,baseFileUnchanged=True,noGradients=True,noOptimizer=True,noAdapter=True,elapsedSeconds=prior_elapsed+time.monotonic()-start,resumed=True,mlxPeakBytesThisProcess=mx.get_peak_memory(),counters=counters))
    signal.alarm(0)


if __name__=='__main__':main()
