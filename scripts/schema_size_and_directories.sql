-- Tamaño del esquema JOBPROCESOR
SELECT segment_type,
       ROUND(SUM(bytes)/1024/1024/1024, 2) AS gb,
       ROUND(SUM(bytes)/1024/1024, 2)      AS mb
FROM   dba_segments
WHERE  owner = 'JOBPROCESOR'
GROUP BY segment_type
ORDER BY gb DESC;

-- Total global del esquema
SELECT ROUND(SUM(bytes)/1024/1024/1024, 2) AS total_gb,
       ROUND(SUM(bytes)/1024/1024, 2)      AS total_mb
FROM   dba_segments
WHERE  owner = 'JOBPROCESOR';

-- DBA Directories disponibles
SELECT directory_name, directory_path
FROM   dba_directories
ORDER BY directory_name;
