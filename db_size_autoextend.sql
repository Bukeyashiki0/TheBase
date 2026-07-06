-- ============================================================
-- 1. TAMAÑO DE BASE DE DATOS: ACTUAL VS MÁXIMO (AUTOEXTEND)
-- ============================================================

-- Tamaño actual ocupado (datafiles + tempfiles)
SELECT SUM(bytes)/1024/1024/1024 AS size_gb
FROM dba_data_files;

SELECT SUM(bytes)/1024/1024/1024 AS size_gb
FROM dba_temp_files;

-- Detalle por datafile: actual vs MAXSIZE (autoextend)
SELECT
    file_name,
    tablespace_name,
    bytes/1024/1024/1024 AS current_gb,
    autoextensible,
    CASE
        WHEN autoextensible = 'YES' AND maxbytes = 0 THEN NULL
        ELSE maxbytes/1024/1024/1024
    END AS maxsize_gb,
    increment_by * (SELECT block_size FROM dba_tablespaces ts WHERE ts.tablespace_name = df.tablespace_name)/1024/1024 AS increment_mb
FROM dba_data_files df
ORDER BY tablespace_name;
