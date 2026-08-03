#!/usr/bin/env python3
"""Tests for block-main-worktree-branch-switch.py (stdlib unittest, no external deps)."""

import importlib.util
import os
import subprocess
import tempfile
import unittest

# Load the module without triggering main()
_spec = importlib.util.spec_from_file_location(
    "block_main_worktree_branch_switch",
    os.path.join(
        os.path.dirname(__file__), "..", "block-main-worktree-branch-switch.py"
    ),
)
_mod = importlib.util.module_from_spec(_spec)
_mod.__name__ = "block_main_worktree_branch_switch"
_spec.loader.exec_module(_mod)

is_main_worktree = _mod.is_main_worktree
default_branch = _mod.default_branch
extract_git_switch_invocations = _mod.extract_git_switch_invocations


def _git(args, cwd):
    subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, check=True)


def _would_be_blocked(command, cwd):
    """Mirror main()'s decision logic for a given command/cwd, without stdin/stdout."""
    for subcmd, target, effective_cwd in extract_git_switch_invocations(command, cwd):
        if not is_main_worktree(effective_cwd):
            continue
        if target != default_branch(effective_cwd):
            return True
    return False


class TestExtractGitSwitchInvocations(unittest.TestCase):
    """extract_git_switch_invocations のテスト（純粋な文字列パース、git 不要）。"""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.cwd = self.tmp.name

    def tearDown(self):
        self.tmp.cleanup()

    def test_git_switch_branch(self):
        result = list(extract_git_switch_invocations("git switch feature/foo", self.cwd))
        self.assertEqual(result, [("switch", "feature/foo", self.cwd)])

    def test_git_checkout_branch(self):
        result = list(extract_git_switch_invocations("git checkout feature/foo", self.cwd))
        self.assertEqual(result, [("checkout", "feature/foo", self.cwd)])

    def test_git_switch_create_new_branch(self):
        result = list(extract_git_switch_invocations("git switch -c feature/new", self.cwd))
        self.assertEqual(result, [("switch", "feature/new", self.cwd)])

    def test_git_checkout_create_new_branch(self):
        result = list(extract_git_switch_invocations("git checkout -b feature/new", self.cwd))
        self.assertEqual(result, [("checkout", "feature/new", self.cwd)])

    def test_ignores_non_git_commands(self):
        result = list(extract_git_switch_invocations("ls -la", self.cwd))
        self.assertEqual(result, [])

    def test_ignores_readonly_git_commands(self):
        result = list(extract_git_switch_invocations("git status", self.cwd))
        self.assertEqual(result, [])

    def test_ignores_file_restore_with_double_dash(self):
        cmd = "git checkout main -- some/file.txt"
        result = list(extract_git_switch_invocations(cmd, self.cwd))
        self.assertEqual(result, [])

    def test_ignores_bare_checkout_of_existing_path(self):
        open(os.path.join(self.cwd, "file.txt"), "w").close()
        result = list(extract_git_switch_invocations("git checkout file.txt", self.cwd))
        self.assertEqual(result, [])

    def test_ignores_checkout_no_args(self):
        result = list(extract_git_switch_invocations("git checkout", self.cwd))
        self.assertEqual(result, [])

    def test_ignores_switch_previous_branch(self):
        result = list(extract_git_switch_invocations("git switch -", self.cwd))
        self.assertEqual(result, [])

    def test_detects_switch_in_chained_command(self):
        cmd = "git status && git switch feature/foo"
        result = list(extract_git_switch_invocations(cmd, self.cwd))
        self.assertEqual(result, [("switch", "feature/foo", self.cwd)])

    def test_dash_c_absolute_path_becomes_effective_cwd(self):
        cmd = "git -C /some/absolute/path switch feature/foo"
        result = list(extract_git_switch_invocations(cmd, self.cwd))
        self.assertEqual(result, [("switch", "feature/foo", "/some/absolute/path")])

    def test_dash_c_relative_path_resolved_against_cwd(self):
        cmd = "git -C sub/dir switch feature/foo"
        result = list(extract_git_switch_invocations(cmd, self.cwd))
        self.assertEqual(
            result, [("switch", "feature/foo", os.path.join(self.cwd, "sub/dir"))]
        )

    def test_repeated_dash_c_resolved_relative_to_previous(self):
        cmd = "git -C a -C b switch feature/foo"
        result = list(extract_git_switch_invocations(cmd, self.cwd))
        self.assertEqual(
            result, [("switch", "feature/foo", os.path.join(self.cwd, "a", "b"))]
        )


class TestGitWorktreeIntegration(unittest.TestCase):
    """is_main_worktree / default_branch / -C 経路のテスト（実 git リポジトリを使用）。"""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = os.path.join(self.tmp.name, "repo")
        os.makedirs(self.repo)
        _git(["init", "-q", "-b", "main"], self.repo)
        _git(["config", "user.email", "test@example.com"], self.repo)
        _git(["config", "user.name", "test"], self.repo)
        open(os.path.join(self.repo, "README.md"), "w").close()
        _git(["add", "README.md"], self.repo)
        _git(["commit", "-q", "-m", "init"], self.repo)
        self.linked = os.path.join(self.tmp.name, "linked")
        _git(["worktree", "add", "-b", "feature/x", self.linked], self.repo)

    def tearDown(self):
        self.tmp.cleanup()

    def test_main_repo_is_main_worktree(self):
        self.assertTrue(is_main_worktree(self.repo))

    def test_linked_worktree_is_not_main_worktree(self):
        self.assertFalse(is_main_worktree(self.linked))

    def test_default_branch_via_local_config_fallback(self):
        # origin が無い場合は init.defaultBranch にフォールバックする
        self.assertEqual(default_branch(self.repo), "main")

    def test_not_a_git_repo(self):
        non_repo = os.path.join(self.tmp.name, "not-a-repo")
        os.makedirs(non_repo)
        self.assertFalse(is_main_worktree(non_repo))

    def test_dash_c_cannot_bypass_block_from_unrelated_cwd(self):
        # cwd が main worktree の外（非 git ディレクトリ）でも、
        # -C で main worktree を明示的に指定した switch は検知されなければならない。
        unrelated = os.path.join(self.tmp.name, "unrelated")
        os.makedirs(unrelated)
        cmd = f"git -C {self.repo} switch feature/x"
        self.assertTrue(_would_be_blocked(cmd, unrelated))

    def test_dash_c_to_linked_worktree_is_not_falsely_blocked(self):
        # cwd が main worktree でも、-C でリンク worktree を明示的に指定した
        # switch は誤ってブロックされてはならない。
        cmd = f"git -C {self.linked} switch main"
        self.assertFalse(_would_be_blocked(cmd, self.repo))

    def test_plain_switch_in_main_worktree_is_blocked(self):
        cmd = "git switch feature/x"
        self.assertTrue(_would_be_blocked(cmd, self.repo))

    def test_plain_switch_in_linked_worktree_is_not_blocked(self):
        cmd = "git switch main"
        self.assertFalse(_would_be_blocked(cmd, self.linked))

    def test_switch_to_default_branch_in_main_worktree_is_not_blocked(self):
        cmd = "git switch main"
        self.assertFalse(_would_be_blocked(cmd, self.repo))


if __name__ == "__main__":
    unittest.main()
