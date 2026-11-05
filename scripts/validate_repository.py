"""Validate the documentation foundation and pull request conventions."""
import json
import os
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
required = ['README.md', 'LICENSE', 'NOTICE', 'CONTRIBUTING.md', 'CODE_OF_CONDUCT.md',
            'SECURITY.md', 'GOVERNANCE.md', 'SUPPORT.md', 'THIRD_PARTY_NOTICES.md',
            'docs/production-prd.md', 'docs/ROADMAP.md']
for name in required:
    assert (root / name).is_file(), f'Missing {name}'
for path in root.rglob('*.md'):
    if '.git' in path.parts:
        continue
    content = path.read_text()
    for target in re.findall(r'\]\(([^)]+)\)', content):
        if '://' in target or target.startswith(('#', 'mailto:')):
            continue
        assert (path.parent / target.split('#')[0]).exists(), f'Broken link: {path}: {target}'
backlog = json.loads((root / 'docs/backlog.json').read_text())
keys = {item['key'] for item in backlog}
assert len(keys) == len(backlog), 'Duplicate task key'
for task in backlog:
    assert set(task['depends']) <= keys, f"Unknown dependency: {task['key']}"
    assert task['criteria'], f"Missing acceptance criteria: {task['key']}"
    assert task['key'] not in task['depends'], 'Self dependency'
# Detect cycles rather than relying on issue display order.
visited, active = set(), set()
by_key = {item['key']: item for item in backlog}
def visit(key):
    assert key not in active, f'Dependency cycle: {key}'
    if key in visited:
        return
    active.add(key)
    for dep in by_key[key]['depends']:
        visit(dep)
    active.remove(key)
    visited.add(key)
for key in keys:
    visit(key)
if os.environ.get('GITHUB_EVENT_NAME') == 'pull_request':
    event = json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text())
    pr = event['pull_request']
    title, base, head = pr['title'], pr['base']['ref'], pr['head']['ref']
    if base == 'main':
        assert head == 'develop' and title == 'chore: release', 'Release must be develop → main, titled chore: release'
    else:
        assert base == 'develop', 'Feature PRs must target develop'
        match = re.fullmatch(r'(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-z0-9-]+\))?!?: \[MRST-(\d+)\] .+', title)
        assert match, 'PR title must use Conventional Commits and [MRST-number]'
        assert re.fullmatch(r'mrst-' + match.group(3) + r'(-[1-9][0-9]*)?', head), 'Branch must match issue number'
print(f'Validated community files, Markdown links and {len(backlog)} acyclic issue definitions.')
