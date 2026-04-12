{pkgs, ...}: let
  notify-relay = pkgs.writeShellScriptBin "vm-notify-relay" ''
    set -euo pipefail
    export PATH="${pkgs.sshpass}/bin:${pkgs.libnotify}/bin:$PATH"

    VM_USER="''${ACTIVITY_SIM_USER:-user}"
    VM_HOST="''${ACTIVITY_SIM_HOST:-192.168.122.100}"
    VM_PASS="''${ACTIVITY_SIM_PASS:-work123}"
    export SSHPASS="$VM_PASS"
    SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5"
    PID_FILE="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/vm-notify-relay.pid"
    LAST_FILE="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/vm-notify-relay.last"

    vm_ssh() {
      ${pkgs.sshpass}/bin/sshpass -e ssh $SSH_OPTS "$VM_USER@$VM_HOST" "$@"
    }

    is_running() {
      if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
          return 0
        fi
        rm -f "$PID_FILE"
      fi
      return 1
    }

    do_start() {
      if is_running; then
        echo "Notification relay already running"
        return 0
      fi

      (
        while true; do
          # Poll the notification log file in the VM
          current=$(vm_ssh "cat /tmp/hubstaff-notify.log 2>/dev/null" 2>/dev/null || echo "")
          last=$(cat "$LAST_FILE" 2>/dev/null || echo "")

          if [ -n "$current" ] && [ "$current" != "$last" ]; then
            # Get only new lines
            if [ -n "$last" ]; then
              new_lines=$(diff <(echo "$last") <(echo "$current") 2>/dev/null | grep '^>' | sed 's/^> //' || echo "$current")
            else
              new_lines="$current"
            fi

            echo "$current" > "$LAST_FILE"

            while IFS= read -r line; do
              if [ -n "$line" ]; then
                notify-send "Hubstaff" "$line" 2>/dev/null || true
              fi
            done <<< "$new_lines"
          fi

          sleep 15
        done
      ) &

      echo $! > "$PID_FILE"
      echo "Notification relay started"
    }

    do_stop() {
      if is_running; then
        local pid
        pid=$(cat "$PID_FILE")
        kill "$pid" 2>/dev/null || true
        pkill -P "$pid" 2>/dev/null || true
        rm -f "$PID_FILE"
      fi
      echo "Notification relay stopped"
    }

    do_status() {
      if is_running; then
        echo "running"
      else
        echo "stopped"
      fi
    }

    case "''${1:-status}" in
      start)  do_start ;;
      stop)   do_stop ;;
      status) do_status ;;
      *)
        echo "Usage: vm-notify-relay {start|stop|status}" >&2
        exit 1
        ;;
    esac
  '';
in {
  home.packages = [notify-relay];
}
