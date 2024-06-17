#!/bin/bash
set -euox pipefail

CLOUD_RUN_TASK_INDEX=${CLOUD_RUN_TASK_INDEX:=0}
CLOUD_RUN_TASK_ATTEMPT=${CLOUD_RUN_TASK_ATTEMPT:=0}

echo "Starting Task #${CLOUD_RUN_TASK_INDEX}, Attempt #${CLOUD_RUN_TASK_ATTEMPT}..."

id
which bundle

echo "running db-init tasks"

export RAILS_ENV=development

bundle exec rake db:create 
bundle exec rake db:environment:set 
bundle exec rake db:reset 
bundle exec rake db:environment:set 
bundle exec rake dev:prime

set +x

echo "db-init tasks finished"