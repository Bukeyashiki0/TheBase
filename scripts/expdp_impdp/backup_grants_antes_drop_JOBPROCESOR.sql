-- Backup de seguridad: captura la definicion del usuario y sus grants ANTES
-- de hacer DROP USER. Ejecutar como SYSDBA en DEV y guardar la salida.
-- Sirve de red de seguridad por si hubiera que reponer algo manualmente.

SET LONG 100000
SET PAGESIZE 0
SET LINESIZE 200
SET FEEDBACK OFF

PROMPT === DDL del usuario (password hash, tablespace por defecto, quotas) ===
SELECT DBMS_METADATA.GET_DDL('USER','JOBPROCESOR') FROM dual;

PROMPT === Roles concedidos al usuario ===
SELECT 'GRANT ' || granted_role || ' TO JOBPROCESOR'
       || CASE WHEN admin_option = 'YES' THEN ' WITH ADMIN OPTION' END || ';'
FROM   dba_role_privs
WHERE  grantee = 'JOBPROCESOR';

PROMPT === Privilegios de sistema ===
SELECT 'GRANT ' || privilege || ' TO JOBPROCESOR'
       || CASE WHEN admin_option = 'YES' THEN ' WITH ADMIN OPTION' END || ';'
FROM   dba_sys_privs
WHERE  grantee = 'JOBPROCESOR';

PROMPT === Quotas en tablespaces ===
SELECT 'ALTER USER JOBPROCESOR QUOTA '
       || CASE WHEN max_bytes = -1 THEN 'UNLIMITED'
               ELSE TO_CHAR(max_bytes) END
       || ' ON ' || tablespace_name || ';'
FROM   dba_ts_quotas
WHERE  username = 'JOBPROCESOR';

PROMPT === Grants que OTROS esquemas dieron sobre objetos de JOBPROCESOR ===
-- (estos los recrea el impdp; informativo)
SELECT grantee, privilege, table_name
FROM   dba_tab_privs
WHERE  owner = 'JOBPROCESOR';

PROMPT === Grants que JOBPROCESOR recibio sobre objetos de OTROS esquemas ===
-- (estos NO estan en el dump del esquema; hay que reponerlos si los hubiera)
SELECT 'GRANT ' || privilege || ' ON ' || owner || '.' || table_name
       || ' TO JOBPROCESOR;'
FROM   dba_tab_privs
WHERE  grantee = 'JOBPROCESOR';

SET FEEDBACK ON
