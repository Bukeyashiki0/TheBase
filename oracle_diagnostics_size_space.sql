-- ============================================================
-- Oracle Scripts - Diagnóstico de Tamaño y Espacio
-- ============================================================

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

-- Resumen agregado: actual vs máximo potencial
SELECT
    SUM(bytes)/1024/1024/1024 AS current_size_gb,
    SUM(CASE
            WHEN autoextensible = 'YES' THEN
                GREATEST(bytes, maxbytes)
            ELSE bytes
        END)/1024/1024/1024 AS max_potential_size_gb
FROM dba_data_files;

-- Cuidado: datafiles con MAXSIZE UNLIMITED (maxbytes puede aparecer como 0)
SELECT file_name, tablespace_name, autoextensible, maxbytes
FROM dba_data_files
WHERE autoextensible = 'YES' AND maxbytes = 0;


-- ============================================================
-- 2. ANÁLISIS DE CONFIGURACIÓN LOB (SecureFile, in-row, chunk)
-- ============================================================

-- Ver la configuración actual del LOB
SELECT table_name, column_name, securefile, in_row, chunk,
       compression, deduplication, retention
FROM dba_lobs
WHERE table_name = 'SMARTPRICING_CUSTOMER_PRICES_U_TMP'
  AND column_name = 'PRECIO';

-- Tamaño medio real del contenido (JSON en este caso)
SELECT AVG(LENGTH(PRECIO)), MAX(LENGTH(PRECIO)), MIN(LENGTH(PRECIO))
FROM EXHPRO.SMARTPRICING_CUSTOMER_PRICES_U_TMP;


-- ============================================================
-- 3. ESPACIO POR SEGMENTOS (tabla + índices + LOB si existe)
-- ============================================================

SELECT segment_name, segment_type, bytes/1024/1024 AS mb
FROM dba_segments
WHERE owner = 'EXHPRO'
  AND segment_name LIKE '%SMARTPRICING_CUSTOMER_PRICES_U_TMP%'
ORDER BY segment_type;

-- Filas, bloques y longitud media de fila (comparar con espacio asignado)
SELECT table_name, num_rows, blocks, avg_row_len, last_analyzed
FROM dba_tables
WHERE owner = 'EXHPRO'
  AND table_name = 'SMARTPRICING_CUSTOMER_PRICES_U_TMP';

-- Configuración de compresión y PCTFREE/PCTUSED
SELECT compression, compress_for, pct_free, pct_used
FROM dba_tables
WHERE owner = 'EXHPRO'
  AND table_name = 'SMARTPRICING_CUSTOMER_PRICES_U_TMP';

-- Conteo de filas (para estimar tamaño esperado vs real)
SELECT COUNT(*) AS num_filas
FROM EXHPRO.SMARTPRICING_CUSTOMER_PRICES_U_TMP;


-- ============================================================
-- 4. TAMAÑO TOTAL DE LA TABLA Y DEL LOB DE LA COLUMNA PRECIO
-- ============================================================

-- Espacio asignado en disco: segmento de tabla + segmento LOB + índice LOB
SELECT
    s.segment_type,
    s.segment_name,
    s.bytes/1024/1024 AS mb
FROM dba_segments s
WHERE s.owner = 'EXHPRO'
  AND s.segment_name IN (
      SELECT table_name  FROM dba_lobs WHERE owner = 'EXHPRO' AND table_name = 'SMARTPRICING_CUSTOMER_PRICES_U_TMP' AND column_name = 'PRECIO'
      UNION ALL
      SELECT segment_name FROM dba_lobs WHERE owner = 'EXHPRO' AND table_name = 'SMARTPRICING_CUSTOMER_PRICES_U_TMP' AND column_name = 'PRECIO'
      UNION ALL
      SELECT index_name   FROM dba_lobs WHERE owner = 'EXHPRO' AND table_name = 'SMARTPRICING_CUSTOMER_PRICES_U_TMP' AND column_name = 'PRECIO'
  )
ORDER BY segment_type;

-- Tamaño real del contenido almacenado en los CLOBs (bytes efectivos, no espacio asignado)
SELECT
    COUNT(*)                                          AS num_filas,
    SUM(DBMS_LOB.GETLENGTH(PRECIO))/1024/1024        AS total_content_mb,
    AVG(DBMS_LOB.GETLENGTH(PRECIO))/1024             AS avg_content_kb,
    MAX(DBMS_LOB.GETLENGTH(PRECIO))/1024             AS max_content_kb,
    MIN(DBMS_LOB.GETLENGTH(PRECIO))/1024             AS min_content_kb
FROM EXHPRO.SMARTPRICING_CUSTOMER_PRICES_U_TMP;
