{
  pkgs,
  lib,
  ...
}: let
  ansibleDir = "${builtins.toString ./.}/ansible";

  work-vm = pkgs.writeShellScriptBin "work-vm" ''
    set -euo pipefail
    export PATH="${pkgs.sshpass}/bin:$PATH"

    VM_NAME="work-ubuntu"
    VM_USER="user"
    VM_HOST_FALLBACK="192.168.122.100"
    SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5"
    ANSIBLE_DIR="${ansibleDir}"
    export ANSIBLE_CONFIG="$ANSIBLE_DIR/ansible.cfg"

    # Use static IP first, only auto-detect if static is unreachable
    VM_HOST="$VM_HOST_FALLBACK"
    export SSHPASS="work123"

    usage() {
      cat <<'USAGE'
    Usage: work-vm <command> [args...]

    VM Control:
      start                Start the VM
      stop                 Graceful ACPI shutdown
      restart              Reboot the VM
      kill                 Force destroy (unresponsive VM)
      status               Show VM state + resource usage (JSON)
      console              Open SPICE viewer
      ssh [cmd]            SSH into VM (optionally run a command)
      ip                   Get VM IP address
      logs                 Show recent VM console logs
      network              Show VM network info

    Snapshots:
      snapshot create [name]   Create a named snapshot
      snapshot list            List all snapshots
      snapshot revert <name>   Revert to snapshot
      snapshot delete <name>   Delete snapshot

    Backup:
      backup [dest]        Live backup of VM disk

    Stats:
      stats                Live resource stats

    Provisioning:
      provision            Run Ansible setup playbook
      update               Run Ansible update playbook
      install <pkg...>     Install packages via Ansible
      playbook <path>      Run a custom Ansible playbook
      vpn <start|stop|status>  Manage OpenConnect VPN in VM

    Scheduling:
      schedule stop <min>  Schedule VM shutdown in N minutes
      schedule cancel      Cancel scheduled shutdown
      schedule status      Check if shutdown is scheduled

    Display:
      fix-res              Reset VM display to preferred resolution

    Networking:
      forward <host:guest> SSH local port forward
      clipboard            Clipboard sync info
      mount                Shared directory info
    USAGE
    }

    get_ip() {
      echo "$VM_HOST"
    }

    get_state() {
      virsh -c qemu:///system domstate "$VM_NAME" 2>/dev/null | head -1 || echo "unknown"
    }

    cmd_start() {
      virsh -c qemu:///system start "$VM_NAME"
      echo "VM $VM_NAME started"
      # Wait for SSH to be ready, then start notification relay
      (
        for i in $(seq 1 30); do
          if ${pkgs.sshpass}/bin/sshpass -e ssh $SSH_OPTS -o BatchMode=no "$VM_USER@$VM_HOST" true 2>/dev/null; then
            # Fix resolution to match virt-viewer window
            sleep 3
            ${pkgs.sshpass}/bin/sshpass -e ssh $SSH_OPTS "$VM_USER@$VM_HOST" "DISPLAY=:0 xrandr --output Virtual-1 --preferred" 2>/dev/null || true
            break
          fi
          sleep 5
        done
      ) &
      disown
    }

    cmd_stop() {
      virsh -c qemu:///system shutdown "$VM_NAME"
      echo "Graceful shutdown sent to $VM_NAME"
    }

    cmd_restart() {
      virsh -c qemu:///system reboot "$VM_NAME"
      echo "Reboot sent to $VM_NAME"
    }

    cmd_kill() {
      virsh -c qemu:///system destroy "$VM_NAME"
      echo "Force destroyed $VM_NAME"
    }

    cmd_status() {
      local state
      state=$(get_state)
      local ip="N/A"
      local cpu="N/A"
      local mem_used="N/A"
      local mem_total="N/A"
      local uptime="N/A"

      if [ "$state" = "running" ]; then
        ip=$(get_ip)

        # Get CPU stats
        cpu=$(virsh -c qemu:///system domstats "$VM_NAME" --cpu-total 2>/dev/null \
          | ${pkgs.gawk}/bin/awk -F= '/cpu.time/ {printf "%.0f%%", $2/1000000000*100/4}' 2>/dev/null || echo "N/A")

        # Get memory info
        local mem_info
        mem_info=$(virsh -c qemu:///system dommemstat "$VM_NAME" 2>/dev/null || true)
        mem_total=$(echo "$mem_info" | ${pkgs.gawk}/bin/awk '/^actual/ {printf "%.1fG", $2/1048576}')
        mem_used=$(echo "$mem_info" | ${pkgs.gawk}/bin/awk '/^rss/ {printf "%.1fG", $2/1048576}')
        [ -z "$mem_total" ] && mem_total="4G"
        [ -z "$mem_used" ] && mem_used="N/A"

        # Get uptime from guest agent if available
        local guest_time
        guest_time=$(virsh -c qemu:///system guestinfo "$VM_NAME" --os 2>/dev/null \
          | ${pkgs.gawk}/bin/awk -F': ' '/os.uptime/ {print $2}' || true)
        if [ -n "$guest_time" ]; then
          local hours=$((guest_time / 3600))
          local minutes=$(( (guest_time % 3600) / 60))
          uptime="''${hours}h ''${minutes}m"
        fi
      fi

      cat <<EOF
    {"state":"$state","cpu":"$cpu","memory":"$mem_used/$mem_total","uptime":"$uptime","ip":"$ip"}
    EOF
    }

    cmd_console() {
      ${pkgs.virt-viewer}/bin/virt-viewer --attach -c qemu:///system "$VM_NAME" &
      disown
      echo "SPICE console opened"
      # Fix resolution after viewer opens
      (sleep 2 && ${pkgs.sshpass}/bin/sshpass -e ssh $SSH_OPTS "$VM_USER@$VM_HOST" "DISPLAY=:0 xrandr --output Virtual-1 --preferred" 2>/dev/null) &
      disown
    }

    cmd_ssh() {
      local ip
      ip=$(get_ip)
      if [ $# -gt 0 ]; then
        ssh $SSH_OPTS "$VM_USER@$ip" "$@"
      else
        ssh $SSH_OPTS "$VM_USER@$ip"
      fi
    }

    cmd_snapshot() {
      local subcmd="''${1:-list}"
      shift || true

      case "$subcmd" in
        create)
          local name="''${1:-snap-$(date +%Y%m%d-%H%M%S)}"
          virsh -c qemu:///system snapshot-create-as "$VM_NAME" --name "$name"
          echo "Snapshot '$name' created"
          ;;
        list)
          virsh -c qemu:///system snapshot-list "$VM_NAME"
          ;;
        revert)
          [ -z "''${1:-}" ] && echo "Usage: work-vm snapshot revert <name>" && exit 1
          virsh -c qemu:///system snapshot-revert "$VM_NAME" "$1"
          echo "Reverted to snapshot '$1'"
          ;;
        delete)
          [ -z "''${1:-}" ] && echo "Usage: work-vm snapshot delete <name>" && exit 1
          virsh -c qemu:///system snapshot-delete "$VM_NAME" "$1"
          echo "Deleted snapshot '$1'"
          ;;
        *)
          echo "Usage: work-vm snapshot {create|list|revert|delete} [name]"
          exit 1
          ;;
      esac
    }

    cmd_backup() {
      local dest="''${1:-$HOME/VMs/backups}"
      mkdir -p "$dest"
      local timestamp
      timestamp=$(date +%Y%m%d-%H%M%S)
      local backup_file="$dest/work-ubuntu-$timestamp.qcow2"

      echo "Creating backup at $backup_file..."
      ${pkgs.qemu}/bin/qemu-img convert -O qcow2 "$HOME/VMs/work-ubuntu.qcow2" "$backup_file"
      echo "Backup complete: $backup_file"
    }

    cmd_stats() {
      echo "=== VM Resource Stats ==="
      virsh -c qemu:///system domstats "$VM_NAME" 2>/dev/null || echo "VM not running"
    }

    cmd_provision() {
      echo "Running setup playbook..."
      ${pkgs.ansible}/bin/ansible-playbook -i "$ANSIBLE_DIR/inventory.yml" -e "ansible_host=$VM_HOST" "$ANSIBLE_DIR/setup.yml"
    }

    cmd_update() {
      echo "Running update playbook..."
      ${pkgs.ansible}/bin/ansible-playbook -i "$ANSIBLE_DIR/inventory.yml" -e "ansible_host=$VM_HOST" "$ANSIBLE_DIR/update.yml"
    }

    cmd_install() {
      [ $# -eq 0 ] && echo "Usage: work-vm install <pkg...>" && exit 1
      local pkgs_json
      pkgs_json=$(printf '%s\n' "$@" | ${pkgs.jq}/bin/jq -R . | ${pkgs.jq}/bin/jq -s .)
      echo "Installing: $*"
      ${pkgs.ansible}/bin/ansible-playbook -i "$ANSIBLE_DIR/inventory.yml" -e "ansible_host=$VM_HOST" "$ANSIBLE_DIR/install.yml" \
        -e "{\"packages\": $pkgs_json}"
    }

    cmd_playbook() {
      [ -z "''${1:-}" ] && echo "Usage: work-vm playbook <path>" && exit 1
      ${pkgs.ansible}/bin/ansible-playbook -i "$ANSIBLE_DIR/inventory.yml" -e "ansible_host=$VM_HOST" "$1"
    }

    cmd_vpn() {
      local action="''${1:-status}"
      case "$action" in
        start|stop|status)
          ${pkgs.ansible}/bin/ansible-playbook -i "$ANSIBLE_DIR/inventory.yml" -e "ansible_host=$VM_HOST" "$ANSIBLE_DIR/vpn.yml" \
            -e "vpn_action=$action"
          ;;
        *)
          echo "Usage: work-vm vpn {start|stop|status}"
          exit 1
          ;;
      esac
    }

    cmd_forward() {
      [ -z "''${1:-}" ] && echo "Usage: work-vm forward <host-port>:<guest-port>" && exit 1
      local host_port guest_port
      host_port=$(echo "$1" | cut -d: -f1)
      guest_port=$(echo "$1" | cut -d: -f2)
      local ip
      ip=$(get_ip)
      echo "Forwarding localhost:$host_port -> $ip:$guest_port (Ctrl+C to stop)"
      ssh -N -L "$host_port:$ip:$guest_port" $SSH_OPTS "$VM_USER@$ip"
    }

    cmd_clipboard() {
      echo "Clipboard sync requires spice-vdagent in the VM."
      echo "It should be installed during provisioning (work-vm provision)."
      echo "If not working, SSH in and run: sudo apt install spice-vdagent && sudo systemctl start spice-vdagentd"
    }

    cmd_ip() {
      get_ip
    }

    cmd_logs() {
      virsh -c qemu:///system console "$VM_NAME" --force 2>/dev/null || \
        echo "Could not attach to console. VM may not be running."
    }

    cmd_mount() {
      echo "Shared directory: ~/Documents/shared <-> /mnt/host (in VM)"
      echo ""
      echo "Host path:  $HOME/Documents/shared"
      echo "Guest path: /mnt/host"
      echo "Type:       virtiofs"
      echo ""
      echo "The mount is configured automatically during provisioning."
      echo "To manually mount in the VM: sudo mount -t virtiofs host-shared /mnt/host"
    }

    cmd_network() {
      echo "=== VM Network Info ==="
      echo "VM Name: $VM_NAME"
      echo "IP: $(get_ip)"
      echo ""
      echo "MAC addresses:"
      virsh -c qemu:///system domiflist "$VM_NAME" 2>/dev/null || echo "  VM not defined"
      echo ""
      echo "IP addresses:"
      virsh -c qemu:///system domifaddr "$VM_NAME" 2>/dev/null || echo "  VM not running"
    }

    cmd_fix_res() {
      ${pkgs.sshpass}/bin/sshpass -e ssh $SSH_OPTS "$VM_USER@$VM_HOST" "DISPLAY=:0 xrandr --output Virtual-1 --preferred" 2>/dev/null
      echo "Resolution set to preferred"
    }

    SCHEDULE_PID_FILE="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/work-vm-schedule.pid"

    cmd_schedule() {
      local subcmd="''${1:-}"
      shift || true

      case "$subcmd" in
        stop)
          local minutes="''${1:-}"
          [ -z "$minutes" ] && echo "Usage: work-vm schedule stop <minutes>" && exit 1

          # Cancel existing schedule
          cmd_schedule cancel 2>/dev/null || true

          echo "VM will shut down in $minutes minutes"
          (
            sleep "$((minutes * 60))"
            activity-sim stop 2>/dev/null || true
            virsh -c qemu:///system shutdown "$VM_NAME"
            echo "Scheduled shutdown executed"
            rm -f "$SCHEDULE_PID_FILE"
          ) &

          echo $! > "$SCHEDULE_PID_FILE"
          ;;
        cancel)
          if [ -f "$SCHEDULE_PID_FILE" ]; then
            local pid
            pid=$(cat "$SCHEDULE_PID_FILE")
            if kill -0 "$pid" 2>/dev/null; then
              kill "$pid" 2>/dev/null || true
              rm -f "$SCHEDULE_PID_FILE"
              echo "Scheduled shutdown cancelled"
            else
              rm -f "$SCHEDULE_PID_FILE"
              echo "No active schedule"
            fi
          else
            echo "No active schedule"
          fi
          ;;
        status)
          if [ -f "$SCHEDULE_PID_FILE" ]; then
            local pid
            pid=$(cat "$SCHEDULE_PID_FILE")
            if kill -0 "$pid" 2>/dev/null; then
              echo "Shutdown scheduled (PID: $pid)"
            else
              rm -f "$SCHEDULE_PID_FILE"
              echo "No active schedule"
            fi
          else
            echo "No active schedule"
          fi
          ;;
        *)
          echo "Usage: work-vm schedule {stop <minutes>|cancel|status}"
          ;;
      esac
    }

    # Main dispatch
    case "''${1:-}" in
      start)    cmd_start ;;
      stop)     cmd_stop ;;
      restart)  cmd_restart ;;
      kill)     cmd_kill ;;
      status)   cmd_status ;;
      console)  cmd_console ;;
      ssh)      shift; cmd_ssh "$@" ;;
      snapshot) shift; cmd_snapshot "$@" ;;
      backup)   shift; cmd_backup "$@" ;;
      stats)    cmd_stats ;;
      provision) cmd_provision ;;
      update)   cmd_update ;;
      install)  shift; cmd_install "$@" ;;
      playbook) shift; cmd_playbook "$@" ;;
      vpn)      shift; cmd_vpn "$@" ;;
      forward)  shift; cmd_forward "$@" ;;
      clipboard) cmd_clipboard ;;
      ip)       cmd_ip ;;
      logs)     cmd_logs ;;
      mount)    cmd_mount ;;
      network)  cmd_network ;;
      schedule) shift; cmd_schedule "$@" ;;
      fix-res)  cmd_fix_res ;;
      -h|--help|help|"")
        usage
        ;;
      *)
        echo "Unknown command: $1"
        usage
        exit 1
        ;;
    esac
  '';
in {
  home.packages = [work-vm];
}
