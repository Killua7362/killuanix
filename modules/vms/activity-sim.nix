{
  pkgs,
  config,
  ...
}: let
  keysFile = "${config.home.homeDirectory}/killuanix/modules/vms/activity-keys.conf";

  activity-sim = pkgs.writeShellScriptBin "activity-sim" ''
    set -euo pipefail
    export PATH="${pkgs.sshpass}/bin:$PATH"

    VM_USER="''${ACTIVITY_SIM_USER:-user}"
    VM_HOST="''${ACTIVITY_SIM_HOST:-192.168.122.100}"
    VM_PASS="''${ACTIVITY_SIM_PASS:-work123}"
    PID_FILE="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/activity-sim.pid"
    MODE_FILE="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/activity-sim.mode"
    KEYS_FILE="${keysFile}"
    export SSHPASS="$VM_PASS"
    SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5"

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

    get_mode() {
      if [ -f "$MODE_FILE" ]; then
        cat "$MODE_FILE"
      else
        echo "normal"
      fi
    }

    do_status() {
      if is_running; then
        echo "{\"running\":true,\"mode\":\"$(get_mode)\"}"
      else
        echo '{"running":false,"mode":"stopped"}'
      fi
    }

    do_start() {
      local mode="''${1:-normal}"

      # Stop existing if running
      if is_running; then
        do_stop > /dev/null
      fi

      echo "$mode" > "$MODE_FILE"

      # Mute VM audio on host
      vm_ssh "DISPLAY=:0 pactl set-sink-mute @DEFAULT_SINK@ 1" 2>/dev/null || true

      (
        while true; do
          current_mode=$(cat "$MODE_FILE" 2>/dev/null || echo "normal")

          case "$current_mode" in
            typing)
              # Typing mode: rapid random keypresses to look like typing
              chars=("a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l" "m" "n" "o" "p" "q" "r" "s" "t" "u" "v" "w" "x" "y" "z" "space" "BackSpace" "period" "comma" "Return")
              # Type 3-8 chars in quick succession
              burst=$((RANDOM % 6 + 3))
              for ((b=0; b<burst; b++)); do
                key=''${chars[$((RANDOM % ''${#chars[@]}))]}
                vm_ssh "DISPLAY=:0 xdotool key $key" 2>/dev/null || true
                sleep 0.$((RANDOM % 3 + 1))
              done
              # Occasional mouse move between bursts (30% chance)
              if [ $((RANDOM % 3)) -eq 0 ]; then
                x=$((RANDOM % 1200 + 100))
                y=$((RANDOM % 700 + 100))
                vm_ssh "DISPLAY=:0 xdotool mousemove $x $y" 2>/dev/null || true
              fi
              # Pause between bursts (like thinking)
              sleep 0.$((RANDOM % 5 + 3))
              ;;
            custom)
              # Custom keys mode: read keys from config file
              if [ -f "$KEYS_FILE" ] && [ -s "$KEYS_FILE" ]; then
                mapfile -t custom_keys < <(grep -v '^#' "$KEYS_FILE" | grep -v '^$')
                if [ ''${#custom_keys[@]} -gt 0 ]; then
                  key=''${custom_keys[$((RANDOM % ''${#custom_keys[@]}))]}
                  vm_ssh "DISPLAY=:0 xdotool key $key" 2>/dev/null || true
                fi
              fi
              sleep 0.$((RANDOM % 5 + 3))
              ;;
            *)
              # Normal mode: mouse + keyboard mix, faster intervals
              action=$((RANDOM % 5))
              case $action in
                0|1)
                  # Mouse move
                  x=$((RANDOM % 1200 + 100))
                  y=$((RANDOM % 700 + 100))
                  vm_ssh "DISPLAY=:0 xdotool mousemove $x $y" 2>/dev/null || true
                  ;;
                2)
                  # Mouse move + click
                  x=$((RANDOM % 1200 + 100))
                  y=$((RANDOM % 700 + 100))
                  vm_ssh "DISPLAY=:0 xdotool mousemove $x $y click 1" 2>/dev/null || true
                  ;;
                3)
                  # Keypress from file or defaults
                  if [ -f "$KEYS_FILE" ] && [ -s "$KEYS_FILE" ]; then
                    mapfile -t file_keys < <(grep -v '^#' "$KEYS_FILE" | grep -v '^$')
                    if [ ''${#file_keys[@]} -gt 0 ]; then
                      key=''${file_keys[$((RANDOM % ''${#file_keys[@]}))]}
                    else
                      keys=("Left" "Right" "Up" "Down" "space" "Tab")
                      key=''${keys[$((RANDOM % ''${#keys[@]}))]}
                    fi
                  else
                    keys=("Left" "Right" "Up" "Down" "space" "Tab")
                    key=''${keys[$((RANDOM % ''${#keys[@]}))]}
                  fi
                  vm_ssh "DISPLAY=:0 xdotool key $key" 2>/dev/null || true
                  ;;
                4)
                  # Scroll
                  dir=$((RANDOM % 2))
                  if [ $dir -eq 0 ]; then
                    vm_ssh "DISPLAY=:0 xdotool click 4" 2>/dev/null || true
                  else
                    vm_ssh "DISPLAY=:0 xdotool click 5" 2>/dev/null || true
                  fi
                  ;;
              esac
              sleep 0.$((RANDOM % 5 + 3))
              ;;
          esac
        done
      ) &

      echo $! > "$PID_FILE"
      echo "{\"running\":true,\"mode\":\"$mode\"}"
    }

    do_stop() {
      if is_running; then
        local pid
        pid=$(cat "$PID_FILE")
        kill "$pid" 2>/dev/null || true
        pkill -P "$pid" 2>/dev/null || true
        rm -f "$PID_FILE"
      fi
      rm -f "$MODE_FILE"
      # Unmute VM audio on host
      vm_ssh "DISPLAY=:0 pactl set-sink-mute @DEFAULT_SINK@ 0" 2>/dev/null || true
      echo '{"running":false,"mode":"stopped"}'
    }

    do_toggle() {
      if is_running; then
        do_stop
      else
        do_start normal
      fi
    }

    case "''${1:-status}" in
      start)   do_start "''${2:-normal}" ;;
      stop)    do_stop ;;
      toggle)  do_toggle ;;
      status)  do_status ;;
      typing)  do_start typing ;;
      custom)  do_start custom ;;
      mode)
        if is_running && [ -n "''${2:-}" ]; then
          echo "''${2}" > "$MODE_FILE"
          echo "Mode switched to ''${2}"
        else
          echo "Current mode: $(get_mode)"
        fi
        ;;
      *)
        echo "Usage: activity-sim {start|stop|toggle|status|typing|custom|mode <normal|typing|custom>}" >&2
        echo ""
        echo "Modes:"
        echo "  normal  - Mouse moves + keypresses (from keys file or defaults)"
        echo "  typing  - Rapid random keypresses (looks like typing)"
        echo "  custom  - Only presses keys from $KEYS_FILE"
        echo ""
        echo "Keys file: $KEYS_FILE"
        echo "  One xdotool key name per line. Lines starting with # are ignored."
        echo ""
        echo "Switch mode while running: activity-sim mode typing"
        exit 1
        ;;
    esac
  '';
in {
  home.packages = [activity-sim];
}
