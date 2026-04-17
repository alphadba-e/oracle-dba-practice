-- ============================================================
-- Oracle 19c Multitenant - PDB Lifecycle Operations
-- Author: alphadba-e
-- Date: 2026-04-17
-- Purpose: PDB creation, cloning, unplug/plug, and management
-- ============================================================

-- ===========================================
-- METHOD 1: Create PDB from PDB$SEED
-- ===========================================

-- ADMIN USER creates a local DBA account (NOT SYS)
-- FILE_NAME_CONVERT maps seed datafile paths to new PDB paths
CREATE PLUGGABLE DATABASE pdb_test
  ADMIN USER pdb_admin IDENTIFIED BY oracle
  ROLES = (DBA)
  FILE_NAME_CONVERT = ('/u01/oradata/cdb1/pdbseed/',
                       '/u01/oradata/cdb1/pdb_test/');

-- New PDB is always in MOUNTED state after creation
SELECT name, open_mode FROM v$pdbs WHERE name = 'PDB_TEST';

-- Open it
ALTER PLUGGABLE DATABASE pdb_test OPEN;

-- Make open state persistent across CDB restarts
ALTER PLUGGABLE DATABASE pdb_test SAVE STATE;

-- ===========================================
-- METHOD 2: Local Clone (cold)
-- ===========================================

-- Source must be READ ONLY for cold clone (shared undo)
-- Source can be READ WRITE for hot clone (local undo required)
ALTER PLUGGABLE DATABASE pdb_test CLOSE;
ALTER PLUGGABLE DATABASE pdb_test OPEN READ ONLY;

CREATE PLUGGABLE DATABASE pdb_clone FROM pdb_test
  FILE_NAME_CONVERT = ('/u01/oradata/cdb1/pdb_test/',
                       '/u01/oradata/cdb1/pdb_clone/');

ALTER PLUGGABLE DATABASE pdb_clone OPEN;

-- ===========================================
-- UNPLUG/PLUG WORKFLOW
-- ===========================================

-- Step 1: Close the PDB (must be at rest)
ALTER PLUGGABLE DATABASE pdb_clone CLOSE IMMEDIATE;

-- Step 2: Generate XML manifest
ALTER PLUGGABLE DATABASE pdb_clone UNPLUG INTO '/tmp/pdb_clone.xml';

-- After UNPLUG: status = UNPLUGGED, can only be DROPPED
SELECT name, open_mode, status FROM v$pdbs WHERE name = 'PDB_CLONE';

-- Step 3: Remove from CDB but KEEP the datafiles!
-- WARNING: Without KEEP DATAFILES, Oracle DELETES all files permanently!
DROP PLUGGABLE DATABASE pdb_clone KEEP DATAFILES;

-- ===========================================
-- PLUG INTO TARGET CDB
-- ===========================================

-- Always check compatibility FIRST
SET SERVEROUTPUT ON
DECLARE
  compatible BOOLEAN;
BEGIN
  compatible := DBMS_PDB.CHECK_PLUG_COMPATIBILITY(
    pdb_descr_file => '/tmp/pdb_clone.xml');
  IF compatible THEN
    DBMS_OUTPUT.PUT_LINE('Compatible - safe to plug');
  ELSE
    DBMS_OUTPUT.PUT_LINE('NOT compatible - check PDB_PLUG_IN_VIOLATIONS');
  END IF;
END;
/

-- Check for specific violations
SELECT name, cause, type, message
FROM pdb_plug_in_violations
WHERE status = 'PENDING';

-- Plug with NOCOPY (files stay in place - no FILE_NAME_CONVERT needed)
CREATE PLUGGABLE DATABASE pdb_clone USING '/tmp/pdb_clone.xml' NOCOPY;

-- Plug with COPY (duplicate files to new location)
-- CREATE PLUGGABLE DATABASE pdb_clone USING '/tmp/pdb_clone.xml'
--   COPY FILE_NAME_CONVERT = ('/old/path/', '/new/path/');

-- Plug with MOVE (relocate files, delete originals)
-- CREATE PLUGGABLE DATABASE pdb_clone USING '/tmp/pdb_clone.xml'
--   MOVE FILE_NAME_CONVERT = ('/old/path/', '/new/path/');

ALTER PLUGGABLE DATABASE pdb_clone OPEN;
ALTER PLUGGABLE DATABASE pdb_clone SAVE STATE;

-- ===========================================
-- CLEANUP
-- ===========================================

ALTER PLUGGABLE DATABASE pdb_test CLOSE;
DROP PLUGGABLE DATABASE pdb_test INCLUDING DATAFILES;

ALTER PLUGGABLE DATABASE pdb_clone CLOSE;
DROP PLUGGABLE DATABASE pdb_clone INCLUDING DATAFILES;
