{
  config,
  pkgs,
  lib,
  hostName ? null,
  ...
}: let
  p = config.theme.palette;
  # WezTerm as terminal + native multiplexer, replacing tmux + zellij.
  # Gated to the two NixOS hosts: archnix already symlinks ~/.config/wezterm
  # from DotFiles (would collide with the HM-written wezterm.lua) and macnix
  # installs wezterm via Homebrew. hostName is only passed for chrollo/killua
  # (flake.nix), so it is null everywhere else and this stays disabled there.
  isTargetHost = hostName == "chrollo" || hostName == "killua";
in {
  programs.wezterm = {
    enable = lib.mkDefault (pkgs.stdenv.isLinux && isTargetHost);
    # extraConfig is written verbatim to ~/.config/wezterm/wezterm.lua.
    # Palette values are interpolated from config.theme.palette (static,
    # matches kitty/ghostty/tmux). Colemak neio = left/down/up/right.
    extraConfig = ''
      local wezterm = require("wezterm")
      local act = wezterm.action
      local config = wezterm.config_builder()

      -- ── Palette (from Nix config.theme.palette) ──────────────────────────
      local pal = {
        fg = "${p.fg}",
        bg = "${p.bg}",
        cursor = "${p.cursor}",
        cursor_text = "${p.cursor_text}",
        selection_fg = "${p.selection_fg}",
        selection_bg = "${p.selection_bg}",
        zellij_bg = "${p.zellij_bg}",
        color0 = "${p.color0}",  color1 = "${p.color1}",
        color2 = "${p.color2}",  color3 = "${p.color3}",
        color4 = "${p.color4}",  color5 = "${p.color5}",
        color6 = "${p.color6}",  color7 = "${p.color7}",
        color8 = "${p.color8}",  color9 = "${p.color9}",
        color10 = "${p.color10}", color11 = "${p.color11}",
        color12 = "${p.color12}", color13 = "${p.color13}",
        color14 = "${p.color14}", color15 = "${p.color15}",
      }

      -- ── Appearance ───────────────────────────────────────────────────────
      config.font = wezterm.font("JetBrainsMono Nerd Font")
      config.font_size = 12.0
      config.window_decorations = "NONE"
      config.window_padding = { left = 12, right = 12, top = 12, bottom = 12 }
      config.scrollback_lines = 1000000
      config.default_prog = { "zsh", "-l" }
      config.window_close_confirmation = "NeverPrompt"
      config.status_update_interval = 1000
      config.enable_tab_bar = true
      config.use_fancy_tab_bar = true
      config.tab_bar_at_bottom = false
      config.hide_tab_bar_if_only_one_tab = false
      config.tab_max_width = 32
      config.show_new_tab_button_in_tab_bar = false
      config.show_tab_index_in_tab_bar = false
      config.window_frame = {
        font = wezterm.font({ family = "JetBrainsMono Nerd Font", weight = "Bold" }),
        font_size = 11.0,
        active_titlebar_bg = pal.zellij_bg,
        inactive_titlebar_bg = pal.zellij_bg,
      }

      config.colors = {
        foreground = pal.fg,
        background = pal.bg,
        cursor_bg = pal.cursor,
        cursor_fg = pal.cursor_text,
        cursor_border = pal.cursor,
        selection_bg = pal.selection_bg,
        selection_fg = pal.selection_fg,
        ansi = {
          pal.color0, pal.color1, pal.color2, pal.color3,
          pal.color4, pal.color5, pal.color6, pal.color7,
        },
        brights = {
          pal.color8, pal.color9, pal.color10, pal.color11,
          pal.color12, pal.color13, pal.color14, pal.color15,
        },
        tab_bar = {
          background = pal.zellij_bg,
          active_tab = { bg_color = pal.color4, fg_color = pal.bg, intensity = "Bold" },
          inactive_tab = { bg_color = pal.zellij_bg, fg_color = pal.fg },
          inactive_tab_hover = { bg_color = pal.color8, fg_color = pal.fg },
          new_tab = { bg_color = pal.zellij_bg, fg_color = pal.fg },
          new_tab_hover = { bg_color = pal.color8, fg_color = pal.fg },
        },
      }

      -- ── Mux persistence: survives closing the GUI window (disconnect-only;
      --    nothing restored across reboot, same as base tmux/zellij) ─────────
      config.unix_domains = { { name = "unix" } }

      -- ── Leader = Ctrl-a (tmux prefix parity) ─────────────────────────────
      config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 1000 }

      -- ── Autolock passthrough ─────────────────────────────────────────────
      -- Forward mode-entry chords to the focused program (nvim/fzf/lazygit/…)
      -- instead of grabbing them. IS_NVIM user-var (set by smart-splits.nvim,
      -- deferred) is authoritative; get_foreground_process_name() is a
      -- best-effort fallback (flaky over SSH) until that is wired.
      -- Trigger substrings (matched loosely so nix wrappers like
      -- ".fzf-wrapped" and pipeline scripts like "git-forgit" still hit).
      local TRIGGERS = {
        "nvim", "vim", "view", "git", "fzf", "zoxide",
        "atuin", "lazygit", "zj-proj", "ghgrab",
      }
      local function line_is_trigger(line)
        line = line:lower()
        for _, t in ipairs(TRIGGERS) do
          if line:find(t, 1, true) then return true end
        end
        return false
      end
      -- User vars are the ONLY signal that survives the `wezterm connect unix`
      -- mux (get_foreground_process_name()/get_tty_name() return nil there):
      --   IS_NVIM      — set by nvim (editors/neovim/.../autocmds.lua)
      --   WEZTERM_PROG — set by the zsh preexec/precmd hook (shells/zsh.nix) to
      --                  the running command; "fzf" when it wraps forgit/fzf.
      -- The tty ps scan below only helps non-mux panes (direct `wezterm` window).
      local function is_passthrough(pane)
        local uv = pane:get_user_vars()
        if uv.IS_NVIM == "true" then return true end
        local prog = uv.WEZTERM_PROG
        if prog and prog ~= "" and line_is_trigger(prog) then return true end
        local tty = pane.get_tty_name and pane:get_tty_name() or nil
        if tty then
          local pok, ok, stdout = pcall(
            wezterm.run_child_process,
            { "${pkgs.procps}/bin/ps", "-o", "comm=", "-t", tty }
          )
          if pok and ok and stdout then
            for line in stdout:gmatch("[^\r\n]+") do
              if line_is_trigger(line) then return true end
            end
            return false
          end
        end
        local name = pane:get_foreground_process_name()
        return name ~= nil and line_is_trigger(name)
      end

      -- Mode-entry key that passes through to the program when appropriate.
      local function guarded(key, mods, action)
        return {
          key = key,
          mods = mods,
          action = wezterm.action_callback(function(win, pane)
            if is_passthrough(pane) then
              win:perform_action(act.SendKey({ key = key, mods = mods }), pane)
            else
              win:perform_action(action, pane)
            end
          end),
        }
      end

      -- Alt-neio always moves between WezTerm panes. Seamless nvim-split
      -- crossing (smart-splits.nvim) is deferred — inside nvim use Ctrl-w neio.
      -- Not forwarded into nvim: the stale zellij-nav.nvim binding would eat it.
      local nav_dir = { n = "Left", e = "Down", i = "Up", o = "Right" }
      local function nav(key)
        return { key = key, mods = "ALT", action = act.ActivatePaneDirection(nav_dir[key]) }
      end

      -- Dump this pane's scrollback (last 20k lines) into nvim in a new tab.
      -- Temp file may hold secrets — removed on exit.
      local scrollback_edit = wezterm.action_callback(function(win, pane)
        local pid = tostring(pane:pane_id())
        win:perform_action(
          act.SpawnCommandInNewTab({
            args = {
              "sh", "-lc",
              "wezterm cli get-text --pane-id " .. pid ..
                " --start-line -20000 > /tmp/wz-scroll.txt 2>/dev/null; " ..
                "nvim /tmp/wz-scroll.txt; rm -f /tmp/wz-scroll.txt",
            },
          }),
          pane
        )
      end)

      local rename_tab = act.PromptInputLine({
        description = "Rename tab:",
        action = wezterm.action_callback(function(win, _, line)
          if line and #line > 0 then win:active_tab():set_title(line) end
        end),
      })

      -- ── QuickSelect (Alt-x): defaults + git-sha + ipv4 ───────────────────
      config.quick_select_patterns = {
        "[0-9a-f]{7,40}",
        "([0-9]{1,3}\\.){3}[0-9]{1,3}",
      }

      -- ── Direct global keys ───────────────────────────────────────────────
      config.keys = {
        -- Modal mode entries. Matching the zellij setup: only Ctrl-p and Ctrl-n
        -- pass through to the focused tool when locked (their zellij binds
        -- excluded "locked"); Ctrl-t/s/h/m stayed with the mux in every mode,
        -- so they are plain (unguarded) here and always grab regardless of focus.
        guarded("p", "CTRL", act.ActivateKeyTable({ name = "pane_mode",   one_shot = false, prevent_fallback = true })),
        guarded("n", "CTRL", act.ActivateKeyTable({ name = "resize_mode", one_shot = false, prevent_fallback = true })),
        { key = "t", mods = "CTRL", action = act.ActivateKeyTable({ name = "tab_mode",  one_shot = false, prevent_fallback = true }) },
        { key = "h", mods = "CTRL", action = act.ActivateKeyTable({ name = "move_mode", one_shot = false, prevent_fallback = true }) },
        { key = "m", mods = "CTRL", action = act.ActivateKeyTable({ name = "move_mode", one_shot = false, prevent_fallback = true }) },
        { key = "s", mods = "CTRL", action = act.ActivateCopyMode },

        -- Lock: swallow everything until Ctrl-g/Esc (not guarded)
        { key = "g", mods = "CTRL", action = act.ActivateKeyTable({ name = "locked", one_shot = false, prevent_fallback = true }) },
        { key = "q", mods = "CTRL", action = act.QuitApplication },
        -- Kill the default Ctrl-Shift-W (CloseCurrentTab) to avoid accidental
        -- tab close — tabs close via Ctrl-t x / Alt-w / leader x instead.
        { key = "w", mods = "CTRL|SHIFT", action = act.DisableDefaultAssignment },
        -- Ctrl-Backspace -> ^W (backward-kill-word in zsh/readline). WezTerm
        -- otherwise sends bare ^H, which shells treat as plain backspace.
        { key = "Backspace", mods = "CTRL", action = act.SendString("\x17") },

        -- Seamless nav (Alt + neio)
        nav("n"), nav("e"), nav("i"), nav("o"),

        -- Direct Alt actions
        { key = "h", mods = "ALT", action = act.SpawnTab("CurrentPaneDomain") },
        { key = "f", mods = "ALT", action = act.TogglePaneZoomState },
        { key = "w", mods = "ALT", action = act.CloseCurrentPane({ confirm = false }) },
        { key = "s", mods = "ALT", action = act.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }) },
        { key = "p", mods = "ALT", action = act.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }) },
        { key = "x", mods = "ALT", action = act.QuickSelect },
        { key = "[", mods = "ALT", action = act.SwitchWorkspaceRelative(-1) },
        { key = "]", mods = "ALT", action = act.SwitchWorkspaceRelative(1) },
        { key = "i", mods = "ALT|SHIFT", action = act.MoveTabRelative(-1) },
        { key = "o", mods = "ALT|SHIFT", action = act.MoveTabRelative(1) },
        { key = "Tab", mods = "CTRL", action = act.ActivateTabRelative(1) },
        { key = "Tab", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(-1) },

        -- Leader (C-a) prefix binds
        { key = "h", mods = "LEADER", action = act.SplitPane({ direction = "Right", size = { Percent = 50 } }) },
        { key = "r", mods = "LEADER", action = act.SplitPane({ direction = "Down", size = { Percent = 50 } }) },
        { key = "c", mods = "LEADER", action = act.SpawnTab("CurrentPaneDomain") },
        { key = "x", mods = "LEADER", action = act.CloseCurrentPane({ confirm = true }) },
        { key = "f", mods = "LEADER", action = act.TogglePaneZoomState },
        { key = "d", mods = "LEADER", action = act.DetachDomain("CurrentPaneDomain") },
        { key = "s", mods = "LEADER", action = act.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }) },
        { key = "p", mods = "LEADER", action = act.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }) },
        { key = "[", mods = "LEADER", action = act.ActivateCopyMode },
        { key = "R", mods = "LEADER", action = act.ReloadConfiguration },
        { key = "v", mods = "LEADER", action = scrollback_edit },
      }
      -- Leader 1..9 -> jump to tab
      for i = 1, 9 do
        table.insert(config.keys, {
          key = tostring(i), mods = "LEADER", action = act.ActivateTab(i - 1),
        })
      end

      -- ── Key tables (modal modes) ─────────────────────────────────────────
      config.key_tables = {
        pane_mode = {
          { key = "h", action = act.Multiple({ act.SplitPane({ direction = "Right", size = { Percent = 50 } }), act.PopKeyTable }) },
          { key = "r", action = act.Multiple({ act.SplitPane({ direction = "Right", size = { Percent = 50 } }), act.PopKeyTable }) },
          { key = "d", action = act.Multiple({ act.SplitPane({ direction = "Down",  size = { Percent = 50 } }), act.PopKeyTable }) },
          { key = "f", action = act.Multiple({ act.TogglePaneZoomState, act.PopKeyTable }) },
          { key = "x", action = act.Multiple({ act.CloseCurrentPane({ confirm = false }), act.PopKeyTable }) },
          { key = "p", action = act.PaneSelect({ mode = "Activate" }) },
          { key = "n", action = act.ActivatePaneDirection("Left") },
          { key = "e", action = act.ActivatePaneDirection("Down") },
          { key = "i", action = act.ActivatePaneDirection("Up") },
          { key = "o", action = act.ActivatePaneDirection("Right") },
          { key = "LeftArrow",  action = act.ActivatePaneDirection("Left") },
          { key = "DownArrow",  action = act.ActivatePaneDirection("Down") },
          { key = "UpArrow",    action = act.ActivatePaneDirection("Up") },
          { key = "RightArrow", action = act.ActivatePaneDirection("Right") },
          { key = "Escape", action = act.PopKeyTable },
          { key = "Enter",  action = act.PopKeyTable },
          { key = "p", mods = "CTRL", action = act.PopKeyTable },
        },

        tab_mode = {
          { key = "h", action = act.Multiple({ act.SpawnTab("CurrentPaneDomain"), act.PopKeyTable }) },
          { key = "x", action = act.Multiple({ act.CloseCurrentTab({ confirm = false }), act.PopKeyTable }) },
          { key = "r", action = act.Multiple({ rename_tab, act.PopKeyTable }) },
          { key = "b", action = wezterm.action_callback(function(win, pane)
              pane:move_to_new_tab()
              win:perform_action(act.PopKeyTable, pane)
            end) },
          -- neio / arrows cycle tabs (stay in mode)
          { key = "n", action = act.ActivateTabRelative(-1) },
          { key = "e", action = act.ActivateTabRelative(1) },
          { key = "i", action = act.ActivateTabRelative(-1) },
          { key = "o", action = act.ActivateTabRelative(1) },
          { key = "LeftArrow",  action = act.ActivateTabRelative(-1) },
          { key = "UpArrow",    action = act.ActivateTabRelative(-1) },
          { key = "RightArrow", action = act.ActivateTabRelative(1) },
          { key = "DownArrow",  action = act.ActivateTabRelative(1) },
          { key = "Tab", action = act.ActivateLastTab },
          { key = "Escape", action = act.PopKeyTable },
          { key = "Enter",  action = act.PopKeyTable },
          { key = "t", mods = "CTRL", action = act.PopKeyTable },
        },

        resize_mode = {
          { key = "n", action = act.AdjustPaneSize({ "Left", 3 }) },
          { key = "e", action = act.AdjustPaneSize({ "Down", 3 }) },
          { key = "i", action = act.AdjustPaneSize({ "Up", 3 }) },
          { key = "o", action = act.AdjustPaneSize({ "Right", 3 }) },
          { key = "h", action = act.AdjustPaneSize({ "Left", 3 }) },
          { key = "j", action = act.AdjustPaneSize({ "Down", 3 }) },
          { key = "k", action = act.AdjustPaneSize({ "Up", 3 }) },
          { key = "l", action = act.AdjustPaneSize({ "Right", 3 }) },
          { key = "LeftArrow",  action = act.AdjustPaneSize({ "Left", 3 }) },
          { key = "DownArrow",  action = act.AdjustPaneSize({ "Down", 3 }) },
          { key = "UpArrow",    action = act.AdjustPaneSize({ "Up", 3 }) },
          { key = "RightArrow", action = act.AdjustPaneSize({ "Right", 3 }) },
          { key = "+", action = act.AdjustPaneSize({ "Up", 3 }) },
          { key = "=", action = act.AdjustPaneSize({ "Up", 3 }) },
          { key = "-", action = act.AdjustPaneSize({ "Down", 3 }) },
          { key = "Escape", action = act.PopKeyTable },
          { key = "Enter",  action = act.PopKeyTable },
          { key = "n", mods = "CTRL", action = act.PopKeyTable },
        },

        -- No native directional pane-swap in WezTerm. Tab/p rotate the stack;
        -- neio open the picker to swap with a chosen pane. Known gap vs tmux.
        move_mode = {
          { key = "Tab", action = act.RotatePanes("Clockwise") },
          { key = "p",   action = act.RotatePanes("CounterClockwise") },
          { key = "n", action = act.PaneSelect({ mode = "SwapWithActiveKeepFocus" }) },
          { key = "e", action = act.PaneSelect({ mode = "SwapWithActiveKeepFocus" }) },
          { key = "i", action = act.PaneSelect({ mode = "SwapWithActiveKeepFocus" }) },
          { key = "o", action = act.PaneSelect({ mode = "SwapWithActiveKeepFocus" }) },
          { key = "Escape", action = act.PopKeyTable },
          { key = "Enter",  action = act.PopKeyTable },
          { key = "h", mods = "CTRL", action = act.PopKeyTable },
        },

        locked = {
          { key = "g", mods = "CTRL", action = act.PopKeyTable },
          { key = "Escape", action = act.PopKeyTable },
        },
      }

      -- tab_mode 1..9 -> jump to tab and exit mode
      for i = 1, 9 do
        table.insert(config.key_tables.tab_mode, {
          key = tostring(i),
          action = act.Multiple({ act.ActivateTab(i - 1), act.PopKeyTable }),
        })
      end

      -- ── Copy mode: extend defaults with Colemak neio + y->clipboard ──────
      local copy_mode = wezterm.gui.default_key_tables().copy_mode
      local copy_extra = {
        { key = "n", mods = "NONE", action = act.CopyMode("MoveLeft") },
        { key = "e", mods = "NONE", action = act.CopyMode("MoveDown") },
        { key = "i", mods = "NONE", action = act.CopyMode("MoveUp") },
        { key = "o", mods = "NONE", action = act.CopyMode("MoveRight") },
        { key = "v", mods = "NONE", action = act.CopyMode({ SetSelectionMode = "Cell" }) },
        { key = "V", mods = "NONE", action = act.CopyMode({ SetSelectionMode = "Line" }) },
        { key = "v", mods = "CTRL", action = act.CopyMode({ SetSelectionMode = "Block" }) },
        { key = "g", mods = "NONE", action = act.CopyMode("MoveToScrollbackTop") },
        { key = "G", mods = "NONE", action = act.CopyMode("MoveToScrollbackBottom") },
        { key = "y", mods = "NONE", action = act.Multiple({ act.CopyTo("ClipboardAndPrimarySelection"), act.CopyMode("Close") }) },
        -- Exit only via Ctrl-s (mirrors the entry chord). Escape no longer
        -- closes — it clears the selection and stays in copy mode.
        { key = "s", mods = "CTRL", action = act.CopyMode("Close") },
        { key = "Escape", mods = "NONE", action = act.CopyMode("ClearSelectionMode") },
      }
      -- Append so ours override the stock bindings (last match wins in a key
      -- table) — the defaults bind n/N to match-nav and Escape to Close.
      for _, k in ipairs(copy_extra) do
        table.insert(copy_mode, k)
      end
      config.key_tables.copy_mode = copy_mode

      -- ── Status bar (tmux layout): tab bar top, workspace left,
      --    hostname + datetime right, palette colored ─────────────────────
      local MODE_LABEL = {
        pane_mode = "PANE",
        tab_mode = "TAB",
        resize_mode = "RESIZE",
        move_mode = "MOVE",
        copy_mode = "COPY",
        search_mode = "SEARCH",
        locked = "LOCKED",
      }
      wezterm.on("update-status", function(window, pane)
        local left = {}
        -- Mode indicator: orange pill for an active key-table, red for LOCKED
        -- or a pending C-a leader. Nothing shown in normal mode.
        local kt = window:active_key_table()
        local label = kt and (MODE_LABEL[kt] or kt:upper()) or nil
        local pill_bg = nil
        if window:leader_is_active() then
          pill_bg, label = pal.color1, "PREFIX"
        elseif kt == "locked" then
          pill_bg = pal.color1
        elseif label then
          pill_bg = pal.color9
        end
        if label then
          table.insert(left, { Background = { Color = pill_bg } })
          table.insert(left, { Foreground = { Color = pal.bg } })
          table.insert(left, { Attribute = { Intensity = "Bold" } })
          table.insert(left, { Text = " " .. label .. " " })
        end
        table.insert(left, { Background = { Color = pal.color4 } })
        table.insert(left, { Foreground = { Color = pal.bg } })
        table.insert(left, { Attribute = { Intensity = "Bold" } })
        table.insert(left, { Text = " " .. window:active_workspace() .. " " })
        window:set_left_status(wezterm.format(left))
        window:set_right_status(wezterm.format({
          { Foreground = { Color = pal.color9 } },
          { Text = " " .. wezterm.hostname() .. " " },
          { Foreground = { Color = pal.fg } },
          { Text = "| " .. wezterm.strftime("%Y-%m-%d %H:%M") .. " " },
        }))
      end)

      -- ── Tab titles: index + process; active tab accent via colors.tab_bar ─
      wezterm.on("format-tab-title", function(tab, tabs, panes, cfg, hover, max_width)
        local proc = tab.active_pane.foreground_process_name or ""
        proc = proc:gsub("(.*[/\\])(.*)", "%2")
        local title = tab.tab_title
        if not title or #title == 0 then
          title = (proc ~= "" and proc) or tab.active_pane.title
        end
        title = wezterm.truncate_right(title, max_width - 4)
        return {
          { Attribute = { Intensity = tab.is_active and "Bold" or "Normal" } },
          { Text = " " .. (tab.tab_index + 1) .. ":" .. title .. " " },
        }
      end)

      return config
    '';
  };
}
