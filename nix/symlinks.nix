{ config, lib, dotfilesDir, ... }:

# ADR-084 Phase A: scripts/setup-manifest.yml の symlinks / configs/fish/setup.sh /
# configs/claude/setup.sh が張っている静的 symlink を、同一パス・同一ターゲットで
# home-manager 側にも定義する。Phase A では manifest 側を削らず共存させ、
# `home-manager switch` と `setup.sh --dry-run` の両方が OK になることを確認する。

let
  # dotfiles clone の実体を指す out-of-store symlink（ADR-084 設計案 A-2）。
  # store コピーにすると configs/ を編集するたび home-manager switch が必要になり、
  # 「dotfiles を直接編集すれば即反映」という現行の運用が壊れる。
  link = relPath: config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/${relPath}";

  # fish の functions は数が多く増減もするため、flake source から動的に列挙する。
  # ここで読むのはファイル名の一覧だけで、symlink 先は上記 link で clone の実体を指す。
  #
  # NOTE: flake source は git tracked なファイルだけを含むため、.gitignore 済みの
  # 端末固有関数（`__*` / claude.fish / fable.fish）はここに現れない。実ディレクトリを
  # glob する configs/fish/setup.sh との意図的な差分で、端末固有設定を dotfiles の管理下に
  # 置かない方針（ADR-012 / ADR-020）と整合する。それらは home-manager の管理外に留まる
  # ため、switch しても削除されない。
  fishFunctionNames = lib.attrNames (
    lib.filterAttrs
      (name: type: type == "regular" && lib.hasSuffix ".fish" name)
      (builtins.readDir ../configs/fish/functions)
  );

  # conf.d は端末固有ファイルを同居させる運用（ADR-012 / ADR-020）のため、
  # dotfiles が管理する共通ファイルだけを明示列挙する（configs/fish/setup.sh と同じリスト）。
  fishConfdNames = [
    "aliases.fish"
    "completions.fish"
    "env.fish"
    "fzf-fish-config.fish"
    "fzf.fish"
    "herdr-ssh-tab.fish"
    "path.fish"
    "ssh-agent.fish"
  ];
in
{
  home.file = lib.mkMerge [
    {
      # --- nvim / ghostty / vim ---
      ".config/nvim".source = link "configs/nvim";
      ".config/ghostty/config".source = link "configs/ghostty/config";
      ".vimrc".source = link "configs/vim/vimrc";

      # --- herdr（ADR-076 / ADR-077 / ADR-079）---
      # config.toml の [[keys.command]] から ~/.local/bin 経由で呼ばれるため、
      # dotfiles clone の絶対パスを config.toml に直書きせず間接参照にしている。
      ".config/herdr/config.toml".source = link "configs/herdr/config.toml";
      ".local/bin/herdr-open-pr".source = link "configs/herdr/open-pr.sh";
      ".local/bin/herdr-new-workspace".source = link "configs/herdr/new-workspace.sh";
      ".local/bin/herdr-agent-picker".source = link "configs/herdr/agent-picker.sh";
      ".local/bin/herdr-new-default-worktree".source = link "configs/herdr/new-default-worktree.sh";
      ".local/bin/herdr-pull-default-branch".source = link "configs/herdr/pull-default-branch.sh";
      # launchd agent（ADR-090）から呼ばれる blocked 通知 watcher
      ".local/bin/herdr-agent-notify".source = link "configs/herdr/agent-notify.py";

      # --- aqua ---
      # 設定ファイルの配置だけを Nix が持つ。ツール本体の導入（`aqua install -l`）は
      # 引き続き configs/aqua/setup.sh が担当する（ADR-084 設計案 A-5 の棲み分け）。
      ".config/aquaproj-aqua/aqua.yaml".source = link "aqua.yaml";

      # --- fish scripts（launchd agent から呼ばれる。ADR-083）---
      ".local/bin/worktree-auto-cleanup".source =
        link "configs/fish/scripts/worktree-auto-cleanup.sh";

      # --- claude ---
      # settings.json は含めない: Claude Code 自身と `herdr integration install` が実行時に
      # 書き換えるため、setup.sh の managed-keys sync が担当する（ADR-015 / ADR-041）。
      ".claude/CLAUDE.md".source = link "configs/claude/CLAUDE.md";
      ".claude/scripts".source = link "configs/claude/scripts";
      ".claude/statusline.js".source = link "configs/claude/statusline.js";
      # skills はディレクトリごと張らない: Claude Code とプラグインが同じディレクトリに
      # 書き込むため、dotfiles 由来の skill だけを個別に張る（configs/claude/setup.sh と同じ）。
      ".claude/skills/codex-sync".source = link "configs/claude/skills/codex-sync";

      # --- fish（dotfiles が占有するもの）---
      ".config/fish/completions".source = link "configs/fish/completions";
      ".config/fish/config.fish".source = link "configs/fish/config.fish";
      ".config/fish/fish_plugins".source = link "configs/fish/fish_plugins";
      # fish_variables は含めない: fish が `set -U` で実行時に書き換えるため（設計案 A-3）。
    }

    (lib.listToAttrs (
      map
        (name: lib.nameValuePair ".config/fish/conf.d/${name}" {
          source = link "configs/fish/conf.d/${name}";
        })
        fishConfdNames
    ))

    (lib.listToAttrs (
      map
        (name: lib.nameValuePair ".config/fish/functions/${name}" {
          source = link "configs/fish/functions/${name}";
        })
        fishFunctionNames
    ))
  ];
}
