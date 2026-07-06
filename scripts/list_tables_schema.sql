-- Lista las tablas de un esquema con número de filas y fecha del último análisis
-- Sustituir JOBPROCESOR por el esquema deseado
-- Requiere acceso a DBA_TABLES (ejecutar como SYSDBA o usuario con ese privilegio)

SELECT table_name, num_rows, last_analyzed
FROM   dba_tables
WHERE  owner = 'JOBPROCESOR'
ORDER BY table_name;
