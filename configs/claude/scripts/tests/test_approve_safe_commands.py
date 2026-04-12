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

is_safe_readonly_gh_api = _mod.is_safe_readonly_gh_api


class TestIsSafeReadonlyGhApi(unittest.TestCase):
    """is_safe_readonly_gh_api のテスト。"""

    def test_simple_gh_api(self):
        cmd = "gh api repos/owner/repo/pulls"
        self.assertTrue(is_safe_readonly_gh_api(cmd))

    def test_gh_api_with_paginate_and_jq(self):
        cmd = (
            "gh api repos/owner/repo/pulls/12345/reviews --paginate "
            "2>/dev/null | jq -r '[.[] | select(.body != \"\" and "
            "(.state == \"COMMENTED\" or .state == \"CHANGES_REQUESTED\"))] | length'"
        )
        self.assertTrue(is_safe_readonly_gh_api(cmd))

    def test_gh_api_piped_to_head(self):
        cmd = "gh api repos/owner/repo/issues --paginate | head -20"
        self.assertTrue(is_safe_readonly_gh_api(cmd))

    def test_reject_post_method(self):
        cmd = "gh api repos/owner/repo/issues -X POST"
        self.assertFalse(is_safe_readonly_gh_api(cmd))

    def test_reject_field_flag(self):
        cmd = "gh api repos/owner/repo/issues -f title=test"
        self.assertFalse(is_safe_readonly_gh_api(cmd))

    def test_reject_raw_field_flag(self):
        cmd = "gh api repos/owner/repo/issues -F body=content"
        self.assertFalse(is_safe_readonly_gh_api(cmd))

    def test_reject_field_long_flag(self):
        cmd = "gh api repos/owner/repo/issues --field title=test"
        self.assertFalse(is_safe_readonly_gh_api(cmd))

    def test_reject_input_flag(self):
        cmd = "gh api repos/owner/repo/issues --input data.json"
        self.assertFalse(is_safe_readonly_gh_api(cmd))

    def test_reject_unsafe_pipe_target(self):
        cmd = "gh api repos/owner/repo/pulls | bash"
        self.assertFalse(is_safe_readonly_gh_api(cmd))

    def test_reject_non_gh_command(self):
        cmd = "curl https://api.github.com/repos/owner/repo"
        self.assertFalse(is_safe_readonly_gh_api(cmd))

    def test_reject_too_few_args(self):
        cmd = "gh api"
        self.assertFalse(is_safe_readonly_gh_api(cmd))


if __name__ == "__main__":
    unittest.main()
