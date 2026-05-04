#!/usr/bin/env bash
# Render a session jsonl into a readable markdown file. Cached by mtime —
# only re-renders when the jsonl is newer than the cached .md. Every jq
# call is fenced with `|| true` so a malformed entry can't kill the loop
# under `set -euo pipefail`.
_render_session() {
  local jl="$1" out="$2" enc="$3"
  mkdir -p "$(dirname "$out")"
  local cwd msg_count first_user
  cwd=$( { jq -rs 'map(select(.cwd? != null))[0].cwd // ""' "$jl" 2>/dev/null || true; } )
  msg_count=$( { jq -rs '[.[]? | select(.type? == "user" or .type? == "assistant")] | length' "$jl" 2>/dev/null || echo 0; } )
  first_user=$( {
    jq -rs '
      [.[]? | select(.type? == "user") | .message?.content?
        | if type == "string" then .
          elif type == "array" then ([.[]? | select(.type? == "text") | .text? // ""] | join(" "))
          else "" end
      ] | map(select(. != "" and . != null and (startswith("<command-name>") | not))) | .[0] // ""
    ' "$jl" 2>/dev/null || true;
  } | tr '\n' ' ' | head -c 240 || true)
  {
    printf '# %s\n\n' "$(basename "$jl" .jsonl)"
    # shellcheck disable=SC2016
    printf -- '- **Project:** `%s`\n' "$enc"
    # shellcheck disable=SC2016
    [ -n "$cwd" ] && printf -- '- **CWD:** `%s`\n' "$cwd"
    printf -- '- **Messages:** %s\n' "$msg_count"
    [ -n "$first_user" ] && printf -- '- **First prompt:** %s…\n' "$first_user"
    printf '\n---\n\n'
    jq -r '
      select(.type? == "user" or .type? == "assistant") |
      # Drop user turns that are just slash-command meta wrappers
      # (`<command-name>/clear</command-name>`, `/compact`, etc.).
      select(.type? != "user" or
             (.message?.content? |
               if type == "string" then (startswith("<command-name>") | not)
               else true end)) |
      (.timestamp? // "") as $t |
      if .type == "user" then
        "## [user] " + $t + "\n\n" +
        (.message?.content?
          | if type == "string" then .
            elif type == "array" then ([.[]? | select(.type? == "text") | .text? // ""] | join("\n"))
            else "" end)
      else
        "## [assistant] " + $t + "\n\n" +
        (.message?.content?
          | if type == "string" then .
            elif type == "array" then ([.[]?
              | if .type? == "text" then .text? // ""
                elif .type? == "tool_use" then "_[tool_use: " + (.name? // "?") + "]_"
                else "" end
            ] | map(select(. != "")) | join("\n"))
            else "" end)
      end
    ' "$jl" 2>/dev/null || true
  } > "$out"
}
