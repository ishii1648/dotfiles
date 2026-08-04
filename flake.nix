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
      username = "sho-ishii";

      # mkOutOfStoreSymlink は「Nix store の外」を指すため絶対パス文字列を要求する。
      # flake の source（store へのコピー）ではなく、この clone の実体を指させることで
      # configs/ を編集した内容が home-manager switch なしで即反映される（ADR-084 設計案 A-2）。
      dotfilesDir = "/Users/${username}/ghq/github.com/ishii1648/dotfiles";

      pkgs = import nixpkgs { inherit system; };
    in
    {
      homeConfigurations."${username}@darwin" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./nix/home.nix ];
        extraSpecialArgs = { inherit username dotfilesDir; };
      };
    };
}
