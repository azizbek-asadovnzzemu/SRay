from contextlib import redirect_stderr, redirect_stdout
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from audit_caption_artifacts import CAPTION, CHUNK_BYTES, contains_caption, main, scan_container, scan_log_events


class CaptionArtifactAuditTests(unittest.TestCase):
    def test_scans_across_boundary_in_all_supported_encodings(self):
        for encoding in ('utf-8', 'utf-16-le', 'utf-16-be'):
            with self.subTest(encoding=encoding):
                stream = io.BytesIO(b'x' * (CHUNK_BYTES - 3) + CAPTION.encode(encoding))
                self.assertTrue(contains_caption(stream))

    def test_ordinary_metadata_does_not_match(self):
        self.assertFalse(contains_caption(io.BytesIO(b'caption phase=ready')))

    def test_reports_only_safe_labels_for_matching_log_events(self):
        events = [
            {'subsystem': 'com.apple.fixture', 'category': 'accessibility', 'eventMessage': CAPTION},
            {'subsystem': 'com.apple.fixture', 'category': CAPTION, 'eventMessage': CAPTION},
            {'subsystem': 'com.apple.fixture', 'category': 'unmatched', 'eventMessage': 'Ready'},
        ]
        logs = io.BytesIO('\n'.join(json.dumps(event) for event in events).encode())
        self.assertEqual(scan_log_events(logs), {('com.apple.fixture', 'accessibility'),
                                                ('com.apple.fixture', 'unavailable')})

    def test_counts_matches_and_excludes_links_outside_the_container(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory, 'data')
            cache = root / 'Library' / 'Caches'
            cache.mkdir(parents=True)
            (cache / 'positive').write_text(CAPTION)
            (root / 'metadata').write_text('caption phase=ready')
            outside = Path(directory, 'outside')
            outside.mkdir()
            (outside / 'positive').write_text(CAPTION)
            (root / 'link-to-folder').symlink_to(outside, target_is_directory=True)
            (root / 'link-to-file').symlink_to(outside / 'positive')
            self.assertEqual(scan_container(root), (2, 1))


    def test_audit_fails_for_a_log_match_without_printing_the_caption(self):
        with tempfile.TemporaryDirectory() as directory:
            def run(command, **kwargs):
                if 'get_app_container' in command:
                    return subprocess.CompletedProcess(command, 0, stdout=directory)
                kwargs['stdout'].write(CAPTION.encode())
                return subprocess.CompletedProcess(command, 0)

            output = io.StringIO()
            with patch('sys.argv', ['audit', 'fixture', '--last', '2m']), \
                 patch('audit_caption_artifacts.subprocess.run', side_effect=run), redirect_stdout(output):
                self.assertEqual(main(), 1)
            self.assertIn('Sentinel in app process logs: found.', output.getvalue())
            self.assertNotIn(CAPTION, output.getvalue())

    def test_missing_container_cannot_pass(self):
        unavailable = subprocess.CompletedProcess([], 0, stdout='')
        error = io.StringIO()
        with patch('sys.argv', ['audit', 'fixture', '--last', '2m']), \
             patch('audit_caption_artifacts.subprocess.run', return_value=unavailable), redirect_stderr(error):
            self.assertEqual(main(), 2)
        self.assertIn('could not read the app data container', error.getvalue())

    def test_failed_log_export_cannot_pass(self):
        with tempfile.TemporaryDirectory() as directory:
            container = subprocess.CompletedProcess([], 0, stdout=directory)
            failure = subprocess.CalledProcessError(1, ['log', 'show'])
            error = io.StringIO()
            with patch('sys.argv', ['audit', 'fixture', '--last', '2m']), \
                 patch('audit_caption_artifacts.subprocess.run', side_effect=[container, failure]), \
                 redirect_stderr(error):
                self.assertEqual(main(), 2)
            self.assertIn('could not export simulator process logs', error.getvalue())
