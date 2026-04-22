{
  config,
  pkgs,
  lib,
  ...
}: let
  p = config.theme.palette;
  op = pkgs.obsidianPlugins;

  # Minimal theme by @kepano — popular dark Obsidian theme that pairs well
  # with the kitty terminal aesthetic. We fetch the repo and wrap it as a
  # theme package the HM module can install into .obsidian/themes/Minimal/.
  minimalSrc = builtins.fetchGit {
    url = "https://github.com/kepano/obsidian-minimal";
    rev = "b0b08ab466d53ea8c7a1d93e79555df084ea89ac";
    shallow = true;
  };
  minimalTheme = pkgs.runCommand "obsidian-theme-minimal" {} ''
    mkdir -p $out
    cp ${minimalSrc}/manifest.json $out/
    # Obsidian loads themes/<name>/theme.css; Minimal ships both theme.css
    # and a legacy obsidian.css — prefer theme.css.
    if [ -f ${minimalSrc}/theme.css ]; then
      cp ${minimalSrc}/theme.css $out/
    else
      cp ${minimalSrc}/obsidian.css $out/theme.css
    fi
  '';

  # Small polish snippet that keeps the editor monospace in sync with kitty
  # (JetBrainsMono Nerd Font) and nudges the chrome toward the terminal's
  # flat look without overriding Minimal's colors.
  paletteCss = ''
    /* Sync editor monospace with kitty's JetBrainsMono Nerd Font; keep
       ligatures on since kitty renders them. Other colors/layout come
       from the Minimal theme. */
    body {
      --font-monospace-theme: "JetBrainsMono Nerd Font", "JetBrains Mono", ui-monospace, monospace;
    }

    .cm-s-obsidian .cm-line,
    .markdown-rendered pre,
    .markdown-rendered code {
      font-family: var(--font-monospace-theme);
      font-feature-settings: "liga", "calt";
    }

    /* Match kitty's exact bg so transitioning between terminal and notes
       is seamless. Minimal's default dark bg is close but not identical. */
    .theme-dark {
      --background-primary:   ${p.bg};
      --background-secondary: ${p.color8};
    }

    /* Full-width notes: strip side padding from editor and preview so
       content fills the whole pane. `readableLineLength` is already off
       in app.json; this removes the residual frame padding Minimal adds. */
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

    .markdown-source-view.mod-cm6 .cm-content,
    .markdown-source-view.mod-cm6 .cm-line,
    .markdown-preview-view > div {
      max-width: 100% !important;
      padding-left: 8px !important;
      padding-right: 8px !important;
    }

    /* Remove the vertical gap above the first heading / line */
    .markdown-source-view.mod-cm6 .cm-scroller {
      padding-top: 0 !important;
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
            pkg = minimalTheme;
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
          # Icon Folder (Iconize): per-file/folder icons in the file explorer.
          # Seeded with regex rules so common file types render automatically;
          # right-click → "Change icon" to override per-file.
          {
            pkg = op.obsidian-icon-folder;
            settings = {
              iconPacksPath = ".obsidian/icons";
              iconsBackgroundCheckEnabled = true;
              iconInTabsEnabled = true;
              iconInFrontmatterEnabled = true;
              iconInTitleEnabled = "above";
              rules = [
                {
                  rule = "^dailies$";
                  icon = "LuCalendar";
                  color = "#89ceff";
                  order = 0;
                  for = "folders";
                  useFilePath = false;
                }
                {
                  rule = "^templates$";
                  icon = "LuFileCode";
                  color = "#aca98a";
                  order = 1;
                  for = "folders";
                  useFilePath = false;
                }
                {
                  rule = "^_inbox$";
                  icon = "LuInbox";
                  color = "#ac8aac";
                  order = 2;
                  for = "folders";
                  useFilePath = false;
                }
                {
                  rule = "^_claude$";
                  icon = "LuBot";
                  color = "#8aacab";
                  order = 3;
                  for = "folders";
                  useFilePath = false;
                }
                {
                  rule = "\\.canvas$";
                  icon = "LuLayoutDashboard";
                  color = "#89ceff";
                  order = 10;
                  for = "everything";
                  useFilePath = false;
                }
                {
                  rule = "\\.excalidraw\\.md$";
                  icon = "LuPencilRuler";
                  color = "#8aac8b";
                  order = 11;
                  for = "everything";
                  useFilePath = false;
                }
                {
                  rule = "\\.md$";
                  icon = "LuFileText";
                  color = "#e2e2e2";
                  order = 99;
                  for = "everything";
                  useFilePath = false;
                }
              ];
            };
          }
        ];

        cssSnippets = [
          {
            name = "palette";
            text = paletteCss;
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

    # Vim keybindings — read by obsidian-vimrc-support from <vault>/.obsidian.vimrc.
    "${vaultRel}/.obsidian.vimrc".text = obsidianVimrc;

    # Claude Code state surfaced into the vault so Obsidian can open/edit it.
    # mkOutOfStoreSymlink points at the live path, so edits write through.
    "${vaultRel}/_claude/plans".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.claude/plans";

    "${vaultRel}/_claude/skills".source =
      config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/killuanix/modules/common/programs/dev/skills";

    "${vaultRel}/_claude/docs/root-CLAUDE.md".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/killuanix/CLAUDE.md";

    "${vaultRel}/_claude/docs/dev-CLAUDE.md".source =
      config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/killuanix/modules/common/programs/dev/CLAUDE.md";

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
