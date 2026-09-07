"""Regression for syntax errors hidden by source concatenation; no DCS required."""
from pathlib import Path
import unittest
from unittest.mock import patch

from lupa.lua51 import LuaRuntime, LuaSyntaxError
import run_tests


class StandaloneSyntaxTest(unittest.TestCase):
    def test_balanced_bundle_does_not_hide_broken_files(self):
        chunks = {"one.lua": "do", "two.lua": "end"}
        LuaRuntime().compile("\n".join(chunks.values()))  # The old check passes.
        with patch.object(run_tests, "ROOT") as root:
            root.__truediv__.return_value.rglob.return_value = [Path(p) for p in chunks]
            with patch.object(Path, "read_text", lambda p, **kw: chunks[p.name]):
                with self.assertRaises(LuaSyntaxError):
                    run_tests.compile_source_files()

    def test_main_checks_sources_even_for_compiled_target(self):
        with patch.object(run_tests.sys, "argv", ["runner", "--target", "compiled"]):
            with patch.object(run_tests, "compile_source_files") as compile_files:
                with patch.object(run_tests, "run", return_value=1):
                    self.assertEqual(run_tests.main(), 0)
                compile_files.assert_called_once_with()


if __name__ == "__main__":
    unittest.main()
