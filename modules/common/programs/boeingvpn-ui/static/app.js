(() => {
  const win = document.getElementById("vpn-window");
  const titlebar = document.getElementById("titlebar");
  const dot = document.getElementById("status-dot");
  const label = document.getElementById("status-label");
  const errLine = document.getElementById("error-line");
  const btnConnect = document.getElementById("btn-connect");
  const btnDisconnect = document.getElementById("btn-disconnect");
  const btnReconnect = document.getElementById("btn-reconnect");
  const btnSubmit = document.getElementById("btn-submit");
  const secret = document.getElementById("secret");

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
  // Local UI states mirror daemon states but add `awaiting-secret`, which only
  // exists between the user pressing Connect and submitting the secret (the
  // daemon has no concept of that — it only spawns openconnect on submit).

  const UI = {
    IDLE: "idle",
    AWAITING: "awaiting-secret",
    CONNECTING: "connecting",
    CONNECTED: "connected",
    DISCONNECTING: "disconnecting",
    ERROR: "error",
  };

  let uiState = UI.IDLE;

  const STYLES = {
    [UI.IDLE]:          { dot: "dot-grey",   text: "Disconnected" },
    [UI.AWAITING]:      { dot: "dot-yellow", text: "Enter PIN+token" },
    [UI.CONNECTING]:    { dot: "dot-yellow", text: "Connecting…" },
    [UI.CONNECTED]:     { dot: "dot-green",  text: "Connected" },
    [UI.DISCONNECTING]: { dot: "dot-yellow", text: "Disconnecting…" },
    [UI.ERROR]:         { dot: "dot-red",    text: "Error" },
  };

  function render(state, errorMsg) {
    uiState = state;
    const s = STYLES[state];
    dot.className = "dot " + s.dot;
    label.textContent = s.text;
    errLine.textContent = state === UI.ERROR && errorMsg ? errorMsg : "";

    const isAwaiting = state === UI.AWAITING;
    const isConnected = state === UI.CONNECTED;
    const isConnecting = state === UI.CONNECTING || state === UI.DISCONNECTING;
    const isIdle = state === UI.IDLE || state === UI.ERROR;

    btnConnect.disabled = !isIdle;
    btnDisconnect.disabled = !(isAwaiting || isConnected || state === UI.CONNECTING);
    btnReconnect.disabled = !(isConnected || state === UI.ERROR);

    secret.disabled = !isAwaiting;
    btnSubmit.disabled = !isAwaiting;

    if (isAwaiting) {
      secret.focus();
    }
    if (!isAwaiting && !isConnecting) {
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
    // Don't clobber the local-only AWAITING state with a poll result.
    if (uiState === UI.AWAITING) return;
    if (snap.state === "connecting") render(UI.CONNECTING);
    else if (snap.state === "connected") render(UI.CONNECTED);
    else if (snap.state === "disconnecting") render(UI.DISCONNECTING);
    else if (snap.state === "error") render(UI.ERROR, snap.last_error || "Unknown error");
    else render(UI.IDLE);
  }

  // ---- Wiring -------------------------------------------------------------

  btnConnect.addEventListener("click", () => {
    render(UI.AWAITING);
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
    render(UI.CONNECTING);
    try {
      const snap = await api("/api/connect", { secret: value });
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

  api("/api/status").then(applyDaemonState).catch(() => render(UI.IDLE));
  setInterval(() => {
    api("/api/status").then(applyDaemonState).catch(() => {});
  }, 2000);
})();
