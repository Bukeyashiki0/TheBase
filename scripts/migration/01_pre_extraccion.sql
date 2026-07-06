-- =============================================================================
-- 01_pre_extraccion.sql  —  Ejecutar en PRE como SYSDBA
--
--   sqlplus / as sysdba
--   SQL> @01_pre_extraccion.sql
--
-- Genera 3 ficheros:
--   informe_pre.txt          Revisar antes de ejecutar nada en DEV
--   dev_1_antes_carga.sql    Ejecutar en DEV antes de la carga de datos
--   dev_2_despues_carga.sql  Ejecutar en DEV despues de la carga de datos
-- =============================================================================

DEFINE v_schema = 'JOBPROCESOR'

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LONG         2000000
SET LONGCHUNKSIZE 32767
SET LINESIZE     200
SET TRIMSPOOL    ON
SET FEEDBACK     OFF
SET VERIFY       OFF
SET ECHO         OFF

PROMPT
PROMPT ============================================================
PROMPT  EXTRACCION PRE -> DEV  |  Esquema: &v_schema
SELECT ' Fecha: ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS') FROM DUAL;
PROMPT ============================================================
PROMPT


-- ============================================================================
-- FICHERO 1: INFORME  (leer antes de tocar nada en DEV)
-- ============================================================================
SET HEADING ON
SET PAGESIZE 50

SPOOL informe_pre.txt

PROMPT ============================================================
PROMPT  INFORME PRE - ESQUEMA: &v_schema
PROMPT  Este fichero es solo de lectura. NO ejecutar en SQL*Plus.
PROMPT  Abrirlo con un editor de texto (Notepad++, vi, etc.)
SELECT ' Fecha: ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS') FROM DUAL;
PROMPT  Revisar TODO antes de ejecutar en DEV
PROMPT ============================================================

PROMPT
PROMPT --- [1] NLS — comparar con DEV (si NLS_CHARACTERSET difiere: PARAR) ---
SELECT parameter, value FROM nls_database_parameters
WHERE  parameter IN ('NLS_CHARACTERSET','NLS_NCHAR_CHARACTERSET','NLS_DATE_FORMAT',
                     'NLS_NUMERIC_CHARACTERS','NLS_LENGTH_SEMANTICS')
ORDER BY parameter;

PROMPT
PROMPT --- [2] USUARIO ---------------------------------------------------
SELECT username, account_status, default_tablespace,
       temporary_tablespace, profile, created
FROM   dba_users WHERE username = UPPER('&v_schema');

PROMPT
PROMPT --- [3] TABLESPACES usados (deben existir en DEV) ----------------
SELECT segment_type, tablespace_name,
       COUNT(*) objetos, ROUND(SUM(bytes)/1048576,1) mb_usado
FROM   dba_segments WHERE owner = UPPER('&v_schema')
GROUP BY segment_type, tablespace_name ORDER BY segment_type, tablespace_name;

PROMPT
PROMPT --- [4] OBJETOS INVALIDOS en PRE (resolver antes de migrar) ------
SELECT object_type, object_name, last_ddl_time FROM dba_objects
WHERE  owner = UPPER('&v_schema') AND status = 'INVALID' ORDER BY 1, 2;

PROMPT
PROMPT --- [5] DEPENDENCIAS EXTERNAS (deben existir en DEV) -------------
PROMPT  -- Grants recibidos de otros esquemas:
SELECT owner AS esquema_origen, table_name, privilege FROM dba_tab_privs
WHERE  grantee = UPPER('&v_schema') AND owner != UPPER('&v_schema') ORDER BY 1, 2;
PROMPT  -- Sinonimos privados hacia otros esquemas:
SELECT synonym_name, table_owner, table_name, db_link FROM dba_synonyms
WHERE  owner = UPPER('&v_schema') AND table_owner != UPPER('&v_schema') ORDER BY 2, 1;

PROMPT
PROMPT --- [6] DATABASE LINKS (verificar accesibilidad desde DEV) --------
SELECT db_link, username, host FROM dba_db_links
WHERE  owner = UPPER('&v_schema') ORDER BY 1;

PROMPT
PROMPT --- [7] PERFIL (limites que pueden cortar sesiones largas de carga)
SELECT p.resource_name, p.limit FROM dba_profiles p
JOIN   dba_users u ON u.profile = p.profile
WHERE  u.username = UPPER('&v_schema')
AND    p.resource_name IN ('IDLE_TIME','CONNECT_TIME','SESSIONS_PER_USER',
                           'PASSWORD_LIFE_TIME','FAILED_LOGIN_ATTEMPTS')
ORDER BY 1;

PROMPT
PROMPT --- [8] TRIGGERS habilitados (se deshabilitaran antes de la carga) -
SELECT trigger_name, table_name, triggering_event FROM dba_triggers
WHERE  owner = UPPER('&v_schema') AND status = 'ENABLED' ORDER BY 2, 1;

PROMPT
PROMPT --- [9] JOBS activos (se deshabilitaran antes de la carga) ---------
SELECT job_name, state, repeat_interval FROM dba_scheduler_jobs
WHERE  owner = UPPER('&v_schema') AND enabled = 'TRUE' ORDER BY 1;

PROMPT
PROMPT --- [10] RESUMEN de objetos por tipo --------------------------------
SELECT object_type, COUNT(*) total,
       SUM(CASE WHEN status='VALID' THEN 1 ELSE 0 END) validos,
       SUM(CASE WHEN status='INVALID' THEN 1 ELSE 0 END) invalidos
FROM   dba_objects WHERE owner = UPPER('&v_schema')
GROUP BY object_type ORDER BY 1;

SPOOL OFF
PROMPT [OK] informe_pre.txt


-- ============================================================================
-- Configuracion DBMS_METADATA: DDL fiel al origen
--   SEGMENT_ATTRIBUTES=TRUE  conserva TABLESPACE, PCTFREE, INITRANS, LOGGING
--   STORAGE=TRUE             conserva INITIAL, NEXT, MAXEXTENTS
--   TABLESPACE=TRUE          incluye clausula TABLESPACE en cada objeto
-- ============================================================================
BEGIN
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'SEGMENT_ATTRIBUTES',TRUE);
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'STORAGE',           TRUE);
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'TABLESPACE',        TRUE);
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'SQLTERMINATOR',     TRUE);
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'PRETTY',            TRUE);
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'REF_CONSTRAINTS',   FALSE);
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'CONSTRAINTS',       FALSE);
END;
/

SET HEADING  OFF
SET PAGESIZE 0


-- ============================================================================
-- FICHERO 2: DEV — ANTES DE LA CARGA
-- Contiene: tablespaces/cuotas, usuario, privilegios, DDL de objetos,
--           deshabilitacion de FKs/triggers/jobs
-- ============================================================================
SPOOL dev_1_antes_carga.sql

PROMPT -- ==================================================================
PROMPT -- dev_1_antes_carga.sql
PROMPT -- Ejecutar en DEV como SYSDBA ANTES de la carga de datos
PROMPT -- Conexion: sqlplus / as sysdba  o  sqlplus /@DEV as sysdba
SELECT '-- Generado desde PRE el ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS') FROM DUAL;
PROMPT -- ==================================================================
PROMPT
PROMPT SET SERVEROUTPUT ON SIZE UNLIMITED
PROMPT SET FEEDBACK ON
PROMPT SET ECHO OFF
PROMPT

-- --------------------------------------------------------------------------
-- [1] TABLESPACES: verificar que existen y dar cuota
-- --------------------------------------------------------------------------
PROMPT -- ================================================================
PROMPT -- [0] COMPROBACION PREVIA — el script para si DEV no esta limpio
PROMPT -- ================================================================
PROMPT SET SERVEROUTPUT ON SIZE UNLIMITED
PROMPT DECLARE
PROMPT   v_schema   VARCHAR2(128) := '&v_schema';
PROMPT   v_tablas   NUMBER;
PROMPT   v_usuario  NUMBER;
PROMPT BEGIN
PROMPT   SELECT COUNT(*) INTO v_usuario FROM dba_users WHERE username = v_schema;
PROMPT   SELECT COUNT(*) INTO v_tablas  FROM dba_objects
PROMPT   WHERE  owner = v_schema AND object_type = 'TABLE';
PROMPT
PROMPT   IF v_tablas > 0 THEN
PROMPT     DBMS_OUTPUT.PUT_LINE('');
PROMPT     DBMS_OUTPUT.PUT_LINE('*** El esquema '||v_schema||' ya contiene '||v_tablas||' tabla(s) en este entorno.');
PROMPT     DBMS_OUTPUT.PUT_LINE('*** Es necesario eliminar los objetos existentes antes de continuar.');
PROMPT     DBMS_OUTPUT.PUT_LINE('*** Script detenido.');
PROMPT     DBMS_OUTPUT.PUT_LINE('');
PROMPT     RAISE_APPLICATION_ERROR(-20001, 'El esquema '||v_schema||' no esta vacio. Script detenido.');
PROMPT   ELSIF v_usuario > 0 THEN
PROMPT     DBMS_OUTPUT.PUT_LINE('El usuario '||v_schema||' ya existe pero no tiene tablas. Continuando...');
PROMPT   ELSE
PROMPT     DBMS_OUTPUT.PUT_LINE('Entorno limpio para el esquema '||v_schema||'. Continuando...');
PROMPT   END IF;
PROMPT END;
PROMPT /
PROMPT

PROMPT -- [1] TABLESPACES — verificar que existen en DEV y asignar cuota
PROMPT --     Si alguno devuelve 0 en la consulta siguiente: crearlo antes de continuar
PROMPT
DECLARE
  v_owner VARCHAR2(128) := UPPER('&v_schema');
BEGIN
  FOR t IN (
    SELECT DISTINCT tablespace_name FROM dba_segments WHERE owner = v_owner
    UNION
    SELECT default_tablespace   FROM dba_users WHERE username = v_owner
    UNION
    SELECT temporary_tablespace FROM dba_users WHERE username = v_owner
    ORDER BY 1
  ) LOOP
    DBMS_OUTPUT.PUT_LINE(
      'SELECT COUNT(*) "'||t.tablespace_name||' existe en DEV?" FROM dba_tablespaces'
      ||' WHERE tablespace_name='''||t.tablespace_name||''';'
    );
  END LOOP;
END;
/
PROMPT

-- --------------------------------------------------------------------------
-- [2] USUARIO
-- --------------------------------------------------------------------------
PROMPT -- [2] USUARIO — ajustar contrasena antes de ejecutar
PROMPT
SELECT 'CREATE USER "' || username || '"'
    || ' IDENTIFIED BY "CAMBIAR_PASSWORD"'
    || ' DEFAULT TABLESPACE "' || default_tablespace || '"'
    || ' TEMPORARY TABLESPACE "' || temporary_tablespace || '"'
    || ' PROFILE "' || profile || '";'
FROM   dba_users WHERE username = UPPER('&v_schema');
PROMPT
SELECT 'ALTER USER "' || username || '" ACCOUNT UNLOCK;'
FROM   dba_users WHERE username = UPPER('&v_schema');
PROMPT

-- --------------------------------------------------------------------------
-- [3] CUOTAS
-- --------------------------------------------------------------------------
PROMPT -- [3] CUOTAS
PROMPT
DECLARE
  v_owner VARCHAR2(128) := UPPER('&v_schema');
BEGIN
  -- Cuota UNLIMITED en todos los tablespaces de segmentos
  FOR t IN (SELECT DISTINCT tablespace_name FROM dba_segments WHERE owner = v_owner ORDER BY 1) LOOP
    DBMS_OUTPUT.PUT_LINE('ALTER USER "'||v_owner||'" QUOTA UNLIMITED ON "'||t.tablespace_name||'";');
  END LOOP;
  -- Cuotas explicitas del usuario (pueden ser mas restrictivas si se desea)
  FOR q IN (SELECT tablespace_name, max_bytes FROM dba_ts_quotas WHERE username = v_owner ORDER BY 1) LOOP
    DBMS_OUTPUT.PUT_LINE('-- Cuota original en PRE: ALTER USER "'||v_owner||'" QUOTA '
      || CASE WHEN q.max_bytes=-1 THEN 'UNLIMITED' ELSE TO_CHAR(ROUND(q.max_bytes/1048576))||'M' END
      ||' ON "'||q.tablespace_name||'";');
  END LOOP;
END;
/
PROMPT

-- --------------------------------------------------------------------------
-- [4] PRIVILEGIOS DE SISTEMA Y ROLES
-- --------------------------------------------------------------------------
PROMPT -- [4] PRIVILEGIOS DE SISTEMA
PROMPT
SELECT 'GRANT ' || privilege
    || CASE WHEN admin_option='YES' THEN ' WITH ADMIN OPTION' ELSE '' END
    || ' TO "' || grantee || '";'
FROM   dba_sys_privs WHERE grantee = UPPER('&v_schema') ORDER BY 1;
PROMPT

PROMPT -- [5] ROLES
PROMPT
SELECT 'GRANT "' || granted_role || '"'
    || CASE WHEN admin_option='YES' THEN ' WITH ADMIN OPTION' ELSE '' END
    || ' TO "' || grantee || '";'
FROM   dba_role_privs WHERE grantee = UPPER('&v_schema') ORDER BY 1;
PROMPT

-- --------------------------------------------------------------------------
-- [5] GRANTS RECIBIDOS / OTORGADOS / SINONIMOS PUBLICOS / ACLs
-- --------------------------------------------------------------------------
PROMPT -- [6] GRANTS RECIBIDOS DE OTROS ESQUEMAS (verificar que esos objetos existen en DEV)
PROMPT
SELECT 'GRANT ' || privilege || ' ON "' || owner || '"."' || table_name || '"'
    || ' TO "' || grantee || '"'
    || CASE WHEN grantable='YES' THEN ' WITH GRANT OPTION' ELSE '' END || ';'
FROM   dba_tab_privs
WHERE  grantee = UPPER('&v_schema') AND owner != UPPER('&v_schema') ORDER BY 1;
PROMPT

PROMPT -- [7] GRANTS OTORGADOS A OTROS
PROMPT
SELECT 'GRANT ' || privilege || ' ON "' || owner || '"."' || table_name || '"'
    || ' TO "' || grantee || '"'
    || CASE WHEN grantable='YES' THEN ' WITH GRANT OPTION' ELSE '' END || ';'
FROM   dba_tab_privs
WHERE  owner = UPPER('&v_schema') AND grantee != UPPER('&v_schema') ORDER BY 1;
PROMPT

PROMPT -- [8] SINONIMOS PUBLICOS
PROMPT
SELECT 'CREATE OR REPLACE PUBLIC SYNONYM "' || synonym_name || '" FOR "'
    || table_owner || '"."' || table_name || '"'
    || CASE WHEN db_link IS NOT NULL THEN '@"'||db_link||'"' ELSE '' END || ';'
FROM   dba_synonyms WHERE owner='PUBLIC' AND table_owner=UPPER('&v_schema') ORDER BY 1;
PROMPT

PROMPT -- [9] ACLs DE RED (Oracle 12c+)
PROMPT
BEGIN
  FOR r IN (SELECT DISTINCT host, lower_port, upper_port, principal, privilege
            FROM dba_host_aces WHERE principal=UPPER('&v_schema') AND is_grant='TRUE') LOOP
    DBMS_OUTPUT.PUT_LINE(
      'BEGIN DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(host=>'''||r.host||''''
      ||CASE WHEN r.lower_port IS NOT NULL THEN ',lower_port=>'||r.lower_port ELSE '' END
      ||CASE WHEN r.upper_port IS NOT NULL THEN ',upper_port=>'||r.upper_port ELSE '' END
      ||',ace=>xs$ace_type(privilege_list=>xs$privilege_list('''||r.privilege||''')'
      ||',principal_name=>'''||r.principal||''',principal_type=>xs_acl.ptype_db)); END;'
      ||CHR(10)||'/'
    );
  END LOOP;
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('-- ACLs: revisar dba_network_acls (Oracle 11g)');
END;
/
PROMPT

-- --------------------------------------------------------------------------
-- DDL DE OBJETOS (orden de dependencias)
-- --------------------------------------------------------------------------
PROMPT -- ================================================================
PROMPT -- DDL DE OBJETOS
PROMPT -- ================================================================
PROMPT

-- Types
DECLARE
  v_ddl CLOB; v_owner VARCHAR2(128):=UPPER('&v_schema');
BEGIN
  DBMS_OUTPUT.PUT_LINE('-- === TYPES ==='); DBMS_OUTPUT.PUT_LINE('');
  FOR r IN (SELECT object_type, object_name FROM dba_objects
            WHERE owner=v_owner AND object_type IN ('TYPE','TYPE BODY') AND status='VALID'
            AND object_name NOT LIKE 'SYS_PLSQL_%'
            ORDER BY CASE object_type WHEN 'TYPE' THEN 1 ELSE 2 END, object_name) LOOP
    BEGIN
      v_ddl := DBMS_METADATA.GET_DDL(REPLACE(r.object_type,' ','_'), r.object_name, v_owner);
      DBMS_OUTPUT.PUT_LINE(v_ddl); DBMS_OUTPUT.PUT_LINE('/'); DBMS_OUTPUT.PUT_LINE('');
    EXCEPTION WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('-- ERROR '||r.object_type||' '||r.object_name||': '||SQLERRM);
    END;
  END LOOP;
END;
/

-- Sequences
DECLARE
  v_ddl CLOB; v_owner VARCHAR2(128):=UPPER('&v_schema');
BEGIN
  DBMS_OUTPUT.PUT_LINE('-- === SEQUENCES ==='); DBMS_OUTPUT.PUT_LINE('');
  FOR r IN (SELECT object_name FROM dba_objects
            WHERE owner=v_owner AND object_type='SEQUENCE' AND status='VALID'
            ORDER BY object_name) LOOP
    BEGIN
      v_ddl := DBMS_METADATA.GET_DDL('SEQUENCE', r.object_name, v_owner);
      DBMS_OUTPUT.PUT_LINE(v_ddl); DBMS_OUTPUT.PUT_LINE('/'); DBMS_OUTPUT.PUT_LINE('');
    EXCEPTION WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('-- ERROR SEQUENCE '||r.object_name||': '||SQLERRM);
    END;
  END LOOP;
END;
/

-- Materialized View Logs (antes que tablas base)
DECLARE
  v_ddl CLOB; v_owner VARCHAR2(128):=UPPER('&v_schema');
BEGIN
  DBMS_OUTPUT.PUT_LINE('-- === MATERIALIZED VIEW LOGS ==='); DBMS_OUTPUT.PUT_LINE('');
  FOR r IN (SELECT log_table FROM dba_mview_logs WHERE log_owner=v_owner ORDER BY 1) LOOP
    BEGIN
      v_ddl := DBMS_METADATA.GET_DDL('MATERIALIZED_VIEW_LOG', r.log_table, v_owner);
      DBMS_OUTPUT.PUT_LINE(v_ddl); DBMS_OUTPUT.PUT_LINE('/'); DBMS_OUTPUT.PUT_LINE('');
    EXCEPTION WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('-- ERROR MVIEW LOG '||r.log_table||': '||SQLERRM);
    END;
  END LOOP;
END;
/

-- Tables
DECLARE
  v_ddl CLOB; v_owner VARCHAR2(128):=UPPER('&v_schema');
BEGIN
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'CONSTRAINTS',FALSE);
  DBMS_OUTPUT.PUT_LINE('-- === TABLES ==='); DBMS_OUTPUT.PUT_LINE('');
  FOR r IN (SELECT object_name FROM dba_objects
            WHERE owner=v_owner AND object_type='TABLE' AND status='VALID'
            AND object_name NOT LIKE 'BIN$%' ORDER BY object_name) LOOP
    BEGIN
      v_ddl := DBMS_METADATA.GET_DDL('TABLE', r.object_name, v_owner);
      DBMS_OUTPUT.PUT_LINE(v_ddl); DBMS_OUTPUT.PUT_LINE('/'); DBMS_OUTPUT.PUT_LINE('');
    EXCEPTION WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('-- ERROR TABLE '||r.object_name||': '||SQLERRM);
    END;
  END LOOP;
END;
/

-- Indexes (excluye los generados por PK/UK)
DECLARE
  v_ddl CLOB; v_owner VARCHAR2(128):=UPPER('&v_schema');
BEGIN
  DBMS_OUTPUT.PUT_LINE('-- === INDEXES ==='); DBMS_OUTPUT.PUT_LINE('');
  FOR r IN (SELECT i.index_name FROM dba_indexes i
            WHERE i.owner=v_owner AND i.index_name NOT LIKE 'BIN$%'
            AND NOT EXISTS (SELECT 1 FROM dba_constraints c
                            WHERE c.owner=v_owner AND c.index_name=i.index_name
                            AND c.constraint_type IN ('P','U'))
            ORDER BY i.index_name) LOOP
    BEGIN
      v_ddl := DBMS_METADATA.GET_DDL('INDEX', r.index_name, v_owner);
      DBMS_OUTPUT.PUT_LINE(v_ddl); DBMS_OUTPUT.PUT_LINE('/'); DBMS_OUTPUT.PUT_LINE('');
    EXCEPTION WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('-- ERROR INDEX '||r.index_name||': '||SQLERRM);
    END;
  END LOOP;
END;
/

-- PK, UK, Check constraints
DECLARE
  v_ddl CLOB; v_owner VARCHAR2(128):=UPPER('&v_schema');
BEGIN
  DBMS_OUTPUT.PUT_LINE('-- === PK / UK / CHECK CONSTRAINTS ==='); DBMS_OUTPUT.PUT_LINE('');
  FOR r IN (SELECT constraint_name, constraint_type FROM dba_constraints
            WHERE owner=v_owner AND constraint_type IN ('P','U','C') AND status='ENABLED'
            AND (constraint_type != 'C' OR generated='USER NAME')
            ORDER BY CASE constraint_type WHEN 'P' THEN 1 WHEN 'U' THEN 2 ELSE 3 END,
                     table_name, constraint_name) LOOP
    BEGIN
      v_ddl := DBMS_METADATA.GET_DDL('CONSTRAINT', r.constraint_name, v_owner);
      DBMS_OUTPUT.PUT_LINE(v_ddl); DBMS_OUTPUT.PUT_LINE('/'); DBMS_OUTPUT.PUT_LINE('');
    EXCEPTION WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('-- ERROR CONSTRAINT '||r.constraint_name||': '||SQLERRM);
    END;
  END LOOP;
END;
/

-- Foreign Keys
DECLARE
  v_ddl CLOB; v_owner VARCHAR2(128):=UPPER('&v_schema');
BEGIN
  DBMS_OUTPUT.PUT_LINE('-- === FOREIGN KEYS ==='); DBMS_OUTPUT.PUT_LINE('');
  FOR r IN (SELECT constraint_name FROM dba_constraints
            WHERE owner=v_owner AND constraint_type='R' AND status='ENABLED'
            ORDER BY table_name, constraint_name) LOOP
    BEGIN
      v_ddl := DBMS_METADATA.GET_DDL('REF_CONSTRAINT', r.constraint_name, v_owner);
      DBMS_OUTPUT.PUT_LINE(v_ddl); DBMS_OUTPUT.PUT_LINE('/'); DBMS_OUTPUT.PUT_LINE('');
    EXCEPTION WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('-- ERROR FK '||r.constraint_name||': '||SQLERRM);
    END;
  END LOOP;
END;
/

-- Materialized Views
DECLARE
  v_ddl CLOB; v_owner VARCHAR2(128):=UPPER('&v_schema');
BEGIN
  DBMS_OUTPUT.PUT_LINE('-- === MATERIALIZED VIEWS ==='); DBMS_OUTPUT.PUT_LINE('');
  FOR r IN (SELECT object_name FROM dba_objects
            WHERE owner=v_owner AND object_type='MATERIALIZED VIEW' AND status='VALID'
            ORDER BY object_name) LOOP
    BEGIN
      v_ddl := DBMS_METADATA.GET_DDL('MATERIALIZED_VIEW', r.object_name, v_owner);
      DBMS_OUTPUT.PUT_LINE(v_ddl); DBMS_OUTPUT.PUT_LINE('/'); DBMS_OUTPUT.PUT_LINE('');
    EXCEPTION WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('-- ERROR MVIEW '||r.object_name||': '||SQLERRM);
    END;
  END LOOP;
END;
/

-- Views
DECLARE
  v_ddl CLOB; v_owner VARCHAR2(128):=UPPER('&v_schema');
BEGIN
  DBMS_OUTPUT.PUT_LINE('-- === VIEWS ==='); DBMS_OUTPUT.PUT_LINE('');
  FOR r IN (SELECT object_name FROM dba_objects
            WHERE owner=v_owner AND object_type='VIEW' AND status='VALID'
            ORDER BY object_name) LOOP
    BEGIN
      v_ddl := DBMS_METADATA.GET_DDL('VIEW', r.object_name, v_owner);
      DBMS_OUTPUT.PUT_LINE(v_ddl); DBMS_OUTPUT.PUT_LINE('/'); DBMS_OUTPUT.PUT_LINE('');
    EXCEPTION WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('-- ERROR VIEW '||r.object_name||': '||SQLERRM);
    END;
  END LOOP;
END;
/

-- Stored code
DECLARE
  v_ddl CLOB; v_owner VARCHAR2(128):=UPPER('&v_schema');
BEGIN
  DBMS_OUTPUT.PUT_LINE('-- === STORED CODE ==='); DBMS_OUTPUT.PUT_LINE('');
  FOR r IN (SELECT object_type, object_name FROM dba_objects
            WHERE owner=v_owner AND status='VALID'
            AND object_type IN ('PROCEDURE','FUNCTION','PACKAGE','PACKAGE BODY','TRIGGER')
            ORDER BY CASE object_type
              WHEN 'PACKAGE'      THEN 1 WHEN 'PACKAGE BODY' THEN 2
              WHEN 'PROCEDURE'    THEN 3 WHEN 'FUNCTION'     THEN 4
              WHEN 'TRIGGER'      THEN 5 ELSE 6 END, object_name) LOOP
    BEGIN
      v_ddl := DBMS_METADATA.GET_DDL(REPLACE(r.object_type,' ','_'), r.object_name, v_owner);
      DBMS_OUTPUT.PUT_LINE(v_ddl); DBMS_OUTPUT.PUT_LINE('/'); DBMS_OUTPUT.PUT_LINE('');
    EXCEPTION WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('-- ERROR '||r.object_type||' '||r.object_name||': '||SQLERRM);
    END;
  END LOOP;
END;
/

-- Synonyms
DECLARE
  v_ddl CLOB; v_owner VARCHAR2(128):=UPPER('&v_schema');
BEGIN
  DBMS_OUTPUT.PUT_LINE('-- === SYNONYMS ==='); DBMS_OUTPUT.PUT_LINE('');
  FOR r IN (SELECT object_name FROM dba_objects
            WHERE owner=v_owner AND object_type='SYNONYM' AND status='VALID'
            ORDER BY object_name) LOOP
    BEGIN
      v_ddl := DBMS_METADATA.GET_DDL('SYNONYM', r.object_name, v_owner);
      DBMS_OUTPUT.PUT_LINE(v_ddl); DBMS_OUTPUT.PUT_LINE('/'); DBMS_OUTPUT.PUT_LINE('');
    EXCEPTION WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('-- ERROR SYNONYM '||r.object_name||': '||SQLERRM);
    END;
  END LOOP;
END;
/

-- Database Links
DECLARE
  v_ddl CLOB; v_owner VARCHAR2(128):=UPPER('&v_schema');
BEGIN
  DBMS_OUTPUT.PUT_LINE('-- === DATABASE LINKS ==='); DBMS_OUTPUT.PUT_LINE('');
  FOR r IN (SELECT object_name FROM dba_objects
            WHERE owner=v_owner AND object_type='DATABASE LINK' ORDER BY object_name) LOOP
    BEGIN
      v_ddl := DBMS_METADATA.GET_DDL('DB_LINK', r.object_name, v_owner);
      DBMS_OUTPUT.PUT_LINE(v_ddl); DBMS_OUTPUT.PUT_LINE('/'); DBMS_OUTPUT.PUT_LINE('');
    EXCEPTION WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('-- ERROR DB_LINK '||r.object_name||': '||SQLERRM);
    END;
  END LOOP;
END;
/

-- Comments
DECLARE
  v_ddl CLOB; v_owner VARCHAR2(128):=UPPER('&v_schema');
BEGIN
  DBMS_OUTPUT.PUT_LINE('-- === COMMENTS ==='); DBMS_OUTPUT.PUT_LINE('');
  FOR r IN (SELECT DISTINCT table_name FROM
              (SELECT table_name FROM dba_tab_comments WHERE owner=v_owner AND comments IS NOT NULL
               UNION
               SELECT table_name FROM dba_col_comments WHERE owner=v_owner AND comments IS NOT NULL)
            ORDER BY 1) LOOP
    BEGIN
      v_ddl := DBMS_METADATA.GET_DEPENDENT_DDL('COMMENT', r.table_name, v_owner);
      IF v_ddl IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE(v_ddl); DBMS_OUTPUT.PUT_LINE('/'); DBMS_OUTPUT.PUT_LINE('');
      END IF;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END LOOP;
END;
/

-- Object grants
DECLARE
  v_ddl CLOB; v_owner VARCHAR2(128):=UPPER('&v_schema');
BEGIN
  DBMS_OUTPUT.PUT_LINE('-- === OBJECT GRANTS ==='); DBMS_OUTPUT.PUT_LINE('');
  FOR r IN (SELECT DISTINCT object_name, object_type FROM dba_objects
            WHERE owner=v_owner AND status='VALID'
            AND object_type IN ('TABLE','VIEW','SEQUENCE','PROCEDURE','FUNCTION','PACKAGE','TYPE')
            ORDER BY object_type, object_name) LOOP
    BEGIN
      v_ddl := DBMS_METADATA.GET_DEPENDENT_DDL('OBJECT_GRANT', r.object_name, v_owner);
      IF v_ddl IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE(v_ddl); DBMS_OUTPUT.PUT_LINE('/'); DBMS_OUTPUT.PUT_LINE('');
      END IF;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END LOOP;
END;
/

-- --------------------------------------------------------------------------
-- DESHABILITAR FKs, TRIGGERS y JOBS antes de la carga
-- --------------------------------------------------------------------------
PROMPT -- ================================================================
PROMPT -- DESHABILITAR ANTES DE LA CARGA
PROMPT -- ================================================================
PROMPT

PROMPT -- Foreign Keys
PROMPT
SELECT 'ALTER TABLE "'||UPPER('&v_schema')||'"."'||table_name
    ||'" DISABLE CONSTRAINT "'||constraint_name||'";'
FROM   dba_constraints
WHERE  owner=UPPER('&v_schema') AND constraint_type='R'
ORDER BY table_name, constraint_name;
PROMPT

PROMPT -- Triggers
PROMPT
SELECT 'ALTER TRIGGER "'||UPPER('&v_schema')||'"."'||trigger_name||'" DISABLE;'
FROM   dba_triggers WHERE owner=UPPER('&v_schema') ORDER BY trigger_name;
PROMPT

PROMPT -- Jobs del Scheduler
PROMPT
SELECT 'BEGIN DBMS_SCHEDULER.DISABLE(''"'||UPPER('&v_schema')||'"."'||job_name||'"''); END;'
    ||CHR(10)||'/'
FROM   dba_scheduler_jobs WHERE owner=UPPER('&v_schema') AND enabled='TRUE' ORDER BY job_name;
PROMPT

PROMPT -- DBMS_JOB (legacy)
PROMPT
SELECT 'BEGIN DBMS_JOB.BROKEN('||job||',TRUE); COMMIT; END;'||CHR(10)||'/'
FROM   dba_jobs WHERE schema_user=UPPER('&v_schema') AND broken='N' ORDER BY job;
PROMPT

PROMPT -- ================================================================
PROMPT -- >>> REALIZAR LA CARGA DE DATOS AHORA <<<
PROMPT -- Cuando termine, ejecutar: dev_2_despues_carga.sql
PROMPT -- ================================================================

SPOOL OFF
PROMPT [OK] dev_1_antes_carga.sql


-- ============================================================================
-- FICHERO 3: DEV — DESPUES DE LA CARGA
-- Contiene: rehabilitar FKs/triggers/jobs, reajustar secuencias,
--           recompilar invalidos, validacion final
-- ============================================================================
SPOOL dev_2_despues_carga.sql

PROMPT -- ==================================================================
PROMPT -- dev_2_despues_carga.sql
PROMPT -- Ejecutar en DEV como SYSDBA DESPUES de la carga de datos
SELECT '-- Generado desde PRE el ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS') FROM DUAL;
PROMPT -- ==================================================================
PROMPT
PROMPT SET SERVEROUTPUT ON SIZE UNLIMITED
PROMPT SET FEEDBACK ON
PROMPT SET LINESIZE 200
PROMPT SET PAGESIZE 50
PROMPT

PROMPT -- [1] REHABILITAR TRIGGERS
PROMPT
SELECT 'ALTER TRIGGER "'||UPPER('&v_schema')||'"."'||trigger_name||'" ENABLE;'
FROM   dba_triggers WHERE owner=UPPER('&v_schema') ORDER BY trigger_name;
PROMPT

PROMPT -- [2] REHABILITAR FOREIGN KEYS (NOVALIDATE: no releer todos los datos)
PROMPT
SELECT 'ALTER TABLE "'||UPPER('&v_schema')||'"."'||table_name
    ||'" ENABLE NOVALIDATE CONSTRAINT "'||constraint_name||'";'
FROM   dba_constraints
WHERE  owner=UPPER('&v_schema') AND constraint_type='R'
ORDER BY table_name, constraint_name;
PROMPT

PROMPT -- [3] REHABILITAR JOBS
PROMPT
SELECT 'BEGIN DBMS_SCHEDULER.ENABLE(''"'||UPPER('&v_schema')||'"."'||job_name||'"''); END;'||CHR(10)||'/'
FROM   dba_scheduler_jobs WHERE owner=UPPER('&v_schema') ORDER BY job_name;
PROMPT
SELECT 'BEGIN DBMS_JOB.BROKEN('||job||',FALSE,SYSDATE); COMMIT; END;'||CHR(10)||'/'
FROM   dba_jobs WHERE schema_user=UPPER('&v_schema') ORDER BY job;
PROMPT

PROMPT -- [4] REAJUSTAR SECUENCIAS al maximo de los datos cargados en DEV
PROMPT --     Evita ORA-00001 cuando la aplicacion use NEXTVAL
PROMPT DECLARE
PROMPT   v_owner VARCHAR2(128) := '&v_schema';
PROMPT   v_col   VARCHAR2(128);
PROMPT   v_table VARCHAR2(128);
PROMPT   v_max   NUMBER;
PROMPT   v_curr  NUMBER;
PROMPT   v_diff  NUMBER;
PROMPT BEGIN
PROMPT   FOR s IN (SELECT sequence_name, last_number FROM dba_sequences
PROMPT             WHERE sequence_owner = v_owner ORDER BY sequence_name) LOOP
PROMPT     BEGIN
PROMPT       SELECT c.table_name, c.column_name INTO v_table, v_col
PROMPT       FROM   dba_tab_columns c
PROMPT       WHERE  c.owner = v_owner
PROMPT         AND  UPPER(c.data_default) LIKE '%'||s.sequence_name||'%'
PROMPT         AND  ROWNUM = 1;
PROMPT       EXECUTE IMMEDIATE
PROMPT         'SELECT NVL(MAX("'||v_col||'"),0) FROM "'||v_owner||'"."'||v_table||'"'
PROMPT         INTO v_max;
PROMPT       v_curr := s.last_number;
PROMPT       v_diff := v_max - v_curr + 1;
PROMPT       IF v_diff > 0 THEN
PROMPT         EXECUTE IMMEDIATE 'ALTER SEQUENCE "'||v_owner||'"."'||s.sequence_name||'" INCREMENT BY '||v_diff;
PROMPT         EXECUTE IMMEDIATE 'SELECT "'||v_owner||'"."'||s.sequence_name||'".NEXTVAL FROM DUAL';
PROMPT         EXECUTE IMMEDIATE 'ALTER SEQUENCE "'||v_owner||'"."'||s.sequence_name||'" INCREMENT BY 1';
PROMPT         DBMS_OUTPUT.PUT_LINE('Ajustada: '||s.sequence_name||' -> '||v_max||' ('||v_table||'.'||v_col||')');
PROMPT       ELSE
PROMPT         DBMS_OUTPUT.PUT_LINE('OK: '||s.sequence_name||' (sin ajuste necesario)');
PROMPT       END IF;
PROMPT     EXCEPTION WHEN NO_DATA_FOUND THEN
PROMPT       DBMS_OUTPUT.PUT_LINE('ATENCION: '||s.sequence_name||' sin columna DEFAULT asociada - revisar manualmente');
PROMPT     END;
PROMPT   END LOOP;
PROMPT END;
PROMPT /
PROMPT

PROMPT -- [5] RECOMPILAR OBJETOS INVALIDOS
PROMPT BEGIN
PROMPT   DBMS_UTILITY.COMPILE_SCHEMA(schema => '&v_schema', compile_all => FALSE);
PROMPT END;
PROMPT /
PROMPT

PROMPT -- ================================================================
PROMPT -- VALIDACION FINAL
PROMPT -- ================================================================
PROMPT

PROMPT -- Objetos invalidos (debe ser 0 filas):
PROMPT SELECT object_type, object_name, status FROM dba_objects
PROMPT WHERE  owner = '&v_schema' AND status = 'INVALID' ORDER BY 1, 2;
PROMPT

PROMPT -- Resumen por tipo:
PROMPT SELECT object_type, COUNT(*) total,
PROMPT        SUM(CASE WHEN status='VALID' THEN 1 ELSE 0 END) validos,
PROMPT        SUM(CASE WHEN status='INVALID' THEN 1 ELSE 0 END) invalidos
PROMPT FROM   dba_objects WHERE owner = '&v_schema'
PROMPT GROUP BY object_type ORDER BY object_type;
PROMPT

PROMPT -- Secuencias: NEXTVAL debe ser mayor que el MAX de cada tabla (0 alertas):
PROMPT DECLARE
PROMPT   v_owner VARCHAR2(128) := '&v_schema';
PROMPT   v_col VARCHAR2(128); v_table VARCHAR2(128); v_max NUMBER;
PROMPT BEGIN
PROMPT   FOR s IN (SELECT sequence_name, last_number FROM dba_sequences
PROMPT             WHERE sequence_owner=v_owner ORDER BY sequence_name) LOOP
PROMPT     BEGIN
PROMPT       SELECT c.table_name, c.column_name INTO v_table, v_col
PROMPT       FROM   dba_tab_columns c
PROMPT       WHERE  c.owner=v_owner AND UPPER(c.data_default) LIKE '%'||s.sequence_name||'%' AND ROWNUM=1;
PROMPT       EXECUTE IMMEDIATE 'SELECT NVL(MAX("'||v_col||'"),0) FROM "'||v_owner||'"."'||v_table||'"' INTO v_max;
PROMPT       IF s.last_number <= v_max THEN
PROMPT         DBMS_OUTPUT.PUT_LINE('*** ALERTA: '||s.sequence_name||' NEXTVAL='||s.last_number||' <= MAX='||v_max||' -> riesgo ORA-00001');
PROMPT       ELSE
PROMPT         DBMS_OUTPUT.PUT_LINE('OK: '||s.sequence_name||' NEXTVAL='||s.last_number||' > MAX='||v_max);
PROMPT       END IF;
PROMPT     EXCEPTION WHEN OTHERS THEN
PROMPT       DBMS_OUTPUT.PUT_LINE('INFO: '||s.sequence_name||' sin columna DEFAULT asociada');
PROMPT     END;
PROMPT   END LOOP;
PROMPT END;
PROMPT /
PROMPT

PROMPT -- Tablespaces que usan los objetos vs los que existen en DEV:
PROMPT SELECT DISTINCT s.tablespace_name,
PROMPT        CASE WHEN t.tablespace_name IS NOT NULL THEN 'OK' ELSE '*** NO EXISTE ***' END estado
PROMPT FROM   dba_segments s
PROMPT LEFT   JOIN dba_tablespaces t ON t.tablespace_name = s.tablespace_name
PROMPT WHERE  s.owner = '&v_schema' ORDER BY 1;

SPOOL OFF
PROMPT [OK] dev_2_despues_carga.sql


-- ============================================================================
-- RESUMEN
-- ============================================================================
SET HEADING  ON
SET PAGESIZE 14
SET FEEDBACK ON
SET VERIFY   ON

PROMPT
PROMPT ============================================================
PROMPT  FICHEROS GENERADOS — esquema: &v_schema
PROMPT ============================================================
PROMPT
PROMPT  [REVISAR EN PRE ANTES DE NADA]
PROMPT  informe_pre.txt
PROMPT    -> NLS: si NLS_CHARACTERSET difiere con DEV, PARAR
PROMPT    -> Tablespaces: asegurarse de que existen en DEV
PROMPT    -> Objetos invalidos: resolver en PRE antes de migrar
PROMPT    -> Dependencias externas: verificar que existen en DEV
PROMPT
PROMPT  [COPIAR A DEV Y EJECUTAR EN ORDEN]
PROMPT  1. dev_1_antes_carga.sql   (como SYSDBA)
PROMPT       >>> CARGA DE DATOS <<<
PROMPT  2. dev_2_despues_carga.sql (como SYSDBA)
PROMPT ============================================================
PROMPT
