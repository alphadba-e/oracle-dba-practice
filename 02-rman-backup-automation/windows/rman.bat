@echo off
REM ============================================================
REM RMAN whole-database backup wrapper - winsrv
REM Target DB : ORAWINDB (NOARCHIVELOG mode)
REM Scheduled : daily 00:00 via Windows Task Scheduler
REM ============================================================

set ORACLE_SID=ORAWINDB
set ORACLE_HOME=D:\oracle\product\19.0.0\db_1

%ORACLE_HOME%\bin\rman ^
  cmdfile=D:\oracle\app\oraclesvc\fast_recovery_area\ORAWINDB\scripts\rman.ora ^
  log=D:\oracle\app\oraclesvc\fast_recovery_area\ORAWINDB\scripts\rman.log append
