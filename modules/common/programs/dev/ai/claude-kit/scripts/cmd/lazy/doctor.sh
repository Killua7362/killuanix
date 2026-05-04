#!/usr/bin/env bash
_lazy_doctor() {
  local ok=1
  echo "claude-kit lazy doctor:"
  if [ ! -d "$LAZY_DIR" ]; then
    echo "  [FAIL] $LAZY_DIR does not exist"
    return 1
  fi
  printf '  [ok]   lazy dir: %s\n' "$LAZY_DIR"
  if [ -f "$LAZY_DIR/lazy.json" ]; then
    if jq '.' "$LAZY_DIR/lazy.json" >/dev/null 2>&1; then
      echo "  [ok]   lazy.json valid"
    else
      echo "  [FAIL] lazy.json invalid JSON"; ok=0
    fi
  else
    echo "  [WARN] missing lazy.json (catalog descriptions)"
  fi
  local c
  for c in $(_lazy_catalogs); do
    if jq '.' "$LAZY_DIR/$c/catalog.json" >/dev/null 2>&1; then
      printf '  [ok]   %s/catalog.json\n' "$c"
    else
      printf '  [FAIL] %s/catalog.json invalid\n' "$c"; ok=0
    fi
  done
  [ "$ok" = 1 ]
}
