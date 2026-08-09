(() => {
  const win = document.getElementById("vpn-window");
  const titlebar = document.getElementById("titlebar");
  const dot = document.getElementById("status-dot");
  const label = document.getElementById("status-label");
  const errLine = document.getElementById("error-line");
  const btnConnect = document.getElementById("btn-connect");
  const btnFastest = document.getElementById("btn-fastest");
  const btnDisconnect = document.getElementById("btn-disconnect");
  const btnReconnect = document.getElementById("btn-reconnect");
  const btnSubmit = document.getElementById("btn-submit");
  const secret = document.getElementById("secret");
  const userid = document.getElementById("userid");
  const gateway = document.getElementById("gateway");

  // ---- Draggable windows --------------------------------------------------
  //
  // Shared, no-library drag. Clicking a titlebar raises that window (z-index)
  // and lets it be dragged within the viewport. Applied to both windows.

  let drag = null;
  let zTop = 10;

  function makeDraggable(winEl, barEl) {
    barEl.addEventListener("mousedown", (e) => {
      if (e.button !== 0) return;
      const rect = winEl.getBoundingClientRect();
      winEl.style.zIndex = String(++zTop);
      drag = { win: winEl, dx: e.clientX - rect.left, dy: e.clientY - rect.top };
      e.preventDefault();
    });
  }

  document.addEventListener("mousemove", (e) => {
    if (!drag) return;
    const w = drag.win.offsetWidth;
    const h = drag.win.offsetHeight;
    let x = e.clientX - drag.dx;
    let y = e.clientY - drag.dy;
    x = Math.max(0, Math.min(window.innerWidth - w, x));
    y = Math.max(0, Math.min(window.innerHeight - h, y));
    drag.win.style.left = x + "px";
    drag.win.style.top = y + "px";
  });

  document.addEventListener("mouseup", () => {
    drag = null;
  });

  makeDraggable(win, titlebar);
  makeDraggable(
    document.getElementById("bastion-window"),
    document.getElementById("bastion-titlebar"),
  );

  // ---- UI state machine ---------------------------------------------------
  //
  // Local UI states mirror daemon states but add `awaiting-secret` (between
  // pressing Connect and submitting the secret) and `probing` (while the
  // fastest-gateway probe runs). The daemon knows neither.

  const UI = {
    IDLE: "idle",
    PROBING: "probing",
    AWAITING: "awaiting-secret",
    CONNECTING: "connecting",
    CONNECTED: "connected",
    DISCONNECTING: "disconnecting",
    ERROR: "error",
  };

  let uiState = UI.IDLE;

  const STYLES = {
    [UI.IDLE]:          { dot: "dot-grey",   text: "Disconnected" },
    [UI.PROBING]:       { dot: "dot-yellow", text: "Finding fastest gateway…" },
    [UI.AWAITING]:      { dot: "dot-yellow", text: "Enter PIN+token" },
    [UI.CONNECTING]:    { dot: "dot-yellow", text: "Connecting…" },
    [UI.CONNECTED]:     { dot: "dot-green",  text: "Connected" },
    [UI.DISCONNECTING]: { dot: "dot-yellow", text: "Disconnecting…" },
    [UI.ERROR]:         { dot: "dot-red",    text: "Error" },
  };

  function render(state, errorMsg, labelOverride) {
    uiState = state;
    const s = STYLES[state];
    dot.className = "dot " + s.dot;
    label.textContent = labelOverride || s.text;
    errLine.textContent = state === UI.ERROR && errorMsg ? errorMsg : "";

    const isAwaiting = state === UI.AWAITING;
    const isConnected = state === UI.CONNECTED;
    const isBusy = state === UI.CONNECTING || state === UI.DISCONNECTING || state === UI.PROBING;
    const isIdle = state === UI.IDLE || state === UI.ERROR;

    btnConnect.disabled = !isIdle;
    btnFastest.disabled = !isIdle;
    btnDisconnect.disabled = !(isAwaiting || isConnected || state === UI.CONNECTING);
    btnReconnect.disabled = !(isConnected || state === UI.ERROR);

    // userid + gateway are editable only while not yet committed to a session.
    userid.disabled = !(isIdle || isAwaiting);
    gateway.disabled = !(isIdle || isAwaiting);

    secret.disabled = !isAwaiting;
    btnSubmit.disabled = !isAwaiting;

    if (isAwaiting) {
      secret.focus();
    }
    if (!isAwaiting && !isBusy) {
      secret.value = "";
    }
  }

  async function api(path, body) {
    const opts = { method: body === undefined ? "GET" : "POST" };
    if (body !== undefined) {
      opts.headers = { "Content-Type": "application/json" };
      opts.body = JSON.stringify(body);
    }
    const res = await fetch(path, opts);
    return res.json();
  }

  function applyDaemonState(snap) {
    // Don't clobber local-only states with a poll result.
    if (uiState === UI.AWAITING || uiState === UI.PROBING) return;
    // Keep the dropdown in sync with whatever gateway is actually in use.
    if (snap.gateway) gateway.value = snap.gateway;
    if (snap.state === "connecting") render(UI.CONNECTING);
    else if (snap.state === "connected") render(UI.CONNECTED);
    else if (snap.state === "disconnecting") render(UI.DISCONNECTING);
    else if (snap.state === "error") render(UI.ERROR, snap.last_error || "Unknown error");
    else render(UI.IDLE);
  }

  // ---- Wiring -------------------------------------------------------------

  btnConnect.addEventListener("click", () => {
    // Uses whatever gateway is selected in the dropdown.
    render(UI.AWAITING);
  });

  btnFastest.addEventListener("click", async () => {
    render(UI.PROBING);
    try {
      const r = await api("/api/fastest");
      if (!r.ok || !r.fastest) {
        render(UI.ERROR, r.error || "no gateway reachable");
        return;
      }
      gateway.value = r.fastest.host;
      render(UI.AWAITING, null, `Fastest: ${r.fastest.name} (${r.fastest.ms}ms)`);
    } catch (e) {
      render(UI.ERROR, String(e));
    }
  });

  btnDisconnect.addEventListener("click", async () => {
    if (uiState === UI.AWAITING) {
      render(UI.IDLE);
      return;
    }
    render(UI.DISCONNECTING);
    try {
      const snap = await api("/api/disconnect", {});
      applyDaemonState(snap);
    } catch (e) {
      render(UI.ERROR, String(e));
    }
  });

  btnReconnect.addEventListener("click", async () => {
    render(UI.CONNECTING);
    try {
      const snap = await api("/api/reconnect", {});
      if (!snap.ok && snap.error) render(UI.ERROR, snap.error);
      else applyDaemonState(snap);
    } catch (e) {
      render(UI.ERROR, String(e));
    }
  });

  async function submit() {
    const value = secret.value;
    if (!value) return;
    if (!userid.value.trim()) {
      render(UI.ERROR, "missing userid");
      return;
    }
    render(UI.CONNECTING);
    try {
      const snap = await api("/api/connect", {
        secret: value,
        userid: userid.value.trim(),
        gateway: gateway.value,
      });
      if (!snap.ok && snap.error) render(UI.ERROR, snap.error);
      else applyDaemonState(snap);
    } catch (e) {
      render(UI.ERROR, String(e));
    }
  }

  btnSubmit.addEventListener("click", submit);
  secret.addEventListener("keydown", (e) => {
    if (e.key === "Enter") submit();
  });

  // ---- Boot ---------------------------------------------------------------

  // Populate userid default + gateway list from the daemon, then sync state.
  api("/api/config")
    .then((cfg) => {
      if (cfg.default_userid && !userid.value) userid.value = cfg.default_userid;
      gateway.innerHTML = "";
      (cfg.gateways || []).forEach((gw) => {
        const opt = document.createElement("option");
        opt.value = gw.host;
        opt.textContent = `${gw.name} (${gw.host})`;
        gateway.appendChild(opt);
      });
    })
    .catch(() => {})
    .finally(() => {
      api("/api/status").then(applyDaemonState).catch(() => render(UI.IDLE));
    });

  setInterval(() => {
    api("/api/status").then(applyDaemonState).catch(() => {});
  }, 2000);

  // ---- Bastion window (DB tunnels) ----------------------------------------

  const bDot = document.getElementById("b-status-dot");
  const bLabel = document.getElementById("b-status-label");
  const bErr = document.getElementById("b-error-line");
  const bConnect = document.getElementById("b-btn-connect");
  const bDisconnect = document.getElementById("b-btn-disconnect");
  const bLogin = document.getElementById("b-login");
  const bLoginUrl = document.getElementById("b-login-url");
  const bLoginCode = document.getElementById("b-login-code");
  const bCopyCode = document.getElementById("b-copy-code");

  const B_STYLES = {
    idle:            { dot: "dot-grey",   text: "Disconnected" },
    connecting:      { dot: "dot-yellow", text: "Connecting…" },
    "login-required":{ dot: "dot-yellow", text: "Sign in to continue" },
    connected:       { dot: "dot-green",  text: "Connected — tunnels up" },
    disconnecting:   { dot: "dot-yellow", text: "Disconnecting…" },
    error:           { dot: "dot-red",    text: "Error" },
  };

  // Copy helper (loopback + http, so navigator.clipboard may be unavailable —
  // fall back to a hidden textarea + execCommand).
  function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) {
      navigator.clipboard.writeText(text).catch(() => {});
      return;
    }
    const ta = document.createElement("textarea");
    ta.value = text;
    ta.style.position = "fixed";
    ta.style.opacity = "0";
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand("copy"); } catch (e) { /* ignore */ }
    document.body.removeChild(ta);
  }

  function renderBastion(snap) {
    const state = snap.state || "idle";
    const s = B_STYLES[state] || B_STYLES.idle;
    bDot.className = "dot " + s.dot;
    bLabel.textContent = s.text;
    bErr.textContent = state === "error" && snap.error ? snap.error : "";

    const loggingIn = state === "login-required";
    bLogin.hidden = !loggingIn;
    if (loggingIn) {
      if (snap.url) {
        bLoginUrl.textContent = snap.url.replace(/^https?:\/\//, "");
        bLoginUrl.href = snap.url;
      }
      bLoginCode.textContent = snap.code || "--------";
    }

    const busy = state === "connecting" || state === "login-required" ||
                 state === "connected" || state === "disconnecting";
    bConnect.disabled = busy;
    bDisconnect.disabled = !(state === "connecting" || state === "login-required" ||
                             state === "connected");
  }

  bCopyCode.addEventListener("click", () => {
    if (bLoginCode.textContent) copyText(bLoginCode.textContent.trim());
  });

  bConnect.addEventListener("click", async () => {
    renderBastion({ state: "connecting" });
    try {
      const snap = await api("/api/bastion/connect", {});
      if (!snap.ok && snap.error) renderBastion({ state: "error", error: snap.error });
      else renderBastion(snap);
    } catch (e) {
      renderBastion({ state: "error", error: String(e) });
    }
  });

  bDisconnect.addEventListener("click", async () => {
    renderBastion({ state: "disconnecting" });
    try {
      const snap = await api("/api/bastion/disconnect", {});
      renderBastion(snap);
    } catch (e) {
      renderBastion({ state: "error", error: String(e) });
    }
  });

  // Credentials — parsed from the env file by the daemon. Fetched on boot and
  // refreshed periodically (values change only on a nix_switch).
  function fillCred(id, value) {
    const el = document.getElementById(id);
    if (!el) return;
    el.textContent = value || "—";
    el.classList.toggle("empty", !value);
  }

  function loadCreds() {
    api("/api/bastion/creds")
      .then((c) => {
        fillCred("b-ora-local", c.oracle && c.oracle.local);
        fillCred("b-ora-user", c.oracle && c.oracle.user);
        fillCred("b-ora-pass", c.oracle && c.oracle.password);
        fillCred("b-ora-url", c.oracle && c.oracle.url);
        fillCred("b-pg-local", c.pg && c.pg.local);
        fillCred("b-pg-user", c.pg && c.pg.user);
        fillCred("b-pg-pass", c.pg && c.pg.password);
        fillCred("b-pg-url", c.pg && c.pg.url);
        fillCred("b-cos-local", c.cosmos && c.cosmos.local);
        fillCred("b-cos-key", c.cosmos && c.cosmos.auth_key);
        fillCred("b-cos-url", c.cosmos && c.cosmos.url);
      })
      .catch(() => {});
  }

  // Click any cred value to copy it.
  document.getElementById("b-creds").addEventListener("click", (e) => {
    const el = e.target.closest("code");
    if (el && el.textContent && el.textContent !== "—") copyText(el.textContent.trim());
  });

  loadCreds();
  api("/api/bastion/status").then(renderBastion).catch(() => renderBastion({ state: "idle" }));

  setInterval(() => {
    api("/api/bastion/status").then(renderBastion).catch(() => {});
  }, 2000);
})();
