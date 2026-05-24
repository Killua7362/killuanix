{
  pkgs,
  lib,
  ...
}: let
  # nixpkgs splits libreoffice into wrapped (CLI launcher) + unwrapped (the
  # `program/` tree). pyuno bindings (`uno.py`, `libpyuno.so`, etc.) live in
  # the unwrapped tree, so PYTHONPATH/LD_LIBRARY_PATH/URE_BOOTSTRAP must point
  # there. `libreoffice.unwrapped` resolves the unwrapped derivation directly.
  loProg = "${pkgs.libreoffice.unwrapped}/lib/libreoffice/program";

  # soffice-mcp — drop-in soffice wrapper that also kicks the in-process MCP
  # HTTP server (port 8765) into life.
  #
  # Why: `jwingnut/mcp-libre`'s LibreOffice extension binds the MCP server only
  # when the menu item `MCP Server > Start MCP Server` is clicked. Upstream's
  # ProtocolHandler.xcu routing is broken on current LO releases — LO's
  # framework returns its built-in `ServiceHandler` stub for
  # `service:org.mcp.libreoffice.MCPExtension*` URLs instead of the extension's
  # `MCPProtocolHandler`, so menu/toolbar clicks never reach the dispatch
  # method. Even with our autostart patch (which auto-fires `_start_server`
  # at module-import time, see patches/mcp-libre-extension-autostart.patch),
  # LO doesn't import the extension's python module at startup — it waits
  # until something queries the impl by name.
  #
  # This wrapper:
  #   1. Launches soffice with a UNO `--accept` socket on 127.0.0.1:2002.
  #   2. Waits for the socket to be ready.
  #   3. Calls `createInstanceWithContext("org.mcp.libreoffice.MCPExtension")`
  #      over the UNO bridge — which forces LO to import the python module,
  #      and the patched module then spawns the MCP HTTP server thread.
  #   4. `wait`s on soffice so foreground/background semantics match `soffice`.
  #
  # Idempotent: if port 2002 is already in use (soffice already running with
  # accept socket), soffice attaches to the existing instance and the dispatch
  # still loads the module / no-ops if already loaded.
  launcher = pkgs.writeShellApplication {
    name = "soffice-mcp";
    runtimeInputs = [pkgs.libreoffice pkgs.python3 pkgs.iproute2 pkgs.coreutils];
    text = ''
      ACCEPT="socket,host=localhost,port=2002;urp;"
      soffice --accept="$ACCEPT" "$@" &
      SOPID=$!

      for _ in $(seq 1 60); do
        if ss -tln 2>/dev/null | grep -q '127.0.0.1:2002'; then
          break
        fi
        sleep 0.5
      done

      PYTHONPATH=${loProg} \
      LD_LIBRARY_PATH=${loProg} \
      URE_BOOTSTRAP=vnd.sun.star.pathname:${loProg}/fundamentalrc \
        python3 - <<'PY' || echo "soffice-mcp: UNO dispatch failed (extension installed? soffice booted?)"
      import uno
      ctx = uno.getComponentContext()
      r = ctx.ServiceManager.createInstanceWithContext(
          "com.sun.star.bridge.UnoUrlResolver", ctx)
      rctx = r.resolve(
          "uno:socket,host=localhost,port=2002;urp;StarOffice.ComponentContext")
      rctx.ServiceManager.createInstanceWithContext(
          "org.mcp.libreoffice.MCPExtension", rctx)
      print("soffice-mcp: extension loaded (MCP HTTP server on :8765)")
      PY

      wait "$SOPID"
    '';
  };
in {
  home.packages = [launcher];
}
