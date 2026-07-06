-- Estimación previa sin crear el índice (Exadata, ejecutar en entorno de prueba o con muestra)
SELECT index_name, leaf_blocks * 8192 / 1024 / 1024 / 1024 AS size_gb
FROM dba_indexes
WHERE table_name = 'HM_FINAL_CONTRATOS_FINAL';

-- Ver espacio disponible en el tablespace del índice
SELECT tablespace_name,
       ROUND(SUM(bytes)/1024/1024/1024,2) AS free_gb
FROM dba_free_space
WHERE tablespace_name = '<TABLESPACE_INDICES>'
GROUP BY tablespace_name;
