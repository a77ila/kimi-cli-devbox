#!/usr/bin/env bash
# Pure-shell parser/selector for the simple projects.yaml schema used by the
# Kimi launcher.  This script is meant to be sourced by run-kimi.sh.
#
# Exposed function:
#   select_project <yaml-file> <devbox-root>
#
# On success it sets:
#   SELECTED_PROJECT_NAME
#   SELECTED_PROJECT_ROOT     (absolute path)
#   SELECTED_PROJECT_AGENTS   (absolute path)

# Trim leading/trailing whitespace and surrounding quotes.
__sp_trim_value() {
  local v="$1"

  # Remove leading whitespace.
  v="${v#"${v%%[![:space:]]*}"}"
  # Remove trailing whitespace.
  v="${v%"${v##*[![:space:]]}"}"

  # Remove matching surrounding quotes.
  if [[ ${#v} -ge 2 ]]; then
    if [[ "${v:0:1}" == '"' && "${v: -1}" == '"' ]]; then
      v="${v:1:-1}"
    elif [[ "${v:0:1}" == "'" && "${v: -1}" == "'" ]]; then
      v="${v:1:-1}"
    fi
  fi

  printf '%s' "$v"
}

# Normalise a path in pure bash (collapse ., .., and duplicate slashes).
__sp_normalize_path() {
  local input="$1"
  local -a parts out
  local part

  [[ -z "$input" ]] && input="."

  local leading_slash=false
  if [[ "${input:0:1}" == "/" ]]; then
    leading_slash=true
  fi

  IFS='/' read -ra parts <<< "$input"
  for part in "${parts[@]}"; do
    [[ -z "$part" || "$part" == "." ]] && continue
    if [[ "$part" == ".." ]]; then
      if (( ${#out[@]} > 0 )); then
        local idx=$(( ${#out[@]} - 1 ))
        unset "out[$idx]"
      fi
    else
      out+=("$part")
    fi
  done

  local result=""
  $leading_slash && result="/"
  result+="$(IFS=/; printf '%s' "${out[*]}")"

  printf '%s' "$result"
}

# Expand leading ~ and resolve relative paths against a base directory.
__sp_resolve_path() {
  local p="$1" base="$2"

  if [[ "$p" == \~ ]]; then
    p="$HOME"
  elif [[ "$p" == \~/* ]]; then
    p="$HOME/${p:2}"
  fi

  if [[ "$p" != /* ]]; then
    p="$base/$p"
  fi

  __sp_normalize_path "$p"
}

# Parse projects.yaml into parallel arrays.
__sp_parse_yaml() {
  local yaml_file="$1"
  local -n _names="$2"
  local -n _roots="$3"
  local -n _agents="$4"

  local line indent indent_len
  local in_projects=false
  local item_indent=-1
  local project_idx=-1
  local key value

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Strip carriage returns (Windows line endings).
    line="${line//$'\r'/}"

    # Skip comments and blank lines.
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue

    # Top-level "projects:" key.
    if [[ "$line" =~ ^[[:space:]]*projects:[[:space:]]*$ ]]; then
      in_projects=true
      continue
    fi

    $in_projects || continue

    # Leading-space indent length.
    indent="${line%%[^[:space:]]*}"
    indent_len=${#indent}

    # New list item.
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]+(.*)$ ]]; then
      local remainder="${BASH_REMATCH[1]}"
      item_indent=$indent_len

      if [[ "$remainder" =~ ^([[:alnum:]_-]+):[[:space:]]*(.*)$ ]]; then
        key="${BASH_REMATCH[1]}"
        value="$(__sp_trim_value "${BASH_REMATCH[2]}")"

        # Plain assignment so set -e never trips on an arithmetic status.
        project_idx=$((project_idx + 1))
        _names[project_idx]=""
        _roots[project_idx]=""
        _agents[project_idx]=""

        case "$key" in
          name) _names[project_idx]="$value" ;;
          root) _roots[project_idx]="$value" ;;
          agents) _agents[project_idx]="$value" ;;
        esac
      fi
      continue
    fi

    # Property belonging to the current list item.
    if (( indent_len > item_indent )) && \
       [[ "$line" =~ ^[[:space:]]*([[:alnum:]_-]+):[[:space:]]*(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      value="$(__sp_trim_value "${BASH_REMATCH[2]}")"

      case "$key" in
        name) _names[project_idx]="$value" ;;
        root) _roots[project_idx]="$value" ;;
        agents) _agents[project_idx]="$value" ;;
      esac
    fi
  done < "$yaml_file"
}

# Public entry point.
select_project() {
  local yaml_file="$1"
  local devbox_root="$2"

  if [[ ! -f "$yaml_file" ]]; then
    echo "Error: project configuration not found: $yaml_file" >&2
    echo "Copy projects.yaml.example to projects.yaml and add your projects." >&2
    return 1
  fi

  local -a names roots agents
  __sp_parse_yaml "$yaml_file" names roots agents

  local count=${#names[@]}
  local i choice

  # Validate the parsed projects.
  if (( count == 0 )); then
    echo "Error: no projects found in projects.yaml" >&2
    return 1
  fi

  for ((i = 0; i < count; i++)); do
    if [[ -z "${names[i]}" ]]; then
      echo "Error: project $((i + 1)) is missing a name" >&2
      return 1
    fi
    if [[ ! "${names[i]}" =~ ^[a-z0-9_-]+$ ]]; then
      echo "Error: project name '${names[i]}' must contain only lowercase letters, digits, underscores, and hyphens" >&2
      return 1
    fi
    if [[ -z "${roots[i]}" ]]; then
      echo "Error: project '${names[i]}' is missing a root directory" >&2
      return 1
    fi
  done

  echo "Available projects:"
  for ((i = 0; i < count; i++)); do
    printf '  %d) %s\n' "$((i + 1))" "${names[i]}"
    printf '       root:   %s\n' "$(__sp_resolve_path "${roots[i]}" "$devbox_root")"

    local agents_default
    agents_default="$(__sp_resolve_path "kimi-agents/${names[i]}" "$devbox_root")"
    printf '       agents: %s\n' "$(__sp_resolve_path "${agents[i]:-$agents_default}" "$devbox_root")"
  done

  while true; do
    if ! read -rp "Select project (1-$count): " choice; then
      echo "" >&2
      echo "Error: no project selected" >&2
      return 1
    fi

    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= count )); then
      i=$((choice - 1))
      SELECTED_PROJECT_NAME="${names[i]}"
      SELECTED_PROJECT_ROOT="$(__sp_resolve_path "${roots[i]}" "$devbox_root")"

      local agents_default
      agents_default="$(__sp_resolve_path "kimi-agents/${names[i]}" "$devbox_root")"
      SELECTED_PROJECT_AGENTS="$(__sp_resolve_path "${agents[i]:-$agents_default}" "$devbox_root")"
      return 0
    fi

    echo "Invalid selection." >&2
  done
}

# If executed directly, run a quick self-test with a sample file.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -uo pipefail

  devbox_root="$(cd "$(dirname "$0")/.." && pwd)"
  yaml_file="${1:-$devbox_root/projects.yaml}"

  if select_project "$yaml_file" "$devbox_root"; then
    echo ""
    echo "Selected:"
    echo "  name:   $SELECTED_PROJECT_NAME"
    echo "  root:   $SELECTED_PROJECT_ROOT"
    echo "  agents: $SELECTED_PROJECT_AGENTS"
  fi
fi
