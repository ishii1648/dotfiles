#!/usr/bin/env python3
"""Tests for redirect-to-tools.py (stdlib unittest, no external deps)."""

import importlib.util
import os
import unittest

# Load the module without triggering main()
_spec = importlib.util.spec_from_file_location(
    "redirect_to_tools",
    os.path.join(os.path.dirname(__file__), "..", "redirect-to-tools.py"),
)
_mod = importlib.util.module_from_spec(_spec)
_mod.__name__ = "redirect_to_tools"
_spec.loader.exec_module(_mod)

has_command_substitution = _mod.has_command_substitution


class TestCommandSubstitutionBasic(unittest.TestCase):
    """基本的な $() / バッククォートの検出。"""

    def test_dollar_paren(self):
        self.assertTrue(has_command_substitution("echo $(whoami)"))

    def test_backtick(self):
        self.assertTrue(has_command_substitution("echo `whoami`"))

    def test_no_substitution(self):
        self.assertFalse(has_command_substitution("echo hello"))

    def test_plain_command(self):
        self.assertFalse(has_command_substitution("ls -la /tmp"))

    def test_dollar_sign_without_paren(self):
        self.assertFalse(has_command_substitution("echo $HOME"))


class TestCommandSubstitutionQuotes(unittest.TestCase):
    """クォート内の挙動。"""

    def test_double_quotes_detected(self):
        """ダブルクォート内の $() はシェルが展開するので検出する。"""
        self.assertTrue(has_command_substitution('echo "$(whoami)"'))

    def test_single_quotes_ignored(self):
        """シングルクォート内の $() はシェルが展開しないのでスキップ。"""
        self.assertFalse(has_command_substitution("echo '$(whoami)'"))

    def test_backtick_in_single_quotes_ignored(self):
        self.assertFalse(has_command_substitution("echo '`whoami`'"))

    def test_backtick_in_double_quotes_detected(self):
        self.assertTrue(has_command_substitution('echo "`whoami`"'))


class TestCommandSubstitutionArithmetic(unittest.TestCase):
    """$((...)) 算術展開は安全なため除外。"""

    def test_arithmetic_expansion(self):
        self.assertFalse(has_command_substitution("echo $((1+2))"))

    def test_arithmetic_with_variable(self):
        self.assertFalse(has_command_substitution("echo $((x + y))"))

    def test_arithmetic_mixed_with_command_sub(self):
        """算術展開と $() が混在する場合、$() を検出する。"""
        self.assertTrue(has_command_substitution("echo $((1+2)) $(whoami)"))


class TestCommandSubstitutionGitCommitHeredoc(unittest.TestCase):
    """git commit の heredoc パターンは approve-safe-commands.py で許可済みのため除外。"""

    def test_git_commit_cat_heredoc(self):
        self.assertFalse(
            has_command_substitution('git commit -m "$(cat <<\'EOF\'\nhello\nEOF\n)"')
        )

    def test_git_commit_cat_heredoc_no_quotes(self):
        self.assertFalse(
            has_command_substitution('git commit -m "$(cat <<EOF\nhello\nEOF\n)"')
        )

    def test_git_commit_without_heredoc_still_detected(self):
        """git commit でも heredoc でない $() は検出する。"""
        self.assertTrue(has_command_substitution('git commit -m "$(date)"'))

    def test_non_git_cat_heredoc_detected(self):
        """git commit 以外の $(cat <<...) は検出する。"""
        self.assertTrue(
            has_command_substitution('echo "$(cat <<EOF\nhello\nEOF\n)"')
        )


class TestCommandSubstitutionNested(unittest.TestCase):
    """ネストされたコマンド置換。"""

    def test_nested_dollar_paren(self):
        self.assertTrue(has_command_substitution("echo $(echo $(whoami))"))


if __name__ == "__main__":
    unittest.main()
