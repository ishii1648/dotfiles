#!/usr/bin/env python3
"""Tests for block-secret-file-read.py (stdlib unittest, no external deps)."""

import importlib.util
import os
import unittest

# Load the module without triggering main()
_spec = importlib.util.spec_from_file_location(
    "block_secret_file_read",
    os.path.join(os.path.dirname(__file__), "..", "block-secret-file-read.py"),
)
_mod = importlib.util.module_from_spec(_spec)
_mod.__name__ = "block_secret_file_read"
_spec.loader.exec_module(_mod)

find_secret_reference = _mod.find_secret_reference


class TestBlocked(unittest.TestCase):
    def assert_blocked(self, command):
        self.assertIsNotNone(
            find_secret_reference(command), f"should be blocked: {command}"
        )

    def test_direct_read_variants(self):
        for cmd in [
            "cat ~/.ssh/id_ed25519",
            "head -1 /Users/sho-ishii/.ssh/id_ed25519",
            "base64 $HOME/.ssh/id_rsa",
            "xxd ~/.ssh/id_ecdsa | head",
            "cp ~/.ssh/id_ed25519 /tmp/x",
            "ssh-keygen -y -f ~/.ssh/id_ed25519",
            "cat < ~/.ssh/id_dsa",
            'python3 -c "print(open(\'/Users/sho-ishii/.ssh/id_ed25519\').read())"',
            "cd ~/.ssh && cat id_ed25519",
            "cat ~/.ssh/id_ed25519_sk",
            "cat ~/.aws/credentials",
            "grep -r aws_access_key_id ~/.aws/credentials",
        ]:
            with self.subTest(cmd=cmd):
                self.assert_blocked(cmd)


class TestAllowed(unittest.TestCase):
    def assert_allowed(self, command):
        self.assertIsNone(
            find_secret_reference(command), f"should be allowed: {command}"
        )

    def test_public_keys_and_neighbours(self):
        # 公開鍵は git の user.signingkey として読まれるので通す
        for cmd in [
            "cat ~/.ssh/id_ed25519.pub",
            "cat /Users/sho-ishii/.ssh/id_rsa.pub",
            "cat ~/.ssh/known_hosts",
            "cat ~/.ssh/allowed_signers",
            "cat ~/.ssh/config",
            "cat ~/.aws/config",
            "ssh-add -L",
            "git log --oneline",
            "grep -rn id_ed25519_backup .",
            "echo valid_ed25519",
        ]:
            with self.subTest(cmd=cmd):
                self.assert_allowed(cmd)

    def test_empty(self):
        self.assert_allowed("")
        self.assert_allowed(None)


if __name__ == "__main__":
    unittest.main()
