-- ============================================================
-- Oracle 19c Multitenant Architecture - CDB/PDB Exploration
-- Author: alphadba-e
-- Date: 2026-04-17
-- Purpose: Verify CDB structure, container info, and PDB states
-- ============================================================

-- 1. Confirm we are in a CDB and show current container
SELECT name, cdb, con_id 
FROM v$database;

SHOW CON_NAME;

-- 2. List all containers with their open mode and status
SELECT con_id, name, open_mode, status, total_size/1024/1024 AS size_mb
FROM v$pdbs
ORDER BY con_id;

-- 3. Show container details from CDB-level view
SELECT pdb_id, pdb_name, status, con_id
FROM cdb_pdbs
ORDER BY pdb_id;

-- 4. Verify undo mode (local vs shared)
-- Local undo is required for: hot cloning, PDB PITR, clean unplug
SHOW PARAMETER local_undo;

-- 5. Check which undo tablespace is active per container
SELECT con_id, tablespace_name, status
FROM cdb_tablespaces
WHERE contents = 'UNDO'
ORDER BY con_id;

-- 6. Switch to a PDB and verify context change
ALTER SESSION SET CONTAINER = pdb1;
SHOW CON_NAME;
SELECT sys_context('USERENV', 'CON_NAME') AS current_container FROM dual;
