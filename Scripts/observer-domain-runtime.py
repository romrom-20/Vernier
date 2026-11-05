#!/usr/bin/env python3
"""Loopback-only Ollama audit of frozen invented domain profiles and controls.

Does not select a model, change preferences, connect personal sources or execute
any action described in the fixtures. Actual coding goals use WorkModelProbe.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import signal
import time
import urllib.request


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,*args,**kwargs):raise RuntimeError('Loopback redirect refused')


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('root',type=Path);p.add_argument('--model',required=True);p.add_argument('--report',type=Path,required=True);p.add_argument('--split',choices=['dev','test'],default='test');p.add_argument('--scope',choices=['current-human-1','whole-excerpt-2'],default='current-human-1');p.add_argument('--suite',choices=['original','capacity'],default='original')
    args=p.parse_args();root=args.root.resolve()
    if args.report.exists():raise ValueError('Refusing repeated runtime comparison')
    if args.model not in ['gemma4:e2b-it-qat','vernier-domain-base:e2b','vernier-observer:e2b-domains-v1','qwen3.5:4b-q4_K_M','vernier-qwen:4b-observer','vernier-qwen:9b-observer']:raise ValueError('Unknown audit model')
    if args.split=='test' and not (root/'selection.json').exists():raise ValueError('Freeze selection before reserved runtime evaluation')
    source=root/'observer-domain-scoring-4.py'
    spec=importlib.util.spec_from_file_location('domain',source);study=importlib.util.module_from_spec(spec);spec.loader.exec_module(study)
    study.frozen(root)
    transfer=study.read(root/'transfer-frozen.json') if (root/'transfer-frozen.json').exists() else None
    capacity=None
    if args.suite=='capacity':
        if args.split!='test' or args.scope!='whole-excerpt-2':raise ValueError('Capacity suite requires its declared test method')
        if args.model not in ['gemma4:e2b-it-qat','vernier-qwen:9b-observer']:raise ValueError('Unselected capacity comparison')
        selection=study.read(root/'capacity-selection.json')
        if selection.get('profileCandidate')!='vernier-qwen:9b-observer':raise ValueError('Freeze capacity selection before reserved access')
        capacity=study.read(root/'capacity-reserved-frozen.json')
        transfer=study.read(root/'capacity-transfer-frozen.json')
        if study.digest(root/capacity['path'])!=capacity['sha256']:raise ValueError('Capacity inputs changed')
    if transfer and study.digest(root/transfer['path'])!=transfer['sha256']:raise ValueError('Transfer input changed')
    def expired(a,b):raise TimeoutError('Ollama audit wall limit')
    signal.signal(signal.SIGALRM,expired);signal.alarm(1200)
    opener=urllib.request.build_opener(NoRedirect)
    def generate(messages,json_mode,schema=None):
        body=dict(model=args.model,messages=messages,think=False,stream=False,keep_alive='30s',options=dict(temperature=0,num_ctx=8192,num_predict=512))
        if json_mode:body['format']=schema or 'json'
        request=urllib.request.Request('http://127.0.0.1:11434/api/chat',data=json.dumps(body).encode(),headers={'Content-Type':'application/json'})
        began=time.monotonic()
        with opener.open(request,timeout=180) as response:value=json.load(response)
        return value['message']['content'],value.get('done_reason'),time.monotonic()-began
    rows=[];controls=[]
    cases=study.read(root/capacity['path']) if capacity else study.read(root/f'corpus/profile-{args.split}.json')
    if args.split=='test' and transfer:cases+=study.read(root/transfer['path'])
    for c in cases:
        messages=study.profile_messages(c)
        if args.scope=='whole-excerpt-2':
            first='Assess the CURRENT human reply H using earlier human U0 and assistant A as context.'
            clearer="Read the WHOLE excerpt. Assess H's choices, permissions and personal report separately from A's completion claim. A's claim counts even when H does not repeat it."
            if first not in messages[1]['content']:raise ValueError('Unexpected frozen task')
            messages[1]['content']=messages[1]['content'].replace(first,clearer,1)
            messages[1]['content']+='\nOperational contrasts: leaving an undecided selection to AI is choiceDelegated, not a separate choiceMade. Applying an already approved selection is executionAuthorized, not choiceDelegated. If both choosing and acting are explicitly authorized, both flags can be true. "Have yet to try" clearly denies an actual attempt, and "will try after work" clearly describes a future attempt: these do not make uncertain true. "Somebody apparently did it" leaves the actor uncertain. Do not credit a quoted first-person statement to the human merely because it contains "I".'
        schema=None
        if args.scope=='whole-excerpt-2':
            properties={'profile':dict(type='string',enum=[c['profile']]),'witnessID':dict(type='string',enum=['H'])}
            properties.update({f:dict(type='boolean') for f in study.FIELDS})
            schema=dict(type='object',properties=properties,required=list(properties),additionalProperties=False)
        raw,finish,seconds=generate(messages,True,schema)
        try:score=study.score_profile(c,raw)
        except (AttributeError,TypeError,KeyError,ValueError):score=dict(valid=False,passed=False,falseClaims=[],missedClaims=[])
        score['passed'] &= finish=='stop'
        rows.append(dict(id=c['id'],profile=c['profile'],group=c.get('group',c['profile']),promptSHA256=hashlib.sha256(json.dumps(messages,sort_keys=True).encode()).hexdigest(),schemaSHA256=hashlib.sha256(json.dumps(schema,sort_keys=True).encode()).hexdigest(),raw=raw,score=score,finishReason=finish,seconds=seconds))
        study.write(args.report,dict(completed=False,model=args.model,promptVariant=args.scope,syntheticOnly=True,profileCases=rows,controls=controls))
    # Controls have only a general instruction, never observer/JSON-only system text.
    for c in (study.read(root/'controls.json') if args.split=='test' else []):
        messages=[dict(role='system',content='Follow the user instruction.'),dict(role='user',content=c['prompt'])]
        raw,finish,seconds=generate(messages,False)
        controls.append(dict(id=c['id'],raw=raw,expected=c['expected'],passed=finish=='stop' and raw.strip()==c['expected'],seconds=seconds))
        study.write(args.report,dict(completed=False,model=args.model,syntheticOnly=True,profileCases=rows,controls=controls))
    metrics={profile:dict(passed=sum(c['score']['passed'] for c in rows if c['group']==profile),total=sum(c['group']==profile for c in rows),falseClaims=sum(len(c['score']['falseClaims']) for c in rows if c['group']==profile)) for profile in ['coding','personal','coding-transfer','personal-transfer']}
    study.write(args.report,dict(completed=True,model=args.model,promptVariant=args.scope,syntheticOnly=True,profileCases=rows,controls=controls,metrics=metrics,controlsPassed=sum(c['passed'] for c in controls),limits='Invented profile assessment, not personal ingestion or verified real-world actions. JSON-mode runtime differs from unconstrained MLX generation.'))
    study.frozen(root)
    if capacity and study.digest(root/capacity['path'])!=capacity['sha256']:raise ValueError('Capacity inputs changed during evaluation')
    if transfer and study.digest(root/transfer['path'])!=transfer['sha256']:raise ValueError('Transfer inputs changed during evaluation')
    print(metrics,flush=True)


if __name__=='__main__':main()
