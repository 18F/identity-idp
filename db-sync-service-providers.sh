#!/bin/bash
set -euox pipefail

CLOUD_RUN_TASK_INDEX=${CLOUD_RUN_TASK_INDEX:=0}
CLOUD_RUN_TASK_ATTEMPT=${CLOUD_RUN_TASK_ATTEMPT:=0}

echo "Starting Task #${CLOUD_RUN_TASK_INDEX}, Attempt #${CLOUD_RUN_TASK_ATTEMPT}..."

id
which bundle

echo "running db-sync-service-providers tasks"

export RAILS_ENV=development

bundle exec rake service_providers:sync

set +x

echo "db-sync-service-providers tasks finished"