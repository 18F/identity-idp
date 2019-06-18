#!/bin/bash

# RAILS_ENV param, default to production
RAILS_ENV=${2:-production}

case $1 in
   start)
      RAILS_ENV=$RAILS_ENV rbenv exec bundle exec rake job_runs:run
      ;;
    stop)
      kill `cat tmp/job_runs-0.pid`
      ;;
    *)
      echo "usage: job_runs {start|stop}" ;;
esac