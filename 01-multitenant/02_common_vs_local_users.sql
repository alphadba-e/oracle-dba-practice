-- ============================================================
-- Oracle 19c Multitenant - Common vs Local Users & Grant Scopes
-- Author: alphadba-e
-- Date: 2026-04-17
-- Purpose: Demonstrate common/local user creation and grant scope rules
-- ============================================================

-- ===========================================
-- PART 1: Common User (must use C## prefix)
-- ===========================================

-- Connect to CDB$ROOT first
ALTER SESSION SET CONTAINER = CDB$ROOT;

-- This FAILS - no C## prefix
-- CREATE USER admin_test IDENTIFIED BY oracle;
-- ORA-65096: invalid common user or role name

-- This WORKS - correct common user syntax
CREATE USER c##dba_imad IDENTIFIED BY oracle;

-- Grant with NO scope clause = CDB$ROOT only
GRANT CREATE SESSION TO c##dba_imad;
-- Result: c##dba_imad can ONLY connect to CDB$ROOT, NOT to any PDB

-- Grant with CONTAINER=ALL = all containers
GRANT CREATE SESSION TO c##dba_imad CONTAINER=ALL;
-- Result: c##dba_imad can now connect to every PDB

-- System privileges work with CONTAINER=ALL
GRANT CREATE TABLE TO c##dba_imad CONTAINER=ALL;

-- Object privileges FAIL with CONTAINER=ALL
-- GRANT SELECT ON hr.employees TO c##dba_imad CONTAINER=ALL;
-- ORA-65063: object privilege cannot be granted with CONTAINER=ALL

-- ===========================================
-- PART 2: Local User (inside a PDB only)
-- ===========================================

ALTER SESSION SET CONTAINER = pdb1;

-- Local users have no C## prefix
CREATE USER app_user IDENTIFIED BY oracle;
GRANT CREATE SESSION TO app_user;
-- app_user exists ONLY in pdb1 - cannot connect to CDB$ROOT or other PDBs

-- ===========================================
-- PART 3: Common Role to Local User (legal!)
-- ===========================================

-- Still inside pdb1
-- A common role like c##myrole exists in every container
-- Granting it to a local user from inside the PDB = legal
-- GRANT c##myrole TO app_user;
-- The local user gets the privileges, but only within this PDB

-- ===========================================
-- PART 4: Verify what we created
-- ===========================================

-- Back to ROOT to see common users
ALTER SESSION SET CONTAINER = CDB$ROOT;

SELECT username, common, con_id
FROM cdb_users
WHERE oracle_maintained = 'N'
ORDER BY username;

-- Cleanup
DROP USER c##dba_imad CASCADE;
ALTER SESSION SET CONTAINER = pdb1;
DROP USER app_user CASCADE;
