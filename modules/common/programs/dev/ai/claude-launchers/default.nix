# Per-invocation Claude Code launchers.
#
# Boots `claude` (the global binary from programs.claude-code) into an
# isolated state dir with a curated extra-resource set layered on top of
# (or replacing) the global config, and masks project-level Claude config
# (`.claude/`, `.mcp.json`, `CLAUDE.md`, `.claude-plugin/`) in cwd
# ancestors via bubblewrap.
#
# Layout:
#   default.nix        — this file. Defines `mkClaudeLauncher` + auto-
#                        imports every sibling `*.nix` (excluding self)
#                        as a launcher definition.
#   <name>.nix         — one per launcher. Pure attrset (function) taking
#                        `{ config, inputs, lib, notesCmd, pkgs }` and
#                        returning the `mkClaudeLauncher` args. All
#                        supported attrs are listed explicitly so the
#                        available surface is visible at the call site.
#   CLAUDE.md          — reference docs (full attr surface + mechanism).
#
# To add a launcher: drop `claude-<name>.nix` here and run `scripts/
# nix_switch`. No edits to this file needed.
{
  inputs,
  config,
  pkgs,
  lib,
  ...
}: let
  # Shared helper for launcher files: turn a personal-catalog command
  # name into the live path under Notes (so content edits propagate
  # without nix_switch).
  notesCmd = name: "${config.home.homeDirectory}/killuanix/Notes/claude/lazy/personal/commands/${name}.md";

  # The HM-built `claude` wrapper exec's `<finalPackage>/bin/.claude-wrapped`
  # with `--plugin-dir <hm-plugin>` baked in. Launchers exec `.claude-wrapped`
  # directly so they can substitute their own `--plugin-dir`, dropping the
  # globally-injected MCPs entirely (mermaid, filesystem, etc. don't leak in).
  claudeWrapped = "${config.programs.claude-code.finalPackage}/bin/.claude-wrapped";

  mkClaudeLauncher = {
    name,
    stateName,
    skills ? {},
    agents ? {},
    commands ? {},
    plugins ? [],
    mcp ? [],
    model ? null, # e.g. "claude-opus-4-7", "claude-sonnet-4-6"
    effort ? null, # e.g. "low" | "medium" | "high" | "xhigh" | "auto"
    inheritGlobal ? true,
    excludeSkills ? [],
    excludeAgents ? [],
    excludeCommands ? [],
    excludePlugins ? [],
    excludeMcp ? [],
    allowedTools ? [],
    deniedTools ? [],
    hooks ? null,
    restrictToDirs ? null,
  }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [
        pkgs.coreutils
        pkgs.findutils
        pkgs.jq
        pkgs.bubblewrap
      ];
      text = let
        mkSymlinkLines = subdir: attrset: suffix:
          lib.concatStringsSep "\n" (lib.mapAttrsToList (
              entryName: src: ''ln -sfn ${lib.escapeShellArg (toString src)} "$state_dir/${subdir}/${entryName}${suffix}"''
            )
            attrset);

        skillLinks = mkSymlinkLines "skills" skills "";
        agentLinks = mkSymlinkLines "agents" agents ".md";
        commandLinks = mkSymlinkLines "commands" commands ".md";

        pluginsJson = builtins.toJSON plugins;
        mcpJson = builtins.toJSON mcp;

        inheritGlobalStr =
          if inheritGlobal
          then "true"
          else "false";
        excludeSkillsJson = builtins.toJSON excludeSkills;
        excludeAgentsJson = builtins.toJSON excludeAgents;
        excludeCommandsJson = builtins.toJSON excludeCommands;
        excludePluginsJson = builtins.toJSON excludePlugins;
        excludeMcpJson = builtins.toJSON excludeMcp;
        allowedToolsJson = builtins.toJSON allowedTools;
        deniedToolsJson = builtins.toJSON deniedTools;
        hooksJson =
          if hooks == null
          then ""
          else builtins.toJSON hooks;
        restrictToDirsJson =
          if restrictToDirs == null
          then ""
          else builtins.toJSON restrictToDirs;

        modelPatch =
          if model == null
          then ""
          else ''
            jq --arg m ${lib.escapeShellArg model} '.model = $m' \
              "$state_dir/settings.json" > "$state_dir/settings.json.tmp"
            mv "$state_dir/settings.json.tmp" "$state_dir/settings.json"
          '';
        effortPatch =
          if effort == null
          then ""
          else ''
            jq --arg e ${lib.escapeShellArg effort} '.effortLevel = $e' \
              "$state_dir/settings.json" > "$state_dir/settings.json.tmp"
            mv "$state_dir/settings.json.tmp" "$state_dir/settings.json"
          '';
      in ''
        src="$HOME/.claude"
        state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/claude-launchers/${stateName}"
        catalog="''${XDG_DATA_HOME:-$HOME/.local/share}/claude-kit/all-mcp-servers.json"

        mkdir -p "$state_dir"/{skills,agents,commands}

        # Refresh top-level symlinks pointing at ~/.claude entries (auth,
        # MCP, projects, …). Skip the ones we rebuild ourselves
        # (skills/agents/commands) and settings.json (real file below).
        if [ -d "$src" ]; then
          while IFS= read -r -d "" entry; do
            base=$(basename "$entry")
            case "$base" in
              skills|agents|commands|settings.json) continue ;;
            esac
            ln -sfn "$entry" "$state_dir/$base"
          done < <(find "$src" -mindepth 1 -maxdepth 1 -print0)
        fi

        # Rebuild skills/agents/commands: clear stale symlinks, mirror
        # upstream entries (when inheritGlobal=true and the entry name isn't
        # in the per-launcher exclude list), then add declared extras.
        inherit_global=${inheritGlobalStr}
        excludeSkillsJson='${excludeSkillsJson}'
        excludeAgentsJson='${excludeAgentsJson}'
        excludeCommandsJson='${excludeCommandsJson}'

        for sub in skills agents commands; do
          find "$state_dir/$sub" -mindepth 1 -maxdepth 1 -type l -delete
          if [ "$inherit_global" = true ] && [ -d "$src/$sub" ]; then
            case "$sub" in
              skills) exclude_list="$excludeSkillsJson" ;;
              agents) exclude_list="$excludeAgentsJson" ;;
              commands) exclude_list="$excludeCommandsJson" ;;
            esac
            while IFS= read -r -d "" entry; do
              base=$(basename "$entry")
              # agents/commands are .md files; strip extension for match.
              key="''${base%.md}"
              if jq -e --arg k "$key" 'index($k)' <<< "$exclude_list" >/dev/null 2>&1; then
                continue
              fi
              ln -sfn "$entry" "$state_dir/$sub/$base"
            done < <(find "$src/$sub" -mindepth 1 -maxdepth 1 -print0)
          fi
        done

        ${skillLinks}
        ${agentLinks}
        ${commandLinks}

        # settings.json — real writable copy so overlayClaude leaves it
        # alone (its guard at claude.nix:223 only rewrites symlinks /
        # non-writable files). jq-merge declared plugins, model, effort.
        # MCPs are NOT written here — they go into the inline plugin's
        # `.mcp.json` (Claude reads MCPs from plugins, not settings.json).
        if [ -e "$src/settings.json" ]; then
          install -m 0644 "$(readlink -f "$src/settings.json")" "$state_dir/settings.json"
        else
          echo '{}' > "$state_dir/settings.json"
        fi

        # Pin model + effort (override values inherited from global settings).
        ${modelPatch}
        ${effortPatch}

        # Enable declared plugins.
        while IFS= read -r plug; do
          [ -z "$plug" ] && continue
          jq --arg p "$plug" '.enabledPlugins[$p] = true' \
            "$state_dir/settings.json" > "$state_dir/settings.json.tmp"
          mv "$state_dir/settings.json.tmp" "$state_dir/settings.json"
        done < <(jq -r '.[]' <<< '${pluginsJson}')

        # Strip excluded plugins (delete the key entirely so it falls back to
        # whatever the global default is, rather than leaving an explicit
        # `false` that might mask a future global re-enable).
        while IFS= read -r plug; do
          [ -z "$plug" ] && continue
          jq --arg p "$plug" 'del(.enabledPlugins[$p])' \
            "$state_dir/settings.json" > "$state_dir/settings.json.tmp"
          mv "$state_dir/settings.json.tmp" "$state_dir/settings.json"
        done < <(jq -r '.[]' <<< '${excludePluginsJson}')

        # Merge per-launcher allowedTools / deniedTools into permissions.
        jq --argjson a '${allowedToolsJson}' --argjson d '${deniedToolsJson}' '
          .permissions.allow = ((.permissions.allow // []) + $a | unique) |
          .permissions.deny  = ((.permissions.deny  // []) + $d | unique)
        ' "$state_dir/settings.json" > "$state_dir/settings.json.tmp"
        mv "$state_dir/settings.json.tmp" "$state_dir/settings.json"

        # Hooks — when the launcher declares its own, replace the inherited
        # .hooks block wholesale (intentional isolation: e.g. don't run the
        # global caveman Stop hook in claude-news).
        hooksJson='${hooksJson}'
        if [ -n "$hooksJson" ]; then
          jq --argjson h "$hooksJson" '.hooks = $h' \
            "$state_dir/settings.json" > "$state_dir/settings.json.tmp"
          mv "$state_dir/settings.json.tmp" "$state_dir/settings.json"
        fi

        # restrictToDirs — pin allowed working dirs and add advisory deny
        # rules for common sensitive paths. Claude Code permission patterns
        # have no "deny all except X" form, so the broad outside-of-restrict
        # restriction is enforced at the MCP layer below (filesystem MCP arg
        # narrowing). The deny patterns here are a belt-and-suspenders layer
        # against the model trying to read well-known sensitive locations
        # via Bash/Read.
        restrictToDirsJson='${restrictToDirsJson}'
        if [ -n "$restrictToDirsJson" ]; then
          jq --argjson dirs "$restrictToDirsJson" \
             --arg home "$HOME" '
            .permissions.additionalDirectories = $dirs |
            .permissions.deny = ((.permissions.deny // []) + [
              "Read(/etc/**)",
              "Read(/var/**)",
              "Read(/root/**)",
              "Read(\($home)/.ssh/**)",
              "Read(\($home)/.gnupg/**)",
              "Read(\($home)/.config/sops/**)",
              "Read(\($home)/.config/age/**)"
            ] | unique)
          ' "$state_dir/settings.json" > "$state_dir/settings.json.tmp"
          mv "$state_dir/settings.json.tmp" "$state_dir/settings.json"
        fi

        # Per-launcher inline plugin holding declared MCP servers. Claude
        # Code reads MCPs from plugin `.mcp.json`, not from
        # `settings.json.mcpServers` — and the global `claude` wrapper
        # injects `--plugin-dir <hm-plugin>` which carries every
        # `programs.claude-code.mcpServers` entry. To stop those leaking
        # in (e.g. mermaid showing up in `claude-news`), we build our
        # OWN plugin dir and exec the inner `.claude-wrapped` directly,
        # passing `--plugin-dir <ours>` instead.
        plugin_dir="$state_dir/plugin"
        mkdir -p "$plugin_dir/.claude-plugin"
        printf '%s\n' '{"name": "${name}-inline"}' > "$plugin_dir/.claude-plugin/plugin.json"

        # Compose the final MCP name list:
        #   inheritGlobal=true  → (global non-optional catalog entries) ∪ (per-launcher `mcp` list)
        #   inheritGlobal=false → (per-launcher `mcp` list) only — total replacement
        # then subtract `excludeMcp`.
        mcp_servers='{}'
        if [ "$inherit_global" = true ] && [ ! -f "$catalog" ]; then
          echo "${name}: MCP catalog not found at $catalog — inheritGlobal=true needs it (run scripts/nix_switch)" >&2
          exit 1
        fi
        global_names='[]'
        if [ "$inherit_global" = true ]; then
          global_names=$(jq '[to_entries[] | select(.value.optional != true) | .key]' "$catalog")
        fi
        mcp_names_json=$(jq --argjson g "$global_names" \
                            --argjson l '${mcpJson}' \
                            --argjson x '${excludeMcpJson}' \
          '($g + $l) | unique | map(select(. as $n | $x | index($n) | not))')
        mcp_names=$(jq -r '.[]' <<< "$mcp_names_json")

        if [ -n "$mcp_names" ]; then
          if [ ! -f "$catalog" ]; then
            echo "${name}: MCP catalog not found at $catalog — declared mcp = [...] cannot be resolved" >&2
            exit 1
          fi
          while IFS= read -r mcp_name; do
            [ -z "$mcp_name" ] && continue
            stanza=$(jq --arg n "$mcp_name" '.[$n] // empty' "$catalog")
            if [ -z "$stanza" ]; then
              echo "${name}: MCP server '$mcp_name' not in catalog ($catalog)" >&2
              exit 1
            fi
            mcp_servers=$(jq --arg n "$mcp_name" --argjson s "$stanza" \
              '.[$n] = ($s | del(.optional))' <<< "$mcp_servers")
          done <<< "$mcp_names"
        fi

        # restrictToDirs — narrow the filesystem MCP's `args` so the server
        # itself refuses paths outside the allow list. Hard half of the
        # filesystem restriction (advisory permissions.deny is set above).
        if [ -n "$restrictToDirsJson" ] \
           && jq -e '.filesystem' <<< "$mcp_servers" >/dev/null 2>&1; then
          mcp_servers=$(jq --argjson dirs "$restrictToDirsJson" \
            '.filesystem.args = $dirs' <<< "$mcp_servers")
        fi

        jq -n --argjson s "$mcp_servers" '{mcpServers: $s}' > "$plugin_dir/.mcp.json"

        # Drop the (unused) mcpServers field from settings.json so the
        # picture stays consistent — MCPs live exclusively in the inline
        # plugin's `.mcp.json` from here on.
        jq 'del(.mcpServers)' "$state_dir/settings.json" > "$state_dir/settings.json.tmp"
        mv "$state_dir/settings.json.tmp" "$state_dir/settings.json"

        # Auth + onboarding state — sibling of ~/.claude/, NOT inside it.
        if [ -e "$HOME/.claude.json" ]; then
          ln -sfn "$HOME/.claude.json" "$state_dir/.claude.json"
        fi

        # Build bwrap masks for project-level Claude config: walk cwd
        # upward to (exclusive) $HOME and mask `.claude/`, `.mcp.json`,
        # `CLAUDE.md`, `.claude-plugin/` at every level.
        mask_args=()
        scan_dir=$(pwd)
        while [ "$scan_dir" != "$HOME" ] && [ "$scan_dir" != "/" ]; do
          [ -e "$scan_dir/.claude" ]        && mask_args+=(--tmpfs "$scan_dir/.claude")
          [ -e "$scan_dir/.claude-plugin" ] && mask_args+=(--tmpfs "$scan_dir/.claude-plugin")
          [ -e "$scan_dir/.mcp.json" ]      && mask_args+=(--ro-bind /dev/null "$scan_dir/.mcp.json")
          [ -e "$scan_dir/CLAUDE.md" ]      && mask_args+=(--ro-bind /dev/null "$scan_dir/CLAUDE.md")
          scan_dir=$(dirname "$scan_dir")
        done

        export CLAUDE_CONFIG_DIR="$state_dir"
        exec bwrap \
          --dev-bind / / \
          --proc /proc \
          --dev /dev \
          --die-with-parent \
          ''${mask_args[@]+"''${mask_args[@]}"} \
          -- ${claudeWrapped} --plugin-dir "$plugin_dir" "$@"
      '';
    };

  # Auto-discover sibling launcher files: every `*.nix` in this dir except
  # `default.nix` is imported as a launcher definition. Each launcher file
  # is a function taking `{ config, inputs, lib, pkgs, notesCmd }` and
  # returning the args for `mkClaudeLauncher`.
  launcherArgs = {inherit config inputs lib pkgs notesCmd;};
  launcherFiles =
    lib.filterAttrs (n: v: v == "regular" && n != "default.nix" && lib.hasSuffix ".nix" n)
    (builtins.readDir ./.);
  launchers =
    lib.mapAttrsToList
    (filename: _: mkClaudeLauncher (import (./. + "/${filename}") launcherArgs))
    launcherFiles;
in {
  home.packages = launchers;
}
