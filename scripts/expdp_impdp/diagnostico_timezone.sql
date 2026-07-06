-- Diagnostico del desfase de zona horaria (TSTZ) entre PRE y DEV
-- Ejecutar como SYSDBA en AMBAS bases y comparar la version.
-- El impdp falla con ORA-39405 cuando la version de PRE (origen) es MAYOR
-- que la de DEV (destino).

-- Version del fichero de timezone de la base
SELECT version FROM v$timezone_file;

-- Misma info via propiedades de la base
SELECT property_name, property_value
FROM   database_properties
WHERE  property_name LIKE 'DST_%';

-- Si DEV tiene version menor que PRE, opciones:
--   1. (RECOMENDADO para solo-DDL) usar impdp con sqlfile= y ejecutar el .sql
--   2. Re-exportar en PRE con VERSION= compatible (degrada el dump)
--   3. Subir el fichero de timezone de DEV con DBMS_DST (tarea de DBA)
