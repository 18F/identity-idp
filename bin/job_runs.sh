#!/bin/bash
set -euo pipefail

usage() {
  cat >&2 <<EOM
usage: $(basename "$0") {start|stop|status} [PIDFILE]

Init script for IdP background job runner.

PIDFILE: defaults to $PIDFILE
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
    if [ -n "$PIDFILE" ]; then
      exec rbenv exec bundle exec rake "job_runs:run[$PIDFILE]"
    else
      exec rbenv exec bundle exec rake job_runs:run
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

