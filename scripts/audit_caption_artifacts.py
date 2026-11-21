"""Look for the fixed SRay QA caption in simulator app files and app-process logs."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

# Keep in sync with CaptionSession+Synthetic.swift and CaptionFlowUITests.swift.
CAPTION = 'Take the elevator to the second floor.'
SIGNATURES = tuple(CAPTION.encode(encoding) for encoding in ('utf-8', 'utf-16-le', 'utf-16-be'))
CHUNK_BYTES = 64 * 1024
OVERLAP_BYTES = max(map(len, SIGNATURES)) - 1
BUNDLE_ID = 'com.azizbekasadov.sray'
READY_MESSAGE = 'Synthetic caption audit ready'


def contains_caption(stream):
    """Find the QA caption across chunk boundaries without loading an entire artifact."""
    trailing = b''
    while chunk := stream.read(CHUNK_BYTES):
        window = trailing + chunk
        if any(signature in window for signature in SIGNATURES):
            return True
        trailing = window[-OVERLAP_BYTES:]
    return False


def scan_container(root):
    """Count files and matches in the app data container without following symlinks."""
    if root.is_symlink() or not root.is_dir():
        raise OSError('Missing app data container')
    files = matches = 0

    def propagate(error):
        raise error

    for folder, _, names in os.walk(root, onerror=propagate):
        for name in names:
            path = Path(folder, name)
            if path.is_symlink() or not path.is_file():
                continue
            files += 1
            with path.open('rb') as artifact:
                if contains_caption(artifact):
                    matches += 1
    return files, matches


def scan_log_events(logs):
    """Report origins of matching records without retaining or printing their messages."""
    origins = set()

    def safe_label(value):
        if isinstance(value, str) and re.fullmatch(r'[A-Za-z0-9._-]{1,100}', value):
            return value
        return 'unavailable'

    for line in logs:
        if not any(signature in line for signature in SIGNATURES):
            continue
        try:
            record = json.loads(line)
        except (json.JSONDecodeError, UnicodeDecodeError):
            origins.add(('unavailable', 'unavailable'))
            continue
        subsystem = safe_label(record.get('subsystem')) if isinstance(record, dict) else 'unavailable'
        category = safe_label(record.get('category')) if isinstance(record, dict) else 'unavailable'
        origins.add((subsystem, category))
    return origins


def launch_fixture(simulator):
    """Launch the installed Debug app outside of XCTest and return its process ID."""
    launched = subprocess.run([
        'xcrun', 'simctl', 'launch', '--terminate-running-process', simulator, BUNDLE_ID,
    ], env={**os.environ, 'SIMCTL_CHILD_SRAY_SYNTHETIC_CAPTIONS': '1', 'SIMCTL_CHILD_SRAY_CAPTION_AUDIT': '1'},
        check=True, capture_output=True, text=True, timeout=45)
    prefix, separator, pid = launched.stdout.strip().rpartition(':')
    if prefix != BUNDLE_ID or not separator or not pid.strip().isdecimal():
        raise OSError('Missing fixture process identity')
    return pid.strip()


def fixture_ready(logs):
    """Require a content-free readiness record from the Debug fixture."""
    for line in logs:
        if READY_MESSAGE.encode() not in line:
            continue
        try:
            record = json.loads(line)
        except (json.JSONDecodeError, UnicodeDecodeError):
            continue
        if (isinstance(record, dict) and record.get('eventMessage') == READY_MESSAGE
                and record.get('subsystem') == BUNDLE_ID + '.audit'):
            return True
    return False


def collect_origins(simulator, window, pid):
    """Read the selected process logs and require the fixture to run when launched here."""
    command = ['xcrun', 'simctl', 'spawn', simulator, 'log', 'show', '--last', window,
               '--info', '--debug', '--style', 'ndjson']
    if pid is None:
        command += ['--predicate', 'process == "SRay"']
    else:
        command += ['--process', pid]

    for _ in range(3 if pid is not None else 1):
        with tempfile.TemporaryFile() as logs:
            subprocess.run(command, check=True, stdout=logs, stderr=subprocess.DEVNULL, timeout=60)
            logs.seek(0)
            if pid is None or fixture_ready(logs):
                logs.seek(0)
                return scan_log_events(logs)
    raise OSError('Synthetic caption fixture never reported readiness')


def audit(simulator, window, pid):
    try:
        container = subprocess.run(
            ['xcrun', 'simctl', 'get_app_container', simulator, BUNDLE_ID, 'data'],
            check=True, capture_output=True, text=True, timeout=30,
        )
        root = container.stdout.strip()
        if not root:
            raise OSError('Missing app data container')
    except (OSError, subprocess.SubprocessError):
        print('Caption audit could not read the app data container.', file=sys.stderr)
        return 2

    try:
        origins = collect_origins(simulator, window, pid)
    except (OSError, subprocess.SubprocessError):
        print('Caption audit could not export simulator process logs.', file=sys.stderr)
        return 2

    try:
        files, matches = scan_container(Path(root))
    except OSError:
        print('Caption audit could not read the app data container.', file=sys.stderr)
        return 2

    print(f'Scanned {files} app data files. Sentinel matches in app files: {matches}.')
    print('Sentinel in app process logs: ' + ('found' if origins else 'none found') + '.')
    for subsystem, category in sorted(origins):
        print(f'Matching log origin: {subsystem} / {category}.')
    if pid is not None:
        print('Verified readiness of the standalone synthetic fixture.')
    return int(matches > 0 or bool(origins))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('simulator', help='Simulator UDID used only for the synthetic SRay suite')
    parser.add_argument('--last', required=True, help='Relative log collection window, for example 2m')
    parser.add_argument('--launch-fixture', action='store_true', help='Audit a fresh Debug process outside XCTest')
    arguments = parser.parse_args()

    if not arguments.launch_fixture:
        return audit(arguments.simulator, arguments.last, None)
    try:
        pid = launch_fixture(arguments.simulator)
    except (OSError, subprocess.SubprocessError):
        print('Caption audit could not start the standalone fixture.', file=sys.stderr)
        return 2
    try:
        outcome = audit(arguments.simulator, arguments.last, pid)
    finally:
        try:
            stopped = subprocess.run(['xcrun', 'simctl', 'terminate', arguments.simulator, BUNDLE_ID],
                                     check=True, capture_output=True, timeout=30)
        except (OSError, subprocess.SubprocessError):
            stopped = None
    if stopped is None:
        print('Caption audit could not stop the standalone fixture.', file=sys.stderr)
        return 2
    return outcome


if __name__ == '__main__':
    sys.exit(main())
