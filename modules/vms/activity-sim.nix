{pkgs, ...}: let
  activity-sim = pkgs.writeShellScriptBin "activity-sim" ''
    set -euo pipefail

    VM_USER="''${ACTIVITY_SIM_USER:-user}"
    VM_HOST="''${ACTIVITY_SIM_HOST:-192.168.122.100}"
    PID_FILE="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/activity-sim.pid"
    SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes"

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

    do_status() {
      if is_running; then
        echo '{"running":true}'
      else
        echo '{"running":false}'
      fi
    }

    do_start() {
      if is_running; then
        echo '{"running":true}'
        return 0
      fi

      (
        while true; do
          # Random delay between 3-15 seconds
          sleep $((RANDOM % 13 + 3))

          # Pick a random action
          action=$((RANDOM % 4))
          case $action in
            0)
              # Random absolute mouse move
              x=$((RANDOM % 1200 + 100))
              y=$((RANDOM % 700 + 100))
              ssh $SSH_OPTS "$VM_USER@$VM_HOST" "DISPLAY=:0 xdotool mousemove $x $y" 2>/dev/null || true
              ;;
            1)
              # Relative mouse move
              dx=$((RANDOM % 200 - 100))
              dy=$((RANDOM % 200 - 100))
              ssh $SSH_OPTS "$VM_USER@$VM_HOST" "DISPLAY=:0 xdotool mousemove_relative -- $dx $dy" 2>/dev/null || true
              ;;
            2)
              # Safe keypress (arrows, space, tab)
              keys=("Left" "Right" "Up" "Down" "space" "Tab")
              key=''${keys[$((RANDOM % ''${#keys[@]}))]}
              ssh $SSH_OPTS "$VM_USER@$VM_HOST" "DISPLAY=:0 xdotool key $key" 2>/dev/null || true
              ;;
            3)
              # Mouse move + small pause + another move (looks like browsing)
              x=$((RANDOM % 1200 + 100))
              y=$((RANDOM % 700 + 100))
              ssh $SSH_OPTS "$VM_USER@$VM_HOST" "DISPLAY=:0 xdotool mousemove $x $y" 2>/dev/null || true
              sleep $((RANDOM % 3 + 1))
              x2=$((RANDOM % 1200 + 100))
              y2=$((RANDOM % 700 + 100))
              ssh $SSH_OPTS "$VM_USER@$VM_HOST" "DISPLAY=:0 xdotool mousemove $x2 $y2" 2>/dev/null || true
              ;;
          esac
        done
      ) &

      echo $! > "$PID_FILE"
      echo '{"running":true}'
    }

    do_stop() {
      if is_running; then
        local pid
        pid=$(cat "$PID_FILE")
        kill "$pid" 2>/dev/null || true
        # Also kill any child ssh processes
        pkill -P "$pid" 2>/dev/null || true
        rm -f "$PID_FILE"
      fi
      echo '{"running":false}'
    }

    do_toggle() {
      if is_running; then
        do_stop
      else
        do_start
      fi
    }

    case "''${1:-status}" in
      start)  do_start ;;
      stop)   do_stop ;;
      toggle) do_toggle ;;
      status) do_status ;;
      *)
        echo "Usage: activity-sim {start|stop|toggle|status}" >&2
        exit 1
        ;;
    esac
  '';
in {
  home.packages = [activity-sim];
}
