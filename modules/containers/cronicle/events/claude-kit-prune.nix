# Daily prune of files older than 7 days under ~/.cache/claude-kit/{sessions,sources}.
# claude-kit's /tmp/claude-kit-* working dirs are already cleaned at script
# exit by traps inside modules/common/programs/dev/ai/claude-kit.nix, so this
# only targets the persistent renderer cache.
{
  enabled = true;

  id = "claudekit_prune";
  title = "claude-kit cache prune";
  notes = "Daily prune of files older than 7 days under ~/.cache/claude-kit/{sessions,sources}.";

  timing = {
    hours = [3];
    minutes = [30];
  };
  timezone = "Asia/Kolkata";

  # Host paths the script needs to see inside the container. Aggregated by
  # the container module into its bind-mount list.
  bindMounts = [
    "/home/killua/.cache/claude-kit:/host-cache:rw"
  ];

  timeout = 600;

  script = ''
    set -euo pipefail
    for sub in sessions sources; do
      d="/host-cache/$sub"
      if [ -d "$d" ]; then
        find "$d" -type f -mtime +7 -delete
        find "$d" -mindepth 1 -type d -empty -delete || true
      fi
    done
  '';
}
