COLUMN tablespace_name FORMAT A20

SELECT d.tablespace_name,
       ROUND(d.total_mb, 2)                            AS "TOTAL_MB",
       ROUND(NVL(f.free_mb, 0), 2)                     AS "FREE_MB",
       ROUND(d.total_mb - NVL(f.free_mb, 0), 2)        AS "USED_MB",
       ROUND(100 * NVL(f.free_mb, 0) / d.total_mb, 2)  AS "%_FREE"
FROM (SELECT tablespace_name,
             SUM(bytes) / 1024 / 1024 AS total_mb
      FROM dba_data_files
      GROUP BY tablespace_name) d
LEFT JOIN (SELECT tablespace_name,
                  SUM(bytes) / 1024 / 1024 AS free_mb
           FROM dba_free_space
           GROUP BY tablespace_name) f
  ON d.tablespace_name = f.tablespace_name
ORDER BY d.tablespace_name;
