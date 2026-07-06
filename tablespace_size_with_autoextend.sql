-- Tamaño de tablespaces incluyendo espacio de AUTOEXTEND sin usar
SELECT
    df.tablespace_name,
    ROUND(SUM(df.bytes) / 1024 / 1024 / 1024, 2)                              AS size_gb,
    ROUND(SUM(fs.free_bytes) / 1024 / 1024 / 1024, 2)                        AS free_gb,
    ROUND(SUM(df.maxbytes) / 1024 / 1024 / 1024, 2)                          AS max_gb,
    ROUND((SUM(df.maxbytes) - SUM(df.bytes)) / 1024 / 1024 / 1024, 2)       AS autoextend_unused_gb
FROM (
    SELECT tablespace_name, bytes,
           CASE WHEN autoextensible = 'YES' AND maxbytes > 0
                THEN maxbytes
                ELSE bytes
           END AS maxbytes
    FROM dba_data_files
) df
JOIN (
    SELECT tablespace_name, SUM(bytes) AS free_bytes
    FROM dba_free_space
    GROUP BY tablespace_name
) fs ON df.tablespace_name = fs.tablespace_name
GROUP BY df.tablespace_name
ORDER BY df.tablespace_name;
