#!/usr/bin/env python3
"""Causal MLP localization and selective weight-column projection, without training.
Requires a frozen invented corpus, an isolated MLX checkpoint and plan.json.
"""
import argparse
import importlib.util
import json
import math
import os
import re
from pathlib import Path
import signal
import time


def load_support():
    spec = importlib.util.spec_from_file_location('observer_protocol', Path(__file__).with_name('observer-weight-experiment.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def execute(run):
    import mlx.core as mx
    import mlx.nn as nn
    import numpy as np
    from mlx_lm import load, generate
    from mlx_lm.sample_utils import make_sampler
    from mlx.utils import tree_flatten

    helper = load_support()
    read, write = helper.read, helper.write
    plan = read(run / 'plan.json')
    counters = dict(teacherForcedForwards=0, generationPackets=0)
    began = time.monotonic()
    mx.set_memory_limit(plan['limits']['mlxMemoryGuidelineBytes'])
    mx.set_cache_limit(256 * 1024 * 1024)
    mx.random.seed(42)
    def timed_out(signum, frame):
        raise TimeoutError('Bounded experiment wall time exhausted')
    signal.signal(signal.SIGALRM, timed_out)
    signal.alarm(plan['limits']['wallSeconds'])
    def budget(kind):
        counters[kind] += 1
        if counters[kind] > plan['limits'][kind]:
            raise RuntimeError('Experiment request budget exceeded')
        if mx.get_peak_memory() > plan['limits']['mlxMemoryGuidelineBytes']:
            raise MemoryError('MLX allocation budget exceeded')
    frozen = {str(p.relative_to(run)): helper.digest(p) for p in [run/'plan.json',run/'controls.json',*sorted((run/'corpus').glob('*.json'))]}
    write(run/'frozen-inputs.json', frozen)
    model, tokenizer = load(plan['modelPath'], adapter_path=None, trust_remote_code=False)
    assert not any('lora_' in key for key, _ in tree_flatten(model.parameters()))
    layers = model.layers
    text_model = model.language_model.model
    forms=[('true','false'),(' true',' false')]
    form_ids=[]
    for yes,no in forms:
        yes_ids=tokenizer.encode(yes,add_special_tokens=False);no_ids=tokenizer.encode(no,add_special_tokens=False)
        if len(yes_ids)!=1 or len(no_ids)!=1:raise ValueError('Boolean form must be one token')
        form_ids.append((yes_ids[0],no_ids[0]))
    true_ids=mx.array([pair[0] for pair in form_ids]);false_ids=mx.array([pair[1] for pair in form_ids])
    development=read(run/'corpus/development-packets.json')['cases']
    extra_selection=read(run/plan['selectionExtraPackets'])['cases'] if plan.get('selectionExtraPackets') else []
    selection_cases=development+extra_selection
    case_map={case['id']:case for case in development}
    native_rows=[];native_outputs={}
    for case in development:
        budget('generationPackets');start=time.monotonic()
        prompt=tokenizer.apply_chat_template(helper.messages(case),tokenize=False,add_generation_prompt=True,enable_thinking=False)
        raw=generate(model,tokenizer,prompt=prompt,sampler=make_sampler(temp=0),max_tokens=512,verbose=False)
        targets=helper.score(case,raw)
        if any(not t['schemaValid'] or not t['witnessValid'] for t in targets):raise ValueError('Native diagnostic source must have valid structure')
        parsed=raw.strip()
        if parsed.startswith('```json') and parsed.endswith('```'):parsed=parsed[7:-3].strip()
        native_outputs[case['id']]=(raw,json.loads(parsed))
        native_rows.append(dict(id=case['id'],seconds=time.monotonic()-start,raw=raw,targets=targets,passOutcome=all(t['passOutcome'] for t in targets)))
    write(run/'quantized-development.json',dict(completed=True,syntheticOnly=True,proposalOnly=True,total=len(native_rows),expectedTotal=len(native_rows),passed=sum(r['passOutcome'] for r in native_rows),cases=native_rows))
    native_targets=[t for r in native_rows for t in r['targets']]
    native_summary=dict(passed=sum(r['passOutcome'] for r in native_rows),total=len(native_rows),falseActs=sum(len(t['falseActs']) for t in native_targets),missedActs=sum(len(t['missedActs']) for t in native_targets))
    queries=[]
    for entry in read(run/'corpus/diagnostics.json'):
        case=case_map[entry['case']];raw,parsed=native_outputs[case['id']]
        source=case['expected'][0]['sourceID']
        source_match=re.search(re.escape(json.dumps(source))+r'\s*:\s*{',raw)
        if source_match is None:raise ValueError('Missing native source object')
        match=re.search(re.escape(json.dumps(entry['field']))+r'\s*:',raw[source_match.end():])
        if match is None:raise ValueError('Missing native Boolean field')
        prefix=raw[:source_match.end()+match.end()]
        rendered=tokenizer.apply_chat_template(helper.messages(case),tokenize=False,add_generation_prompt=True,enable_thinking=False)
        tokens=tokenizer.encode(rendered+prefix,add_special_tokens=False)
        for pair,ids in zip(forms,form_ids):
            for word,token in zip(pair,ids):
                if tokenizer.encode(rendered+prefix+word,add_special_tokens=False)!=tokens+[token]:raise ValueError('Boolean boundary mismatch')
        queries.append(dict(entry,tokens=tokens,nativeBoolean=parsed['readings'][source][entry['field']]))
    variant_counts=[0,0]
    def decision(logits):
        margin=(mx.logsumexp(logits[true_ids])-mx.logsumexp(logits[false_ids])).item()
        choices=[logits[token].item() for pair in form_ids for token in pair]
        best=max(range(len(choices)),key=lambda i:choices[i])
        return margin,best%2==0,best//2
    original_call=nn.QuantizedLinear.__call__
    ids={id(layer.mlp.down_proj):i for i,layer in enumerate(layers)}
    capture_mode=False;ablate=None;captured={}
    def observed(module,x):
        y=original_call(module,x)
        index=ids.get(id(module))
        if index is not None:
            if capture_mode:captured[index]=(x[0,-1,:],y[0,-1,:])
            if index==ablate:return mx.zeros_like(y)
        return y
    def probe():
        rows=[]
        for q in queries:
            budget('teacherForcedForwards')
            logits=model(mx.array([q['tokens']]))[0,-1]
            margin,greedy,variant=decision(logits)
            signed=margin if q['expected'] else -margin
            rows.append(dict(case=q['case'],field=q['field'],expected=q['expected'],margin=margin,
                             correct=(margin>0)==q['expected'],loss=max(0,-signed)+math.log1p(math.exp(-abs(signed)))))
        return dict(loss=sum(r['loss'] for r in rows)/len(rows),correct=sum(r['correct'] for r in rows),
                    wrongNegatives=sum(not r['correct'] and not r['expected'] for r in rows),total=len(rows),cases=rows)
    # Capture all matched-pair activations while recording the untouched baseline.
    activations={i:dict(present=[],absent=[]) for i in range(len(layers))}
    baseline_rows=[]
    try:
        nn.QuantizedLinear.__call__=observed
        capture_mode=True
        for qi,q in enumerate(queries):
            captured.clear();budget('teacherForcedForwards')
            logits=model(mx.array([q['tokens']]))[0,-1]
            margin,greedy,variant=decision(logits)
            if greedy!=q['nativeBoolean']:raise ValueError('Teacher prefix does not replay the actual greedy Boolean decision')
            variant_counts[variant]+=1
            signed=margin if q['expected'] else -margin
            baseline_rows.append(dict(case=q['case'],field=q['field'],expected=q['expected'],margin=margin,
                                      correct=(margin>0)==q['expected'],loss=max(0,-signed)+math.log1p(math.exp(-abs(signed)))))
            saved={}
            for index,(features,output) in captured.items():
                norm=mx.rsqrt(mx.mean(output.astype(mx.float32)**2)+layers[index].post_feedforward_layernorm.eps)
                normalized=features.astype(mx.float32)*norm
                mx.eval(normalized)
                activations[index]['present' if q['expected'] else 'absent'].append(normalized)
                saved[f'layer_{index}_features']=features;saved[f'layer_{index}_output']=output
            mx.save_safetensors(str(run/f'mlp-activations-{qi:02d}.safetensors'),saved)
            mx.clear_cache()
        capture_mode=False
        baseline=dict(loss=sum(r['loss'] for r in baseline_rows)/len(baseline_rows),correct=sum(r['correct'] for r in baseline_rows),wrongNegatives=sum(not r['correct'] and not r['expected'] for r in baseline_rows),total=len(baseline_rows),cases=baseline_rows)
        # The output direction must correspond to the model's actual native token choice.
        selected_variant=max(range(len(variant_counts)),key=lambda i:variant_counts[i])
        pair=form_ids[selected_variant]
        embedding=text_model.embed_tokens(mx.array(pair)).astype(mx.float32)
        readout=(embedding[1]-embedding[0])*text_model.norm.weight.astype(mx.float32)
        write(run/'tokenization-audit.json',dict(forms=forms,tokenIDs=form_ids,nativeVariantCounts=variant_counts,selectedReadoutVariant=selected_variant,allNativeDecisionsReplayed=True,likelihood='logsumexp over both spaced and bare variants'))
        geometry=[]
        for index,layer in enumerate(layers):
            module=layer.mlp.down_proj
            weights=mx.dequantize(module.weight,module.scales,module.biases,group_size=module.group_size,bits=module.bits,mode=module.mode).astype(mx.float32)
            direction=readout*layer.post_feedforward_layernorm.weight.astype(mx.float32)*layer.layer_scalar
            direction=direction/mx.linalg.norm(direction)
            present=mx.stack(activations[index]['present'])
            absent=mx.stack(activations[index]['absent'])
            alignment=direction@weights
            present_effect=(present*alignment).mean(0)
            absent_influence=mx.abs(absent*alignment).mean(0)
            scores=present_effect-absent_influence
            eligible=(present_effect>0)&(scores>0)
            mx.eval(scores,eligible)
            if int(mx.sum(eligible).item())<plan['columns']:raise ValueError('Insufficient actually false-writing selective columns')
            masked=mx.where(eligible,scores,mx.array(float('-inf')))
            columns=mx.argsort(masked)[-plan['columns']:].tolist()
            geometry.append(dict(layer=index,weightShape=list(weights.shape),positiveScoreColumns=int(mx.sum(eligible).item()),
                                 selectedColumns=columns,selectedPresentEffects=[float(present_effect[i].item()) for i in columns],selectedAbsentInfluence=[float(absent_influence[i].item()) for i in columns],selectedScores=[float(scores[i].item()) for i in columns],
                                 weightFrobeniusNorm=float(mx.linalg.norm(weights).item()),directionNorm=float(mx.linalg.norm(direction).item())))
            mx.clear_cache()
        write(run/'weight-geometry.json',geometry)
        tracing=[]
        if plan.get('reuseLocalizationFrom'):
            previous=Path(plan['reuseLocalizationFrom'])
            if helper.digest(previous/'corpus/development-packets.json')!=helper.digest(run/'corpus/development-packets.json'):raise ValueError('Cached localization development input differs')
            previous_plan=read(previous/'plan.json')
            if previous_plan['modelPath']!=plan['modelPath'] or previous_plan['modelSHA256']!=plan['modelSHA256']:raise ValueError('Cached localization base differs')
            prior=read(previous/'causal-localization.json')
            for before,now in zip(prior['baseline']['cases'],baseline_rows):
                if before['case']!=now['case'] or abs(before['margin']-now['margin'])>.001:raise ValueError('Cached native baseline does not replay')
            tracing=prior['ranked']
            write(run/'localization-reuse.json',dict(source=str(previous),developmentHash=helper.digest(run/'corpus/development-packets.json'),allBaselineMarginsReplayed=True))
        else:
            for index in range(len(layers)):
                ablate=index
                result=probe();result['layer']=index
                result['newWrongNegatives']=sum((not a['correct']) and not a['expected'] and b['correct'] for a,b in zip(result['cases'],baseline_rows))
                tracing.append(result)
                print('CAUSAL MLP',index,result['correct'],result['wrongNegatives'],result['loss'],flush=True)
                write(run/'localization-progress.json',tracing)
        ablate=None
    finally:
        nn.QuantizedLinear.__call__=original_call
    tracing.sort(key=lambda r:(r['newWrongNegatives'],r['loss']))
    nominated=[r['layer'] for r in tracing[:plan['candidateLayers']]]
    write(run/'causal-localization.json',dict(baseline=baseline,ranked=tracing,nominated=nominated))
    edits={}
    for index in nominated:
        original=layers[index].mlp.down_proj
        weights=mx.dequantize(original.weight,original.scales,original.biases,group_size=original.group_size,bits=original.bits,mode=original.mode).astype(mx.float32)
        direction=readout*layers[index].post_feedforward_layernorm.weight.astype(mx.float32)*layers[index].layer_scalar
        direction=direction/mx.linalg.norm(direction)
        columns=geometry[index]['selectedColumns']
        selected=weights[:,mx.array(columns)]
        component=direction[:,None]*(direction@selected)[None,:]
        delta=mx.zeros_like(weights);delta[:,mx.array(columns)]=component
        edits[index]=dict(original=original,weights=weights,direction=direction,columns=columns,delta=delta)
    def replace(index,dose=0,random_delta=None):
        info=edits[index]
        new=nn.Linear(info['weights'].shape[1],info['weights'].shape[0],bias=False)
        new.weight=info['weights']-dose*(random_delta if random_delta is not None else info['delta'])
        layers[index].mlp.down_proj=new
    def restore(index):layers[index].mlp.down_proj=edits[index]['original']
    def diagnostic(index,dose):
        replace(index,dose)
        try:return probe()
        finally:restore(index);mx.clear_cache()
    def generations(label,cases,index=None,dose=0,random_delta=None):
        if index is not None:replace(index,dose,random_delta)
        rows=[]
        try:
            for case in cases:
                budget('generationPackets');start=time.monotonic()
                prompt=tokenizer.apply_chat_template(helper.messages(case),tokenize=False,add_generation_prompt=True,enable_thinking=False)
                text=generate(model,tokenizer,prompt=prompt,sampler=make_sampler(temp=0),max_tokens=512,verbose=False)
                targets=helper.score(case,text)
                rows.append(dict(id=case['id'],seconds=time.monotonic()-start,raw=text,targets=targets,passOutcome=all(t['passOutcome'] for t in targets)))
                write(run/(label+'.json'),dict(completed=len(rows)==len(cases),syntheticOnly=True,proposalOnly=True,noCritic=True,productionHostValidation=False,total=len(rows),expectedTotal=len(cases),passed=sum(r['passOutcome'] for r in rows),cases=rows))
                print('GENERATE',label,case['id'],rows[-1]['passOutcome'],flush=True);mx.clear_cache()
        finally:
            if index is not None:restore(index)
        targets=[t for r in rows for t in r['targets']]
        return dict(passed=sum(r['passOutcome'] for r in rows),total=len(rows),falseActs=sum(len(t['falseActs']) for t in targets),missedActs=sum(len(t['missedActs']) for t in targets))
    base_dev=native_summary
    if extra_selection:generations('quantized-extra-development',extra_selection)
    candidates=[];shams={}
    for index in nominated:
        sham_diag=diagnostic(index,0)
        shams[index]=dict(diagnostic=sham_diag,generation=generations(f'sham-{index}-development',selection_cases,index,0))
        for dose in plan['doses']:
            diag=diagnostic(index,dose)
            result=generations(f'candidate-{index}-{dose}-development',selection_cases,index,dose)
            candidates.append(dict(layer=index,dose=dose,diagnostic=diag,generation=result))
            write(run/'candidate-results.json',dict(candidates=candidates,shams=shams))
    # Candidate choice uses full development outcomes, never fresh test results.
    chosen=min(candidates,key=lambda r:(r['generation']['falseActs'],-r['generation']['passed'],r['generation']['missedActs'],r['diagnostic']['loss']))
    index,dose=chosen['layer'],chosen['dose'];info=edits[index]
    selected_sham=shams[index]['generation']
    development_gain=chosen['generation']['passed']>selected_sham['passed'] and chosen['generation']['falseActs']<=selected_sham['falseActs']
    rng=np.random.default_rng(42);direction=info['direction']
    random_direction=mx.array(rng.normal(size=direction.shape).astype(np.float32))
    random_direction=random_direction-(random_direction@direction)*direction
    random_direction=random_direction/mx.linalg.norm(random_direction)
    selected=info['weights'][:,mx.array(info['columns'])]
    random_component=random_direction[:,None]*(random_direction@selected)[None,:]
    random_component=random_component*(mx.linalg.norm(info['delta'])/mx.linalg.norm(random_component))
    random_delta=mx.zeros_like(info['weights']);random_delta[:,mx.array(info['columns'])]=random_component
    mx.eval(random_delta)
    selection=dict(chosen=chosen,sham=shams[index],developmentGainWithoutNewFalseActs=development_gain,
                   randomNormRatio=float((mx.linalg.norm(random_delta)/mx.linalg.norm(info['delta'])).item()))
    write(run/'selection-before-test.json',selection)
    # Save actual full linear weights, original dequantization and direction data.
    updated=info['weights']-dose*info['delta']
    actual_delta=info['weights']-updated
    outside=mx.ones((info['weights'].shape[1],),dtype=mx.bool_);outside[mx.array(info['columns'])]=False
    if mx.any(actual_delta*outside[None,:]!=0).item():raise ValueError('Weight edit escaped declared columns')
    orthogonal=actual_delta-direction[:,None]*(direction@actual_delta)[None,:]
    orthogonal_fraction=float((mx.linalg.norm(orthogonal)/mx.linalg.norm(actual_delta)).item())
    if orthogonal_fraction>1e-4:raise ValueError('Weight edit changed unrelated column directions beyond rounding tolerance')
    prefix=f'language_model.model.layers.{index}.mlp.down_proj.weight'
    mx.save_safetensors(str(run/'projection-patch.safetensors'),{prefix:updated})
    mx.save_safetensors(str(run/'sham-dequantized.safetensors'),{prefix:info['weights']})
    mx.save_safetensors(str(run/'projection-directions.safetensors'),dict(direction=direction,randomDirection=random_direction,delta=info['delta'],randomDelta=random_delta))
    write(run/'patch-manifest.json',dict(layer=index,dose=dose,columns=info['columns'],shape=list(updated.shape),
          effectivePositions=updated.shape[0]*len(info['columns']),orthogonalChangeFraction=orthogonal_fraction,
          relativeFrobeniusChange=float((mx.linalg.norm(actual_delta)/mx.linalg.norm(info['weights'])).item()),
          patchSHA256=helper.digest(run/'projection-patch.safetensors'),replacement='Replace this isolated module with nn.Linear fp32; sham conversion must be compared separately. Not an Ollama artifact.'))
    # Causal controls: equal-size random edit and opposite signed edit on the same columns.
    for label,control_dose,random in [('random',dose,random_delta),('reversed',-dose,None)]:
        replace(index,control_dose,random)
        try:diag=probe()
        finally:restore(index)
        gen=generations(label+'-development',selection_cases,index,control_dose,random)
        write(run/(label+'-control-summary.json'),dict(diagnostic=diag,generation=gen))
    fresh=read(run/'corpus/test-packets.json')['cases']
    for label,layer,amount,random in [('quantized',None,0,None),('sham',index,0,None),('edited',index,dose,None),('random',index,dose,random_delta)]:
        generations(label+'-test',fresh,layer,amount,random)
    for label,layer,amount in [('quantized',None,0),('sham',index,0),('edited',index,dose)]:
        if layer is not None:replace(layer,amount)
        try:
            rows=[]
            for case in read(run/'controls.json'):
                budget('generationPackets')
                prompt=tokenizer.apply_chat_template([dict(role='user',content=case['prompt'])],tokenize=False,add_generation_prompt=True,enable_thinking=False)
                text=generate(model,tokenizer,prompt=prompt,sampler=make_sampler(temp=0),max_tokens=64,verbose=False)
                rows.append(dict(id=case['id'],raw=text,expected=case['expected'],passOutcome=text.strip()==case['expected']))
            write(run/(label+'-controls.json'),dict(completed=True,passed=sum(r['passOutcome'] for r in rows),total=len(rows),cases=rows))
        finally:
            if layer is not None:restore(layer)
    for path,expected in frozen.items():
        if helper.digest(run/path)!=expected:raise ValueError('Frozen input changed')
    if helper.digest(Path(plan['modelPath'])/'model.safetensors')!=plan['modelSHA256']:raise ValueError('Base checkpoint changed')
    write(run/'completion.json',dict(completed=True,baseFileUnchanged=True,noGradients=True,noOptimizer=True,noAdapter=True,
          elapsedSeconds=time.monotonic()-began,mlxPeakBytes=mx.get_peak_memory(),counters=counters))
    signal.alarm(0)


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('run',type=Path);args=parser.parse_args()
    run=args.run.resolve();run.relative_to((Path.cwd()/'.context').resolve())
    if (run/'frozen-inputs.json').exists():raise ValueError('Refusing to overwrite an existing experiment')
    for name in ['HF_HUB_OFFLINE','TRANSFORMERS_OFFLINE','HF_HUB_DISABLE_TELEMETRY','HF_HUB_DISABLE_IMPLICIT_TOKEN']:os.environ[name]='1'
    os.environ['TOKENIZERS_PARALLELISM']='false'
    execute(run)


if __name__=='__main__':main()
