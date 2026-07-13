{
  imports = [
    ./ghostty.nix
    ./kitty.nix
    # tmux + zellij replaced by wezterm (terminal + native mux); files
    # retained for revert. wezterm.nix is gated to chrollo/killua.
    # ./zellij.nix
    # ./tmux.nix
    ./wezterm.nix
  ];
}
