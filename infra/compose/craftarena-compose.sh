#!/usr/bin/env bash
# Daily start/stop/update for the test compose stack.
# Owner: docs/runbooks/server-deploy.md §4.1
# Never pass -v to compose down: that deletes control-plane-data (SQLite).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="${SCRIPT_DIR}"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

usage() {
  cat <<'EOF'
Usage: bash infra/compose/craftarena-compose.sh <command>

Test-host helper. Does not print IPs. In-progress matches die on down/update/restart.
ICMP ping from a client to this host is unaffected (do not stop a 24h ping for this).

Commands:
  status   git HEAD + docker compose ps
  logs     last 80 lines (logs -f to follow)
  down     stop containers; keep the SQLite volume
  up       start existing images (no git, no rebuild)
  restart  docker compose restart (same images; kills matches)
  build    docker compose build (no git; uses cache, do not add --no-cache)
  update   fetch + ff-only, build, up -d, wait /readyz  (the usual path)

Env:
  CRAFTARENA_GIT_REF    default origin/main
  CRAFTARENA_SKIP_GIT   if 1, update skips git (rebuild the tree as-is)

Needs Docker Compose v2, curl, and infra/compose/.env with GODOT_SHA512 set.
First time the script is not on the host yet: git fetch && git checkout main &&
git pull --ff-only origin main, then run update.
EOF
}

die() {
  echo "craftarena-compose: $*" >&2
  exit 1
}

need_compose() {
  docker compose version >/dev/null 2>&1 || die "need Docker Compose v2 (docker compose version)"
}

compose() {
  docker compose --project-directory "${COMPOSE_DIR}" "$@"
}

trim() {
  local s="$1"
  s="${s%%$'\r'}"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

env_value() {
  local key="$1" line val
  [[ -f "${COMPOSE_DIR}/.env" ]] || return 0
  line="$(grep -E "^${key}=" "${COMPOSE_DIR}/.env" | tail -n1 || true)"
  [[ -n "${line}" ]] || return 0
  val="${line#"${key}="}"
  val="${val%%#*}"
  val="$(trim "${val}")"
  val="${val#\"}"
  val="${val%\"}"
  val="${val#\'}"
  val="${val%\'}"
  printf '%s' "$val"
}

published_port() {
  local key="$1" default="$2" val
  val="$(env_value "${key}")"
  [[ -n "${val}" ]] || val="${default}"
  if [[ "${val}" == *:* ]]; then
    val="${val##*:}"
  fi
  if [[ "${val}" =~ ^[0-9]+$ ]]; then
    printf '%s' "${val}"
  else
    printf '%s' "${default}"
  fi
}

need_env() {
  [[ -f "${COMPOSE_DIR}/.env" ]] || die "missing ${COMPOSE_DIR}/.env (copy .env.example; set GODOT_SHA512)"
  local sha
  sha="$(env_value GODOT_SHA512)"
  [[ -n "${sha}" ]] || die "GODOT_SHA512 empty in ${COMPOSE_DIR}/.env"
}

cmd_status() {
  need_compose
  echo "repo: ${REPO_DIR}"
  if git -C "${REPO_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "git:  $(git -C "${REPO_DIR}" log -1 --oneline)"
    echo "ref:  $(git -C "${REPO_DIR}" rev-parse --abbrev-ref HEAD) $(git -C "${REPO_DIR}" rev-parse --short HEAD)"
  else
    echo "git:  (not a git checkout)"
  fi
  echo
  compose ps
}

cmd_logs() {
  need_compose
  if [[ "${1:-}" == "-f" ]]; then
    compose logs -f
  else
    compose logs --tail=80
  fi
}

cmd_down() {
  need_compose
  compose down
}

cmd_up() {
  need_compose
  need_env
  compose up -d --remove-orphans
  wait_ready
}

cmd_restart() {
  need_compose
  compose restart
  wait_ready
}

cmd_build() {
  need_compose
  need_env
  compose build
}

git_update() {
  if [[ "${CRAFTARENA_SKIP_GIT:-0}" == "1" ]]; then
    echo "CRAFTARENA_SKIP_GIT=1: leaving git tree as-is"
    return 0
  fi
  git -C "${REPO_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not a git repo: ${REPO_DIR}"
  local dirty
  dirty="$(git -C "${REPO_DIR}" status --porcelain --untracked-files=no)"
  [[ -z "${dirty}" ]] || die "tracked files dirty on the test host; commit, stash, or discard before update"$'\n'"${dirty}"
  git -C "${REPO_DIR}" fetch origin
  local ref="${CRAFTARENA_GIT_REF:-origin/main}"
  echo "git: checking out ${ref}"
  if [[ "${ref}" == "origin/main" || "${ref}" == "main" ]]; then
    git -C "${REPO_DIR}" checkout main
    git -C "${REPO_DIR}" merge --ff-only origin/main
  else
    git -C "${REPO_DIR}" checkout --detach "${ref}"
  fi
  echo "git now: $(git -C "${REPO_DIR}" log -1 --oneline)"
}

wait_ready() {
  command -v curl >/dev/null 2>&1 || die "need curl to wait for /readyz"
  local cp_port gw_port i
  cp_port="$(published_port CONTROL_PLANE_PUBLISH 8080)"
  gw_port="$(published_port GATEWAY_PUBLISH 8090)"
  echo "waiting for http://127.0.0.1:${cp_port}/readyz and :${gw_port}/readyz"
  for ((i = 1; i <= 60; i++)); do
    if curl -fsS "http://127.0.0.1:${cp_port}/readyz" >/dev/null 2>&1 \
      && curl -fsS "http://127.0.0.1:${gw_port}/readyz" >/dev/null 2>&1; then
      echo "ready: control-plane :${cp_port}  gateway :${gw_port}"
      if git -C "${REPO_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "git: $(git -C "${REPO_DIR}" log -1 --oneline)"
      fi
      return 0
    fi
    sleep 2
  done
  echo "readyz still failing after ~120s; last logs:" >&2
  compose logs --tail=40 >&2 || true
  die "services did not become ready"
}

cmd_update() {
  need_compose
  need_env
  git_update
  compose build
  compose up -d --remove-orphans
  wait_ready
}

main() {
  local cmd="${1:-}"
  if [[ $# -gt 0 ]]; then
    shift
  fi
  case "${cmd}" in
    status) cmd_status ;;
    logs) cmd_logs "$@" ;;
    down) cmd_down ;;
    up) cmd_up ;;
    restart) cmd_restart ;;
    build) cmd_build ;;
    update) cmd_update ;;
    -h|--help|help) usage ;;
    '') usage; exit 1 ;;
    *) usage >&2; die "unknown command: ${cmd}" ;;
  esac
}

main "$@"
