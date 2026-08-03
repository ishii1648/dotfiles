{ pkgs, lib, username, ... }:

{
  imports = [ ./symlinks.nix ];

  home.username = username;
  home.homeDirectory = "/Users/${username}";

  # 初回導入時点の互換基準。home-manager のデフォルト挙動が変わる境界を示すだけの値なので、
  # 上げる必要が生じるまで固定する（上げると一部オプションの既定値が変わる）。
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;

  # ADR-084 設計案 A-6（Phase A）: Homebrew から移すパッケージは最小限に絞る。
  #   - fish: シェル本体。Homebrew 版と PATH 上で混在すると fish_variables /
  #     fish_plugins の解決が壊れうるため、symlink 層の検証後に Phase B で単独移行する
  #   - docker / colima: VM 状態を持つため Phase C
  #   - GNU tools（ggrep/gsed/gtar/gawk/gfind/gdate）: nixpkgs の gnugrep 等は `grep` と
  #     いう名前で PATH に入り BSD 版を上書きしてしまう。g-prefix 共存は Homebrew の方が
  #     素直なので移さない（設計案 A-4）
  # 現在は空にしている。ADR-084「Spike の知見」3 の通り、Phase A では既存 symlink が
  # スキップされて Nix レイヤが実効を持たないことが分かったため、まず symlink を張る経路
  # そのものを検証する。パッケージを PATH に入れるのは Homebrew 版との二重化を伴うので、
  # symlink 経路の検証が終わってから別途行う。
  #
  # 検証済みの定義（eval / build 成功、そのまま復帰できる）:
  #   home.packages = with pkgs; [ neovim jq ]
  #     ++ lib.optionals pkgs.stdenv.isDarwin [ ghostty-bin ];
  #   # nixpkgs の `ghostty` は Darwin で broken（xcodebuild が Nix 環境で動かないため）、
  #   # 公式 .dmg を再パッケージした ghostty-bin を使う
  home.packages = [ ];
}
