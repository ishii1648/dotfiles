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

writes_to_tmp = _mod.writes_to_tmp
is_sed_in_place = _mod.is_sed_in_place
check_command = _mod.check_command
check_and_chain = _mod.check_and_chain
split_chain = _mod.split_chain


class TestWritesToTmp(unittest.TestCase):
    """/tmp/ 書き込みの検出。"""

    def test_redirect_to_tmp(self):
        self.assertTrue(writes_to_tmp("gh pr view 123 --json body -q '.body' > /tmp/pr-body.txt"))

    def test_redirect_append_to_tmp(self):
        self.assertTrue(writes_to_tmp("echo 'data' >> /tmp/log.txt"))

    def test_tee_to_tmp(self):
        self.assertTrue(writes_to_tmp("echo 'data' | tee /tmp/output.txt"))

    def test_printf_to_tmp(self):
        self.assertTrue(writes_to_tmp("printf 'hello' > /tmp/msg.txt"))

    def test_redirect_to_project_dir(self):
        """プロジェクト内への出力は許可。"""
        self.assertFalse(writes_to_tmp("echo 'data' > .outputs/claude/result.txt"))

    def test_no_redirect(self):
        self.assertFalse(writes_to_tmp("ls -la /tmp"))

    def test_tmp_in_read_path(self):
        """読み取りのみの /tmp/ パスは許可。"""
        self.assertFalse(writes_to_tmp("cat /tmp/foo.txt"))

    def test_redirect_to_other_path(self):
        self.assertFalse(writes_to_tmp("echo 'data' > /var/log/app.log"))


class TestSedInPlace(unittest.TestCase):
    """sed は -i（インプレース編集）のときだけ deny する（ADR-091）。"""

    def test_short_flag(self):
        self.assertTrue(is_sed_in_place("sed -i '' 's/a/b/' foo.txt"))

    def test_short_flag_with_suffix(self):
        self.assertTrue(is_sed_in_place("sed -i.bak 's/a/b/' foo.txt"))

    def test_flag_cluster(self):
        self.assertTrue(is_sed_in_place("sed -ri 's/a/b/' foo.txt"))

    def test_long_flag(self):
        self.assertTrue(is_sed_in_place("sed --in-place 's/a/b/' foo.txt"))

    def test_read_only_print(self):
        self.assertFalse(is_sed_in_place("sed -n '1,50p' foo.txt"))

    def test_read_only_substitute(self):
        self.assertFalse(is_sed_in_place("sed 's/a/b/' foo.txt"))

    def test_expression_flag_containing_i(self):
        """-e の式に i が含まれても -i と誤認しない。"""
        self.assertFalse(is_sed_in_place("sed -e 's/i/x/' foo.txt"))


class TestRedirectRules(unittest.TestCase):
    """残したルールが従来どおり deny すること。"""

    def test_find_denied(self):
        self.assertIsNotNone(check_command("find . -name '*.py'"))

    def test_grep_denied(self):
        self.assertIsNotNone(check_command("grep -r pattern src/"))

    def test_rg_denied(self):
        self.assertIsNotNone(check_command("rg pattern src/"))

    def test_cat_denied(self):
        self.assertIsNotNone(check_command("cat foo.txt"))

    def test_cat_redirect_denied(self):
        self.assertIsNotNone(check_command("cat > foo.txt"))

    def test_echo_redirect_denied(self):
        self.assertIsNotNone(check_command("echo 'x' > foo.txt"))

    def test_sed_in_place_denied(self):
        self.assertIsNotNone(check_command("sed -i '' 's/a/b/' foo.txt"))

    def test_piped_grep_allowed(self):
        """パイプ先の grep は先頭コマンドではないので許可。"""
        self.assertIsNone(check_command("git log --oneline | grep fix"))


class TestPrunedRules(unittest.TestCase):
    """ADR-091 で削除したルールが deny しないこと。"""

    def test_head_allowed(self):
        self.assertIsNone(check_command("head -20 foo.log"))

    def test_tail_allowed(self):
        self.assertIsNone(check_command("tail -f app.log"))

    def test_awk_allowed(self):
        self.assertIsNone(check_command("awk '{print $1}' foo.txt"))

    def test_sed_without_in_place_allowed(self):
        self.assertIsNone(check_command("sed -n '1,50p' foo.txt"))

    def test_mkdir_allowed(self):
        self.assertIsNone(check_command("mkdir -p build/out"))

    def test_cp_allowed(self):
        self.assertIsNone(check_command("cp src/a.bin dest/a.bin"))

    def test_for_loop_allowed(self):
        self.assertIsNone(check_command("for f in *.py; do echo $f; done"))

    def test_while_loop_allowed(self):
        self.assertIsNone(check_command("while read l; do echo $l; done"))

    def test_python_inline_allowed(self):
        self.assertIsNone(check_command("python3 -c 'print(1)'"))

    def test_external_python_script_allowed(self):
        self.assertIsNone(check_command("python3 /tmp/foo.py"))


class TestAndChain(unittest.TestCase):
    """cd 起点の連結だけを deny し、それ以外の && は許可する（ADR-091）。"""

    def test_cd_git_suggests_git_c(self):
        result = check_and_chain(split_chain("cd /path/to/repo && git status"))
        self.assertIsNotNone(result)
        self.assertIn("git -C /path/to/repo", result[1])

    def test_cd_other_command_denied(self):
        result = check_and_chain(split_chain("cd /path/to/repo && npm test"))
        self.assertIsNotNone(result)
        self.assertIn("絶対パス", result[1])

    def test_plain_and_chain_allowed(self):
        self.assertIsNone(check_and_chain(split_chain("npm ci && npm test")))

    def test_semicolon_chain_allowed(self):
        self.assertIsNone(check_and_chain(split_chain("make build; make test")))

    def test_single_command_allowed(self):
        self.assertIsNone(check_and_chain(split_chain("npm test")))

    def test_command_substitution_allowed(self):
        """$() は ADR-091 で許可した（deny ルール自体を削除）。"""
        self.assertIsNone(check_and_chain(split_chain('echo "$(date)"')))
        self.assertIsNone(check_command('echo "$(date)"'))


if __name__ == "__main__":
    unittest.main()
