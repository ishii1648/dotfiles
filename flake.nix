{
  description = "ishii1648 dotfiles - package + static symlink layer (ADR-084)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      # ADR-084 Phase A: darwin の full profile のみを対象にする。
      # remote / linux profile は引き続き scripts/setup.sh が担当する。
      system = "aarch64-darwin";

      # macOS のユーザー名はマシンごとに異なる（個人 mac: sho / 会社 mac: sho-ishii）。
      # home-manager は activation の冒頭で $USER と home.username の一致を検証し、
      # 食い違うと `USER is "sho", expected "sho-ishii"` で止まる。username を 1 つに
      # ハードコードすると必ず片方のマシンが switch 不能になるため、両方の output を
      # 生成して各マシンが自分のユーザー名の flake output を選ぶ形にする。
      usernames = [ "sho" "sho-ishii" ];

      pkgs = import nixpkgs { inherit system; };

      mkHome = username: home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./nix/home.nix ];
        extraSpecialArgs = {
          inherit username;
          # mkOutOfStoreSymlink は「Nix store の外」を指すため絶対パス文字列を要求する。
          # flake の source（store へのコピー）ではなく、この clone の実体を指させることで
          # configs/ を編集した内容が home-manager switch なしで即反映される
          # （ADR-084 設計案 A-2）。ghq のパスは $HOME 配下なので username に追従する。
          dotfilesDir = "/Users/${username}/ghq/github.com/ishii1648/dotfiles";
        };
      };
    in
    {
      homeConfigurations = builtins.listToAttrs (map
        (username: {
          name = "${username}@darwin";
          value = mkHome username;
        })
        usernames);
    };
}
