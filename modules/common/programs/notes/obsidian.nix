{
  config,
  pkgs,
  lib,
  ...
}: let
  op = pkgs.obsidianPlugins;

  # AnuPpuccin theme by @AnubisNekhet — Catppuccin-flavored Obsidian theme
  # with an "extended colorschemes" snippet that adds palettes outside the
  # Catppuccin family (Atom, Nord, Gruvbox, Dracula, etc). We pick Atom Dark
  # via Style Settings — see the obsidian-style-settings entry below.
  anuppuccinSrc = builtins.fetchGit {
    url = "https://github.com/AnubisNekhet/AnuPpuccin";
    rev = "82d207c646904e7af371ced499f682fbdfad1012";
    shallow = true;
  };
  anuppuccinTheme = pkgs.runCommand "obsidian-theme-anuppuccin" {} ''
    mkdir -p $out
    cp ${anuppuccinSrc}/manifest.json $out/
    # Obsidian loads themes/<name>/theme.css; AnuPpuccin ships both theme.css
    # (compiled) and obsidian.css (legacy companion) — prefer theme.css.
    if [ -f ${anuppuccinSrc}/theme.css ]; then
      cp ${anuppuccinSrc}/theme.css $out/
    else
      cp ${anuppuccinSrc}/obsidian.css $out/theme.css
    fi
  '';

  # Extended colorschemes snippet from AnuPpuccin's repo — adds Atom, Nord,
  # Gruvbox, Dracula, etc. on top of the base Catppuccin flavors. Required
  # for Atom Dark; Style Settings reads this snippet's @settings block to
  # populate the extended dark/light dropdowns.
  extendedColorschemesCss = builtins.readFile "${anuppuccinSrc}/snippets/extended-colorschemes.css";

  # Custom rainbow folder colors snippet — lets Style Settings choose which
  # Catppuccin palette colors appear per folder depth and how many cycle.
  customRainbowColorsCss = builtins.readFile "${anuppuccinSrc}/snippets/custom-rainbow-colors.css";

  # Small polish snippet that keeps the editor monospace in sync with kitty
  # (JetBrainsMono Nerd Font) and forces full-width notes. Background
  # colors come from AnuPpuccin's Atom Dark palette — don't override them.
  paletteCss = ''
    /* Sync editor monospace with kitty's JetBrainsMono Nerd Font; keep
       ligatures on since kitty renders them. Colors/layout come from
       AnuPpuccin + the extended Atom Dark scheme. */
    body {
      --font-monospace-theme: "JetBrainsMono Nerd Font", "JetBrains Mono", ui-monospace, monospace;
    }

    .cm-s-obsidian .cm-line,
    .markdown-rendered pre,
    .markdown-rendered code {
      font-family: var(--font-monospace-theme);
      font-feature-settings: "liga", "calt";
    }

    /* Full-width notes: strip side padding from editor and preview so
       content fills the whole pane. `readableLineLength` is already off
       in app.json; this removes the residual frame padding the theme adds. */
    body {
      --file-margins: 0 !important;
      --file-folding-offset: 0 !important;
    }

    .markdown-source-view.mod-cm6 .cm-contentContainer,
    .markdown-source-view.mod-cm6 .cm-sizer,
    .markdown-preview-view,
    .markdown-reading-view {
      padding-left: 0 !important;
      padding-right: 0 !important;
      max-width: 100% !important;
    }

    /* Indent the gutter+content block away from the pane edge so it
       doesn't sit flush against the file-explorer divider. */
    .markdown-source-view.mod-cm6 .cm-editor {
      padding-left: 24px !important;
    }

    .markdown-source-view.mod-cm6 .cm-content,
    .markdown-source-view.mod-cm6 .cm-line,
    .markdown-preview-view > div {
      max-width: 100% !important;
      padding-left: 16px !important;
      padding-right: 24px !important;
    }

    .markdown-source-view.mod-cm6 .cm-scroller {
      padding-top: 12px !important;
    }
  '';

  # Colemak vim keymap. Minimal-only — if this doesn't apply, the plugin
  # isn't loading the file at all (not a syntax issue). Uses `noremap`
  # explicitly (obsidian-vimrc-support aliases `map` = `noremap` but the
  # explicit form is unambiguous).
  #
  # DIAGNOSTIC: the line `noremap ;; :cmdPalette<CR>` below binds a
  # visible canary — press `;;` in normal mode and the command palette
  # should open. If it doesn't, the vimrc isn't loading.
  obsidianVimrc = ''
    exmap cmdPalette obcommand command-palette:open
    nnoremap ;; :cmdPalette<CR>

    " Motion — NEIO replaces HJKL
    nnoremap n h
    nnoremap e j
    nnoremap i k
    nnoremap o l
    vnoremap n h
    vnoremap e j
    vnoremap i k
    vnoremap o l

    " Insert / append (u / U replaces i / I)
    nnoremap u i
    nnoremap U I

    " Open new line below / above (y / Y replaces o / O)
    nnoremap y o
    nnoremap Y O

    " End-of-word on j (since j moved to 'e')
    nnoremap j e
    vnoremap j e

    " Search next / previous (h / H replaces n / N)
    nnoremap h n
    nnoremap H N

    " Yank on l (replaces y)
    nnoremap l y
    vnoremap l y

    " Undo on k (replaces u)
    nnoremap k u
  '';

  # The nixpille overlay only has 0.2.0 which has known issues; pin to latest
  # from the obsidian-community fork (the canonical source per community-plugins.json).
  imageToolkit = pkgs.stdenv.mkDerivation {
    pname = "obsidian-image-toolkit";
    version = "1.4.3";
    src = pkgs.fetchzip {
      url = "https://github.com/obsidian-community/obsidian-image-toolkit/releases/download/1.4.3/obsidian-image-toolkit-1.4.3.zip";
      hash = "sha256-j5uTxEgAedx9uqduYdM4gkfqs6/sxDG5nP9IRt3xBks=";
    };
    installPhase = ''
      mkdir -p $out
      cp -r * $out/
    '';
  };

  vaultRel = "killuanix/Notes";
in {
  programs.obsidian = {
    enable = true;
    package = pkgs.obsidian;

    vaults."killuanix-notes" = {
      enable = true;
      target = vaultRel;

      settings = {
        app = {
          # Full-width content: disable Obsidian's narrow "readable line
          # length" column and let text fill the pane.
          readableLineLength = false;
          livePreview = true;
          vimMode = true;
          defaultViewMode = "source";
          promptDelete = false;
          showLineNumber = true;
          alwaysUpdateLinks = true;
          useMarkdownLinks = false;
          newLinkFormat = "shortest";
        };

        appearance = {
          baseFontSize = 16;
          # cssTheme is written automatically from the enabled theme below.
        };

        themes = [
          {
            pkg = anuppuccinTheme;
            enable = true;
          }
        ];

        corePlugins = [
          {
            name = "templates";
            settings = {
              folder = "templates";
              format = "YYYY-MM-DD";
            };
          }
          {
            name = "daily-notes";
            settings = {
              folder = "dailies";
              format = "YYYY-MM-DD";
              template = "templates/daily.md";
            };
          }
          "file-explorer"
          "global-search"
          "switcher"
          "graph"
          "backlink"
          "outgoing-link"
          "outline"
          "tag-pane"
          "properties"
          "page-preview"
          "command-palette"
          "file-recovery"
          "bookmarks"
          "canvas"
          "editor-status"
          "word-count"
          "note-composer"
        ];

        communityPlugins = [
          # Style Settings — required by AnuPpuccin to pick a palette. Keys
          # in `settings` follow the plugin's `<@settings.id>@@<item.id>`
          # convention and become entries in the plugin's data.json.
          # Wired here to enable the extended dark scheme and pin Atom Dark.
          {
            pkg = op.obsidian-style-settings;
            settings = {
              # Atom Dark palette (requires extended-colorschemes snippet)
              "anuppuccin-theme-settings-extended@@anp-theme-ext-dark" = true;
              "anuppuccin-theme-settings-extended@@catppuccin-theme-dark-extended" = "ctp-atom-dark";
              # Rainbow folders — simple style: colored title text, collapse icon,
              # indentation guide, and a colored ⬤ dot appended after the name.
              "anuppuccin-theme-settings@@anp-alt-rainbow-style" = "anp-simple-rainbow-color-toggle";
              "anuppuccin-theme-settings@@anp-simple-rainbow-title-toggle" = true;
              "anuppuccin-theme-settings@@anp-simple-rainbow-collapse-icon-toggle" = true;
              "anuppuccin-theme-settings@@anp-simple-rainbow-indentation-toggle" = true;
              "anuppuccin-theme-settings@@anp-simple-rainbow-icon-toggle" = true;
              "anuppuccin-theme-settings@@anp-rainbow-subfolder-color-toggle" = true;
              # Custom rainbow colors snippet: cycle all 11 Catppuccin accent colors
              "anp-custom-rainbow-colors@@rainbow-color-repeat" = "rainbow-repeat-11";
              # Minimalistic tab style — flat tabs with a bottom underline on the active tab
              "anuppuccin-theme-settings@@anp-alt-tab-style" = "anp-mini-tab-toggle";
            };
          }
          {
            pkg = op.obsidian-git;
            settings = {
              commitMessage = "vault: {{date}}";
              commitDateFormat = "YYYY-MM-DD HH:mm:ss";
              # All automatic git activity off — commits, pushes, and pulls
              # happen only when triggered from the command palette
              # (Obsidian Git: Create backup / Push / Pull).
              autoSaveInterval = 0;
              autoPushInterval = 0;
              autoPullInterval = 0;
              autoPullOnBoot = false;
            };
          }
          op.dataview
          op.obsidian-excalidraw-plugin
          # Draw.io embedded editor — creates/edits `.drawio.svg` / `.drawio.png`
          # diagrams inside Obsidian (zapthedingbat's plugin).
          op.obsidian-diagrams-net
          # Mermaid polish: theming, zoom/pan, hover preview, quick actions.
          op.mermaid-tools
          op.mermaid-themes
          op.mermaid-popup
          op.mermaid-helper
          op.diagram-zoom-drag
          op.table-editor-obsidian
          op.obsidian-tasks-plugin
          op.calendar
          op.templater-obsidian
          op.nldates-obsidian
          # Vimrc Support: reads <vault>/.obsidian.vimrc at startup so
          # Obsidian's vim mode can be customized like .vimrc / init.vim.
          op.obsidian-vimrc-support
          # Icon Folder (Iconize): custom icons per folder/file in the explorer.
          # Settings are written via home.file below (not here) because the HM
          # obsidian module serialises plugin.settings to the TOP LEVEL of
          # data.json, but Iconize reads settings from data.settings (nested).
          # Writing at the top level causes `data.settings[k]` to throw
          # TypeError on load, crashing the plugin.
          op.obsidian-icon-folder
          op.notebook-navigator
          # Image Toolkit: zoom with Ctrl+scroll and drag-to-pan with left click.
          # Pinned to 1.4.2 — nixpille overlay only has 0.2.0 (known issues).
          imageToolkit
        ];

        cssSnippets = [
          {
            name = "palette";
            text = paletteCss;
          }
          # AnuPpuccin's extended palettes (Atom, Nord, Gruvbox, Dracula, …).
          # Style Settings picks Atom Dark via the keys above; without this
          # snippet enabled, those classes have no styles attached.
          {
            name = "anuppuccin-extended-colorschemes";
            text = extendedColorschemesCss;
          }
          # Rainbow folder color definitions — required for the custom color
          # cycling set by `anp-custom-rainbow-colors@@rainbow-color-repeat`.
          {
            name = "anuppuccin-custom-rainbow-colors";
            text = customRainbowColorsCss;
          }
        ];

        hotkeys = {
          "editor:toggle-bold" = [
            {
              modifiers = ["Mod"];
              key = "B";
            }
          ];
          "editor:toggle-italics" = [
            {
              modifiers = ["Mod"];
              key = "I";
            }
          ];
          "command-palette:open" = [
            {
              modifiers = ["Mod"];
              key = "P";
            }
          ];
          "switcher:open" = [
            {
              modifiers = ["Mod"];
              key = "O";
            }
          ];
          "workspace:split-vertical" = [
            {
              modifiers = ["Mod"];
              key = "\\";
            }
          ];
          "app:go-back" = [
            {
              modifiers = ["Mod" "Alt"];
              key = "ArrowLeft";
            }
          ];
          "app:go-forward" = [
            {
              modifiers = ["Mod" "Alt"];
              key = "ArrowRight";
            }
          ];
          "daily-notes" = [
            {
              modifiers = ["Mod" "Shift"];
              key = "D";
            }
          ];
        };
      };
    };
  };

  # Markdown templates go in <vault>/templates/ (not inside .obsidian/, which is
  # where programs.obsidian.vaults.*.settings.extraFiles writes).
  home.file = {
    "${vaultRel}/templates/daily.md".source = ./templates/daily.md;
    "${vaultRel}/templates/meeting.md".source = ./templates/meeting.md;
    "${vaultRel}/templates/project.md".source = ./templates/project.md;
    "${vaultRel}/templates/clipper.md".source = ./templates/clipper.md;

    # Iconize data.json — written directly because the HM obsidian module puts
    # plugin.settings at the top level of data.json, but Iconize reads from
    # data.settings (nested). The mismatch causes a TypeError crash on load.
    # We bypass the plugin settings mechanism entirely and write the file here
    # with the correct structure. `migrated: 6` skips all five migration steps
    # (each of which calls saveData, which would fail writing through the
    # read-only Nix-store symlink). recentlyUsedIcons/Size defaults prevent the
    # checkRecentlyUsedIcons saveData path from triggering.
    "${vaultRel}/.obsidian/plugins/obsidian-icon-folder/data.json".text = builtins.toJSON {
      settings = {
        lucideIconPackType = "native";
        iconInTabsEnabled = true;
        iconInFrontmatterEnabled = true;
        iconInFrontmatterFieldName = "icon";
        iconColorInFrontmatterFieldName = "iconColor";
        iconInTitleEnabled = "above";
        iconInTitlePosition = "above";
        iconPacksPath = ".obsidian/icons";
        iconsBackgroundCheckEnabled = false;
        iconsInNotesEnabled = true;
        iconsInLinksEnabled = true;
        iconIdentifier = ":";
        debugMode = false;
        useInternalPlugins = false;
        recentlyUsedIcons = [];
        recentlyUsedIconsSize = 5;
        migrated = 6;
        rules = [
          # --- Folders ---
          {
            rule = "^dailies$";
            icon = "LiCalendarDays";
            order = 0;
            for = "folders";
            useFilePath = false;
          }
          {
            rule = "^templates$";
            icon = "LiLayoutTemplate";
            order = 1;
            for = "folders";
            useFilePath = false;
          }
          {
            rule = "^_inbox$";
            icon = "LiInbox";
            order = 2;
            for = "folders";
            useFilePath = false;
          }
          {
            rule = "^_claude$";
            icon = "LiBot";
            order = 3;
            for = "folders";
            useFilePath = false;
          }
          {
            rule = "^skills$";
            icon = "LiBrainCircuit";
            order = 4;
            for = "folders";
            useFilePath = false;
          }
          # --- Specific template files ---
          {
            rule = "^clipper\\.md$";
            icon = "LiClipboard";
            order = 20;
            for = "files";
            useFilePath = false;
          }
          {
            rule = "^daily\\.md$";
            icon = "LiSunMedium";
            order = 21;
            for = "files";
            useFilePath = false;
          }
          {
            rule = "^meeting\\.md$";
            icon = "LiUsers";
            order = 22;
            for = "files";
            useFilePath = false;
          }
          {
            rule = "^project\\.md$";
            icon = "LiKanbanSquare";
            order = 23;
            for = "files";
            useFilePath = false;
          }
          # --- File-type rules ---
          {
            rule = "\\.canvas$";
            icon = "LiLayoutDashboard";
            order = 30;
            for = "everything";
            useFilePath = false;
          }
          {
            rule = "\\.excalidraw\\.md$";
            icon = "LiPencilRuler";
            order = 31;
            for = "everything";
            useFilePath = false;
          }
          {
            rule = "\\.md$";
            icon = "LiFileText";
            order = 99;
            for = "everything";
            useFilePath = false;
          }
        ];
      };
    };

    # Vim keybindings — read by obsidian-vimrc-support from <vault>/.obsidian.vimrc.
    "${vaultRel}/.obsidian.vimrc".text = obsidianVimrc;

    # Claude Code state surfaced into the vault so Obsidian can open/edit it.
    # mkOutOfStoreSymlink points at the live path, so edits write through.
    "${vaultRel}/_claude/plans".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.claude/plans";

    "${vaultRel}/_claude/skills".source =
      config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/killuanix/Notes/claude/skills";

    "${vaultRel}/_claude/docs/root-CLAUDE.md".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/killuanix/CLAUDE.md";

    "${vaultRel}/_claude/docs/dev-CLAUDE.md".source =
      config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/killuanix/modules/common/programs/dev/CLAUDE.md";

    "${vaultRel}/_claude/docs/ai-CLAUDE.md".source =
      config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/killuanix/modules/common/programs/dev/ai/CLAUDE.md";

    "${vaultRel}/_claude/docs/browsers-CLAUDE.md".source =
      config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/killuanix/modules/common/programs/browsers/CLAUDE.md";

    "${vaultRel}/_claude/docs/hyprland-CLAUDE.md".source =
      config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/killuanix/modules/common/programs/desktop/hyprland/CLAUDE.md";

    "${vaultRel}/_claude/docs/utils-CLAUDE.md".source =
      config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/killuanix/modules/common/programs/utils/CLAUDE.md";
  };
}
