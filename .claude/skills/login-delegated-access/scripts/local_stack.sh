#!/usr/bin/env bash
# Start, stop and inspect the local delegated-access stack: the identity-idp server (:3000) with
# its good_job worker, the service provider (:9292), the OIDC agency (:9393) and the SAML agency
# (:4567). See references/local-runbook.md.
#
#   local_stack.sh up      start everything this script is not already running
#   local_stack.sh down    stop only the processes this script started (PID files)
#   local_stack.sh status  ports, listener PIDs, recorded PIDs
#   local_stack.sh check   curl discovery, config.json and the three roots
#
# Worktree paths (override with environment variables):
#   IDP_DIR          identity-idp worktree to serve from; default: the repository this skill is in
#   SP_DIR           identity-sts-sinatra;  default ~/coding/worktrees/identity-sts-sinatra-public-client
#   OIDC_AGENCY_DIR  identity-oidc-sinatra; default ~/coding/worktrees/identity-oidc-sinatra-sts
#   SAML_AGENCY_DIR  identity-saml-sinatra; default ~/coding/worktrees/identity-saml-sinatra-sts
#   START_GOOD_JOB   "false" to skip the good_job worker (default "true")
#
# The script never seeds, never runs git, never copies files, never modifies tracked files and
# never signals a process it did not start. State lives in tmp/local_stack/ of the skill's
# repository (PID and log files).
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../../../.." && pwd)
STATE_DIR="$REPO_ROOT/tmp/local_stack"

IDP_DIR=${IDP_DIR:-$REPO_ROOT}
SP_DIR=${SP_DIR:-$HOME/coding/worktrees/identity-sts-sinatra-public-client}
OIDC_AGENCY_DIR=${OIDC_AGENCY_DIR:-$HOME/coding/worktrees/identity-oidc-sinatra-sts}
SAML_AGENCY_DIR=${SAML_AGENCY_DIR:-$HOME/coding/worktrees/identity-saml-sinatra-sts}
START_GOOD_JOB=${START_GOOD_JOB:-true}

# name|port|directory ; the good_job worker has no port.
SERVICES=(
  "idp|3000|$IDP_DIR"
  "sp|9292|$SP_DIR"
  "oidc-agency|9393|$OIDC_AGENCY_DIR"
  "saml-agency|4567|$SAML_AGENCY_DIR"
)

say() { printf '%s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# PID of the process listening on a TCP port, or empty.
listener_pid() {
  lsof -nP -iTCP:"$1" -sTCP:LISTEN -t 2>/dev/null | head -n 1 || true
}

describe_pid() {
  ps -o pid=,command= -p "$1" 2>/dev/null | sed 's/^ *//' || true
}

pid_alive() {
  [ -n "$1" ] && kill -0 "$1" 2>/dev/null
}

recorded_pid() {
  local f="$STATE_DIR/$1.pid"
  [ -r "$f" ] && cat "$f" || true
}

check_dir() {
  [ -d "$2" ] || die "$1 worktree not found at $2 (set ${3} to the right path)"
}

# Prerequisite checks: print instructions, change nothing.
check_prerequisites() {
  local ok=true
  check_dir "identity-idp" "$IDP_DIR" IDP_DIR
  check_dir "service provider" "$SP_DIR" SP_DIR
  check_dir "OIDC agency" "$OIDC_AGENCY_DIR" OIDC_AGENCY_DIR
  check_dir "SAML agency" "$SAML_AGENCY_DIR" SAML_AGENCY_DIR

  if [ ! -r "$IDP_DIR/config/application.yml" ]; then
    warn "identity-idp: config/application.yml missing; copy it from a sibling worktree (runbook)."
    ok=false
  elif ! grep -Eq '^[[:space:]]*token_exchange_enabled:[[:space:]]*true' "$IDP_DIR/config/application.yml"; then
    warn "identity-idp: config/application.yml does not set token_exchange_enabled: true; discovery will advertise nothing."
  fi
  if [ ! -e "$IDP_DIR/config/delegated_access.yml" ]; then
    warn "identity-idp: config/delegated_access.yml missing; run bin/setup or link config/delegated_access.localdev.yml to it, then rake delegated_access:seed."
  fi
  if [ ! -r "$IDP_DIR/certs/sp/rs_records_demo.crt" ]; then
    warn "identity-idp: certs/sp/rs_records_demo.crt missing; copy the OIDC agency's config/rs_demo.crt there (certs must be a real directory, not the certs.example link) and rake delegated_access:seed, or the records API answers 503."
  fi
  if [ ! -d "$IDP_DIR/tmp/pids" ]; then
    warn "identity-idp: tmp/pids missing; mkdir -p $IDP_DIR/tmp/pids before starting puma."
  fi
  local entry name port dir
  for entry in "${SERVICES[@]}"; do
    IFS='|' read -r name port dir <<<"$entry"
    [ "$name" = idp ] && continue
    [ -r "$dir/.env" ] || warn "$name: $dir/.env missing; run make setup there (copies .env.example)."
    [ -d "$dir/public/vendor/identity-design-system" ] || warn "$name: design-system assets missing; run make copy_vendor in $dir or pages render unstyled."
    [ -d "$dir/node_modules" ] || warn "$name: node_modules missing; run make setup in $dir."
  done
  [ "$ok" = true ] || die "fix the items above, then rerun up"
}

start_one() {
  local name=$1 dir=$2 log="$STATE_DIR/$1.log" pidfile="$STATE_DIR/$1.pid"
  shift 2
  say "starting $name in $dir"
  say "  $*"
  say "  log: $log"
  (cd "$dir" && nohup "$@" >>"$log" 2>&1 &
   echo $! >"$pidfile")
  say "  pid: $(cat "$pidfile")"
}

cmd_up() {
  mkdir -p "$STATE_DIR"
  check_prerequisites

  local entry name port dir busy=false
  for entry in "${SERVICES[@]}"; do
    IFS='|' read -r name port dir <<<"$entry"
    local lp; lp=$(listener_pid "$port")
    if [ -n "$lp" ]; then
      if [ "$lp" = "$(recorded_pid "$name")" ]; then
        say "$name: already running on :$port (pid $lp, started by this script)"
      else
        warn "$name: port $port is busy and not ours: $(describe_pid "$lp")"
        busy=true
      fi
    fi
  done
  [ "$busy" = false ] || die "refusing to start while a port is owned by another process; stop it yourself if it is yours, then rerun"

  for entry in "${SERVICES[@]}"; do
    IFS='|' read -r name port dir <<<"$entry"
    [ -z "$(listener_pid "$port")" ] || continue
    if [ "$name" = idp ]; then
      LAUNCHY_DRY_RUN=true start_one idp "$dir" bundle exec rackup config.ru --port 3000 --host localhost
    else
      start_one "$name" "$dir" bundle exec rackup -p "$port" --host localhost
    fi
  done

  if [ "$START_GOOD_JOB" = true ]; then
    local gj; gj=$(recorded_pid idp-jobs)
    if pid_alive "$gj"; then
      say "idp-jobs: already running (pid $gj)"
    else
      start_one idp-jobs "$IDP_DIR" bundle exec good_job start
    fi
  fi
  say "started; run '$0 status' and '$0 check' once the servers are listening."
}

cmd_down() {
  local f name pid
  [ -d "$STATE_DIR" ] || { say "nothing recorded in $STATE_DIR"; return 0; }
  for f in "$STATE_DIR"/*.pid; do
    [ -e "$f" ] || continue
    name=$(basename "$f" .pid)
    pid=$(cat "$f")
    if pid_alive "$pid"; then
      say "stopping $name (pid $pid): $(describe_pid "$pid")"
      kill -TERM "$pid" 2>/dev/null || true
      local i
      for i in 1 2 3 4 5 6 7 8 9 10; do
        pid_alive "$pid" || break
        sleep 1
      done
      if pid_alive "$pid"; then
        warn "$name (pid $pid) still running after 10s; not forcing. Inspect it yourself."
        continue
      fi
    else
      say "$name: recorded pid $pid is not running"
    fi
    rm -f "$f"
  done
}

cmd_status() {
  local entry name port dir lp rp
  printf '%-12s %-6s %-9s %-9s %s\n' service port listener recorded owner
  for entry in "${SERVICES[@]}"; do
    IFS='|' read -r name port dir <<<"$entry"
    lp=$(listener_pid "$port"); rp=$(recorded_pid "$name")
    local owner="down"
    if [ -n "$lp" ]; then
      if [ "$lp" = "$rp" ]; then owner="ours: $(describe_pid "$lp")"; else owner="not ours: $(describe_pid "$lp")"; fi
    fi
    printf '%-12s %-6s %-9s %-9s %s\n' "$name" "$port" "${lp:--}" "${rp:--}" "$owner"
  done
  rp=$(recorded_pid idp-jobs)
  if [ -n "$rp" ]; then
    if pid_alive "$rp"; then printf '%-12s %-6s %-9s %-9s %s\n' idp-jobs - "$rp" "$rp" "ours: $(describe_pid "$rp")"
    else printf '%-12s %-6s %-9s %-9s %s\n' idp-jobs - - "$rp" "recorded pid not running"; fi
  fi
  say "state: $STATE_DIR"
}

http_code() {
  curl -s -o /dev/null -m 10 -w '%{http_code}' "$1" || echo "000"
}

cmd_check() {
  local disc url code
  say "discovery: http://localhost:3000/.well-known/openid-configuration"
  disc=$(curl -s -m 10 http://localhost:3000/.well-known/openid-configuration || true)
  if [ -z "$disc" ]; then
    say "  unreachable"
  else
    local item
    for item in 'urn:ietf:params:oauth:grant-type:token-exchange' refresh_token introspection_endpoint revocation_endpoint; do
      if printf '%s' "$disc" | grep -q "\"$item\"\|$item\""; then say "  present: $item"; else say "  MISSING: $item (token_exchange_enabled off?)"; fi
    done
  fi
  for url in http://localhost:9292/ http://localhost:9292/config.json http://localhost:9393/ http://localhost:9393/api/health http://localhost:4567/; do
    code=$(http_code "$url")
    say "$code  $url"
  done
  local cfg
  cfg=$(curl -s -m 10 http://localhost:9292/config.json || true)
  if [ -n "$cfg" ]; then
    say "config.json hosts:"
    printf '%s' "$cfg" | grep -o '"\(idp_url\|redirect_uri\|url\)":"[^"]*"' | sed 's/^/  /'
  fi
}

case "${1:-}" in
  up) cmd_up ;;
  down) cmd_down ;;
  status) cmd_status ;;
  check) cmd_check ;;
  *) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
