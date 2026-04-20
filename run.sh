#!/bin/ksh
# =============================================================================
# Audi MMI 3G - Green Engineering Menu Activator
# =============================================================================
# Original method: Vlasoff / Keldo (2016)
# Improved & maintained by: 50bvd (https://github.com/50bvd)
#
# Compatible with: MMI 3G Basic (BNav_), MMI 3G High (HNav_), MMI 3G Plus (HN+_)
# Tested on: Audi A4 B8, A5 8T, Q5, A6 C6, A8 D3 (2008-2016)
#
# Usage: Copy contents of this repo root to a FAT32 SD card (8-32GB),
#        insert into MMI SD Slot 1, follow on-screen prompts, reboot MMI.
# =============================================================================

# --- Resolve SD card mount path ---
sdcard=`ls /mnt | grep sdcard.*t`
SDPath=/mnt/$sdcard

# Remount SD card read/write
mount -u $SDPath
cd $SDPath

# --- Init log file on SD card ---
LOG=$SDPath/green_menu_activator.log
echo "======================================" > $LOG
echo " MMI 3G Green Menu Activator - 50bvd" >> $LOG
echo " https://github.com/50bvd" >> $LOG
echo "======================================" >> $LOG
echo "Date  : `date`" >> $LOG
echo "SDPath: $SDPath" >> $LOG

# Read current firmware version
FWVER=`cat /dev/shmem/sw_trainname.txt 2>/dev/null || echo "unknown"`
echo "FW    : $FWVER" >> $LOG
echo "" >> $LOG

# --- Show start screen ---
$SDPath/utils/showScreen $SDPath/screens/scriptStart.png

# Track execution state
rm -f $SDPath/.done
echo "started" > $SDPath/.started

# --- Mount persistent filesystems ---
mount -uw /mnt/efs-persist 2>> $LOG

# --- Database paths ---
DB1=/mnt/efs-persist/DataPST.db
DB2=/HBpersistence/DataPST.db
DB3=/mnt/hmisql/DataPST.db

SQLITE=$SDPath/utils/sqlite3
PST_KEY=4100
PST_NS=4

# --- Backup original databases ---
echo ">> Backing up databases..." >> $LOG
cp -v $DB1 $SDPath/DB/efs-persist/old/DataPST.db >> $LOG 2>&1
cp -v $DB2 $SDPath/DB/HBpersistence/old/DataPST.db >> $LOG 2>&1
cp -v $DB3 $SDPath/DB/hmisql/old/DataPST.db >> $LOG 2>&1

# --- Remove existing entry (avoid duplicates) ---
echo "" >> $LOG
echo ">> Removing existing GEM entry (key=$PST_KEY, ns=$PST_NS)..." >> $LOG
$SQLITE $DB1 "DELETE FROM tb_intvalues WHERE pst_key=$PST_KEY AND pst_namespace=$PST_NS;" >> $LOG 2>&1
$SQLITE $DB2 "DELETE FROM tb_intvalues WHERE pst_key=$PST_KEY AND pst_namespace=$PST_NS;" >> $LOG 2>&1
$SQLITE $DB3 "DELETE FROM tb_intvalues WHERE pst_key=$PST_KEY AND pst_namespace=$PST_NS;" >> $LOG 2>&1

# --- Snapshot after delete ---
cp -v $DB1 $SDPath/DB/efs-persist/process/DataPST.db >> $LOG 2>&1
cp -v $DB2 $SDPath/DB/HBpersistence/process/DataPST.db >> $LOG 2>&1
cp -v $DB3 $SDPath/DB/hmisql/process/DataPST.db >> $LOG 2>&1

# --- Insert new value to enable Green Menu ---
echo "" >> $LOG
echo ">> Enabling Green Engineering Menu (value=1)..." >> $LOG
$SQLITE $DB1 "INSERT INTO tb_intvalues (pst_namespace, pst_key, pst_value) VALUES ($PST_NS, $PST_KEY, 1);" >> $LOG 2>&1
$SQLITE $DB2 "INSERT INTO tb_intvalues (pst_namespace, pst_key, pst_value) VALUES ($PST_NS, $PST_KEY, 1);" >> $LOG 2>&1
$SQLITE $DB3 "INSERT INTO tb_intvalues (pst_namespace, pst_key, pst_value) VALUES ($PST_NS, $PST_KEY, 1);" >> $LOG 2>&1

# --- Verify insertion ---
echo "" >> $LOG
echo ">> Verifying insertion..." >> $LOG
VAL1=`$SQLITE $DB1 "SELECT pst_value FROM tb_intvalues WHERE pst_key=$PST_KEY AND pst_namespace=$PST_NS;" 2>/dev/null`
VAL2=`$SQLITE $DB2 "SELECT pst_value FROM tb_intvalues WHERE pst_key=$PST_KEY AND pst_namespace=$PST_NS;" 2>/dev/null`
VAL3=`$SQLITE $DB3 "SELECT pst_value FROM tb_intvalues WHERE pst_key=$PST_KEY AND pst_namespace=$PST_NS;" 2>/dev/null`
echo "efs-persist   : pst_value=$VAL1" >> $LOG
echo "HBpersistence : pst_value=$VAL2" >> $LOG
echo "hmisql        : pst_value=$VAL3" >> $LOG

# --- Backup final databases ---
echo "" >> $LOG
echo ">> Saving final database snapshots..." >> $LOG
cp -v $DB1 $SDPath/DB/efs-persist/new/DataPST.db >> $LOG 2>&1
cp -v $DB2 $SDPath/DB/HBpersistence/new/DataPST.db >> $LOG 2>&1
cp -v $DB3 $SDPath/DB/hmisql/new/DataPST.db >> $LOG 2>&1

echo "" >> $LOG
echo ">> Done. Reboot MMI to access Green Engineering Menu." >> $LOG
echo ">> Access via: SETUP + CAR  (hold 5-6 seconds)" >> $LOG
echo "======================================" >> $LOG

# --- Show end screen & cleanup ---
$SDPath/utils/showScreen $SDPath/screens/scriptDone.png
echo "done" > $SDPath/.done
rm -f $SDPath/.started
