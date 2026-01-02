{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:let
  utils = inputs.nixCats.utils;
in{
  nixCats = {
    enable = true;
    addOverlays = /* (import ./overlays inputs) ++ */ [
      (utils.standardPluginOverlay inputs)
    ];
    packageNames = [ "nvim" ];
    luaPath = ./.;
    categoryDefinitions.replace = ({ pkgs, settings, categories, extra, name, mkPlugin, ... }@packageDef: {
        lspsAndRuntimeDeps = {
          general = with pkgs; [
            universal-ctags
            curl
            (pkgs.writeShellScriptBin "lazygit" ''
              exec ${pkgs.lazygit}/bin/lazygit --use-config-file ${pkgs.writeText "lazygit_config.yml" ""} "$@"
            '')
            ripgrep
            fd
            stdenv.cc.cc
            lua-language-server
            nil # I would go for nixd but lazy chooses this one idk
            stylua
            vscode-extensions.vscjava.vscode-java-debug
            vscode-extensions.vscjava.vscode-java-test
            shfmt
            postgres-language-server
            sqlfluff
            jdt-language-server
          ];
        };

        startupPlugins = {
          general = with pkgs.vimPlugins; [
          lazy-nvim
          LazyVim
          bufferline-nvim
          lazydev-nvim
          conform-nvim
          flash-nvim
          friendly-snippets
          gitsigns-nvim
          grug-far-nvim
          noice-nvim
          lualine-nvim
          nui-nvim
          nvim-lint
          nvim-lspconfig
          nvim-treesitter-textobjects
          nvim-ts-autotag
          ts-comments-nvim
          blink-cmp
          nvim-web-devicons
          persistence-nvim
          plenary-nvim
          telescope-fzf-native-nvim
          telescope-nvim
          todo-comments-nvim
          tokyonight-nvim
          trouble-nvim
          vim-illuminate
          vim-startuptime
          which-key-nvim
          snacks-nvim
          nvim-treesitter-textobjects
          nvim-treesitter.withAllGrammars

          # sometimes you have to fix some names
          { plugin = catppuccin-nvim; name = "catppuccin"; }
          { plugin = mini-ai; name = "mini.ai"; }
          { plugin = mini-icons; name = "mini.icons"; }
          { plugin = mini-pairs; name = "mini.pairs"; }
          # you could do this within the lazy spec instead if you wanted
          # and get the new names from `:NixCats pawsible` debug command
          ];
        };

        optionalPlugins = {
          general = with pkgs; [
            # libgit2
          ];
        };

        environmentVariables = {
        };

        python3.libraries = {
        };

        extraWrapperArgs = {
        };
      });

      packageDefinitions.replace = {
        nvim = {pkgs, name, ... }: {
          settings = {
            suffix-path = true;
            suffix-LD = true;
            wrapRc = true;
            # aliases = [ "nvim" ];
            neovim-unwrapped = inputs.neovim-nightly-overlay.packages.${pkgs.system}.default;
            hosts.python3.enable = true;
            hosts.node.enable = true;
          };
          categories = {
            general = true;
          };
          extra = {
          };
        };
      };

  };
}
