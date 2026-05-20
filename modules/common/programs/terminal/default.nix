{
  imports = [
    ./ghostty.nix
    ./kitty.nix
    # ./zellij.nix  # disabled — replaced by tmux; file retained for revert
    ./tmux.nix
  ];
}
