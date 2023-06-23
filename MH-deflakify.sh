#!/usr/bin/env bash
# Usage: script RUNS COMMAND ["string signifying a real failure"]
# Execute COMMAND RUNS times, track outputs and success rates.

set -euo pipefail

LOG_DIR=${LOG_DIR:-.deflakify}
RUN_ID="run_$(date "+%Y%m%d-%H%M%S")"
RUN_DIR="${LOG_DIR}/${RUN_ID}"

mkdir -p "$RUN_DIR"

RUNS=$1; shift
COMMAND=$1; shift
STRING_THAT_MEANS_FAILURE=${1:-}; shift

ITERATION=0
SUCCESSES=0
FAILURES=0
REAL_FAILURES=0

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
        FAILURES=$(($FAILURES + 1))

        if grep "$STRING_THAT_MEANS_FAILURE" "$OUT_FILE" "$ERR_FILE" > /dev/null 2>&1; then
            echo "Result:      ❌ Failure"
            REAL_FAILURES=$(($REAL_FAILURES + 1))
        else
            echo "Result:      🤔 Failure, but ignoring"
        fi
    fi

    echo "Finished at: $(date '+%Y-%m-%d %H:%M:%S')"

    SUCCESS_PCT=$((($SUCCESSES * 100) / $ITERATION))
    FAILURE_PCT=$((($FAILURES * 100) / $ITERATION))
    REAL_FAILURE_PCT=$((($REAL_FAILURES * 100) / $ITERATION))

    echo ""
    echo "Successes:        $SUCCESSES (${SUCCESS_PCT}%)"
    echo "Failures (soft):  $FAILURES (${FAILURE_PCT}%)"
    echo "Failures (hard):  $REAL_FAILURES (${REAL_FAILURE_PCT}%)"
    
    if [[ "$ITERATION" == "$RUNS" ]]; then
        if [[ "$REAL_FAILURES" -gt 0 ]]; then
            exit 1 # Tell git bisect something broke
        elif [[ "$FAILURES" -g 0 ]]; then
            exit 125 # Tell git bisect we couldn't figure it out
        fi
    fi

done    