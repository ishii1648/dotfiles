---
name: coderabbit-code-review
description: Reviews code changes using CodeRabbit AI. Use when user asks for code review, PR feedback, code quality checks, security issues, or wants autonomous fix-review cycles.
---

# CodeRabbit Code Review

AI-powered code review using CodeRabbit. Enables autonomous development workflows where you can implement features, review code, and fix issues without manual intervention.

## When to Use

When user asks to:

- Review code changes / Review my code / Review this
- Check code quality / Code quality check
- Find bugs or security issues / Check for bugs / Find issues
- Security review / Security check
- Get feedback on their code / PR review / Pull request feedback
- Review staged/uncommitted changes
- What's wrong with my code / What's wrong with my changes
- Run coderabbit / Use coderabbit
- Implement a feature and review it
- Fix issues found in review

## How to Review

### 1. Run Review as Background Agent

CodeRabbitレビューはbackground agentとして実行する。Taskツールで`run_in_background: true`を指定:

```
Task tool parameters:
- subagent_type: "Bash"
- run_in_background: true
- prompt: "coderabbit review --plain を実行してレビュー結果を取得"
```

Options:

- `-t all` - All changes (default)
- `-t committed` - Committed changes only
- `-t uncommitted` - Uncommitted changes only
- `--base main` - Compare against specific branch

### 2. Check Background Agent Results

Background agentの完了後、TaskOutputツールまたはReadツールで`output_file`の内容を確認する。

### 3. Triage (Main Agent)

CodeRabbitの指摘は必ずしも的確とは限らない。メインエージェントが各指摘を精査し、対応要否を判断する:

1. レビュー結果の各指摘について、コードの文脈を読み取り対応が必要か判断
2. 対応不要と判断した指摘はスキップ理由とともにユーザーに報告
3. 対応が必要な指摘のみタスクリスト化して修正
4. 必要に応じて再レビュー（手順1に戻る）

### 4. Autonomous Workflow

ユーザーが実装+レビューを要求した場合:

1. 機能を実装
2. Background agentでCodeRabbitレビューを実行
3. レビュー完了を待機
4. メインエージェントが各指摘をトリアージし、対応要否を判断
5. 対応が必要な問題のみ修正
6. 重大な問題が解消されるまで繰り返し

## Documentation

For more details: <https://docs.coderabbit.ai/cli/claude-code-integration>
