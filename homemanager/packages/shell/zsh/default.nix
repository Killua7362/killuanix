{ pkgs, config, ... }:


{
  programs.direnv.enable = true;
  programs.direnv.enableNixDirenvIntegration = true;

  home.sessionVariables = {
   STARSHIP_CONFIG = "/home/killua/Nix-Config/DotFiles/starship/starship.toml";
   };

  programs.zsh = {
    enable = true;
    enableAutosuggestions = true;
    initExtraFirst = ''
      eval "$(starship init zsh)"
      eval "$(direnv hook zsh)"
    '';

    plugins = [{
      name = "zsh-autosuggestions";
      src = pkgs.fetchFromGitHub {
        owner = "zsh-users";
        repo = "zsh-autosuggestions";
        rev = "ae315ded4dba10685dbbafbfa2ff3c1aefeb490d";
        sha256 = "xv4eleksJzomCtLsRUj71RngIJFw8+A31O6/p7i4okA=";
        fetchSubmodules = true;
      };
    }

      {
        name = "zsh-syntax-highlighting";
        file = "zsh-syntax-highlighting.zsh";
        src = builtins.fetchGit {
          url = "https://github.com/zsh-users/zsh-syntax-highlighting/";
          rev = "932e29a0c75411cb618f02995b66c0a4a25699bc";
        };
      }
      {
        name = "zsh-nix-shell";
        file = "nix-shell.plugin.zsh";
        src = pkgs.fetchFromGitHub {
          owner = "chisui";
          repo = "zsh-nix-shell";
          rev = "v0.2.0";
          sha256 = "1gfyrgn23zpwv1vj37gf28hf5z0ka0w5qm6286a7qixwv7ijnrx9";
        };
      }];
  };

  programs.dircolors = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.bat = {
    enable = true;
    config = { theme = "base16"; };
  };

  programs.zsh.shellAliases =
    {
      nix-stray-roots = "nix-store --gc --print-roots | egrep -v \"^(/nix/var|/run/\w+-system|\{memory)\"";
      untar = "tar -xvzf";
      ga = "git add * && git add -u";
      g = "lazygit";
      c = "clear";
    };
}
