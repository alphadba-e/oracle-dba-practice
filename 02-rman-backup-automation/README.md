# 02 — Automating RMAN Backup Jobs

Hands-on practice implementing a scheduled RMAN backup strategy on Oracle Database 19c,
on both Linux (via `crontab`) and Windows (via Task Scheduler).

> Lab environment: non-CDB database `ORADB` on Oracle Linux 7 (`srv1`), Oracle 19c.
> Based on a backup-automation exercise from the *Oracle DBA from Zero to Hero* course by Ahmed Baraka,
> reproduced and documented here from my own lab run.

---

## The backup strategy

A sample strategy — **not** a production blueprint. In a real environment the policy is always
negotiated with the business against its RPO/RTO targets.

| Rule | Implementation |
|------|----------------|
| Retention | Recovery window of **8 days** — anything older is obsolete |
| Weekly base | **Level 0** incremental every **Friday 22:00** |
| Daily deltas | **Level 1** incremental every weekday (Mon–Thu) at **13:00** and **20:00** |
| Weekend | No backups on Saturday/Sunday |
| Archived logs | Backed up with every job, then deleted from disk after being backed up |
| Cleanup | Obsolete backups deleted at the end of every job |
| Monitoring | Job logs reviewed daily to confirm overnight runs succeeded |

### RPO / RTO reasoning

- **RTO can't be derived from the schedule alone.** It depends on database size, storage
  bandwidth, and the specific recovery scenario — none of which the policy fixes.
- **RPO (worst case ≈ 17 hours).** If a failure hits just before a scheduled level 1 — say 12:50,
  ten minutes before the 13:00 run — the most recent usable backup is the 20:00 run from the
  previous weekday. That window of unprotected change is the exposure. Tightening RPO is simply
  a matter of running the incremental more often.

---

## Protection policies configured (RMAN)

```sql
-- 8-day recovery window
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 8 DAYS;

-- never let DELETE ARCHIVELOG remove a log that hasn't been backed up at least once
CONFIGURE ARCHIVELOG DELETION POLICY TO BACKED UP 1 TIMES TO DEVICE TYPE DISK;

-- controlfile autobackup is on by default in 12c+ (lands in the FRA)
SHOW CONTROLFILE AUTOBACKUP;
SHOW CONTROLFILE AUTOBACKUP FORMAT;
```

---

## Linux automation (`crontab`)

Two shell scripts wrap RMAN and are scheduled through the `oracle` user's crontab.

| File | Role |
|------|------|
| [`linux/rman_script0.sh`](linux/rman_script0.sh) | Level 0 — weekly base backup |
| [`linux/rman_script1.sh`](linux/rman_script1.sh) | Level 1 — weekday delta backup |
| [`linux/crontab_schedule.txt`](linux/crontab_schedule.txt) | The crontab entries implementing the schedule |

Each job, in order:
1. takes the incremental backup (level 0 or 1) tagged for clarity,
2. deletes obsolete backups per the retention policy,
3. backs up the current controlfile and SPFILE,
4. backs up all archived logs and deletes them from disk after.

**Recovery prep saved to the backup destination:**
- `DBID.txt` — the DBID, needed in some restore-from-scratch scenarios.
- A text copy of the controlfile via `ALTER DATABASE BACKUP CONTROLFILE TO TRACE;` — gives the
  SQL to recreate the controlfile if it's ever lost.

---

## Windows automation (Task Scheduler)

A single daily full backup at midnight on `winsrv` (database `ORAWINDB`).

| File | Role |
|------|------|
| [`windows/rman.bat`](windows/rman.bat) | Batch wrapper that sets the environment and calls RMAN |
| [`windows/rman.ora`](windows/rman.ora) | RMAN command file run by the batch job |

Because `ORAWINDB` runs in **NOARCHIVELOG** mode, the database must be mounted (not open) to take
a consistent whole-database backup — so the command file shuts down, starts in `MOUNT`, backs up,
then reopens. A *Basic Task* in Task Scheduler runs `rman.bat` daily, configured to run whether
the user is logged on or not.

---

## What I practiced

- Wrapping RMAN in shell/batch scripts driven by a heredoc / command file.
- Translating a written backup policy into concrete `crontab` and Task Scheduler schedules.
- The difference between automating in an **ARCHIVELOG** DB (online incremental backups) vs a
  **NOARCHIVELOG** DB (mounted whole-DB backup).
- Saving the artifacts a clean recovery actually needs: DBID, controlfile trace, job logs.
- Reasoning about RPO from a schedule, and why RTO can't be read off one.
