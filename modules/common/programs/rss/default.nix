{
  imports = [
    ./rssguard.nix
    # Optional companion service that seeds the FreshRSS account row directly
    # into RSSGuard's SQLite DB so the first launch doesn't need a manual
    # account-add. Off by default — flip `cfg.enable` at the top of the file
    # to use. Pulled in here (not commented at import-level) so the option
    # surface exists; the body is `lib.mkIf cfg.enable {}` so it's a no-op
    # until enabled.
    ./account-seed.nix
  ];
}
