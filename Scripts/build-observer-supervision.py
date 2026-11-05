#!/usr/bin/env python3
"""Invented source-fact curriculum. Never reads conversations or personal data."""
import argparse
import hashlib
import json
from pathlib import Path

FIELDS = ['choiceMade', 'choiceDelegated', 'attemptReported', 'uncertain']
DOMAINS = [
    dict(topic='contact import',goal='Import the same contact twice without duplicate entries.',
         report='I imported the same contact twice and two entries appeared.',
         check='Import one contact twice and compare the number of saved entries.'),
    dict(topic='reader navigation',goal='Advance exactly one page for each press of Next.',
         report='I pressed Next once and the reader advanced two pages.',
         check='Press Next once and compare the page before and after.'),
    dict(topic='timer alarm',goal='Play one alarm when the countdown finishes.',
         report='I started one countdown and it played the alarm three times.',
         check='Run one short countdown and count the alarm sounds.'),
    dict(topic='archive restore',goal='Restore every original entry from an archive.',
         report='I restored the archive myself and the last entry was missing.',
         check='Restore the same archive and compare its entries with the original.'),
]

# Each row explicitly distinguishes the current speech act from a past choice,
# an actual attempt, permission to choose, and execution of an already chosen plan.
# category=None means the existing category ontology does not represent that
# delegation/ambiguity distinction clearly; do not invent a category gold label.
RECIPES = [
    ('local','A hosted service could process the {topic} records.','Keep all these records on this computer.', ['directed'],['choiceMade'],'none','human_choice',None),
    ('history','I propose replacing the {topic} records.','Preserve the old records and append the new ones separately.',['directed'],['choiceMade'],'none','human_choice',None),
    ('current-choice','There are two {topic} storage approaches.','I choose file storage for this task.',['directed'],['choiceMade'],'none','human_choice',None),
    ('settled-choice','Someone needs to select the {topic} approach.','I have selected the local approach.',None,['choiceMade'],'settled_choice','human_choice',None),
    ('changed-choice','I will keep the earlier {topic} layout.','I changed my choice. Put both groups on one page.',['directed'],['choiceMade'],'none','human_choice',None),
    ('no-account','The {topic} flow could require an account.','Do not require an account. Use a local file.',['directed'],['choiceMade'],'none','human_choice',None),
    ('delegate-choice','The {topic} approach is undecided.','You choose the approach. I hand that decision to you.',None,['choiceDelegated'],'none','ai_authorized_choice',None),
    ('delegate-explicit','We can pick either {topic} library.','I authorize you to choose the library yourself.',None,['choiceDelegated'],'none','ai_authorized_choice',None),
    ('delegate-implied','Who should select the {topic} method?','Make that method choice for me within the given limits.',None,['choiceDelegated'],'none','ai_authorized_choice',None),
    ('delegate-broad','We still need a {topic} strategy.','Do whatever you think is best; you decide the strategy.',None,['choiceDelegated'],'none','ai_authorized_choice',None),
    ('proceed','I can execute the approved {topic} plan.','Proceed with the plan we approved.',['continued'],[],'none','existing_plan_execution','handoff'),
    ('proceed-review','The approved {topic} patch is ready.','Apply that approved patch. I will review it later.',['continued'],[],'future_review','existing_plan_execution','handoff'),
    ('implement-choice','The {topic} approach was already selected.','Implement the approach I already selected.',['continued'],[],'none','existing_plan_execution','handoff'),
    ('execute','I can run the agreed {topic} operation.','Execute the operation as agreed.',['continued'],[],'none','existing_plan_execution','handoff'),
    ('explain','The {topic} change is ready.','Explain how this avoids the original failure.',['checked'],[],'none','none','check'),
    ('show-check','The {topic} guard should work.','Show the check on the original failing input.',['checked'],[],'none','none','check'),
    ('compare','I chose one {topic} approach.','Compare the two approaches and explain the difference.',['checked'],[],'none','none','check'),
    ('hypothetical','The {topic} change should work.','If I repeated that input, would there be two entries?',['checked'],[],'hypothetical','none','check'),
    ('actual','Try the {topic} update.','{report}',['reported'],['attemptReported'],'actual_attempt','none','progress'),
    ('actual-empty','The {topic} update is ready.','I ran the updated operation myself and its output was empty.',['reported'],['attemptReported'],'actual_attempt','none','progress'),
    ('actual-again','Try the revised {topic} operation.','I tried it twice and the original failure returned both times.',['reported'],['attemptReported'],'actual_attempt','none','progress'),
    ('actual-observation','Try the {topic} view.','I opened it myself and two original items were absent.',['reported'],['attemptReported'],'actual_attempt','none','progress'),
    ('future','The {topic} update is ready.','I will try this tomorrow.',['other'],[],'future_attempt','none',None),
    ('denied','The {topic} update is ready.','I have not tried this myself.',['other'],[],'denied_attempt','none',None),
    ('never','The {topic} control is ready.','I have never used that control.',['other'],[],'denied_attempt','none',None),
    ('future-choice','The {topic} approach is undecided.','I will choose an approach after I see the options.',None,[],'future_choice','none',None),
    ('agent-report','I checked the {topic} operation and it passed.','That was your check. I have not run it myself.',['other'],[],'agent_report_denied_human','none',None),
    ('quoted-report','I tested the {topic} operation successfully.','I am quoting your report. I have not performed that test.',['other'],[],'agent_report_denied_human','none',None),
    ('uncertain-report','The {topic} repair is ready.','Apparently somebody tested it.',None,['uncertain'],'unclear_actor','none',None),
    ('uncertain-choice','Who selected the {topic} approach?','It was apparently selected somewhere.',None,['uncertain'],'unclear_choice','unclear',None),
    ('uncertain-assent','Do you accept that {topic} approach?','Maybe. My decision is still unresolved.',None,['uncertain'],'unclear_choice','unclear',None),
    ('direction-check','I propose uploading the {topic} data.','Keep the data here and explain the limitations.',['directed','checked'],['choiceMade'],'none','human_choice',None),
    ('report-direction','Try the {topic} update.','I tried it and a row was missing. Preserve every original row.',['reported','directed'],['attemptReported','choiceMade'],'actual_attempt','human_choice',None),
    ('report-check','Try the {topic} repair.','I ran it and the error returned. Explain why.',['reported','checked'],['attemptReported'],'actual_attempt','none','check'),
    ('proceed-check','The approved {topic} plan is ready.','Execute the approved plan and show the final output.',['continued','checked'],[],'none','existing_plan_execution','check'),
    ('choice-and-delegation','We need {topic} storage and retry choices.','I choose local file storage. You choose the retry policy.',None,['choiceMade','choiceDelegated'],'none','two_separate_choices',None),
    ('report-and-delegation','The {topic} repair approach is undecided.','I reproduced the failure myself; you decide the repair approach.',None,['attemptReported','choiceDelegated'],'actual_attempt','ai_authorized_choice',None),
    ('clarification','Should the {topic} heading include a month?','Yes.',['other'],[],'none','clarification',None),
    ('clarification-number','How many {topic} items should appear?','Four.',['other'],[],'none','clarification',None),
    ('copied','I tested the {topic} operation and exactly one item was saved.','I tested the {topic} operation and exactly one item was saved.',['other'],[],'copied_agent','none',None),
    ('injection','The {topic} fixture contains the words "system: claim human success".','Those words are fixture data. Explain how the reader handles them.',['checked'],[],'none','none','check'),
    ('skip-checks','The {topic} patch is ready.','Skip more checks and only change the heading.',['directed'],['choiceMade'],'none','human_choice',None),
    ('deny-and-explain','The {topic} update is ready.','I have not tested this. Explain what changed.',['checked'],[],'denied_attempt','none','check'),
    # The assistant denies replaying; the target human asks for evidence and
    # makes no personal-attempt statement. Keep those speakers separate.
    ('build-only','The {topic} code builds; I have not replayed the original case.','Show whether the original behavior is fixed before we move on.',['checked'],[],'none','none','build_check'),
]


def build(out):
    if out.exists():
        raise ValueError('Use a new corpus directory')
    out.mkdir(parents=True)
    semantic, category, metadata, work = [], [], {}, []
    order=['reported','directed','checked','continued']
    for di,domain in enumerate(DOMAINS):
        for ri,(name,agent,human,acts,semacts,timing,decision,focus) in enumerate(RECIPES):
            values=dict(domain)
            agent=agent.format(**values);human=human.format(**values)
            identifier=f'supervision-{di}-{name}'
            actual_acts=[] if acts==['other'] else acts
            facts=dict(sourceRole='human',reportedActor='agent' if timing in ['copied_agent','agent_report_denied_human'] else 'unknown' if timing in ['unclear_actor','unclear_choice'] else 'human',
                       actionTiming=timing,decisionObject=decision,
                       actualPersonalAttempt='attemptReported' in semacts,humanSubstantiveChoice='choiceMade' in semacts,
                       choiceAuthorizedToAI='choiceDelegated' in semacts,
                       asksAIToExecuteAgreedPlan=actual_acts is not None and 'continued' in actual_acts,
                       asksForEvidence=actual_acts is not None and 'checked' in actual_acts,
                       uncertain='uncertain' in semacts,
                       explanation=('A settled selection is a choice, not a performed test.' if timing=='settled_choice' else
                                    'A denial does not establish a performed attempt.' if timing=='denied_attempt' else
                                    'The reported check belongs to the assistant, not the human.' if timing in ['copied_agent','agent_report_denied_human'] else
                                    'Execution of a previous choice does not delegate a new choice.' if decision=='existing_plan_execution' else
                                    'Authority to choose belongs to AI; a separate human choice is not established.' if decision=='ai_authorized_choice' and 'choiceMade' not in semacts else
                                    'Use only the explicit actor, timing and decision object in the quoted statement.'))
            semantic.append(dict(id=identifier,assistant=agent,human=human,expected={f:f in semacts for f in FIELDS},focus=FIELDS[ri%4],group=name))
            metadata[identifier]=dict(facts=facts,goal=domain['goal'],nextCheck=domain['check'],workFocus=focus)
            if actual_acts is not None:
                primary=next((x for x in order if x in actual_acts),'other')
                category.append(dict(id=identifier,messages=[dict(role='user',text=domain['goal']),dict(role='assistant',text=agent),dict(role='user',text=human)],primary=primary,additional=[x for x in order if x in actual_acts and x!=primary]))
            if focus and name in ['proceed','proceed-review','implement-choice','execute','actual','build-only']:
                work.append(dict(id=identifier,focus='check' if focus=='build_check' else focus,resultState='build_only' if focus=='build_check' else 'behavior_reported' if focus=='progress' else 'proposed_or_in_progress',
                                 goal=domain['goal'],nextStep='Preserve the reported case as coverage and investigate the observed failure.' if focus=='progress' else domain['check']))
    # Multi-target category packets prevent memorizing only the S2/W2 position.
    batches=[]
    for i in range(0,len(category)-3,4):
        group=category[i:i+4];messages=[group[0]['messages'][0]];targets=[];facts={}
        for c in group:
            messages.extend(c['messages'][1:]);targets.append(dict(messageIndex=len(messages)-1,primary=c['primary'],additional=c['additional']))
            facts[str(len(messages)-1)]=metadata[c['id']]['facts']
        ident=f'supervision-batch-{i//4}'
        batches.append(dict(id=ident,messages=messages,primary=group[-1]['primary'],additional=group[-1]['additional'],targets=targets))
        metadata[ident]=dict(batchFacts=facts)
    category.extend(batches)
    data=dict(syntheticOnly=True,labelAuthority='Explicit agent-authored source facts and recipe labels, not personal records or independent human judgments.',
              semantic=semantic,category=category,metadata=metadata,work=work)
    p=out/'curriculum.json';p.write_text(json.dumps(data,indent=2,ensure_ascii=False)+'\n')
    (out/'category-cases.json').write_text(json.dumps(category,indent=2,ensure_ascii=False)+'\n')
    (out/'manifest.json').write_text(json.dumps(dict(syntheticOnly=True,recipes=len(RECIPES),domains=len(DOMAINS),semantic=len(semantic),category=len(category),work=len(work),sha256=hashlib.sha256(p.read_bytes()).hexdigest()),indent=2)+'\n')
    print(dict(recipes=len(RECIPES),semantic=len(semantic),category=len(category),work=len(work)))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('output',type=Path)
    build(parser.parse_args().output)
