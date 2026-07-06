-- Runbook para extraer usuarios/perfiles de una aplicacion Oracle APEX
-- cuyo workspace tiene activo "Database Accounts" (autenticacion contra
-- cuentas nativas de la base de datos, no usuarios internos de APEX).
--
-- Sustituir los valores entre &&: WORKSPACE_NAME, APP_ID, SCHEMA_NAME, PDB_NAME.
-- Requiere conexion con privilegios DBA (SYSDBA o rol equivalente).

-- =====================================================================
-- PASO 0: Confirmar que la sesion esta en el PDB donde vive APEX
-- =====================================================================
SHOW CON_NAME;

SELECT name, open_mode FROM v$pdbs;

-- Si hace falta, cambiar de contenedor:
-- ALTER SESSION SET CONTAINER = &&PDB_NAME;

SELECT owner, synonym_name
FROM   dba_synonyms
WHERE  synonym_name = 'APEX_WORKSPACES';

-- =====================================================================
-- PASO 1: Ubicar la aplicacion y su schema de analisis (parsing schema)
-- =====================================================================
SELECT application_id, application_name, alias, owner AS parsing_schema, workspace
FROM   apex_applications
WHERE  workspace = '&&WORKSPACE_NAME'
ORDER BY application_id;

-- =====================================================================
-- PASO 2: Confirmar el esquema de autenticacion de la aplicacion
-- =====================================================================
SELECT application_id, authentication_type, scheme_name
FROM   apex_application_authentication
WHERE  application_id = &&APP_ID;

-- =====================================================================
-- PASO 3: Usuarios de workspace registrados en APEX (admins/developers)
-- APEX mantiene esta lista aunque la autenticacion sea Database Accounts
-- =====================================================================
SELECT workspace_name, user_name, default_schema, account_type, last_access_date
FROM   apex_workspace_apex_users
WHERE  workspace_name = '&&WORKSPACE_NAME'
ORDER BY user_name;

-- =====================================================================
-- PASO 4: Cuentas de base de datos que pueden autenticarse como
-- usuarios finales de la aplicacion (LOGIN ID real)
-- =====================================================================
SELECT username AS login_id, account_status, created, lock_date, comments
FROM   dba_users
WHERE  account_status = 'OPEN'
ORDER BY username;

-- Acotado a quienes tienen privilegios sobre el schema de la aplicacion
SELECT grantee, privilege
FROM   dba_tab_privs
WHERE  owner = '&&SCHEMA_NAME'
ORDER BY grantee;

-- =====================================================================
-- PASO 5: FULLNAME / ID CORPORATIVO / PROFILE
-- Oracle no almacena nombre completo ni perfil de negocio de una cuenta
-- nativa de BD. Revisar estas dos fuentes antes de descartar el dato:
-- =====================================================================

-- 5a. Comentario documentado al crear la cuenta (si existe)
SELECT username, comments
FROM   dba_users
WHERE  username = '&&LOGIN_ID';

-- 5b. Esquemas de autorizacion/grupos propios de la aplicacion APEX
SELECT application_id, name, scheme_type
FROM   apex_application_authorization
WHERE  application_id = &&APP_ID;

SELECT application_id, group_id, group_name
FROM   apex_application_groups
WHERE  application_id = &&APP_ID;

-- Si ninguna de las dos fuentes anteriores tiene datos, el FULLNAME /
-- ID CORPORATIVO / PROFILE no reside en la base de datos: hay que
-- solicitarlo al dueño funcional de la aplicacion.

-- =====================================================================
-- PASO 6: Evidencia para auditoria SOX
-- =====================================================================

-- Marca de tiempo para el pantallazo de la query
SELECT SYSDATE FROM DUAL;

-- Primeros registros
SELECT * FROM (
    SELECT username AS login_id, account_status, created
    FROM   dba_users
    WHERE  account_status = 'OPEN'
    ORDER BY username
) FETCH FIRST 5 ROWS ONLY;

-- Ultimos registros
SELECT * FROM (
    SELECT username AS login_id, account_status, created
    FROM   dba_users
    WHERE  account_status = 'OPEN'
    ORDER BY username DESC
) FETCH FIRST 5 ROWS ONLY;

-- Total de registros
SELECT COUNT(*) AS total_registros
FROM   dba_users
WHERE  account_status = 'OPEN';
