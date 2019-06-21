#!/bin/bash
set -euo pipefail

usage() {
  cat >&2 <<EOM
usage: $(basename "$0") {start|stop|status} [PIDFILE]

Init script for IdP background job runner.

PIDFILE: if provided, fork to run in background (allowing stop/status as well)
EOM
}

run() {
  echo >&2 "+ $*"
  "$@"
}

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  usage
  exit 1
fi

PIDFILE=
if [ $# -ge 2 ]; then
  PIDFILE="$2"
fi

case $1 in
  start)
    # If PIDFILE is given, fork into background
    if [ -n "$PIDFILE" ]; then
      run rbenv exec bundle exec rake "job_runs:run[$PIDFILE]" &
      # save last process pid to the pidfile
      echo "$!" > "$PIDFILE"
    else
      run rbenv exec bundle exec rake job_runs:run
    fi
    ;;
  stop)
    pid="$(run cat "$PIDFILE")"
    run kill -2 "$pid"
    ;;
  status)
    pid="$(run cat "$PIDFILE")"
    run ps -fp "$pid"
    ;;
  *)
    usage
    ;;
esac

