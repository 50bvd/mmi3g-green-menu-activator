#!/usr/bin/env bash
# Runs sdcard/run.sh against fake MMI databases on a PC.
#
# The MMI's file system is simulated in a temporary directory (GEM_SYSROOT),
# the host sqlite3 replaces the QNX one, showScreen and mount are stubs.
# The script runs under mksh, the closest shell to the QNX 6 Korn shell.
#
# Usage: tests/run_test.sh            (needs mksh and sqlite3)
#        SHELL_UNDER_TEST=ksh tests/run_test.sh
#
# Assertions are strings evaluated by check(), hence the single quotes.
# shellcheck disable=SC2016,SC2034,SC2119,SC2120

set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SH=${SHELL_UNDER_TEST:-mksh}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

for tool in "$SH" sqlite3; do
    command -v "$tool" >/dev/null || { echo "missing: $tool"; exit 2; }
done

PASS=0
FAIL=0
ok()   { PASS=$((PASS + 1)); echo "  ok   $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL $1"; }
check() { if eval "$2"; then ok "$1"; else fail "$1"; fi; }

# --- Fixtures ----------------------------------------------------------------
# Like a production MMI: the Green Menu record exists with value 0.
# pst_note is an extra column: the script must keep every column as it is.
SCHEMA='CREATE TABLE tb_intvalues (pst_namespace INTEGER, pst_key INTEGER, pst_value INTEGER, pst_note TEXT);
INSERT INTO tb_intvalues VALUES (4, 1, 7, NULL);
INSERT INTO tb_intvalues VALUES (1, 4100, 3, NULL);'
RECORD="INSERT INTO tb_intvalues VALUES (4, 4100, 0, 'keep');"

# new_case <name>: fresh SD card + MMI file system, sets CARD and SYS
new_case() {
    CARD=$WORK/$1/sdcard
    SYS=$WORK/$1/mmi
    mkdir -p "$CARD" "$SYS/bin" "$SYS/mnt/efs-persist" "$SYS/HBpersistence" \
             "$SYS/mnt/hmisql" "$SYS/dev/shmem"
    cp -R "$ROOT/sdcard/." "$CARD/"
    echo "HNav_EU_K0942_4" > "$SYS/dev/shmem/sw_trainname.txt"
    # stubs: record what was shown / mounted
    printf '#!/bin/sh\necho "$1" >> "%s/screens.txt"\n' "$SYS" > "$SYS/bin/showScreen"
    printf '#!/bin/sh\necho "$*" >> "%s/mount.txt"\n' "$SYS" > "$SYS/bin/mount"
    chmod +x "$SYS/bin/showScreen" "$SYS/bin/mount"
}

# make_db <path> [SQL]: database with the Green Menu record (value 0), or
# with the SQL given instead of the record
make_db() {
    sqlite3 "$1" "$SCHEMA ${2-$RECORD}"
}

run() {
    (cd "$CARD" && PATH="$SYS/bin:$PATH" GEM_SYSROOT="$SYS" \
        GEM_SQLITE="$(command -v sqlite3)" GEM_SHOWSCREEN="$SYS/bin/showScreen" \
        "$SH" ./run.sh "$@")
    STATUS=$?
}

gem() {
    sqlite3 "$1" "SELECT group_concat(pst_value) FROM tb_intvalues WHERE pst_namespace=4 AND pst_key=4100;"
}

note() {
    sqlite3 "$1" "SELECT group_concat(pst_note) FROM tb_intvalues WHERE pst_namespace=4 AND pst_key=4100;"
}

others() {
    sqlite3 "$1" "SELECT group_concat(pst_namespace||':'||pst_key||'='||pst_value) FROM tb_intvalues WHERE NOT (pst_namespace=4 AND pst_key=4100);"
}

last_screen() { tail -n 1 "$SYS/screens.txt" 2>/dev/null | sed 's#.*/##'; }
logfile() { cat "$CARD/green_menu_activator.log"; }

DBS="mnt/efs-persist mnt/hmisql"

# --- Cases -------------------------------------------------------------------
echo "1. production MMI: record present with value 0"
new_case fresh
for d in $DBS HBpersistence; do make_db "$SYS/$d/DataPST.db"; done
hb_sum=$(cksum < "$SYS/HBpersistence/DataPST.db")
run
check "exit code 0" '[ "$STATUS" -eq 0 ]'
for d in $DBS; do
    check "$d: flag = 1" '[ "$(gem "$SYS/$d/DataPST.db")" = "1" ]'
    check "$d: other columns kept" '[ "$(note "$SYS/$d/DataPST.db")" = "keep" ]'
    check "$d: other rows kept" '[ "$(others "$SYS/$d/DataPST.db")" = "4:1=7,1:4100=3" ]'
done
check "HBpersistence never touched" '[ "$(cksum < "$SYS/HBpersistence/DataPST.db")" = "$hb_sum" ] && [ ! -d "$CARD/backup/HBpersistence" ]'
check "start screen shown first" '[ "$(head -n 1 "$SYS/screens.txt" | sed "s#.*/##")" = "scriptStart.png" ]'
check "done screen shown last" '[ "$(last_screen)" = "scriptDone.png" ]'
check "efs-persist remounted read/write" 'grep -q -- "-uw $SYS/mnt/efs-persist" "$SYS/mount.txt"'
for n in efs-persist hmisql; do
    check "$n: original backup" '[ -f "$CARD/backup/$n/DataPST.db.orig" ]'
    check "$n: backup has the old value" '[ "$(gem "$CARD/backup/$n/DataPST.db.orig")" = "0" ]'
done
check "log says OK" 'logfile | grep -q "^RESULT: OK"'
check "log has firmware" 'logfile | grep -q "HNav_EU_K0942_4"'

echo "2. second run on the same car"
orig_sum=$(cksum < "$CARD/backup/efs-persist/DataPST.db.orig")
backups_before=$(find "$CARD/backup/efs-persist" -type f | wc -l)
run
check "exit code 0" '[ "$STATUS" -eq 0 ]'
check "log says already set" 'logfile | grep -q "already set"'
check ".orig backup unchanged" '[ "$(cksum < "$CARD/backup/efs-persist/DataPST.db.orig")" = "$orig_sum" ]'
check "no new backup when nothing changes" '[ "$(find "$CARD/backup/efs-persist" -type f | wc -l)" = "$backups_before" ]'

echo "3. duplicate rows, one database missing"
new_case duplicates
make_db "$SYS/mnt/efs-persist/DataPST.db" "$RECORD $RECORD"
run
check "exit code 0" '[ "$STATUS" -eq 0 ]'
check "both rows = 1, none added or removed" '[ "$(gem "$SYS/mnt/efs-persist/DataPST.db")" = "1,1" ]'
check "missing database not created" '[ ! -e "$SYS/mnt/hmisql/DataPST.db" ]'
check "log says skipped" '[ "$(logfile | grep -c "not present")" = "1" ]'

echo "4. record missing: nothing is invented"
new_case norecord
make_db "$SYS/mnt/efs-persist/DataPST.db" ""
sum=$(cksum < "$SYS/mnt/efs-persist/DataPST.db")
run
check "exit code 1" '[ "$STATUS" -eq 1 ]'
check "error screen" '[ "$(last_screen)" = "scriptError.png" ]'
check "database unchanged" '[ "$(cksum < "$SYS/mnt/efs-persist/DataPST.db")" = "$sum" ]'
check "log explains" 'logfile | grep -q "no Green Menu record"'

echo "5. database without the table"
new_case notable
make_db "$SYS/mnt/efs-persist/DataPST.db"
sqlite3 "$SYS/mnt/hmisql/DataPST.db" "CREATE TABLE other (x);"
run
check "exit code 1" '[ "$STATUS" -eq 1 ]'
check "error screen" '[ "$(last_screen)" = "scriptError.png" ]'
check "good database still changed" '[ "$(gem "$SYS/mnt/efs-persist/DataPST.db")" = "1" ]'
check "bad database untouched" '[ "$(sqlite3 "$SYS/mnt/hmisql/DataPST.db" "SELECT count(*) FROM sqlite_master WHERE name=\"tb_intvalues\";")" = "0" ]'
check "log says FAILED" 'logfile | grep -q "^RESULT: FAILED"'

echo "6. no database at all"
new_case nodb
run
check "exit code 1" '[ "$STATUS" -eq 1 ]'
check "error screen" '[ "$(last_screen)" = "scriptError.png" ]'
check "nothing created" '[ -z "$(find "$SYS/mnt" "$SYS/HBpersistence" -name "DataPST.db*")" ]'

echo "7. DRYRUN: everything checked, nothing changed"
new_case dryrun
for d in $DBS; do make_db "$SYS/$d/DataPST.db"; done
sums=$(cat "$SYS/mnt/efs-persist/DataPST.db" "$SYS/mnt/hmisql/DataPST.db" | cksum)
: > "$CARD/DRYRUN"
run
check "exit code 0" '[ "$STATUS" -eq 0 ]'
check "databases unchanged" '[ "$(cat "$SYS/mnt/efs-persist/DataPST.db" "$SYS/mnt/hmisql/DataPST.db" | cksum)" = "$sums" ]'
check "no remount" '[ ! -f "$SYS/mount.txt" ]'
check "backups still written and checked" '[ "$(gem "$CARD/backup/efs-persist/DataPST.db.orig")" = "0" ] && [ -f "$CARD/backup/hmisql/DataPST.db.orig" ]'
check "log says what would change" '[ "$(logfile | grep -c "would set value=1")" = "2" ]'
check "log says DRYRUN" 'logfile | grep -q "^RESULT: DRYRUN"'
check "test screen shown" '[ "$(last_screen)" = "scriptDryRun.png" ]'
rm "$CARD/DRYRUN"
run
check "then without DRYRUN: applied" '[ "$STATUS" -eq 0 ] && [ "$(gem "$SYS/mnt/efs-persist/DataPST.db")" = "1" ]'

echo "7b. DRYRUN.txt works too"
new_case dryruntxt
make_db "$SYS/mnt/hmisql/DataPST.db"
: > "$CARD/DRYRUN.txt"
run
check "flag still 0" '[ "$(gem "$SYS/mnt/hmisql/DataPST.db")" = "0" ]'

echo "8. DISABLE file switches the menu off"
new_case disable
make_db "$SYS/mnt/hmisql/DataPST.db" "INSERT INTO tb_intvalues VALUES (4, 4100, 1, 'keep');"
: > "$CARD/DISABLE"
run
check "exit code 0" '[ "$STATUS" -eq 0 ]'
check "flag = 0" '[ "$(gem "$SYS/mnt/hmisql/DataPST.db")" = "0" ]'
check "backup has the old value" '[ "$(gem "$CARD/backup/hmisql/DataPST.db.orig")" = "1" ]'

echo "8b. DISABLE.txt (Windows adds the extension) works too"
new_case disabletxt
make_db "$SYS/mnt/hmisql/DataPST.db" "INSERT INTO tb_intvalues VALUES (4, 4100, 1, 'keep');"
: > "$CARD/DISABLE.txt"
run
check "exit code 0" '[ "$STATUS" -eq 0 ]'
check "flag = 0" '[ "$(gem "$SYS/mnt/hmisql/DataPST.db")" = "0" ]'

echo "9. locked database (MMI writing)"
new_case locked
make_db "$SYS/mnt/efs-persist/DataPST.db"
# hold an exclusive lock for longer than the three attempts
(sqlite3 "$SYS/mnt/efs-persist/DataPST.db" "BEGIN EXCLUSIVE; SELECT 1;" ".shell sleep 10" "COMMIT;" >/dev/null 2>&1) &
LOCKER=$!
sleep 1
run
kill "$LOCKER" 2>/dev/null; wait "$LOCKER" 2>/dev/null
check "exit code 1" '[ "$STATUS" -eq 1 ]'
check "error screen" '[ "$(last_screen)" = "scriptError.png" ]'
check "database unchanged" '[ "$(gem "$SYS/mnt/efs-persist/DataPST.db")" = "0" ]'
check "three attempts made" '[ "$(logfile | grep -c "attempt .* failed")" = "3" ]'

echo "9b. short lock, released while the script waits"
new_case shortlock
make_db "$SYS/mnt/efs-persist/DataPST.db"
(sqlite3 "$SYS/mnt/efs-persist/DataPST.db" "BEGIN EXCLUSIVE; SELECT 1;" ".shell sleep 3" "COMMIT;" >/dev/null 2>&1) &
LOCKER=$!
sleep 1
run
wait "$LOCKER" 2>/dev/null
check "exit code 0" '[ "$STATUS" -eq 0 ]'
check "retried" 'logfile | grep -q "attempt 1 failed"'
check "flag = 1" '[ "$(gem "$SYS/mnt/efs-persist/DataPST.db")" = "1" ]'

echo "10. SD card path given as argument (from another directory)"
new_case argpath
make_db "$SYS/mnt/efs-persist/DataPST.db"
(cd "$WORK" && PATH="$SYS/bin:$PATH" GEM_SYSROOT="$SYS" GEM_SQLITE="$(command -v sqlite3)" \
    GEM_SHOWSCREEN="$SYS/bin/showScreen" "$SH" "$CARD/run.sh" "$CARD")
STATUS=$?
check "exit code 0" '[ "$STATUS" -eq 0 ]'
check "log written on the card" 'logfile | grep -q "SD card : $CARD"'

echo "11. sqlite3 missing from the card"
new_case nosqlite
make_db "$SYS/mnt/efs-persist/DataPST.db"
(cd "$CARD" && PATH="$SYS/bin:$PATH" GEM_SYSROOT="$SYS" GEM_SQLITE="$CARD/utils/nope" \
    GEM_SHOWSCREEN="$SYS/bin/showScreen" "$SH" ./run.sh)
STATUS=$?
check "exit code 1" '[ "$STATUS" -eq 1 ]'
check "start screen never shown" '! grep -q scriptStart "$SYS/screens.txt"'
check "database unchanged" '[ "$(gem "$SYS/mnt/efs-persist/DataPST.db")" = "0" ]'

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
