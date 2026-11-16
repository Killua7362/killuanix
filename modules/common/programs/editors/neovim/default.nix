{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: let
  utils = inputs.nixCats.utils;
  # Build mcp-hub from npm
  mcp-hub = pkgs.buildNpmPackage {
    pname = "mcp-hub";
    version = "latest";
    src = pkgs.fetchFromGitHub {
      owner = "ravitemer"; # Adjust if different
      repo = "mcp-hub";
      rev = "main"; # Or specific version tag
      hash = "sha256-KakvXZf0vjdqzyT+LsAKHEr4GLICGXPmxl1hZ3tI7Yg="; # Run once to get the hash
    };
    npmDepsHash = "sha256-nyenuxsKRAL0PU/UPSJsz8ftHIF+LBTGdygTqxti38g="; # Run once to get the hash
  };
in {
  nixCats = {
    enable = true;
    addOverlays =
      /*
      (import ./overlays inputs) ++
      */
      [
        (utils.standardPluginOverlay inputs)
      ];
    packageNames = ["nvim"];
    luaPath = ./.;
    categoryDefinitions.replace = {
      pkgs,
      settings,
      categories,
      extra,
      name,
      mkPlugin,
      ...
    } @ packageDef: {
      lspsAndRuntimeDeps = {
        java = with pkgs; [
          jdt-language-server
          lombok
          vscode-extensions.vscjava.vscode-java-debug
          vscode-extensions.vscjava.vscode-java-test
        ];
        general = with pkgs; [
          universal-ctags
          curl
          pkgs.lazygit
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
          kdePackages.qtdeclarative
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
          nvim-dap
          nvim-dap-virtual-text
          diffview-nvim
          git-worktree-nvim
          claudecode-nvim

          # sometimes you have to fix some names
          {
            plugin = catppuccin-nvim;
            name = "catppuccin";
          }
          {
            plugin = mini-ai;
            name = "mini.ai";
          }
          {
            plugin = mini-icons;
            name = "mini.icons";
          }
          {
            plugin = mini-pairs;
            name = "mini.pairs";
          }
          # you could do this within the lazy spec instead if you wanted
          # and get the new names from `:NixCats pawsible` debug command
        ];
      };

      optionalPlugins = {
        general = with pkgs; [
          # libgit2
        ];
      };

      environmentVariables = {};

      python3.libraries = {};

      extraWrapperArgs = {};
    };

    packageDefinitions.replace = {
      nvim = {
        pkgs,
        name,
        ...
      }: {
        settings = {
          suffix-path = true;
          suffix-LD = true;
          wrapRc = true;
          # aliases = [ "nvim" ];
          neovim-unwrapped = inputs.neovim-nightly-overlay.packages.${pkgs.stdenv.hostPlatform.system}.default;
          hosts.python3.enable = true;
          hosts.node.enable = true;
        };
        categories = {
          general = true;
        };
        extra = {
          jdtls = "${pkgs.jdt-language-server}/share/java/jdtls";
          lombok = "${pkgs.lombok}/share/java/lombok.jar";
          # JDK homes registered as jdtls `runtimes` so a single jdtls (which
          # runs on its own bundled JDK) can compile projects targeting any of
          # these levels. The default runtime is chosen at attach time from
          # $JAVA_HOME (see java.lua): JDK 25 everywhere, JDK 8 inside the
          # Boeing bdsi tree where direnv pins JAVA_HOME → ~/.local/jvm/jdk8.
          jdk8 = "${pkgs.zulu8}";
          jdk21 = "${pkgs.jdk21.home}";
          jdk25 = "${pkgs.jdk25.home}";
          java_debug_adapter = "${pkgs.vscode-extensions.vscjava.vscode-java-debug}/share/vscode/extensions/vscjava.vscode-java-debug";
          java_test = "${pkgs.vscode-extensions.vscjava.vscode-java-test}/share/vscode/extensions/vscjava.vscode-java-test";
          python = "${pkgs.python3.withPackages (ps: [ps.debugpy])}/bin/python";
          lldb = "${pkgs.lldb}/bin/lldb-vscode";
          codelldb = "${pkgs.vscode-extensions.vadimcn.vscode-lldb}/share/vscode/extensions/vadimcn.vscode-lldb/adapter/codelldb";
          delve = "${pkgs.delve}/bin/dlv";
          bash = "${pkgs.bashdb}/bin/bashdb";
          bashdbLib = "${pkgs.bashdb}/share/bashdb";
        };
      };
    };
  };
}
