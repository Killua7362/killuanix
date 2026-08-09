{
  imports = [
    ./ghostty.nix
    ./kitty.nix
    # zellij (multiplexer) is active; ghostty/kitty host it. wezterm
    # disabled — retained on disk for revert. wezterm.nix was gated to
    # chrollo/killua.
    ./zellij.nix
    # ./tmux.nix
    # ./wezterm.nix
  ];
}
