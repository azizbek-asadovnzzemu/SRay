"""Look for the fixed SRay QA caption in simulator app files and app-process logs."""
import argparse
import os
from pathlib import Path
import subprocess
import sys
import tempfile

# Keep in sync with CaptionSession+Synthetic.swift and CaptionFlowUITests.swift.
CAPTION = 'Take the elevator to the second floor.'
SIGNATURES = tuple(CAPTION.encode(encoding) for encoding in ('utf-8', 'utf-16-le', 'utf-16-be'))
CHUNK_BYTES = 64 * 1024
OVERLAP_BYTES = max(map(len, SIGNATURES)) - 1


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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('simulator', help='Simulator UDID used only for the synthetic SRay UI suite')
    parser.add_argument('--since', required=True, help='Simulator-local start time in YYYY-MM-DD HH:MM:SS format')
    arguments = parser.parse_args()
    try:
        container = subprocess.run(
            ['xcrun', 'simctl', 'get_app_container', arguments.simulator, 'com.azizbekasadov.sray', 'data'],
            check=True, capture_output=True, text=True, timeout=30,
        )
        root = container.stdout.strip()
        if not root:
            raise OSError('Missing app data container')
        files, matches = scan_container(Path(root))
        with tempfile.TemporaryFile() as logs:
            subprocess.run([
                'xcrun', 'simctl', 'spawn', arguments.simulator, 'log', 'show', '--start', arguments.since,
                '--info', '--debug', '--predicate', 'process == "SRay"',
            ], check=True, stdout=logs, stderr=subprocess.DEVNULL, timeout=60)
            logs.seek(0)
            log_match = contains_caption(logs)
    except (OSError, subprocess.SubprocessError):
        print('Caption audit could not inspect app files and process logs.', file=sys.stderr)
        return 2

    print(f'Scanned {files} app data files. Sentinel matches in app files: {matches}.')
    print('Sentinel in app process logs: ' + ('found' if log_match else 'none found') + '.')
    return int(matches > 0 or log_match)


if __name__ == '__main__':
    sys.exit(main())
