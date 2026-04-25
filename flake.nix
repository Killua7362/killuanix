{
  nixConfig = {
    extra-substituters = [
      "https://hyprland.cachix.org"
      "https://vicinae.cachix.org"
      "https://nix-community.cachix.org"
      "https://chaotic-nyx.cachix.org"
      "https://yazi.cachix.org"
      "https://attic.xuyh0120.win/lantian"
      "https://cache.garnix.io"
    ];
    extra-trusted-public-keys = [
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "chaotic-nyx.cachix.org-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8="
      "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k="
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # Pipewire 1.6.3 source for the killua (MSI Claw) host. The 1.6.2 build
    # in current nixpkgs has two unrelated bluez5 bugs that hit on Intel
    # Lunar Lake / CMF Buds Pro 2:
    #   - libldac-dec init bug → "LDAC decoder initialization failed:
    #     LDACBT_ERR_FATAL (268981248)"
    #   - SIGSEGV in libspa-bluez5.so spa_bt_device_supports_media_codec()
    #     when switching codecs (regcomp via do_match → get_features).
    # Both are fixed in 1.6.3. Specifically, upstream commit 99f901d
    # ("bluez5: fix spa_bt_device_supports_media_codec() for HFP codecs")
    # addresses the SEGV, and 1.6.3's LDAC codec dropped the libldac-dec
    # decoder dependency entirely so the libldac-dec bug no longer reaches
    # us. Used by killua/bluez5-ldac-pin.nix to swap only the bluez5/
    # subdir of pipewire's SPA plugin tree at runtime via SPA_PLUGIN_DIR;
    # pkgs.pipewire stays vanilla so downstream consumers (ffmpeg, gtk4,
    # electron, …) keep substituting from cache.
    nixpkgs-pipewire.url = "github:NixOS/nixpkgs/b9ca2db46f043c1dfcac36d8622653a430647f9f";

    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixpkgs-24.11-darwin";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-virtualbox.url = "github:NixOS/nixpkgs/346dd96ad74dc4457a9db9de4f4f57dab2e5731d";
    homemanager = {
      url = "github:rycee/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    emacs.url = "github:nix-community/emacs-overlay";
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin.url = "github:nix-darwin/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs-unstable";

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };

    flake-utils.url = "github:numtide/flake-utils";
    mk-darwin-system.url = "github:vic/mk-darwin-system/main";
    spacebar.url = "github:cmacrae/spacebar/v1.3.0";
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";

    nonNixosGpu = {
      url = "github:exzombie/non-nixos-gpu";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nixos specific packages
    nixospkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixospkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    quickshell = {
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";

      # THIS IS IMPORTANT
      # Mismatched system dependencies will lead to crashes and other issues.
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland.url = "github:hyprwm/Hyprland";
    portainer-on-nixos.url = "gitlab:cbleslie/portainer-on-nixos";
    portainer-on-nixos.inputs.nixpkgs.follows = "nixpkgs";

    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    globalprotect-openconnect.url = "github:yuezk/GlobalProtect-openconnect";

    vicinae-extensions.url = "github:vicinaehq/extensions";
    vicinae.url = "github:vicinaehq/vicinae";

    nixCats.url = "github:BirdeeHub/nixCats-nvim";

    opencode-flake.url = "github:aodhanhayter/opencode-flake";

    chaotic = {
      url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
      inputs.home-manager.follows = "home-manager";
    };

    arkenfox = {
      url = "github:dwarfmaster/arkenfox-nixos";
      inputs.flake-parts.follows = "flake-parts";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "systems";
    };

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };

    yazi.url = "github:sxyazi/yazi";
    nix-yazi-plugins = {
      url = "github:lordkekz/nix-yazi-plugins?ref=yazi-v0.2.5";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-yazi-flavors.url = "github:aguirre-matteo/nix-yazi-flavors";
    firefox.url = "github:nix-community/flake-firefox-nightly";
    firefox.inputs.nixpkgs.follows = "nixpkgs";
    zed-editor-flake.url = "github:Rishabh5321/zed-editor-flake";
    nixgl = {
      url = "github:nix-community/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    system-manager = {
      url = "github:numtide/system-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    quadlet-nix = {
      url = "github:SEIAROTg/quadlet-nix";
    };

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";
    claude-code.url = "github:sadjow/claude-code-nix";

    # Declarative MCP server catalog (Home Manager integration)
    mcp-servers-nix = {
      url = "github:natsukium/mcp-servers-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Obsidian community plugins/themes overlay — exposes pkgs.obsidianPlugins.*
    nixpille-obsidian-community-plugins = {
      url = "github:cjavad/nixpille-obsidian-community-plugins";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Official Anthropic skills repository — consumed as plain source
    anthropics-skills = {
      url = "github:anthropics/skills";
      flake = false;
    };

    # agentient/vibekit — cherry-picked skills (see modules/common/programs/dev/claude.nix)
    vibekit = {
      url = "github:agentient/vibekit";
      flake = false;
    };

    # ruvnet/ruflo — Claude Flow v3.5 (agents, commands, skills, CLI).
    # Wired in via modules/common/programs/dev/claude-resources.nix and
    # modules/common/programs/dev/ruflo-cli.nix.
    ruflo = {
      url = "github:ruvnet/ruflo/01070ede81fa6fbae93d01c347bec1af5d6c17f0";
      flake = false;
    };

    # wshobson/agents — Claude Code plugin marketplace (78 plugins, 184 agents,
    # 98 commands, 150 skills). Flattened into ~/.claude/ by claude-resources.nix.
    wshobson-agents = {
      url = "github:wshobson/agents/27a7ed95755a5c3a2948694343a8e2cd7a7ef6fb";
      flake = false;
    };

    # Handheld / MSI Claw
    nix-cachyos-kernel = {
      url = "github:xddxdd/nix-cachyos-kernel/release";
    };
    jovian = {
      url = "github:Jovian-Experiments/Jovian-NixOS";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    flake-utils,
    homemanager,
    home-manager,
    nixpkgs,
    neovim-nightly-overlay,
    nur,
    emacs,
    darwin,
    mk-darwin-system,
    nix-flatpak,
    nixospkgs,
    nixgl,
    system-manager,
    ...
  }: let
    inherit (darwin.lib) darwinSystem;
    inherit
      (inputs.nixpkgs-unstable.lib)
      attrValues
      makeOverridable
      optionalAttrs
      singleton
      ;

    systems = [
      "aarch64-linux"
      "i686-linux"
      "x86_64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];

    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);
    customOverlays = import ./overlays {inherit inputs;};
    nixosModules = import ./modules/nixos;
    homeManagerModules = import ./modules/home-manager;
    commonModules = import ./modules/common;
    crossPlatformModules = import ./modules/cross-platform;

    nixosConfigurations = {
      chrollo = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs;};
        modules = [
          ./chrollo/configuration.nix
          inputs.quadlet-nix.nixosModules.quadlet
        ];
      };
    };

    nixosConfigurations.killua = nixpkgs.lib.nixosSystem {
      specialArgs = {inherit inputs;};
      modules = [
        ./killua/configuration.nix
        inputs.quadlet-nix.nixosModules.quadlet
        inputs.jovian.nixosModules.jovian
        ({
          inputs,
          pkgs,
          ...
        }: {
          nixpkgs.overlays = [
            inputs.nix-cachyos-kernel.overlays.pinned
          ];
        })
      ];
    };

    darwinConfigurations = rec {
      macnix = darwinSystem {
        system = "aarch64-darwin";
        modules = [
          homemanager.darwinModules.home-manager
          ./macnix/packages/nix-index.nix
          ./macnix/settings.nix
          ./macnix/brew.nix
          ./macnix/packages
          ./macnix
        ];
      };
    };

    systemConfigs.default = system-manager.lib.makeSystemConfig {
      modules = [
        ./archnix/system-manager.nix
      ];
    };

    homeManagerConfigurations = {
      archnix = home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs-unstable.legacyPackages.x86_64-linux;
        extraSpecialArgs = {
          inherit inputs nixgl;
        };
        modules = [
          inputs.chaotic.homeManagerModules.default
          inputs.nix-flatpak.homeManagerModules.nix-flatpak
          inputs.vicinae.homeManagerModules.default
          inputs.nixCats.homeModule
          inputs.dms.homeModules.dank-material-shell
          inputs.nix-index-database.homeModules.default
          # inputs.nix-yazi-plugins.legacyPackages.x86_64-linux.homeManagerModules.default # TODO: Revisit in future
          ./archnix/home.nix
        ];
      };

      # Standalone Home Manager for the chrollo NixOS host.
      # Apply with: home-manager switch --flake .#chrollo
      chrollo = home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = {inherit inputs;};
        modules = [
          ./chrollo/home-manager/home.nix
        ];
      };

      # Standalone Home Manager for the killua NixOS host (MSI Claw).
      # Apply with: home-manager switch --flake .#killua
      killua = home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = {inherit inputs;};
        modules = [
          ./killua/home.nix
        ];
      };
    };
  };
}
