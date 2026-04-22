{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  # Starship configuration
  programs.starship = {
    enable = lib.mkDefault true;
    enableZshIntegration = true;
    settings = {
      aws = {
        symbol = " ";
      };

      character = {
        success_symbol = "[❯](bold purple)";
        vicmd_symbol = "[❮](bold purple)";
      };

      battery = {
        full_symbol = "";
        charging_symbol = "";
        discharging_symbol = "";
      };

      conda = {
        symbol = " ";
      };

      directory = {
        style = "cyan";
        read_only = " 🔒";
      };

      # docker = {
      # symbol =" ";
      # };

      elixir = {
        symbol = " ";
      };

      elm = {
        symbol = " ";
      };

      git_branch = {
        format = "[$symbol$branch]($style) ";
        symbol = " ";
        style = "bold dimmed white";
      };

      git_status = {
        format = "([「$all_status$ahead_behind」]($style) )";
        conflicted = "⚠️";
        ahead = "⟫\${count} ";
        behind = "⟪\${count}";
        diverged = "🔀 ";
        untracked = "📁 ";
        stashed = "↪ ";
        modified = "𝚫 ";
        staged = "✔ ";
        renamed = "⇆ ";
        deleted = "✘ ";
        style = "bold bright-white";
        # scan_timeout= 1000;
      };

      golang = {
        symbol = " ";
      };

      haskell = {
        symbol = " ";
      };

      hg_branch = {
        symbol = " ";
      };

      java = {
        symbol = " ";
      };

      julia = {
        symbol = " ";
      };

      memory_usage = {
        symbol = " ";
        disabled = false;
      };

      nim = {
        symbol = " ";
      };

      nix_shell = {
        format = "[$symbol$state]($style) ";
        symbol = " ";
        pure_msg = "λ";
        impure_msg = "⎔";
      };

      nodejs = {
        symbol = " ";
      };

      package = {
        symbol = " ";
      };

      php = {
        symbol = " ";
      };

      python = {
        symbol = " ";
      };

      ruby = {
        symbol = " ";
      };

      rust = {
        symbol = " ";
      };

      status = {
        disabled = false;
      };
    };
  };
}
