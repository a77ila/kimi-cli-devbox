#!/usr/bin/env bash
# Pure-shell parser/selector for the projects.yaml schema used by the launcher.
# This script is meant to be sourced by run-kimi.sh.
#
# Exposed function:
#   select_project <yaml-file> <devbox-root>
#
# On success it sets SELECTED_PROJECT_NAME, SELECTED_PROJECT_ROOT,
# SELECTED_PROJECT_AGENTS, SELECTED_PROJECT_SERVICE,
# SELECTED_PROJECT_COMPOSE_PROJECT, SELECTED_PROJECT_COMPOSE_FILES, and
# SELECTED_PROJECT_ENV_FILES. Lists are newline-separated.

__sp_trim_value() {
  local v="$1"
  local quote="" char
  local i

  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"

  for ((i = 0; i < ${#v}; i++)); do
    char="${v:i:1}"
    if [[ -n "$quote" ]]; then
      if [[ "$char" == "$quote" ]]; then
        quote=""
      fi
    elif [[ "$char" == '"' || "$char" == "'" ]]; then
      quote="$char"
    elif [[ "$char" == "#" ]]; then
      if (( i == 0 )) || [[ "${v:i-1:1}" =~ [[:space:]] ]]; then
        v="${v:0:i}"
        v="${v%"${v##*[![:space:]]}"}"
        break
      fi
    fi
  done

  if [[ ${#v} -ge 2 ]]; then
    if [[ "${v:0:1}" == '"' && "${v: -1}" == '"' ]]; then
      v="${v:1:-1}"
    elif [[ "${v:0:1}" == "'" && "${v: -1}" == "'" ]]; then
      v="${v:1:-1}"
    fi
  fi

  printf '%s' "$v"
}

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

__sp_resolve_path_list() {
  local paths="$1" base="$2"
  local path result=""

  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    if [[ -n "$result" ]]; then
      result+=$'\n'
    fi
    result+="$(__sp_resolve_path "$path" "$base")"
  done <<< "$paths"

  printf '%s' "$result"
}

__sp_parse_yaml() {
  local yaml_file="$1"
  local -n _names="$2"
  local -n _roots="$3"
  local -n _agents="$4"
  local -n _services="$5"
  local -n _compose_projects="$6"
  local -n _compose_files="$7"
  local -n _env_files="$8"

  local line indent indent_len
  local in_projects=false
  local item_indent=-1
  local project_idx=-1
  local active_list=""
  local key value

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line//$'\r'/}"

    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue

    if [[ "$line" =~ ^[[:space:]]*projects:[[:space:]]*$ ]]; then
      in_projects=true
      continue
    fi

    $in_projects || continue

    indent="${line%%[^[:space:]]*}"
    indent_len=${#indent}

    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*(.*)$ ]]; then
      local remainder="${BASH_REMATCH[1]}"

      if (( project_idx < 0 || indent_len == item_indent )); then
        if [[ ! "$remainder" =~ ^([[:alnum:]_-]+):[[:space:]]*(.*)$ ]]; then
          echo "Error: each project must be a YAML mapping" >&2
          return 1
        fi

        key="${BASH_REMATCH[1]}"
        value="$(__sp_trim_value "${BASH_REMATCH[2]}")"
        item_indent=$indent_len
        active_list=""
        project_idx=$((project_idx + 1))
        _names[project_idx]=""
        _roots[project_idx]=""
        _agents[project_idx]=""
        _services[project_idx]=""
        _compose_projects[project_idx]=""
        _compose_files[project_idx]=""
        _env_files[project_idx]=""

        case "$key" in
          name) _names[project_idx]="$value" ;;
          root) _roots[project_idx]="$value" ;;
          agents) _agents[project_idx]="$value" ;;
          service) _services[project_idx]="$value" ;;
          compose_project) _compose_projects[project_idx]="$value" ;;
        esac
        continue
      fi

      if (( indent_len > item_indent )) && [[ -n "$active_list" ]]; then
        value="$(__sp_trim_value "$remainder")"
        if [[ -z "$value" ]]; then
          echo "Error: empty path in $active_list" >&2
          return 1
        fi

        local -n _list="_$active_list"
        if [[ -n "${_list[project_idx]}" ]]; then
          _list[project_idx]+=$'\n'
        fi
        _list[project_idx]+="$value"
        unset -n _list
        continue
      fi

      echo "Error: unsupported list entry in projects.yaml: $line" >&2
      return 1
    fi

    if (( indent_len > item_indent )) && \
       [[ "$line" =~ ^[[:space:]]*([[:alnum:]_-]+):[[:space:]]*(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      value="$(__sp_trim_value "${BASH_REMATCH[2]}")"
      active_list=""

      case "$key" in
        name) _names[project_idx]="$value" ;;
        root) _roots[project_idx]="$value" ;;
        agents) _agents[project_idx]="$value" ;;
        service) _services[project_idx]="$value" ;;
        compose_project) _compose_projects[project_idx]="$value" ;;
        compose_files|env_files)
          if [[ -n "$value" ]]; then
            echo "Error: $key must be a YAML list of paths" >&2
            return 1
          fi
          active_list="$key"
          ;;
      esac
    fi
  done < "$yaml_file"
}

select_project() {
  local yaml_file="$1"
  local devbox_root="$2"

  if [[ ! -f "$yaml_file" ]]; then
    echo "Error: project configuration not found: $yaml_file" >&2
    echo "Copy projects.yaml.example to projects.yaml and add your projects." >&2
    return 1
  fi

  local -a names roots agents services compose_projects compose_files env_files
  __sp_parse_yaml "$yaml_file" names roots agents services compose_projects compose_files env_files

  local count=${#names[@]}
  local i choice

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
    if [[ -n "${compose_files[i]}" && -z "${services[i]}" ]]; then
      echo "Error: project '${names[i]}' must set service when compose_files is used" >&2
      return 1
    fi
    if [[ -z "${compose_files[i]}" && -n "${services[i]}${compose_projects[i]}${env_files[i]}" ]]; then
      echo "Error: project '${names[i]}' must set compose_files when Compose options are used" >&2
      return 1
    fi
    if [[ -n "${services[i]}" && ! "${services[i]}" =~ ^[a-zA-Z0-9._-]+$ ]]; then
      echo "Error: project '${names[i]}' has an invalid Compose service name" >&2
      return 1
    fi
    if [[ -n "${compose_projects[i]}" && ! "${compose_projects[i]}" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
      echo "Error: project '${names[i]}' has an invalid compose_project name" >&2
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
    if [[ -n "${compose_files[i]}" ]]; then
      printf '       service: %s\n' "${services[i]}"
    fi
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
      SELECTED_PROJECT_SERVICE="${services[i]}"
      SELECTED_PROJECT_COMPOSE_PROJECT="${compose_projects[i]}"
      SELECTED_PROJECT_COMPOSE_FILES="$(__sp_resolve_path_list "${compose_files[i]}" "$SELECTED_PROJECT_ROOT")"
      SELECTED_PROJECT_ENV_FILES="$(__sp_resolve_path_list "${env_files[i]}" "$SELECTED_PROJECT_ROOT")"
      return 0
    fi

    echo "Invalid selection." >&2
  done
}

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
    if [[ -n "$SELECTED_PROJECT_COMPOSE_FILES" ]]; then
      echo "  service: $SELECTED_PROJECT_SERVICE"
      echo "  compose project: ${SELECTED_PROJECT_COMPOSE_PROJECT:-$SELECTED_PROJECT_NAME}"
      echo "  compose files:"
      while IFS= read -r compose_file; do
        echo "    $compose_file"
      done <<< "$SELECTED_PROJECT_COMPOSE_FILES"
      if [[ -n "$SELECTED_PROJECT_ENV_FILES" ]]; then
        echo "  env files:"
        while IFS= read -r env_file; do
          echo "    $env_file"
        done <<< "$SELECTED_PROJECT_ENV_FILES"
      fi
    fi
  else
    exit 1
  fi
fi
