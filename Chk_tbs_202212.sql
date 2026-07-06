-- Paso previo: Purgar la recycle bin de los tablespaces afectados
-- (elimina los objetos BIN$ que inflan los resultados de los checks)
PURGE TABLESPACE TBHIS_202212;
PURGE TABLESPACE TBOUT_202212;
PURGE TABLESPACE TBSRD_202212;
PURGE TABLESPACE TBCGB_202212;
PURGE TABLESPACE TBCPT_202212;
PURGE TABLESPACE TBDAT_202212;
PURGE TABLESPACE TBRDM_202212;
PURGE TABLESPACE TBESG_202212;

-- Check 1: Segmentos activos en los tablespaces
SELECT tablespace_name, owner, segment_name, segment_type
FROM dba_segments
WHERE tablespace_name IN (
'TBHIS_202212','TBOUT_202212','TBSRD_202212','TBCGB_202212','TBCPT_202212','TBDAT_202212','TBRDM_202212','TBESG_202212'
)
ORDER BY tablespace_name, owner, segment_name;

-- Check 2: Constraints cruzadas con otros tablespaces
SELECT c.owner, c.constraint_name, c.table_name, t.tablespace_name
FROM dba_constraints c
JOIN dba_tables t ON t.owner = c.owner AND t.table_name = c.table_name
WHERE c.status = 'ENABLED'
  AND c.constraint_type = 'R'
  AND c.r_owner IN (
    SELECT owner FROM dba_tables
    WHERE tablespace_name IN ('TBHIS_202212','TBOUT_202212','TBSRD_202212','TBCGB_202212','TBCPT_202212','TBDAT_202212','TBRDM_202212','TBESG_202212'))
ORDER BY t.tablespace_name, c.owner, c.table_name;

-- Check 3: Particiones a borrar en los tablespaces
SELECT tablespace_name, table_owner, table_name, partition_name
FROM dba_tab_partitions
WHERE tablespace_name IN (
'TBHIS_202212','TBOUT_202212','TBSRD_202212','TBCGB_202212','TBCPT_202212','TBDAT_202212','TBRDM_202212','TBESG_202212'
)
ORDER BY tablespace_name, table_owner, table_name;

-- Check 4: Tablas con particiones repartidas entre los tablespaces a borrar y otros (ORA-14404)
SELECT DISTINCT p.table_owner, p.table_name, p.tablespace_name AS ts_a_borrar, p2.tablespace_name AS ts_externo
FROM dba_tab_partitions p
JOIN dba_tab_partitions p2 ON p2.table_owner = p.table_owner AND p2.table_name = p.table_name
WHERE p.tablespace_name IN (
'TBHIS_202212','TBOUT_202212','TBSRD_202212','TBCGB_202212','TBCPT_202212','TBDAT_202212','TBRDM_202212','TBESG_202212'
)
  AND p2.tablespace_name NOT IN (
'TBHIS_202212','TBOUT_202212','TBSRD_202212','TBCGB_202212','TBCPT_202212','TBDAT_202212','TBRDM_202212','TBESG_202212'
)
ORDER BY p.table_owner, p.table_name;
