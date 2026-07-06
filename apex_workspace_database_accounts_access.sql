-- Consultas para investigar el acceso de usuarios a un workspace de Oracle APEX
-- que usa el esquema de autenticacion "Database Account Credentials".
--
-- Requiere privilegios de DBA / administrador de instancia de APEX.
-- Sustituir YOUR_WORKSPACE y SCHEMA_DEL_WORKSPACE segun corresponda.

-- 1. Datos generales del workspace
SELECT workspace_id, workspace_name, workspace_display_name
FROM   apex_workspaces
WHERE  workspace_name = 'YOUR_WORKSPACE';

-- 2. Schema(s) de base de datos asociado(s) al workspace
SELECT workspace_id, workspace_name, schema
FROM   apex_workspace_schemas
WHERE  workspace_name = 'YOUR_WORKSPACE';

-- 3. Aplicaciones del workspace que usan Database Account Credentials
-- (el nombre de vista/columna puede variar segun version de APEX;
--  verificar con: SELECT * FROM dictionary WHERE table_name LIKE 'APEX_APPL%AUTH%';)
SELECT a.application_id,
       a.application_name,
       a.owner            AS parsing_schema,
       auth.authentication_type
FROM   apex_applications a
JOIN   apex_application_authentication auth
       ON auth.application_id = a.application_id
WHERE  a.workspace = 'YOUR_WORKSPACE'
  AND  auth.authentication_type IN ('DB_ACCOUNT', 'DATABASE_ACCOUNT');

-- 4. Cuentas de base de datos activas que podrian autenticarse
SELECT username, account_status, lock_date, expiry_date, default_tablespace
FROM   dba_users
WHERE  account_status = 'OPEN'
ORDER BY username;

-- 5. De esas cuentas, cuales tienen privilegio de conexion (CREATE SESSION),
--    directo o via rol
SELECT grantee, privilege
FROM   dba_sys_privs
WHERE  privilege = 'CREATE SESSION'
UNION
SELECT rp.grantee, sp.privilege
FROM   dba_role_privs rp
JOIN   dba_sys_privs  sp ON sp.grantee = rp.granted_role
WHERE  sp.privilege = 'CREATE SESSION';

-- 6. Privilegios de objeto concedidos sobre el schema del workspace
SELECT grantee, owner, table_name, privilege
FROM   dba_tab_privs
WHERE  owner = 'SCHEMA_DEL_WORKSPACE'
ORDER BY grantee;

-- 7. Roles/privilegios de sistema otorgados al propio schema del workspace
SELECT grantee, granted_role
FROM   dba_role_privs
WHERE  grantee = 'SCHEMA_DEL_WORKSPACE';
