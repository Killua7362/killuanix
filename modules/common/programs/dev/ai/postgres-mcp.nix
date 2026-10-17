# Postgres MCP servers — crystaldba/postgres-mcp ("Postgres MCP Pro").
#
# The Postgres analogue of oracle-sqlcl-mcp.nix: exposes live Postgres
# connections to Claude Code as MCP tools (SQL, EXPLAIN plans, index tuning
# advisor, health checks). Resolved lazily on first call via `uvx postgres-mcp`
# (uv caches under $UV_CACHE_DIR).
#
# ONE MCP SERVER PER DATABASE. A Postgres connection is bound to a single
# database — you cannot cross-query databases on one connection (no `USE`,
# tables in another DB are invisible). The DAS dev server hosts several
# (kitting_db, contract_db, bin_db, …) side by side, so each gets its own MCP
# server `postgres-<db>` with its own DATABASE_URI. They share everything but
# the trailing `/<db>`: same RO creds, same `bastion pg` tunnel (127.0.0.1:5433),
# same uv-resolved env. Add/remove a database by editing `pgDatabases` below.
#
# ONE SET PER ENVIRONMENT. dev/qa/uat each host the same databases behind
# their own local tunnel port (`pgEnvs` below). Dev keeps the bare
# `postgres-<db>` names (existing claude-kit.nix opt-ins keep working); other
# envs get an `-<env>` suffix → `postgres-kitting-qa`, `postgres-kitting-uat`.
# All envs share the same RO creds.
#
# Read-only by design: connects as the GRANT-restricted `azure/pg_ro_*` role
# (separate from the full-access bastion `azure/pg_db_*` creds) AND runs with
# `--access-mode=restricted` (read-only transactions), so an LLM can inspect
# but not mutate. Flip both if you ever want write access.
#
# postgres-mcp 0.3.0 imports the mcp 1.x API (`mcp.server.fastmcp`) but doesn't
# pin `mcp<2`, so a bare `uvx` resolves mcp 2.x (FastMCP→MCPServer rename) and
# the server dies with `ModuleNotFoundError: No module named
# 'mcp.server.fastmcp'`. Pin both the app version and `mcp<2`. Revisit when
# upstream migrates to mcp 2.x.
#
# `optional = true` — none load in every session. Opt in per-project via
#   claude-kit.nix:mcp = [ "postgres-kitting" "postgres-contract" ];
# Linux-only: the bastion tunnel these target is chrollo/killua-only.
{
  pkgs,
  config,
  lib,
  ...
}: let
  # Databases on the DAS dev Postgres server, each exposed as its own MCP
  # server `postgres-<short>` (short = name minus a trailing `_db`). Append to
  # add another; the server name, env file, and wrapper are all derived.
  pgDatabases = [
    "kitting_db"
    "contract_db"
    "bin_db"
    "collab_db"
  ];

  # Environment → local tunnel port. `suffix` is appended to the server name;
  # dev has none so its names predate (and match) the single-env layout.
  pgEnvs = [
    {
      suffix = "";
      port = 5433;
    }
    {
      suffix = "-qa";
      port = 5434;
    }
    {
      suffix = "-uat";
      port = 5435;
    }
  ];

  shortName = db: lib.removeSuffix "_db" db;

  # `sslmode=require`: the ssh -L leg is plain TCP but the Azure PG endpoint
  # negotiates TLS end-to-end; `require` (not verify-full) tolerates the
  # 127.0.0.1 hostname mismatch the tunnel introduces.
  mkWrapper = name: envPath:
    pkgs.writeShellApplication {
      name = "mcp-${name}";
      runtimeInputs = [pkgs.uv];
      text = ''
        export UV_CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/mcp-postgres/uv-cache"
        mkdir -p "$UV_CACHE_DIR"
        # DATABASE_URI carries the password — source it from the sops-rendered
        # env file so it never lands in the nix store or process argv.
        set -a
        # shellcheck disable=SC1091
        . "${envPath}"
        set +a
        exec uvx --from "postgres-mcp==0.3.0" --with "mcp<2" \
          postgres-mcp --access-mode=restricted "$@"
      '';
    };

  mkDb = env: db: let
    name = "postgres-${shortName db}${env.suffix}";
    envName = "pg-mcp-${shortName db}${env.suffix}.env";
  in {
    sops.templates.${envName}.content = ''
      DATABASE_URI=postgresql://${config.sops.placeholder."azure/pg_ro_user"}:${config.sops.placeholder."azure/pg_ro_pass"}@127.0.0.1:${toString env.port}/${db}?sslmode=require
    '';
    local.extraMcpServers.${name} = {
      command = lib.getExe (mkWrapper name config.sops.templates.${envName}.path);
      optional = true;
    };
  };
in {
  config = lib.mkIf pkgs.stdenv.isLinux (lib.mkMerge (lib.concatMap (env: map (mkDb env) pgDatabases) pgEnvs));
}
