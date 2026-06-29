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

  // ---- Draggable window ---------------------------------------------------

  let drag = null;
  titlebar.addEventListener("mousedown", (e) => {
    if (e.button !== 0) return;
    const rect = win.getBoundingClientRect();
    drag = { dx: e.clientX - rect.left, dy: e.clientY - rect.top };
    e.preventDefault();
  });

  document.addEventListener("mousemove", (e) => {
    if (!drag) return;
    const w = win.offsetWidth;
    const h = win.offsetHeight;
    let x = e.clientX - drag.dx;
    let y = e.clientY - drag.dy;
    x = Math.max(0, Math.min(window.innerWidth - w, x));
    y = Math.max(0, Math.min(window.innerHeight - h, y));
    win.style.left = x + "px";
    win.style.top = y + "px";
  });

  document.addEventListener("mouseup", () => {
    drag = null;
  });

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
})();
