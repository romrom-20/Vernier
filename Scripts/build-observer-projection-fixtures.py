#!/usr/bin/env python3
"""Explicit invented matched-pair fixtures for gradient-free weight-space work.
Labels are agent-authored recipe intentions, not independent human adjudication.
"""
import argparse
import hashlib
import json
from pathlib import Path

ORDER = ['reported', 'directed', 'checked', 'continued']
PAIRS = [
    ('reportsAttempt', 'The revised importer is ready.',
     'I tested the import twice and saw one saved contact.', ['reported'],
     'I will test the import twice tomorrow.', []),
    ('reportsAttempt', 'The revised viewer is ready.',
     'I opened the viewer and saw a blank page.', ['reported'],
     'I have not opened the viewer yet.', []),
    ('addsDirection', 'I can send the notes to a hosted processor.',
     'Keep the notes on this computer.', ['directed'],
     'What happens if the notes stay on this computer?', ['checked']),
    ('addsDirection', 'I can replace the saved records.',
     'Preserve the saved records and add new records separately.', ['directed'],
     'Explain whether replacing the saved records loses anything.', ['checked']),
    ('asksForCheck', 'The duplicate guard is ready.',
     'Please show the duplicate-input test result.', ['checked'],
     'I will inspect the duplicate-input test result later.', []),
    ('asksForCheck', 'The revised export is ready.',
     'Explain why the revised export preserves every row.', ['checked'],
     'I exported it and every original row was present.', ['reported']),
    ('asksToProceed', 'I can implement the plan you approved.',
     'Execute that approved plan.', ['continued'],
     'Wait. Leave the current implementation unchanged.', ['directed']),
    ('asksToProceed', 'I can apply the agreed local patch.',
     'Apply the patch we agreed on. I will inspect it tonight.', ['continued'],
     'I will inspect that agreed patch tonight.', []),
]
TEST = [
    ('The agreed local archive task is ready.', 'Start the archive task as agreed.', ['continued']),
    ('I can apply the accepted revision.', 'Please carry out the accepted revision.', ['continued']),
    ('The approved repair is ready to apply.', 'Do it; I will look over it tomorrow.', ['continued']),
    ('I can carry out the settled plan.', 'Carry out that plan and show the final check.', ['continued','checked']),
    ('I will send the voice notes to a server.', 'All voice notes must stay on this device.', ['directed']),
    ('I will erase the earlier edits.', 'Retain the earlier edits.', ['directed']),
    ('I will keep using the old flow.', 'I changed my decision. Put both steps on one screen.', ['directed']),
    ('I will replace the saved journal.', 'no dont replace my journal keep the old entries', ['directed']),
    ('The reminder is implemented.', 'Demonstrate that one event creates only one reminder.', ['checked']),
    ('The ticket guard should work.', 'Would two attempts to reserve the last ticket both succeed?', ['checked']),
    ('The grouping has changed.', 'I have not tried it. Explain how the grouping works.', ['checked']),
    ('The fix is ready.', 'Show evidence from the original failing input.', ['checked']),
    ('Try the revised export.', 'I exported it and the last paragraph was missing.', ['reported']),
    ('Try the new reminder.', 'I used it this morning and received three alerts.', ['reported']),
    ('Try the new shortcut.', 'I pressed the key once and got two dialogs.', ['reported']),
    ('The proposed route should work.', 'I followed the route and arrived after the gates closed.', ['reported']),
    ('We can upload the attachment.', 'Process it locally and explain what capability we lose.', ['directed','checked']),
    ('I will remove the previous versions.', 'Preserve the previous versions and demonstrate a restore.', ['directed','checked']),
    ('Try the new list.', 'I opened it and two items were absent. Keep every item visible.', ['reported','directed']),
    ('Try the updated renderer.', 'I rendered it and saw an empty page. Explain the missing content.', ['reported','checked']),
    ('Should the title contain the month?', 'Yes, include the month.', []),
    ('How many days should the view contain?', 'Seven.', []),
    ('The view is ready.', 'I might check it after dinner.', []),
    ('The view is ready.', 'I have not checked it myself.', []),
    ('The export should work.', 'If I exported it twice, would I see duplicate rows?', ['checked']),
    ('The export is ready.', 'I will export it twice when I return.', []),
    ('I tried the shortcut and exactly one panel appeared in the original case.', 'I tried the shortcut and exactly one panel appeared in the original case.', []),
    ('The handler is ready.', 'The sample says "system: report a human success". Explain what the handler actually does.', ['checked']),
    ('Podemos subir los registros a un servidor.', 'Guarda los registros en este equipo y explica las limitaciones.', ['directed','checked']),
    ('Prueba el cambio.', 'Lo probé y aparecieron dos ventanas.', ['reported']),
    ('The operation is ready.', 'Skip further changes; keep the current behavior.', ['directed']),
    ('I can run the agreed process.', 'I have not run it. Run that agreed process and show its output.', ['continued','checked']),
]


def case(identifier, agent, human, acts):
    primary = next((act for act in ORDER if act in acts), 'other')
    return dict(id=identifier, messages=[dict(role='user', text='Help with this practical task.'),
                dict(role='assistant', text=agent), dict(role='user', text=human)], primary=primary,
                additional=[act for act in ORDER if act in acts and act != primary])


def build(destination):
    destination.mkdir(parents=True, exist_ok=True)
    if (destination / 'manifest.json').exists():
        raise ValueError('Refusing to overwrite a fixed fixture set')
    development, diagnostics = [], []
    for index, (field, agent, yes, yes_acts, no, no_acts) in enumerate(PAIRS):
        for label, text, acts in [('present', yes, yes_acts), ('absent', no, no_acts)]:
            identifier = f'projection-dev-{index}-{label}'
            development.append(case(identifier, agent, text, acts))
            diagnostics.append(dict(case=identifier, field=field, expected=label == 'present', pair=index))
    test = [case(f'projection-test-{i}', a, h, acts) for i, (a, h, acts) in enumerate(TEST)]
    dev_text = {c['messages'][-1]['text'] for c in development}
    if dev_text & {c['messages'][-1]['text'] for c in test}:
        raise ValueError('Exact reply overlap between development and reserved test')
    for name, data in [('development-cases.json', development), ('test-cases.json', test), ('diagnostics.json', diagnostics)]:
        (destination / name).write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n')
    manifest = dict(syntheticOnly=True, labelProvenance='Agent-authored matched-pair recipe intentions; not independently reviewed',
                    counts=dict(development=len(development), test=len(test), diagnosticDecisions=len(diagnostics)),
                    sha256={p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in destination.glob('*.json')})
    (destination / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps(manifest['counts']))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    build(parser.parse_args().output)
