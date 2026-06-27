#!/bin/bash
# ============================================================
# RMAN Level 1 (delta) incremental backup - weekdays
# Target DB : ORADB (non-CDB, 19c) on srv1
# Schedule  : Mon-Thu 13:00 and 20:00 via crontab
# ============================================================

ORACLE_SID=oradb;                                  export ORACLE_SID
ORACLE_HOME=/u01/app/oracle/product/19.0.0/db_1;   export ORACLE_HOME

$ORACLE_HOME/bin/rman log=/media/sf_staging/backups/oradb/rman1.log append <<EOF
connect target '/ AS SYSBACKUP';
set echo on;
run {
  BACKUP DEVICE TYPE disk
    INCREMENTAL LEVEL 1
    FORMAT '/media/sf_staging/backups/oradb/DB0%U.bk'
    DATABASE TAG 'DBLVL1';

  DELETE NOPROMPT OBSOLETE DEVICE TYPE disk;

  BACKUP DEVICE TYPE disk
    CURRENT CONTROLFILE TAG 'ORADBCTL'   FORMAT '/media/sf_staging/backups/oradb/CTL%U.bk'
    SPFILE              TAG 'ORADBSPFILE' FORMAT '/media/sf_staging/backups/oradb/SPFILE%U.bk';

  BACKUP DEVICE TYPE disk
    ARCHIVELOG ALL TAG 'ORADBARCH'
    FORMAT '/media/sf_staging/backups/oradb/ARC%U.bk'
    DELETE ALL INPUT;
}
exit;
EOF
