#!/usr/bin/env python3
"""Check setup structure; never execute application commands."""
from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = [
    'README.md', 'AGENTS.md', 'docs/PROJECT.md', 'docs/DECISIONS.md',
    'docs/ARCHITECTURE.md', 'docs/FranToken-manual-consulta.md',
    'docs/adr/TEMPLATE.md', 'agent/CODING.md', 'agent/FRONTEND.md',
    'agent/BACKEND.md', 'agent/BLOCKCHAIN.md', 'agent/BUSINESS.md',
    'agent/SECURITY.md', 'agent/QUALITY.md', 'agent/BOOTSTRAP.md',
    'agent/repo-config.json', 'agent/TASK-TEMPLATE.md', 'agent/HANDOFF.md',
    'agent/EVALUATION.md',
]
errors = []
for rel in REQUIRED:
    path = ROOT / rel
    if not path.is_file() or not path.stat().st_size:
        errors.append(f'Missing or empty: {rel}')
for path in ROOT.rglob('*.md'):
    if path.name == 'FranToken-manual-consulta.md':
        continue
    for ref in re.findall(r'`((?:agent/|docs/|scripts/)[A-Za-z0-9_./-]+\.(?:md|json|py))`', path.read_text(encoding='utf-8')):
        if not (ROOT / ref).is_file():
            errors.append(f'{path.relative_to(ROOT)}: missing reference {ref}')
try:
    config = json.loads((ROOT / 'agent/repo-config.json').read_text(encoding='utf-8'))
    if config.get('schemaVersion') != 1:
        errors.append('Unsupported schemaVersion')
    if config.get('status') not in ('unconfigured', 'discovered'):
        errors.append('Invalid configuration status')
    commands = config.get('commands')
    expected = {'install','lint','typecheck','testUnit','testIntegration','testE2E','testContracts','build'}
    if not isinstance(commands, dict) or not expected.issubset(commands):
        errors.append('Missing command map or required command keys')
    else:
        for key, value in commands.items():
            if value is None:
                continue
            if not isinstance(value, dict):
                errors.append(f'{key}: use null or an object')
                continue
            for field in ('command', 'cwd', 'source'):
                if not isinstance(value.get(field), str) or not value[field].strip():
                    errors.append(f'{key}: missing {field}')
            if not isinstance(value.get('verified'), bool):
                errors.append(f'{key}: verified must be boolean')
    if not isinstance(config.get('baseline'), list):
        errors.append('baseline must be an array')
except (OSError, ValueError, AttributeError, TypeError) as exc:
    errors.append(f'Invalid repo-config.json: {exc}')
if errors:
    for error in errors:
        print('ERROR:', error, file=sys.stderr)
    sys.exit(1)
print(f'OK: {len(REQUIRED)} required files and local references present; configuration structure valid.')
print(f'Repository status: {config["status"]}. Application tests and agent behavior NOT evaluated.')
