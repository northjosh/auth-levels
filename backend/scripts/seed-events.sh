#!/usr/bin/env bash
# Seeds synthetic SecurityEvents for the DataLoader user so cursor pagination
# (and the Activity filters) can be exercised without performing real logins.
#
# Writes directly into backend/db.sqlite, matching the SecurityEvent enum
# ordinals and the epoch-ms timestamp format Hibernate uses on SQLite.
#
# Usage: scripts/seed-events.sh [N]   (default 25 events)

set -euo pipefail

DB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/db.sqlite"
COUNT="${1:-25}"

if ! command -v sqlite3 >/dev/null 2>&1; then
	echo "error: sqlite3 not found" >&2
	exit 1
fi

USER_ID=$(sqlite3 "$DB" "SELECT id FROM users WHERE email = 'test@example.com' LIMIT 1;")
if [ -z "$USER_ID" ]; then
	echo "error: no test@example.com user in $DB (run the app once so DataLoader seeds it)" >&2
	exit 1
fi

# ActivityType (0-19), Method (0-5) per SecurityEvent.java enum order.
# One entry per row; spread types/methods so filters and paging both have data.
TYPES=(0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19)
METHODS=(0 1 2 3 4 5)
OSES=("macOS" "Windows" "Linux" "iOS" "Android" "Chrome OS")
DEVICES=("Desktop" "Laptop" "Mobile" "Tablet" "Other")
ADDRS=("203.0.113.42" "198.51.100.7" "192.0.2.88" "10.0.2.15" "172.16.0.9")
UAS=("Chrome" "Firefox" "Safari" "Edge" "curl" "AuthMobile")

NOW=$(( $(date +%s) * 1000 ))
# First event 30 days ago; step so timestamps are strictly monotonic (keyset).
STEP_MS=$(( (30 * 24 * 60 * 60 * 1000) / (COUNT > 1 ? COUNT - 1 : COUNT) ))

for i in $(seq 0 $((COUNT - 1))); do
	ts=$((NOW - 30 * 24 * 60 * 60 * 1000 + i * STEP_MS))
	type=${TYPES[$((i % 20))]}
	method=${METHODS[$((i % 6))]}
	os=${OSES[$((i % 6))]}
	device=${DEVICES[$((i % 5))]}
	addr=${ADDRS[$((i % 5))]}
	ua=${UAS[$((i % 6))]}

	sqlite3 "$DB" "INSERT INTO security_event
		(id, created_at, updated_at, created_by, last_modified_by, details,
		 device_family, method, os_family, remote_address, type, user_agent_family, user_id)
		VALUES
		('$(uuidgen | tr -d '-')', $ts, $ts, 'system', 'system', '{}',
		 '$device', $method, '$os', '$addr', $type, '$ua', $USER_ID);"
done

echo "inserted $COUNT events for user $USER_ID ($(sqlite3 "$DB" 'SELECT count(*) FROM security_event;') total)"