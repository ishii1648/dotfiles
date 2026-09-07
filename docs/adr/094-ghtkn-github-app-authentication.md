# ADR-094: GitHub 認証に ghtkn と最小権限の GitHub App を採用する

## ステータス

採用済み（2026-09-08。実装予定）

## 関連 ADR

- 関連: ADR-028（Git 設定のプロファイル分離）
- 関連: ADR-029（端末ごとの SSH 鍵生成。SSH 鍵の生成・署名鍵の管理方針は継続する）

## コンテキスト

ローカルの `gh` はユーザーの OAuth トークンを使い、確認時点では `repo`、`workflow`、`read:org`、`gist` の権限を持つ。codex-issue-loop も内部で `gh` を起動して実行環境の認証を引き継ぐため、上書きがなければ同じ広い権限で動作する。dotfiles には ghtkn の導入設定がない。

通常の GitHub API 操作と自動実行に渡す権限・対象リポジトリを限定し、漏えいしたアクセストークンが利用できる期間を短くしたい。一方、codex-issue-loop には `/user` と回答者のユーザーIDを照合する処理があり、ユーザーとしての操作を維持したい。

Mac mini は原則常時起動する。通常運転中の認証更新は自動化するが、マシンや認証agentの再起動は例外として手動復旧を許容する。

## 設計案

### 案A: ghtkn の User Access Token と agent backend を使う（採用）

- GitHub App の User Access Token を採用する。操作主体はユーザーのまま、App の権限とインストール対象リポジトリでアクセスを制限し、アクセストークンの有効期限を通常8時間とする。App の秘密鍵や Client Secret を管理する必要がない。
- 通常操作の読み取り用・変更用と codex-issue-loop 専用の App を分ける。loop の権限は Issues・Pull requests・Contents を中心に、実際に使うAPIを調べて確定する。CI状態取得や回答者の検証も含めて確認し、不要な管理権限は付与しない。
- macOS の ghtkn agent backend で refresh を有効にする。各 `gh` 呼び出しを `ghtkn exec -e GH_TOKEN:<app> -- gh ...` 相当の実行経路に接続する。常駐loop起動時に一度だけ環境変数へ渡す方式は、起動済みプロセスのトークンが更新されないため採用しない。loop の直接起動にも適用できるよう、シェルaliasだけに依存しない。
- 対象の Git 操作は HTTPS と ghtkn の Git credential helper を使う。既存の HTTPS から SSH への URL 変換を対象経路で解消する。SSH によるコミット署名は認証と分けて維持する。
- 初回認証、Mac または ghtkn agent の再起動後のアンロック、必要時の再認証は手動とする。アンロックには `--enable-refresh` を指定する。無人アンロック用の秘密情報保存は導入しない。
- agent のロック、認証失効、更新失敗時は GitHub 操作を失敗として扱う。既存の広権限トークンへの自動切り替えは行わない。移行完了時には自動実行環境から既存の広権限認証を取得できる経路も整理する。
- dotfiles では導入と秘密でない設定を管理し、アクセストークン・refresh token・アンロック用パスフレーズをリポジトリやログへ保存しない。agent がアンロック中は同一ユーザーのプロセスがトークンを取得できるため、短命化だけでプロセス間の権限分離が成立するとは扱わない。

自動更新により継続運転を維持しつつ、例外的な再起動のための無人復旧機構を持たずに済む。認証更新は ghtkn に任せ、loop 内に独自の更新機構を実装しない。

### 案B: 現在の GitHub CLI OAuth トークンを継続する（却下）

変更は不要だが、自動実行に渡す権限と有効期間を絞る目的を満たさない。

### 案C: fine-grained PAT を使う（却下）

権限とリポジトリは限定できるが、短い有効期間で運用すると手動ローテーションの負担が残る。常時起動環境では ghtkn の更新機能を利用する。

### 案D: GitHub App の installation access token を使う（却下）

Bot としての無人運転には適するが、秘密鍵管理と、ユーザー本人を前提にする loop の回答認証の見直しが必要になる。今回の目的には User Access Token が合う。

### 変更が必要なファイル

以下は実装時の対象であり、このADRでは設定変更やサービス起動を行わない。

| ファイル・領域 | リポジトリ | 変更内容 |
|---|---|---|
| `aqua.yaml`、設定配布定義、ghtkn 設定・起動定義 | dotfiles | ghtkn の導入と agent backend の設定を管理する。具体的な配布先は実装時に確定する |
| `configs/git/gitconfig`、`configs/git/gitconfig.macos` | dotfiles | 対象の GitHub 認証を HTTPS と ghtkn credential helper に接続する |
| `gh` の実行経路 | dotfiles / codex-issue-loop | API操作ごとに専用トークンを取得し、常駐プロセスへの一度限りの注入を避ける |

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-094 セクション）

## 参考

- [ghtkn](https://github.com/suzuki-shunsuke/ghtkn)
- [自動更新と agent backend](https://github.com/suzuki-shunsuke/ghtkn/blob/main/docs/refresh-token.md)
- [ghtkn exec の取得タイミングと失敗時の動作](https://github.com/suzuki-shunsuke/ghtkn/blob/main/docs/exec.md)
