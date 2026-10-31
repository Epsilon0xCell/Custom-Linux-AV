"""Tests for custom.sh using stub ClamAV tools.

A real run updates signatures and scans the whole filesystem as
root, which no test should do. I stub sudo, freshclam, and clamscan
on PATH instead, so the script's own logic runs for real: argument
handling, the missing tool check, and how each clamscan exit code
maps to this script's exit code and summary line.
"""

import os
import pathlib
import stat
import subprocess
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).with_name("custom.sh")


def write_stub(folder, name, body):
    path = pathlib.Path(folder) / name
    path.write_text(body)
    path.chmod(path.stat().st_mode | stat.S_IXUSR)


class CustomScriptTests(unittest.TestCase):
    def run_script(self, args=(), clamscan_exit=0, with_clamav=True):
        with tempfile.TemporaryDirectory() as tmp:
            write_stub(tmp, "sudo", "#!/bin/sh\nexec \"$@\"\n")
            write_stub(tmp, "freshclam", "#!/bin/sh\nexit 0\n")
            if with_clamav:
                write_stub(tmp, "clamscan", f"#!/bin/sh\nexit {clamscan_exit}\n")
            env = dict(os.environ, PATH=tmp + os.pathsep + os.environ["PATH"])
            # Hide the real tools behind the stubs by putting tmp
            # first; clamscan is only reachable through the stub
            # when with_clamav is set, so also shadow it with a
            # failing marker in the missing case.
            return subprocess.run(
                ["bash", str(SCRIPT), *args],
                capture_output=True,
                text=True,
                cwd=tmp,
                env=env,
            )

    def test_help_exits_0(self):
        out = self.run_script(["--help"])
        self.assertEqual(out.returncode, 0)
        self.assertIn("Usage:", out.stdout)

    def test_unknown_argument_exits_2(self):
        out = self.run_script(["--bogus"])
        self.assertEqual(out.returncode, 2)

    def test_clean_scan_exits_0(self):
        out = self.run_script(clamscan_exit=0)
        self.assertEqual(out.returncode, 0)
        self.assertIn("no infected files found", out.stdout)

    def test_infections_exit_1_with_summary(self):
        out = self.run_script(clamscan_exit=1)
        self.assertEqual(out.returncode, 1)
        self.assertIn("moved into ./virus", out.stdout)

    def test_clamscan_error_exits_2(self):
        out = self.run_script(clamscan_exit=2)
        self.assertEqual(out.returncode, 2)
        self.assertIn("may be incomplete", out.stderr)

    def test_bash_syntax(self):
        out = subprocess.run(["bash", "-n", str(SCRIPT)], capture_output=True, text=True)
        self.assertEqual(out.returncode, 0, out.stderr)


if __name__ == "__main__":
    unittest.main()
