#!/bin/bash

ME_UTIL="/usr/local/bin/me-util"
SLOT_NAME=$1

function is_numeric {
  if [ $(echo "$1" | grep -cE "^\-?([[:xdigit:]]+)(\.[[:xdigit:]]+)?$") -gt 0 ]; then
    return 1 
  else
    return 0
  fi
}

case $SLOT_NAME in
    slot1)
      SLOT_NUM=1
      ;;
    slot2)
      SLOT_NUM=2
      ;;
    slot3)
      SLOT_NUM=3
      ;;
    slot4)
      SLOT_NUM=4
      ;;
    *)
      N=${0##*/}
      N=${N#[SK]??}
      echo "Usage: $N {slot1|slot2|slot3|slot4}"
      exit 1
      ;;
esac

# File format autodump<slot_id>.pid (See pal_is_crashdump_ongoing()
# function definition)
PID_FILE="/var/run/autodump$SLOT_NUM.pid"

# check if auto crashdump is already running
if [ -f $PID_FILE ]; then
  echo "Another auto crashdump for $SLOT_NAME is runnung"
  exit 1
else
  touch $PID_FILE
fi

# Set crashdump timestamp
sys_runtime=$(awk '{print $1}' /proc/uptime)
sys_runtime=$(printf "%0.f" $sys_runtime)
echo $((sys_runtime+630)) > /tmp/cache_store/fru${SLOT_NUM}_crashdump

DUMP_SCRIPT="/usr/local/bin/dump.sh"
CRASHDUMP_FILE="/mnt/data/crashdump_$SLOT_NAME"
CRASHDUMP_LOG_ARCHIVE="/mnt/data/crashdump_$SLOT_NAME.tar.gz"
LOG_MSG_PREFIX=""

DWR=0
SECOND_DUMP=0

while test $# -gt 1
do
  case "$2" in
  --dwr)
    DWR=1
    ;;
  --second)
    SECOND_DUMP=1
    ;;
  *)
    echo "unknown argument $2"
    ;;
  esac
  shift
done

if [ "$DWR" == "1" ] || [ "$SECOND_DUMP" == "1" ]; then
  echo "Auto Dump after System Reset or Demoted Warm Reset"
fi

echo "Auto Dump for $SLOT_NAME Started"

#HEADER LINE for the dump
$DUMP_SCRIPT "time" > $CRASHDUMP_FILE

# Get Device ID
echo "Get Device ID:" >> $CRASHDUMP_FILE
RES=$($ME_UTIL $SLOT_NAME 0x18 0x01)
echo "$RES" >> $CRASHDUMP_FILE
# Major Firmware Revision
REV=$(echo $RES| awk '{print $3;}')
# Check whether the first parameter is numeric or not
# If not, then it is an error message from me-util
is_numeric $(echo $RES| awk '{print $1;}')
if [ "$?" == 1 ] ;then
  Mode=$(echo $(($REV & 0x80)))
  if [ $Mode -ne 0 ] ;then
    echo "Device firmware update or Self-initialization in progress or Firmware in the recovery boot-loader mode" >> $CRASHDUMP_FILE
  fi
fi

# Get Self-test result
echo "Get Self-test result:" >> $CRASHDUMP_FILE
RES=$($ME_UTIL $SLOT_NAME 0x18 0x04)
echo "$RES" >> $CRASHDUMP_FILE
CC=$(echo $RES| awk '{print $1;}')
# Check whether the first parameter is numeric or not
# If not, then it is an error message from me-util 
is_numeric $CC
if [ "$?" == 1 ] ;then
  if [ $CC -ne 55 ] ;then
    if [ $CC -eq 56 ] ;then
      echo "Self Test function not implemented in this controller" >> $CRASHDUMP_FILE
    elif [ $CC -eq 57 ] ;then
      echo "Corrupted or inaccessible data or devices" >> $CRASHDUMP_FILE
    elif [ $CC -eq 58 ] ;then
      echo "Fatal hardware error" >> $CRASHDUMP_FILE
    elif [ $CC -eq 80 ] ;then
      echo "PSU Monitoring service error" >> $CRASHDUMP_FILE
    elif [ $CC -eq 81 ] ;then
      echo "Firmware entered Recovery boot-loader mode" >> $CRASHDUMP_FILE
    elif [ $CC -eq 82 ] ;then
      echo "HSC Monitoring service error" >> $CRASHDUMP_FILE
    elif [ $CC -eq 83 ] ;then
      echo "Firmware entered non-UMA restricted mode of operation" >> $CRASHDUMP_FILE
    else
      echo "Unknown error" >> $CRASHDUMP_FILE
    fi
  fi
fi

#COREID dump
$DUMP_SCRIPT $SLOT_NAME "coreid" >> $CRASHDUMP_FILE
#MSR dump
$DUMP_SCRIPT $SLOT_NAME "msr" >> $CRASHDUMP_FILE
#PCIe dump
$DUMP_SCRIPT $SLOT_NAME "pcie" >> $CRASHDUMP_FILE

# Sensors & sensor thresholds
echo "Sensor history at dump:" >> $CRASHDUMP_FILE 2>&1
$DUMP_SCRIPT $SLOT_NAME "sensors" >> $CRASHDUMP_FILE
echo "Sensor threshold at dump:" >> $CRASHDUMP_FILE 2>&1
$DUMP_SCRIPT $SLOT_NAME "threshold" >> $CRASHDUMP_FILE

# only second/dwr autodump need to rename accordingly
if [ "$DWR" == "1" ] || [ "$SECOND_DUMP" == "1" ]; then
  # dwr
  $DUMP_SCRIPT $SLOT_NAME  "dwr" >> $CRASHDUMP_FILE

  # rename the archieve file based on whether dump in DWR mode or not
  if [ "$?" == "2" ]; then
    CRASHDUMP_LOG_ARCHIVE="/mnt/data/crashdump_dwr_$SLOT_NAME.tar.gz"
    LOG_MSG_PREFIX="DWR "
  else
    CRASHDUMP_LOG_ARCHIVE="/mnt/data/crashdump_second_$SLOT_NAME.tar.gz"
    LOG_MSG_PREFIX="SECOND_DUMP "
  fi
fi

tar zcf $CRASHDUMP_LOG_ARCHIVE -C `dirname $CRASHDUMP_FILE` `basename $CRASHDUMP_FILE` && \
rm -rf $CRASHDUMP_FILE && \
logger -t "ipmid" -p daemon.crit "${LOG_MSG_PREFIX}Crashdump for FRU: $SLOT_NUM is generated at $CRASHDUMP_LOG_ARCHIVE"

echo "Auto Dump for $SLOT_NAME Completed"
echo -n "Auto Dump End at " >> $CRASHDUMP_FILE
date >> $CRASHDUMP_FILE

# Remove current pid file
rm $PID_FILE

echo "${LOG_MSG_PREFIX}Auto Dump Stored in $CRASHDUMP_LOG_ARCHIVE"
exit 0