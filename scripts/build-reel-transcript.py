#!/usr/bin/env python3
"""Build the unsigned companion from an unsigned MediaDL v1.3 iCloud export."""

import argparse
import plistlib
import re
from pathlib import Path
from uuid import uuid4


ACTION_PREFIX = 'is.workflow.actions.'
SCRIPTABLE = 'dk.simonbs.Scriptable.RunScriptInlineIntent'
TRANSCRIBE = 'com.apple.ShortcutsActions.TranscribeAudioAction'
SAVER_PATH = Path(__file__).resolve().parents[1] / 'helpers/scriptable/save-transcript.js'


def action(identifier, **parameters):
    return {
        'WFWorkflowActionIdentifier': identifier,
        'WFWorkflowActionParameters': parameters,
    }


def output_action(identifier, name, **parameters):
    return action(identifier, UUID=str(uuid4()).upper(), CustomOutputName=name, **parameters)


def output_value(source):
    parameters = source['WFWorkflowActionParameters']
    return {
        'Type': 'ActionOutput',
        'OutputUUID': parameters['UUID'],
        'OutputName': parameters['CustomOutputName'],
    }


def output(source):
    return {'Value': output_value(source), 'WFSerializationType': 'WFTextTokenAttachment'}


def text_token(text, attachments):
    return {
        'Value': {
            'string': text,
            'attachmentsByRange': {f'{{{offset}, 1}}': value for offset, value in attachments.items()},
        },
        'WFSerializationType': 'WFTextTokenString',
    }


def make_companion(workflow):
    actions = workflow['WFWorkflowActions']
    landmarks = {
        0: ACTION_PREFIX + 'comment',
        2: SCRIPTABLE,
        13: SCRIPTABLE,
        23: ACTION_PREFIX + 'conditional',
        27: ACTION_PREFIX + 'repeat.each',
        29: ACTION_PREFIX + 'downloadurl',
        31: ACTION_PREFIX + 'repeat.each',
    }
    if len(actions) <= 31 or any(
        actions[index]['WFWorkflowActionIdentifier'] != identifier
        for index, identifier in landmarks.items()
    ):
        raise ValueError('Expected the published MediaDL v1.3 shortcut.')

    resolver = actions[2]['WFWorkflowActionParameters']
    marker = 'var inputUrl = args.shortcutParameter'
    if resolver['script'].count(marker) != 1:
        raise ValueError('Could not find the MediaDL Scriptable input.')
    resolver['script'] = re.sub(
        r'^[ \t]*(?://[^\n]*|/\*.*?\*/)[ \t]*$', '', resolver['script'], flags=re.M | re.S
    )
    resolver['script'] = resolver['script'].replace(marker, r"""const sharedUrl = String(args.shortcutParameter || '').trim()
const reel = /^https:\/\/(?:www\.|m\.)?instagram\.com\/reel\/([\w-]+)\/?(\?[^#\s]*)?(?:#[^\s]*)?$/i.exec(sharedUrl)
if (!reel) {
  return scriptError('Share an Instagram Reel link to MediaDL Reel Transcript.')
}
var inputUrl = 'https://www.instagram.com/reel/' + reel[1] + '/' + (reel[2] || '?')""")

    audio = output_action(
        ACTION_PREFIX + 'encodemedia', 'Reel Audio', WFMedia=output(actions[29]),
        WFMediaAudioOnly=True, WFMediaAudioFormat='M4A',
    )
    transcript = output_action(TRANSCRIBE, 'Transcript', audioFile=output(audio))
    post_id = output_value(actions[2])
    post_id['Aggrandizements'] = [
        {'Type': 'WFCoercionVariableAggrandizement', 'CoercionItemClass': 'WFDictionaryContentItem'},
        {'Type': 'WFDictionaryValueVariableAggrandizement', 'DictionaryKey': 'postId'},
    ]
    save = output_action(
        SCRIPTABLE, 'Saved Transcript',
        script=SAVER_PATH.read_text(encoding='utf-8'),
        parameter=text_token('￼\n￼', {0: post_id, 2: output_value(transcript)}),
        runInApp=False, ShowWhenRun=False, **{'Show-texts': False, 'Show-urls': False},
    )
    workflow['WFWorkflowActions'] = [
        *(item for item in actions[1:24] if item['WFWorkflowActionIdentifier'] != ACTION_PREFIX + 'comment'),
        actions[27],
        actions[29],
        audio,
        transcript,
        save,
        actions[31],
    ]
    return workflow


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    workflow = make_companion(plistlib.loads(args.source.read_bytes()))
    args.output.write_bytes(plistlib.dumps(workflow, fmt=plistlib.FMT_BINARY))


if __name__ == '__main__':
    main()
