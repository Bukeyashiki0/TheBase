-- SCHEMA_DDL.sql
-- Extrae el DDL de todos los objetos de un esquema.
-- Ejecutar como SYSDBA: sqlplus / as sysdba
-- Ajustar el owner en la clausula WHERE si es necesario.

SELECT dbms_metadata.get_ddl(
    decode(object_type,
        'PACKAGE',           'PACKAGE_SPEC',
        'PACKAGE BODY',      'PACKAGE_BODY',
        'TYPE',              'TYPE_SPEC',
        'TYPE BODY',         'TYPE_BODY',
        'MATERIALIZED VIEW', 'MATERIALIZED_VIEW',
        object_type
    ), object_name, owner
) || chr(10) || '//' || chr(10) || chr(10)
FROM   dba_objects
WHERE  owner = 'JOBPROCESOR'
    -- Tipos incluidos dentro del DDL de otros objetos
    AND object_type NOT IN (
        'INDEX PARTITION','INDEX SUBPARTITION',
        'LOB','LOB PARTITION',
        'TABLE SUBPARTITION','TABLE PARTITION',
        'JOB','TABLESPACE'
    )
    -- Tipos generados por el sistema para colecciones
    AND NOT (object_type = 'TYPE' AND object_name LIKE 'SYS_PLSQL_%')
    -- Tablas anidadas: su DDL forma parte de la tabla padre
    AND (owner, object_name) NOT IN (
        SELECT owner, table_name FROM dba_nested_tables
    )
    -- Segmentos overflow de IOT: su DDL forma parte de la tabla padre
    AND (owner, object_name) NOT IN (
        SELECT owner, table_name FROM dba_tables WHERE iot_type = 'IOT_OVERFLOW'
    )
    -- Secuencias internas de columnas IDENTITY (ISEQ$$_ / ISEQS_):
    -- su DDL ya va incluido en el CREATE TABLE de la columna identity
    AND NOT (object_type = 'SEQUENCE' AND (
        object_name LIKE 'ISEQ$$_%' OR
        object_name LIKE 'ISEQS_%'
    ))
ORDER BY owner, object_name;
