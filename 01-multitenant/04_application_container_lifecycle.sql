-- ============================================================
-- Oracle 19c - Application Container Full Lifecycle
-- Author: alphadba-e
-- Date: 2026-04-18
-- Purpose: Complete workflow from creating an application
--          container to upgrading 50 application PDBs
-- ============================================================

-- ===========================================
-- STEP 1: Create the Application Container
-- ===========================================

-- Connected to CDB$ROOT as SYS
-- An application container is just a PDB created with AS APPLICATION CONTAINER
CREATE PLUGGABLE DATABASE saas_app AS APPLICATION CONTAINER
  ADMIN USER saas_admin IDENTIFIED BY oracle
  FILE_NAME_CONVERT = ('/u01/oradata/cdb1/pdbseed/',
                       '/u01/oradata/cdb1/saas_app/');

-- Open it
ALTER PLUGGABLE DATABASE saas_app OPEN;
ALTER PLUGGABLE DATABASE saas_app SAVE STATE;

-- ===========================================
-- STEP 2: Install Application v1.0
-- ===========================================

-- Switch into the application root
ALTER SESSION SET CONTAINER = saas_app;

-- BEGIN INSTALL tells Oracle: "record everything I do as version 1.0"
ALTER PLUGGABLE DATABASE APPLICATION crm_app BEGIN INSTALL '1.0';

-- Create shared table structures
-- These will appear in every application PDB
CREATE TABLE customers (
  customer_id   NUMBER PRIMARY KEY,
  company_name  VARCHAR2(200) NOT NULL,
  email         VARCHAR2(100),
  created_date  DATE DEFAULT SYSDATE
);

CREATE TABLE orders (
  order_id      NUMBER PRIMARY KEY,
  customer_id   NUMBER REFERENCES customers(customer_id),
  order_date    DATE DEFAULT SYSDATE,
  total_amount  NUMBER(12,2),
  status        VARCHAR2(20) DEFAULT 'NEW'
);

CREATE TABLE order_items (
  item_id       NUMBER PRIMARY KEY,
  order_id      NUMBER REFERENCES orders(order_id),
  product_name  VARCHAR2(200),
  quantity      NUMBER,
  unit_price    NUMBER(10,2)
);

-- Create shared procedures
CREATE OR REPLACE PROCEDURE place_order(
  p_cust_id   NUMBER,
  p_amount    NUMBER
) AS
  v_order_id NUMBER;
BEGIN
  SELECT NVL(MAX(order_id), 0) + 1 INTO v_order_id FROM orders;
  INSERT INTO orders (order_id, customer_id, total_amount, status)
  VALUES (v_order_id, p_cust_id, p_amount, 'NEW');
  COMMIT;
END;
/

-- Create a shared common user for the application
CREATE USER app_readonly IDENTIFIED BY oracle;
GRANT SELECT ON customers TO app_readonly;
GRANT SELECT ON orders TO app_readonly;
GRANT SELECT ON order_items TO app_readonly;

-- END INSTALL seals version 1.0
ALTER PLUGGABLE DATABASE APPLICATION crm_app END INSTALL '1.0';

-- ===========================================
-- STEP 3: Create Application Seed
-- ===========================================

-- The seed is a template for creating application PDBs quickly
-- It automatically contains all the shared objects from v1.0
CREATE PLUGGABLE DATABASE AS SEED
  ADMIN USER seed_admin IDENTIFIED BY oracle
  FILE_NAME_CONVERT = ('/u01/oradata/cdb1/saas_app/',
                       '/u01/oradata/cdb1/saas_app_seed/');

-- Open the seed and sync it with the application
ALTER PLUGGABLE DATABASE saas_app$SEED OPEN;
ALTER SESSION SET CONTAINER = saas_app$SEED;
ALTER PLUGGABLE DATABASE APPLICATION crm_app SYNC;

-- Go back to application root
ALTER SESSION SET CONTAINER = saas_app;

-- ===========================================
-- STEP 4: Create Application PDBs (customers)
-- ===========================================

-- Each application PDB = one customer
-- They clone from the application seed (not PDB$SEED)
-- In production you'd script this in a loop for 50 customers

-- Customer 1: Acme Corp
CREATE PLUGGABLE DATABASE cust_acme
  ADMIN USER acme_admin IDENTIFIED BY oracle
  FILE_NAME_CONVERT = ('/u01/oradata/cdb1/saas_app_seed/',
                       '/u01/oradata/cdb1/cust_acme/');
ALTER PLUGGABLE DATABASE cust_acme OPEN;
ALTER PLUGGABLE DATABASE cust_acme SAVE STATE;

-- Customer 2: Beta Industries
CREATE PLUGGABLE DATABASE cust_beta
  ADMIN USER beta_admin IDENTIFIED BY oracle
  FILE_NAME_CONVERT = ('/u01/oradata/cdb1/saas_app_seed/',
                       '/u01/oradata/cdb1/cust_beta/');
ALTER PLUGGABLE DATABASE cust_beta OPEN;
ALTER PLUGGABLE DATABASE cust_beta SAVE STATE;

-- Customer 3: Gamma Solutions
CREATE PLUGGABLE DATABASE cust_gamma
  ADMIN USER gamma_admin IDENTIFIED BY oracle
  FILE_NAME_CONVERT = ('/u01/oradata/cdb1/saas_app_seed/',
                       '/u01/oradata/cdb1/cust_gamma/');
ALTER PLUGGABLE DATABASE cust_gamma OPEN;
ALTER PLUGGABLE DATABASE cust_gamma SAVE STATE;

-- ... repeat for customers 4 through 50 ...

-- ===========================================
-- STEP 5: Each customer has their OWN data
-- ===========================================

-- Switch to Acme's PDB - insert Acme's data
ALTER SESSION SET CONTAINER = cust_acme;

INSERT INTO customers VALUES (1, 'Acme Corp', 'info@acme.com', SYSDATE);
INSERT INTO orders VALUES (1, 1, SYSDATE, 5000.00, 'NEW');
COMMIT;

-- Switch to Beta's PDB - insert Beta's data
ALTER SESSION SET CONTAINER = cust_beta;

INSERT INTO customers VALUES (1, 'Beta Industries', 'info@beta.com', SYSDATE);
INSERT INTO orders VALUES (1, 1, SYSDATE, 12000.00, 'NEW');
COMMIT;

-- Each PDB has the SAME table structure but DIFFERENT data
-- Acme sees only Acme's orders
-- Beta sees only Beta's orders
-- Complete data isolation between customers

-- ===========================================
-- STEP 6: Upgrade Application to v2.0
-- ===========================================

-- Go back to the application root
ALTER SESSION SET CONTAINER = saas_app;

-- BEGIN UPGRADE wraps all changes as "from 1.0 to 2.0"
ALTER PLUGGABLE DATABASE APPLICATION crm_app BEGIN UPGRADE '1.0' TO '2.0';

-- Add new columns
ALTER TABLE customers ADD (phone VARCHAR2(30));
ALTER TABLE customers ADD (tier VARCHAR2(20) DEFAULT 'STANDARD');
ALTER TABLE orders ADD (shipped_date DATE);

-- Add new table
CREATE TABLE invoices (
  invoice_id    NUMBER PRIMARY KEY,
  order_id      NUMBER REFERENCES orders(order_id),
  invoice_date  DATE DEFAULT SYSDATE,
  amount        NUMBER(12,2),
  paid          VARCHAR2(1) DEFAULT 'N'
);

-- Update the procedure
CREATE OR REPLACE PROCEDURE place_order(
  p_cust_id   NUMBER,
  p_amount    NUMBER
) AS
  v_order_id NUMBER;
  v_inv_id   NUMBER;
BEGIN
  SELECT NVL(MAX(order_id), 0) + 1 INTO v_order_id FROM orders;
  INSERT INTO orders (order_id, customer_id, total_amount, status)
  VALUES (v_order_id, p_cust_id, p_amount, 'NEW');
  
  -- v2.0: auto-create invoice
  SELECT NVL(MAX(invoice_id), 0) + 1 INTO v_inv_id FROM invoices;
  INSERT INTO invoices (invoice_id, order_id, amount)
  VALUES (v_inv_id, v_order_id, p_amount);
  
  COMMIT;
END;
/

-- Grant access to new table
GRANT SELECT ON invoices TO app_readonly;

-- Seal the upgrade
ALTER PLUGGABLE DATABASE APPLICATION crm_app END UPGRADE TO '2.0';

-- ===========================================
-- STEP 7: Sync Application PDBs (pull upgrade)
-- ===========================================

-- IMPORTANT: Each PDB must SYNC individually
-- Oracle does NOT push upgrades automatically

-- Sync Acme (test first)
ALTER SESSION SET CONTAINER = cust_acme;
ALTER PLUGGABLE DATABASE APPLICATION crm_app SYNC;

-- Verify: Acme should now have the new columns and invoices table
DESC customers;
DESC invoices;
SELECT * FROM customers;  -- existing data preserved, new columns added

-- If test passes, sync the rest
ALTER SESSION SET CONTAINER = cust_beta;
ALTER PLUGGABLE DATABASE APPLICATION crm_app SYNC;

ALTER SESSION SET CONTAINER = cust_gamma;
ALTER PLUGGABLE DATABASE APPLICATION crm_app SYNC;

-- ... repeat for remaining customers ...

-- ===========================================
-- STEP 8: Verify application versions
-- ===========================================

-- Back to application root
ALTER SESSION SET CONTAINER = saas_app;

-- Check which version each PDB is running
SELECT con_id, name, open_mode
FROM v$pdbs
ORDER BY con_id;

-- Check application status across all containers
SELECT app_name, app_version, app_status
FROM dba_applications;

-- ===========================================
-- STEP 9: Query across ALL application PDBs
-- ===========================================

-- From the application root, you can query across all customers
-- This is powerful for reporting
ALTER SESSION SET CONTAINER = saas_app;

-- See all customers across all PDBs
SELECT c.con_id, c.company_name, c.email
FROM CONTAINERS(customers) c
ORDER BY c.con_id;

-- See total orders across all PDBs
SELECT o.con_id, COUNT(*) AS order_count, SUM(o.total_amount) AS revenue
FROM CONTAINERS(orders) o
GROUP BY o.con_id
ORDER BY o.con_id;

-- ===========================================
-- CLEANUP
-- ===========================================

-- Back to CDB$ROOT
ALTER SESSION SET CONTAINER = CDB$ROOT;

-- Close and drop application PDBs
ALTER PLUGGABLE DATABASE cust_acme CLOSE;
ALTER PLUGGABLE DATABASE cust_beta CLOSE;
ALTER PLUGGABLE DATABASE cust_gamma CLOSE;
DROP PLUGGABLE DATABASE cust_acme INCLUDING DATAFILES;
DROP PLUGGABLE DATABASE cust_beta INCLUDING DATAFILES;
DROP PLUGGABLE DATABASE cust_gamma INCLUDING DATAFILES;

-- Close and drop the application container itself
ALTER PLUGGABLE DATABASE saas_app CLOSE;
DROP PLUGGABLE DATABASE saas_app INCLUDING DATAFILES;
