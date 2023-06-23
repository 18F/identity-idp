#!/usr/bin/env bash
# Usage: script RUNS COMMAND
# Execute COMMAND RUNS times, track outputs and success rates.

set -euo pipefail

LOG_DIR=${LOG_DIR:-.deflakify}
RUN_ID="run_$(date "+%Y%m%d-%H%M%S")"
RUN_DIR="${LOG_DIR}/${RUN_ID}"

mkdir -p "$RUN_DIR"

RUNS=$1; shift
COMMAND=$1; shift

ITERATION=0
SUCCESSES=0
FAILURES=0

while (true)
do
    ITERATION=$(($ITERATION+1))
    OUT_FILE="$RUN_DIR/$ITERATION.out.txt"
    ERR_FILE="$RUN_DIR/$ITERATION.err.txt"

    STARTED_AT=$(date '+%Y-%m-%d %H:%M:%S')

    echo ""

    echo "
Iteration:   ${ITERATION}
Command:     $COMMAND
Started at:  $STARTED_AT" | tee "$OUT_FILE" "$ERR_FILE"

    if sh -c "$COMMAND" >> "$OUT_FILE"  2>> "$ERR_FILE"; then
        echo "Result:      ✅ Success"
        SUCCESSES=$(($SUCCESSES + 1))
    else
        echo "Result:      ❌ Failure"
        FAILURES=$(($FAILURES + 1))

        cat "$ERR_FILE"
    fi

    echo "Finished at: $(date '+%Y-%m-%d %H:%M:%S')"

    SUCCESS_RATE=$(($SUCCESSES / $ITERATION))
    FAILURE_RATE=$(($FAILURES / $ITERATION))

    echo ""
    echo "Successes:    $SUCCESSES ($(($SUCCESS_RATE * 100))%)"
    echo "Failures:     $FAILURES ($(($FAILURE_RATE * 100))%)"
    
    if [[ "$ITERATION" == "$RUNS" ]]; then
        exit
    fi

done    