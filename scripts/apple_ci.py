"""Run unsigned Apple builds or discover and test repository Swift packages."""
import json
import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
mode = sys.argv[1]
assert mode in {'ios', 'visionos', 'packages'}, 'Unknown CI mode'
output = Path(os.environ.get('RUNNER_TEMP', '/tmp')) / 'sray-ci' / mode
output.mkdir(parents=True, exist_ok=True)
results = []


def run(label, command):
    """Record only a stable task label and exit status in the public artifact."""
    result = subprocess.run(command, cwd=root, check=False)
    results.append({'task': label, 'exit_code': result.returncode})
    return result.returncode


try:
    if mode == 'packages':
        for package in sorted([*root.glob('Packages/*/Package.swift'), *root.glob('Tools/*/Package.swift')]):
            path = package.parent
            manifest = subprocess.run(
                ['swift', 'package', '--package-path', str(path), 'dump-package'],
                cwd=root, check=True, capture_output=True, text=True,
            )
            has_tests = any(t['type'] == 'test' for t in json.loads(manifest.stdout)['targets'])
            action = 'test' if has_tests else 'build'
            run(f'{path.name}: {action}', ['swift', action, '--package-path', str(path),
                '--scratch-path', str(output / path.name)])
        assert results, 'No packages discovered'
    else:
        scheme, platform = ('SRay-iOS', 'iOS') if mode == 'ios' else ('SRay-visionOS', 'visionOS')
        run(scheme, ['xcodebuild', '-project', 'SRay.xcodeproj', '-scheme', scheme,
            '-destination', f'generic/platform={platform}', '-derivedDataPath', str(output / 'DerivedData'),
            'CODE_SIGNING_ALLOWED=NO', 'build'])
except Exception:
    # Do not serialize exceptions, subprocess output, environment or user content.
    results.append({'task': 'CI infrastructure', 'exit_code': 1})
finally:
    (output / 'outcomes.json').write_text(json.dumps({'mode': mode, 'outcomes': results}, indent=2) + '\n')
sys.exit(0 if results and all(r['exit_code'] == 0 for r in results) else 1)
