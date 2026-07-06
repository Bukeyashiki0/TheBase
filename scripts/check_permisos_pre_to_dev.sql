-- =============================================================================
-- check_permisos_pre_to_dev.sql
-- Audita todos los permisos relevantes de un esquema en PRE y genera el
-- script SQL para replicarlos en DEV antes de la carga de datos.
--
-- INSTRUCCIONES DE USO:
--   1. Conectar a PRE como SYSDBA:
--         sqlplus / as sysdba        (local)
--         sqlplus /@PRE as sysdba    (remota)
--   2. Ajustar la variable v_schema.
--   3. Ejecutar:
--         SQL> @check_permisos_pre_to_dev.sql
--   4. Revisar el informe en pantalla y aplicar el script generado en DEV.
-- =============================================================================

DEFINE v_schema      = 'NOMBRE_ESQUEMA'    -- Esquema a auditar (MAYÚSCULAS)
DEFINE v_output_ddl  = 'grants_dev_&v_schema..sql'
DEFINE v_output_rpt  = 'informe_permisos_&v_schema..txt'

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE    200
SET PAGESIZE    50
SET TRIMSPOOL   ON
SET FEEDBACK    OFF
SET VERIFY      OFF

-- ===========================================================================
-- INFORME DE DIAGNÓSTICO (pantalla + fichero de texto)
-- ===========================================================================
SPOOL &v_output_rpt

PROMPT ============================================================
PROMPT  INFORME DE PERMISOS - ESQUEMA: &v_schema
SELECT 'Fecha: ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS') FROM DUAL;
PROMPT ============================================================
PROMPT


-- ---------------------------------------------------------------------------
-- 1. DEFINICION DEL USUARIO (perfil, tablespace por defecto, estado)
-- ---------------------------------------------------------------------------
PROMPT --- [1] DEFINICION DEL USUARIO ------------------------------------
SELECT username,
       account_status,
       default_tablespace,
       temporary_tablespace,
       profile,
       created
FROM   dba_users
WHERE  username = UPPER('&v_schema');
PROMPT


-- ---------------------------------------------------------------------------
-- 2. CUOTAS DE TABLESPACE
--    Sin cuota el usuario no puede insertar datos aunque tenga permisos.
-- ---------------------------------------------------------------------------
PROMPT --- [2] CUOTAS DE TABLESPACE (sin cuota = no puede escribir) ------
SELECT tablespace_name,
       CASE WHEN max_bytes = -1 THEN 'UNLIMITED'
            ELSE TO_CHAR(ROUND(max_bytes/1048576,2)) || ' MB'
       END AS cuota_maxima,
       ROUND(bytes/1048576,2) || ' MB' AS usado
FROM   dba_ts_quotas
WHERE  username = UPPER('&v_schema')
ORDER BY tablespace_name;
PROMPT


-- ---------------------------------------------------------------------------
-- 3. PRIVILEGIOS DE SISTEMA (CREATE SESSION, CREATE TABLE, etc.)
-- ---------------------------------------------------------------------------
PROMPT --- [3] PRIVILEGIOS DE SISTEMA ------------------------------------
SELECT privilege, admin_option
FROM   dba_sys_privs
WHERE  grantee = UPPER('&v_schema')
ORDER BY privilege;
PROMPT


-- ---------------------------------------------------------------------------
-- 4. ROLES CONCEDIDOS AL USUARIO
-- ---------------------------------------------------------------------------
PROMPT --- [4] ROLES CONCEDIDOS AL USUARIO --------------------------------
SELECT granted_role, admin_option, default_role
FROM   dba_role_privs
WHERE  grantee = UPPER('&v_schema')
ORDER BY granted_role;
PROMPT


-- ---------------------------------------------------------------------------
-- 5. PRIVILEGIOS DE OBJETO RECIBIDOS DESDE OTROS ESQUEMAS
--    (el usuario necesita SELECT/INSERT/EXECUTE sobre objetos externos)
-- ---------------------------------------------------------------------------
PROMPT --- [5] PRIVILEGIOS RECIBIDOS DE OTROS ESQUEMAS -------------------
SELECT owner        AS esquema_origen,
       table_name   AS objeto,
       grantor,
       privilege,
       grantable,
       hierarchy
FROM   dba_tab_privs
WHERE  grantee = UPPER('&v_schema')
  AND  owner  != UPPER('&v_schema')
ORDER BY owner, table_name, privilege;
PROMPT


-- ---------------------------------------------------------------------------
-- 6. GRANTS CONCEDIDOS POR ESTE ESQUEMA A OTROS (para que aplicación pueda leer)
-- ---------------------------------------------------------------------------
PROMPT --- [6] GRANTS OTORGADOS POR ESTE ESQUEMA A OTROS ----------------
SELECT grantee, table_name AS objeto, privilege, grantable, hierarchy
FROM   dba_tab_privs
WHERE  owner   = UPPER('&v_schema')
  AND  grantee != UPPER('&v_schema')
ORDER BY grantee, table_name, privilege;
PROMPT


-- ---------------------------------------------------------------------------
-- 7. SINONIMOS PUBLICOS que apuntan a objetos de este esquema
--    Si no se recrean, aplicación no encontrará los objetos por su nombre corto
-- ---------------------------------------------------------------------------
PROMPT --- [7] SINONIMOS PUBLICOS que apuntan a este esquema -------------
SELECT synonym_name, table_owner, table_name, db_link
FROM   dba_synonyms
WHERE  owner       = 'PUBLIC'
  AND  table_owner = UPPER('&v_schema')
ORDER BY synonym_name;
PROMPT


-- ---------------------------------------------------------------------------
-- 8. SINONIMOS PRIVADOS del esquema que apuntan a objetos externos
--    Si el objeto externo no existe en DEV, fallará en tiempo de ejecución
-- ---------------------------------------------------------------------------
PROMPT --- [8] SINONIMOS PRIVADOS hacia objetos EXTERNOS (dependencias) --
SELECT synonym_name, table_owner AS esquema_destino, table_name, db_link
FROM   dba_synonyms
WHERE  owner       = UPPER('&v_schema')
  AND  table_owner != UPPER('&v_schema')
ORDER BY table_owner, synonym_name;
PROMPT


-- ---------------------------------------------------------------------------
-- 9. DATABASE LINKS definidos en el esquema
--    Verificar que los destinos sean accesibles desde DEV
-- ---------------------------------------------------------------------------
PROMPT --- [9] DATABASE LINKS (verificar accesibilidad desde DEV) --------
SELECT db_link, username, host
FROM   dba_db_links
WHERE  owner = UPPER('&v_schema')
ORDER BY db_link;
PROMPT


-- ---------------------------------------------------------------------------
-- 10. PERFIL DEL USUARIO: límites que pueden cortar sesiones largas de carga
-- ---------------------------------------------------------------------------
PROMPT --- [10] PERFIL DEL USUARIO (límites que afectan carga larga) -----
SELECT p.resource_name, p.limit
FROM   dba_profiles p
JOIN   dba_users    u ON u.profile = p.profile
WHERE  u.username      = UPPER('&v_schema')
  AND  p.resource_name IN (
           'SESSIONS_PER_USER',
           'IDLE_TIME',
           'CONNECT_TIME',
           'CPU_PER_SESSION',
           'LOGICAL_READS_PER_SESSION',
           'PASSWORD_LIFE_TIME',
           'FAILED_LOGIN_ATTEMPTS'
       )
ORDER BY p.resource_name;
PROMPT


-- ---------------------------------------------------------------------------
-- 11. OBJETOS INVALIDOS en PRE (si están inválidos en PRE, llegarán inválidos)
-- ---------------------------------------------------------------------------
PROMPT --- [11] OBJETOS INVALIDOS en PRE (resolver antes de migrar) ------
SELECT object_type, object_name, status, last_ddl_time
FROM   dba_objects
WHERE  owner  = UPPER('&v_schema')
  AND  status = 'INVALID'
ORDER BY object_type, object_name;
PROMPT


-- ---------------------------------------------------------------------------
-- 12. TRIGGERS habilitados (pueden fallar si tablas referenciadas no existen)
-- ---------------------------------------------------------------------------
PROMPT --- [12] TRIGGERS HABILITADOS en el esquema -----------------------
SELECT trigger_name, table_name, trigger_type, triggering_event, status
FROM   dba_triggers
WHERE  owner  = UPPER('&v_schema')
  AND  status = 'ENABLED'
ORDER BY table_name, trigger_name;
PROMPT


-- ---------------------------------------------------------------------------
-- 13. DIRECTORY OBJECTS usados por el esquema (para cargas con external tables / UTL_FILE)
-- ---------------------------------------------------------------------------
PROMPT --- [13] DIRECTORY OBJECTS con acceso desde este esquema ----------
SELECT d.directory_name, d.directory_path,
       tp.privilege
FROM   dba_tab_privs tp
JOIN   dba_directories d ON d.directory_name = tp.table_name
WHERE  tp.grantee   = UPPER('&v_schema')
   OR  tp.grantor   = UPPER('&v_schema')
ORDER BY d.directory_name;
PROMPT

SPOOL OFF


-- ===========================================================================
-- SCRIPT DDL DE PERMISOS PARA APLICAR EN DEV
-- ===========================================================================
SET HEADING   OFF
SET PAGESIZE  0
SET LONG      2000000
SET ECHO      OFF

SPOOL &v_output_ddl

PROMPT -- ==================================================================
PROMPT -- SCRIPT DE PERMISOS para recrear en DEV - Esquema: &v_schema
SELECT '-- Generado: ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS') FROM DUAL;
PROMPT -- Ejecutar como SYSDBA en DEV
PROMPT -- ==================================================================
PROMPT

-- ---- Usuario (contraseña placeholder, ajustar antes de ejecutar) ----------
PROMPT -- [A] RECREAR USUARIO (ajustar contraseña y tablespaces si difieren)
PROMPT
SELECT
    'CREATE USER "' || username || '"'
    || ' IDENTIFIED BY "CAMBIAR_CONTRASENA"'
    || ' DEFAULT TABLESPACE "' || default_tablespace || '"'
    || ' TEMPORARY TABLESPACE "' || temporary_tablespace || '"'
    || ' PROFILE "' || profile || '"'
    || ';'
FROM   dba_users
WHERE  username = UPPER('&v_schema');
PROMPT

-- ---- Cuotas ---------------------------------------------------------------
PROMPT -- [B] CUOTAS DE TABLESPACE
PROMPT
SELECT
    'ALTER USER "' || username || '"'
    || ' QUOTA ' || CASE WHEN max_bytes = -1 THEN 'UNLIMITED' ELSE TO_CHAR(ROUND(max_bytes/1048576)) || 'M' END
    || ' ON "' || tablespace_name || '";'
FROM   dba_ts_quotas
WHERE  username = UPPER('&v_schema')
ORDER BY tablespace_name;
PROMPT

-- ---- Privilegios de sistema -----------------------------------------------
PROMPT -- [C] PRIVILEGIOS DE SISTEMA
PROMPT
SELECT
    'GRANT ' || privilege
    || CASE WHEN admin_option = 'YES' THEN ' WITH ADMIN OPTION' ELSE '' END
    || ' TO "' || grantee || '";'
FROM   dba_sys_privs
WHERE  grantee = UPPER('&v_schema')
ORDER BY privilege;
PROMPT

-- ---- Roles ----------------------------------------------------------------
PROMPT -- [D] ROLES
PROMPT
SELECT
    'GRANT "' || granted_role || '"'
    || CASE WHEN admin_option = 'YES' THEN ' WITH ADMIN OPTION' ELSE '' END
    || ' TO "' || grantee || '";'
FROM   dba_role_privs
WHERE  grantee = UPPER('&v_schema')
ORDER BY granted_role;
PROMPT

-- ---- Privilegios de objeto recibidos --------------------------------------
PROMPT -- [E] PRIVILEGIOS DE OBJETO RECIBIDOS DE OTROS ESQUEMAS
PROMPT --     VERIFICAR que esos objetos existen en DEV antes de ejecutar
PROMPT
SELECT
    'GRANT ' || privilege
    || ' ON "' || owner || '"."' || table_name || '"'
    || ' TO "' || grantee || '"'
    || CASE WHEN grantable = 'YES' THEN ' WITH GRANT OPTION' ELSE '' END
    || ';'
FROM   dba_tab_privs
WHERE  grantee = UPPER('&v_schema')
  AND  owner  != UPPER('&v_schema')
ORDER BY owner, table_name, privilege;
PROMPT

-- ---- Grants otorgados a otros ---------------------------------------------
PROMPT -- [F] GRANTS OTORGADOS POR ESTE ESQUEMA A OTROS USUARIOS/ROLES
PROMPT
SELECT
    'GRANT ' || privilege
    || ' ON "' || owner || '"."' || table_name || '"'
    || ' TO "' || grantee || '"'
    || CASE WHEN grantable = 'YES' THEN ' WITH GRANT OPTION' ELSE '' END
    || ';'
FROM   dba_tab_privs
WHERE  owner   = UPPER('&v_schema')
  AND  grantee != UPPER('&v_schema')
ORDER BY grantee, table_name, privilege;
PROMPT

-- ---- Sinónimos públicos ---------------------------------------------------
PROMPT -- [G] SINONIMOS PUBLICOS
PROMPT
SELECT
    'CREATE OR REPLACE PUBLIC SYNONYM "' || synonym_name || '"'
    || ' FOR "' || table_owner || '"."' || table_name || '"'
    || CASE WHEN db_link IS NOT NULL THEN '@"' || db_link || '"' ELSE '' END
    || ';'
FROM   dba_synonyms
WHERE  owner       = 'PUBLIC'
  AND  table_owner = UPPER('&v_schema')
ORDER BY synonym_name;
PROMPT

PROMPT -- ==================================================================
PROMPT -- FIN DEL SCRIPT DE PERMISOS
PROMPT -- ==================================================================

SPOOL OFF

SET FEEDBACK ON
SET HEADING  ON
SET PAGESIZE 14
SET VERIFY   ON

PROMPT
PROMPT >>> Informe de diagnóstico : &v_output_rpt
PROMPT >>> Script de permisos DEV : &v_output_ddl
PROMPT
PROMPT >>> PASOS RECOMENDADOS:
PROMPT >>>  1. Revisar &v_output_rpt para detectar problemas antes de migrar
PROMPT >>>  2. Resolver objetos INVALID en PRE (sección 11 del informe)
PROMPT >>>  3. Verificar que los esquemas externos (sección 5 y 8) existen en DEV
PROMPT >>>  4. Ajustar la contraseña en la sección [A] del script generado
PROMPT >>>  5. Aplicar en DEV: sqlplus / as sysdba @&v_output_ddl
PROMPT >>>  6. Si hay triggers (sección 12): considerar deshabilitarlos durante la carga
PROMPT >>>     ALTER TABLE <tabla> DISABLE ALL TRIGGERS;
PROMPT
