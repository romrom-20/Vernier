#!/usr/bin/env python3
"""Add invented lexical contrasts after the first adapter's development audit.

Uses no reserved outcomes, personal records or model-generated labels. The
follow-up changes data and training duration; do not call it a causal ablation.
"""
import argparse
import importlib.util
from pathlib import Path


EXTRA = [
    ('execute-inspect','The {topic} operation was agreed.','Run the agreed operation. I will inspect its behavior tomorrow.',['continued'],[],'future_review','existing_plan_execution',None),
    ('execute-check-later','I can apply the agreed {topic} edit.','Apply it; checking the outcome is something I will do next week.',['continued'],[],'future_review','existing_plan_execution',None),
    ('execute-verify-later','The approved {topic} change is ready.','Go ahead with that change. I intend to verify it myself later.',['continued'],[],'future_review','existing_plan_execution',None),
    ('execute-examine-later','The {topic} plan was approved.','Carry on as agreed; I will examine the outcome after work.',['continued'],[],'future_review','existing_plan_execution',None),
    ('future-inspect','The {topic} view is ready.','I will inspect it this evening.',['other'],[],'future_attempt','none',None),
    ('future-verify','The {topic} update is ready.','My next step is to verify it tomorrow.',['other'],[],'future_attempt','none',None),
    ('actual-inspect','The {topic} view is ready.','I inspected the view and one entry was absent.',['reported'],['attemptReported'],'actual_attempt','none',None),
    ('actual-verify','The {topic} update is ready.','I verified the updated behavior myself; the failure still occurs.',['reported'],['attemptReported'],'actual_attempt','none',None),
    ('deny-inspect','The {topic} view is ready.','I did not inspect it.',['other'],[],'denied_attempt','none',None),
    ('deny-verify','The {topic} update is ready.','I have not verified that behavior personally.',['other'],[],'denied_attempt','none',None),
    ('ask-inspect','The {topic} view is ready.','Inspect the view and show whether every original entry is present.',['checked'],[],'none','none',None),
    ('ask-verify','The {topic} update is ready.','Verify the original failing behavior and show me what happened.',['checked'],[],'none','none',None),
    ('ask-replay','The {topic} guard is ready.','Show the outcome when the original input is replayed.',['checked'],[],'none','none',None),
    ('ask-double','The {topic} guard is ready.','What happens if the input is submitted a second time?',['checked'],[],'hypothetical','none',None),
    ('ask-repeat','The {topic} guard is ready.','If I repeated the operation, would the same failure return?',['checked'],[],'hypothetical','none',None),
    ('assert-local','A remote service could process {topic}.','These records must remain on this device.',['directed'],['choiceMade'],'none','human_choice',None),
    ('reject-remote','I suggest processing {topic} remotely.','Do not send these records elsewhere. Perform the operation here.',['directed'],['choiceMade'],'none','human_choice',None),
    ('reject-edit','I can revise the {topic} behavior again.','Stop revising it. Retain the present behavior.',['directed'],['choiceMade'],'none','human_choice',None),
    ('reject-delete','I could delete old {topic} entries.','Do not delete the old entries. Keep every original.',['directed'],['choiceMade'],'none','human_choice',None),
    ('new-constraint','I can change the {topic} layout.','The first entry must remain visible without scrolling.',['directed'],['choiceMade'],'none','human_choice',None),
    ('observed-constraint','Try the {topic} view.','I opened the view and one entry was concealed. Make every entry visible.',['reported','directed'],['attemptReported','choiceMade'],'actual_attempt','human_choice',None),
    ('observed-question','Try the {topic} update.','I used the update and the failure returned. What caused that?',['reported','checked'],['attemptReported'],'actual_attempt','none',None),
    ('observed-continue','The approved {topic} repair is ready.','I ran the repair and it worked. Continue with the remaining agreed work.',['reported','continued'],['attemptReported'],'actual_attempt','existing_plan_execution',None),
    ('choose-explain','The {topic} approach could use a remote service.','Choose local processing for this task and explain its limitations.',['directed','checked'],['choiceMade'],'none','human_choice',None),
    ('two-choices','The {topic} storage and timeout choices are open.','Use local files. I authorize you to select the timeout.',None,['choiceMade','choiceDelegated'],'none','two_separate_choices',None),
    ('two-choices-second','We need {topic} format and retry decisions.','I select the text format; deciding the retry behavior is up to you.',None,['choiceMade','choiceDelegated'],'none','two_separate_choices',None),
    ('delegate-scope','The {topic} implementation approach is undecided.','Decide the approach yourself, within the limits I stated.',None,['choiceDelegated'],'none','ai_authorized_choice',None),
    ('delegate-owner','Who should settle the {topic} policy?','That policy decision is yours to make.',None,['choiceDelegated'],'none','ai_authorized_choice',None),
    ('ambiguous-result','The {topic} report is ready.','Someone says it passed, but I do not know who performed the run.',None,['uncertain'],'unclear_actor','none',None),
    ('ambiguous-source','The {topic} repair is ready.','Apparently it worked for somebody.',None,['uncertain'],'unclear_actor','none',None),
    ('agent-owned','I ran the {topic} operation and it worked.','You performed that run; I did not.',['other'],[],'agent_report_denied_human','none',None),
    ('agent-owned-future','I tested the {topic} operation.','That test was yours. I will run it myself tomorrow.',['other'],[],'agent_report_denied_human','none',None),
    ('clarification-color','Should the {topic} label be green?','Yes, green.',['other'],[],'none','clarification',None),
    ('clarification-two','Should {topic} show two or three groups?','Three.',['other'],[],'none','clarification',None),
    ('generic-repair','The {topic} change is ready.','Fix it again.',['other'],[],'none','none',None),
    ('es-direction','Podríamos procesar los datos de {topic} en un servicio externo.','No envíes los datos. Procésalos en este ordenador.',['directed'],['choiceMade'],'none','human_choice',None),
    ('es-direction-check','Podríamos procesar los datos de {topic} fuera del equipo.','Conserva los datos aquí y explica los límites.',['directed','checked'],['choiceMade'],'none','human_choice',None),
    ('es-attempt','La actualización de {topic} está lista.','La probé personalmente y el error volvió a aparecer.',['reported'],['attemptReported'],'actual_attempt','none',None),
    ('es-future','La actualización de {topic} está lista.','La probaré mañana; todavía no la he usado.',['other'],[],'future_attempt','none',None),
    ('es-check','La actualización de {topic} está lista.','Comprueba el caso que fallaba y muestra el resultado.',['checked'],[],'none','none',None),
]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('output', type=Path)
    args = p.parse_args()
    path = Path(__file__).with_name('build-observer-supervision.py')
    spec = importlib.util.spec_from_file_location('curriculum', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.RECIPES.extend(EXTRA)
    module.build(args.output)


if __name__ == '__main__':
    main()
