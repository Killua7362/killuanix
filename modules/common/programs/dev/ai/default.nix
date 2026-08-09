{
  imports = [
    ./opencode.nix
    ./claude.nix
    ./cc-hooks-ts.nix
    ./pkexec-broker
    ./rtk.nix
    # ./claudio.nix  # disabled — no contextual hook sounds
    ./claude-resources
    ./claude-kit
    ./claude-launchers
    ./ruflo-cli.nix
    ./claude-flow-cli.nix
    ./ccr.nix
    ./ccmanager.nix
    ./claude-powerline.nix
    ./jupyter-env-mcp.nix
    ./kindly-web-search.nix
    ./libreoffice-mcp-launcher.nix
    ./oracle-sqlcl-mcp.nix
    ./serena-mcp.nix
    ./codebase-memory-mcp.nix
    ./freshrss-mcp
    ./den
  ];
}
