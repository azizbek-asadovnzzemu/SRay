"""Run unsigned Apple builds, simulator app tests and Swift package tests."""
import json
import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
mode = sys.argv[1]
simulator_families = {'iphone-ui': 'iPhone', 'ipad-ui': 'iPad'}
assert mode in {'ios', 'visionos', 'packages', *simulator_families}, 'Unknown CI mode'
output = Path(os.environ.get('RUNNER_TEMP', '/tmp')) / 'sray-ci' / mode
output.mkdir(parents=True, exist_ok=True)
results = []
packages = sorted([*root.glob('Packages/*/Package.swift'), *root.glob('Tools/*/Package.swift')])


def run(label, command):
    """Record only a stable task label and exit status in the public artifact."""
    result = subprocess.run(command, cwd=root, check=False)
    results.append({'task': label, 'exit_code': result.returncode})
    return result.returncode


def package_manifest(path):
    """Read SwiftPM's platform and target declarations."""
    result = subprocess.run(
        ['swift', 'package', '--package-path', str(path), 'dump-package'],
        cwd=root, check=True, capture_output=True, text=True,
    )
    return json.loads(result.stdout)


def simulator_id(family):
    """Select an available simulator of the requested family on the newest installed iOS runtime."""
    devices = subprocess.run(
        ['xcrun', 'simctl', 'list', 'devices', 'available', '--json'],
        cwd=root, check=True, capture_output=True, text=True,
    )
    runtime_prefix = 'com.apple.CoreSimulator.SimRuntime.iOS-'
    type_prefix = f'com.apple.CoreSimulator.SimDeviceType.{family}'
    requested = os.environ.get('SRAY_SIMULATOR_UDID', '').upper()
    candidates = []
    for runtime, entries in json.loads(devices.stdout)['devices'].items():
        if not runtime.startswith(runtime_prefix):
            continue
        version = tuple(int(component) for component in runtime.removeprefix(runtime_prefix).split('-'))
        for device in entries:
            if (device['isAvailable'] and device['deviceTypeIdentifier'].startswith(type_prefix)
                    and (not requested or device['udid'].upper() == requested)):
                candidates.append((version, device['name'], device['udid']))
    if not candidates:
        print(f'No available {family} simulator matches the selected runtime or override.', file=sys.stderr)
        raise RuntimeError('Missing simulator')
    return max(candidates)[2]


try:
    if mode in simulator_families:
        family = simulator_families[mode]
        device = simulator_id(family)
        boot_status = run(f'{family}: prepare simulator', ['xcrun', 'simctl', 'bootstatus', device, '-b'])
        if boot_status == 0:
            test_status = run(f'{family}: app UI tests', ['xcodebuild', '-project', 'SRay.xcodeproj', '-scheme', 'SRay-iOS',
                '-destination', f'platform=iOS Simulator,id={device}',
                '-derivedDataPath', str(output / 'DerivedData'), '-parallel-testing-enabled', 'NO',
                '-testLanguage', 'en', '-testRegion', 'US', 'CODE_SIGNING_ALLOWED=NO', 'test'])
            if test_status == 0:
                run(f'{family}: pose caption artifact audit', [sys.executable, 'scripts/audit_caption_artifacts.py',
                    device, '--last', '3m', '--launch-fixture', '--pose-fixture'])
                run(f'{family}: caption artifact audit', [sys.executable, 'scripts/audit_caption_artifacts.py',
                    device, '--last', '3m', '--launch-fixture'])
    elif mode == 'packages':
        for package in packages:
            path = package.parent
            has_tests = any(t['type'] == 'test' for t in package_manifest(path)['targets'])
            action = 'test' if has_tests else 'build'
            run(f'{path.name}: {action}', ['swift', action, '--package-path', str(path),
                '--scratch-path', str(output / path.name)])
        assert results, 'No packages discovered'
    else:
        scheme, platform = ('SRay-iOS', 'iOS') if mode == 'ios' else ('SRay-visionOS', 'visionOS')
        run(scheme, ['xcodebuild', '-project', 'SRay.xcodeproj', '-scheme', scheme,
            '-destination', f'generic/platform={platform}', '-derivedDataPath', str(output / 'DerivedData'),
            'CODE_SIGNING_ALLOWED=NO', 'build'])
        sdk_name, triple = ('iphoneos', 'arm64-apple-ios17.0') if mode == 'ios' else ('xros', 'arm64-apple-xros2.0')
        sdk = subprocess.run(['xcrun', '--sdk', sdk_name, '--show-sdk-path'],
            check=True, capture_output=True, text=True).stdout.strip()
        for package in packages:
            platforms = {item['platformName'] for item in package_manifest(package.parent)['platforms']}
            if platforms == {'macos'}:
                print(f'Skipping {package.parent.name} on {platform}: macOS-only package', flush=True)
                continue
            run(f'{package.parent.name}: {platform}', ['swift', 'build',
                '--package-path', str(package.parent), '--triple', triple, '--sdk', sdk,
                '--scratch-path', str(output / package.parent.name)])
except Exception:
    # Do not serialize exceptions, subprocess output, environment or user content.
    results.append({'task': 'CI infrastructure', 'exit_code': 1})
finally:
    (output / 'outcomes.json').write_text(json.dumps({'mode': mode, 'outcomes': results}, indent=2) + '\n')
sys.exit(0 if results and all(r['exit_code'] == 0 for r in results) else 1)
