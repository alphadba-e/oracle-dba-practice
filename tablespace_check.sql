-- Oracle DBA Practice - Tablespace Monitoring
-- Author: alphadba-e
-- Date: 2026-03-27

-- Check all tablespaces and their status
SELECT tablespace_name, status, contents, logging
FROM dba_tablespaces
ORDER BY tablespace_name;

-- Check tablespace space usage
SELECT 
    df.tablespace_name,
    ROUND(df.total_mb, 2) AS total_mb,
    ROUND(df.total_mb - fs.free_mb, 2) AS used_mb,
    ROUND(fs.free_mb, 2) AS free_mb,
    ROUND((fs.free_mb / df.total_mb) * 100, 2) AS pct_free
FROM 
    (SELECT tablespace_name, SUM(bytes)/1024/1024 AS total_mb 
     FROM dba_data_files GROUP BY tablespace_name) df,
    (SELECT tablespace_name, SUM(bytes)/1024/1024 AS free_mb 
     FROM dba_free_space GROUP BY tablespace_name) fs
WHERE df.tablespace_name = fs.tablespace_name
ORDER BY pct_free;
