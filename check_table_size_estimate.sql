SELECT
    t.table_name,
    t.compress_for,
    t.num_rows,
    t.avg_row_len,
    ROUND(t.num_rows * t.avg_row_len / 1024/1024/1024, 2) AS gb_raw_estimado
FROM dba_tables t
WHERE t.owner = 'ESQUEMA'
  AND t.table_name IN ('TABLA1', 'TABLA2');
