"""Write a content-free inventory of a pinned prototype Git revision."""
import argparse
import csv
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('checkout', type=Path)
parser.add_argument('--revision', required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
def git(*arguments):
    return subprocess.check_output(['git', '-C', str(args.checkout), *arguments])
revision = git('rev-parse', '--verify', args.revision + '^{commit}').decode().strip()
entries = git('ls-tree', '-r', '-z', revision).split(b'\0')
rows = []
for entry in entries:
    if not entry:
        continue
    metadata, raw_path = entry.split(b'\t', 1)
    mode, kind, blob = metadata.decode().split()
    path = raw_path.decode()
    category = 'project-metadata'
    decision = 'review-before-import'
    evidence = 'No repository-wide license found at reviewed revision'
    if '/dist/' in path or path.endswith('.zip'):
        category, decision = 'bundled-distribution', 'exclude'
        evidence = 'Bundled artifact; upstream source/license mapping not established'
    elif 'EnvConfig.swift' in path or path.endswith('.xcconfig'):
        category, decision = 'configuration', 'exclude'
        evidence = 'Environment-specific configuration; recreate from documented inputs'
    elif Path(path).suffix in {'.png', '.jpg', '.jpeg', '.usda', '.rcprojectdata'}:
        category, decision = 'asset', 'exclude-pending-rights'
        evidence = 'Asset provenance and redistribution terms not established'
    elif path.endswith('.swift'):
        category = 'swift-source'
        content = git('show', revision + ':' + path).decode(errors='replace')
        if 'Created by Azizbek Asadov' in '\n'.join(content.splitlines()[:12]):
            evidence = 'Owner author header; not proof of all incorporated material rights'
        else:
            evidence = 'No owner author header in first twelve lines'
    rows.append([revision, path, blob, category, decision, evidence])
args.output.parent.mkdir(parents=True, exist_ok=True)
with args.output.open('w', newline='') as output:
    writer = csv.writer(output)
    writer.writerow(['revision', 'path', 'git_blob', 'category', 'import_decision', 'evidence'])
    writer.writerows(rows)
print(f'Inventoried {len(rows)} tracked paths at {revision}; no source contents exported.')
