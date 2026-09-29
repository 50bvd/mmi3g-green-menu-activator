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
# shellcheck disable=SC2016,SC2034

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
SCHEMA='CREATE TABLE tb_intvalues (pst_namespace INTEGER, pst_key INTEGER, pst_value INTEGER);
INSERT INTO tb_intvalues VALUES (4, 1, 7);
INSERT INTO tb_intvalues VALUES (1, 4100, 3);'

# new_case <name>: fresh SD card + MMI file system, sets CARD and SYS
new_case() {
    CARD=$WORK/$1/sdcard
    SYS=$WORK/$1/mmi
    mkdir -p "$CARD" "$SYS/bin" "$SYS/mnt/efs-persist" "$SYS/HBpersistence" \
             "$SYS/mnt/hmisql" "$SYS/dev/shmem"
    cp -R "$ROOT/sdcard/." "$CARD/"
    echo "HN+_EU_AU_K0942_4" > "$SYS/dev/shmem/sw_trainname.txt"
    # stubs: record what was shown / mounted
    printf '#!/bin/sh\necho "$1" >> "%s/screens.txt"\n' "$SYS" > "$SYS/bin/showScreen"
    printf '#!/bin/sh\necho "$*" >> "%s/mount.txt"\n' "$SYS" > "$SYS/bin/mount"
    chmod +x "$SYS/bin/showScreen" "$SYS/bin/mount"
}

# make_db <path> [extra SQL]
make_db() {
    sqlite3 "$1" "$SCHEMA ${2:-}"
}

run() {
    (cd "$CARD" && PATH="$SYS/bin:$PATH" GEM_SYSROOT="$SYS" \
        GEM_SQLITE="$(command -v sqlite3)" GEM_SHOWSCREEN="$SYS/bin/showScreen" \
        "$SH" ./run.sh)
    STATUS=$?
}

gem() {
    sqlite3 "$1" "SELECT group_concat(pst_value) FROM tb_intvalues WHERE pst_namespace=4 AND pst_key=4100;"
}

others() {
    sqlite3 "$1" "SELECT group_concat(pst_namespace||':'||pst_key||'='||pst_value) FROM tb_intvalues WHERE NOT (pst_namespace=4 AND pst_key=4100);"
}

last_screen() { tail -n 1 "$SYS/screens.txt" 2>/dev/null | sed 's#.*/##'; }

DBS="mnt/efs-persist HBpersistence mnt/hmisql"

# --- Cases -------------------------------------------------------------------
echo "1. three databases, flag missing"
new_case fresh
for d in $DBS; do make_db "$SYS/$d/DataPST.db"; done
run
check "exit code 0" '[ "$STATUS" -eq 0 ]'
for d in $DBS; do
    check "$d: flag = 1" '[ "$(gem "$SYS/$d/DataPST.db")" = "1" ]'
    check "$d: other rows kept" '[ "$(others "$SYS/$d/DataPST.db")" = "4:1=7,1:4100=3" ]'
done
check "start screen shown first" '[ "$(head -n 1 "$SYS/screens.txt" | sed "s#.*/##")" = "scriptStart.png" ]'
check "done screen shown last" '[ "$(last_screen)" = "scriptDone.png" ]'
check "efs-persist remounted read/write" 'grep -q -- "-uw $SYS/mnt/efs-persist" "$SYS/mount.txt"'
for n in efs-persist HBpersistence hmisql; do
    check "$n: original backup" '[ -f "$CARD/backup/$n/DataPST.db.orig" ]'
    check "$n: backup has the old state" '[ -z "$(gem "$CARD/backup/$n/DataPST.db.orig")" ]'
done
check "log says OK" 'grep -q "^RESULT: OK" "$CARD/green_menu_activator.log"'
check "log has firmware" 'grep -q "HN+_EU_AU_K0942_4" "$CARD/green_menu_activator.log"'

echo "2. second run on the same car"
orig_sum=$(cksum < "$CARD/backup/efs-persist/DataPST.db.orig")
backups_before=$(find "$CARD/backup/efs-persist" -type f | wc -l)
run
check "exit code 0" '[ "$STATUS" -eq 0 ]'
check "log says already set" 'grep -q "already set" "$CARD/green_menu_activator.log"'
check ".orig backup unchanged" '[ "$(cksum < "$CARD/backup/efs-persist/DataPST.db.orig")" = "$orig_sum" ]'
check "no new backup when nothing changes" '[ "$(find "$CARD/backup/efs-persist" -type f | wc -l)" = "$backups_before" ]'

echo "3. duplicate and wrong rows"
new_case duplicates
make_db "$SYS/mnt/efs-persist/DataPST.db" "INSERT INTO tb_intvalues VALUES (4, 4100, 0); INSERT INTO tb_intvalues VALUES (4, 4100, 0);"
run
check "exit code 0" '[ "$STATUS" -eq 0 ]'
check "exactly one row = 1" '[ "$(gem "$SYS/mnt/efs-persist/DataPST.db")" = "1" ]'
check "missing databases are not created" '[ ! -e "$SYS/HBpersistence/DataPST.db" ] && [ ! -e "$SYS/mnt/hmisql/DataPST.db" ]'
check "log says skipped" '[ "$(grep -c "not present" "$CARD/green_menu_activator.log")" = "2" ]'

echo "4. database without the table"
new_case notable
make_db "$SYS/mnt/efs-persist/DataPST.db"
sqlite3 "$SYS/HBpersistence/DataPST.db" "CREATE TABLE other (x);"
run
check "exit code 1" '[ "$STATUS" -eq 1 ]'
check "error screen" '[ "$(last_screen)" = "scriptError.png" ]'
check "good database still changed" '[ "$(gem "$SYS/mnt/efs-persist/DataPST.db")" = "1" ]'
check "bad database untouched" '[ "$(sqlite3 "$SYS/HBpersistence/DataPST.db" "SELECT count(*) FROM sqlite_master WHERE name=\"tb_intvalues\";")" = "0" ]'
check "log says FAILED" 'grep -q "^RESULT: FAILED" "$CARD/green_menu_activator.log"'

echo "5. no database at all"
new_case nodb
run
check "exit code 1" '[ "$STATUS" -eq 1 ]'
check "error screen" '[ "$(last_screen)" = "scriptError.png" ]'
check "nothing created" '[ -z "$(find "$SYS/mnt" "$SYS/HBpersistence" -name "DataPST.db*")" ]'

echo "6. DISABLE file switches the menu off"
new_case disable
make_db "$SYS/mnt/hmisql/DataPST.db" "INSERT INTO tb_intvalues VALUES (4, 4100, 1);"
: > "$CARD/DISABLE"
run
check "exit code 0" '[ "$STATUS" -eq 0 ]'
check "flag = 0" '[ "$(gem "$SYS/mnt/hmisql/DataPST.db")" = "0" ]'
check "backup has the old value" '[ "$(gem "$CARD/backup/hmisql/DataPST.db.orig")" = "1" ]'

echo "6b. DISABLE.txt (Windows adds the extension) works too"
new_case disabletxt
make_db "$SYS/mnt/hmisql/DataPST.db" "INSERT INTO tb_intvalues VALUES (4, 4100, 1);"
: > "$CARD/DISABLE.txt"
run
check "exit code 0" '[ "$STATUS" -eq 0 ]'
check "flag = 0" '[ "$(gem "$SYS/mnt/hmisql/DataPST.db")" = "0" ]'

echo "7. locked database (MMI writing)"
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
check "database unchanged" '[ -z "$(gem "$SYS/mnt/efs-persist/DataPST.db")" ]'
check "three attempts made" '[ "$(grep -c "attempt .* failed" "$CARD/green_menu_activator.log")" = "3" ]'

echo "7b. short lock, released while the script waits"
new_case shortlock
make_db "$SYS/mnt/efs-persist/DataPST.db"
(sqlite3 "$SYS/mnt/efs-persist/DataPST.db" "BEGIN EXCLUSIVE; SELECT 1;" ".shell sleep 3" "COMMIT;" >/dev/null 2>&1) &
LOCKER=$!
sleep 1
run
wait "$LOCKER" 2>/dev/null
check "exit code 0" '[ "$STATUS" -eq 0 ]'
check "retried" 'grep -q "attempt 1 failed" "$CARD/green_menu_activator.log"'
check "flag = 1" '[ "$(gem "$SYS/mnt/efs-persist/DataPST.db")" = "1" ]'

echo "8. sqlite3 missing from the card"
new_case nosqlite
make_db "$SYS/mnt/efs-persist/DataPST.db"
(cd "$CARD" && PATH="$SYS/bin:$PATH" GEM_SYSROOT="$SYS" GEM_SQLITE="$CARD/utils/nope" \
    GEM_SHOWSCREEN="$SYS/bin/showScreen" "$SH" ./run.sh)
STATUS=$?
check "exit code 1" '[ "$STATUS" -eq 1 ]'
check "start screen never shown" '! grep -q scriptStart "$SYS/screens.txt"'
check "database unchanged" '[ -z "$(gem "$SYS/mnt/efs-persist/DataPST.db")" ]'

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
