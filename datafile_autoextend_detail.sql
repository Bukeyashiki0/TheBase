-- Detalle por datafile: tamaño actual, máximo y espacio de autoextend sin usar
-- Nota: MAXBYTES = 32767 MB indica que el datafile fue creado con MAXSIZE UNLIMITED
SELECT
    file_name,
    tablespace_name,
    autoextensible                                          AS autoext,
    ROUND(bytes / 1024 / 1024 / 1024, 2)                         AS current_gb,
    ROUND(maxbytes / 1024 / 1024 / 1024, 2)                      AS max_gb,
    ROUND((maxbytes - bytes) / 1024 / 1024 / 1024, 2)           AS unused_autoext_gb
FROM dba_data_files
ORDER BY tablespace_name, file_name;
