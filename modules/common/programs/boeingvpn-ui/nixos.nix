# Boeing VPN browser-UI — NixOS half.
#
# Drops a Chrome ManagedBookmarks policy file so the browser bookmark bar
# shows a "Boeing → VPN" entry pointing at http://127.0.0.1:7777/ (where
# the per-user `boeingvpn-ui` systemd user service listens). Chrome reads
# this policy regardless of `--user-data-dir`, so the bookmark also
# appears inside the `chrome-socks` profile.
#
# Avoids editing Chrome's user-scoped `Bookmarks` JSON (checksummed and
# clobbered by the browser — same category of fragile-UX hazard as
# Firefox's HM bookmarks option).
{...}: {
  environment.etc."opt/chrome/policies/managed/boeingvpn-ui.json".text = builtins.toJSON {
    ManagedBookmarks = [
      {toplevel_name = "Boeing";}
      {
        name = "VPN";
        url = "http://127.0.0.1:7777/";
      }
    ];
  };
}
