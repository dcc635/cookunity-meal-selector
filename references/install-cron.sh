#!/usr/bin/env bash
# Register the weekly CookUnity order as an OpenClaw cron job.
#
#   bash references/install-cron.sh
#
# Edit the block below to match references/config.md, then run it. Idempotent-ish:
# `openclaw cron add` creates a new job each time, so remove the old one first if
# you re-run (see the bottom of this file).

set -euo pipefail

# ---- match references/config.md -------------------------------------------------
JOB_NAME="cookunity-weekly-order"
SCHEDULE="0 12 * * 5"            # Friday 12:00 PM
TIMEZONE="America/Los_Angeles"
TIMEOUT_SECONDS=1200             # 20 minutes — browser automation is slow
CHANNEL="telegram"               # set to "" to skip fallback delivery
TARGET=""                        # your chat id; leave "" to skip fallback delivery
# --------------------------------------------------------------------------------

MESSAGE="Run the weekly CookUnity order. Use the cookunity-meal-selector skill and follow references/weekly-order.md end to end, reading references/config.md for all settings. Confirm the order — do not stop at the summary page."

args=(
  cron add
  --name "$JOB_NAME"
  --cron "$SCHEDULE"
  --tz "$TIMEZONE"
  --message "$MESSAGE"
  --timeout-seconds "$TIMEOUT_SECONDS"
  --session isolated
)

# Fallback delivery: if the run dies before Step 8 sends its own notification,
# OpenClaw still pushes the final text to this chat.
if [[ -n "$TARGET" && -n "$CHANNEL" ]]; then
  args+=(--announce --channel "$CHANNEL" --to "$TARGET" --best-effort-deliver)
fi

openclaw "${args[@]}"

cat <<'EOF'

Registered. Useful follow-ups:

  openclaw cron list                     # confirm it's there and see the next run time
  openclaw cron run <job-id>             # trigger a real order right now (it will confirm!)
  openclaw cron runs <job-id>            # run history
  openclaw cron disable <job-id>         # pause without deleting
  openclaw cron rm <job-id>              # remove, e.g. before re-running this script

`cron run` places a real order. Use `openclaw cron show <job-id>` if you only want to
inspect the definition.
EOF
