-- =============================================================================
-- extract_ddl_pre_to_dev.sql
-- Genera un script con los DDLs de todos los objetos de un esquema en PRE
-- para recrearlos en DEV.
--
-- INSTRUCCIONES DE USO:
--   1. Conectarse a la base de datos PRE como SYSDBA (autenticación SO):
--         sqlplus / as sysdba
--      Si la BD es remota indicar el servicio:
--         sqlplus /@PRE as sysdba
--   2. Ajustar la variable v_schema con el nombre del esquema origen.
--   3. Ejecutar el script desde SQL*Plus:
--         SQL> @extract_ddl_pre_to_dev.sql
--   4. El spool genera el fichero 'ddl_dev_<SCHEMA>.sql' listo para ejecutar en DEV.
-- =============================================================================

-- ---- Parámetros editables ---------------------------------------------------
DEFINE v_schema        = 'NOMBRE_ESQUEMA'    -- Esquema origen en PRE (en mayúsculas)
DEFINE v_tablespace    = 'USERS'             -- Tablespace destino en DEV
DEFINE v_output_file   = 'ddl_dev_&v_schema..sql'
-- ----------------------------------------------------------------------------

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LONG        2000000
SET LONGCHUNKSIZE 32767
SET LINESIZE    32767
SET TRIMSPOOL   ON
SET FEEDBACK    OFF
SET VERIFY      OFF
SET HEADING     OFF
SET PAGESIZE    0
SET ECHO        OFF

SPOOL &v_output_file

PROMPT -- ==========================================================
PROMPT -- DDL generado desde PRE para el esquema: &v_schema
PROMPT -- Fecha:
SELECT '-- ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS') FROM DUAL;
PROMPT -- Destino tablespace: &v_tablespace
PROMPT -- ==========================================================
PROMPT

-- ---------------------------------------------------------------------------
-- Configuración de DBMS_METADATA para obtener DDL limpio
-- ---------------------------------------------------------------------------
BEGIN
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'STORAGE',         FALSE);
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'TABLESPACE',       TRUE);
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'SEGMENT_ATTRIBUTES', FALSE);
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'SQLTERMINATOR',    TRUE);
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'PRETTY',           TRUE);
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'REF_CONSTRAINTS',  FALSE); -- se sacan por separado
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'CONSTRAINTS',      FALSE); -- se sacan por separado
END;
/

-- ---------------------------------------------------------------------------
-- 1. SEQUENCES
-- ---------------------------------------------------------------------------
PROMPT -- ==================== SEQUENCES ====================
PROMPT

DECLARE
    v_ddl   CLOB;
    v_owner VARCHAR2(128) := UPPER('&v_schema');
BEGIN
    FOR r IN (
        SELECT object_name
        FROM   dba_objects
        WHERE  owner       = v_owner
          AND  object_type = 'SEQUENCE'
          AND  status      = 'VALID'
        ORDER BY object_name
    ) LOOP
        BEGIN
            v_ddl := DBMS_METADATA.GET_DDL('SEQUENCE', r.object_name, v_owner);
            -- Reasignar tablespace si aplica
            v_ddl := REGEXP_REPLACE(v_ddl, 'TABLESPACE\s+"[^"]+"', 'TABLESPACE "&v_tablespace"', 1, 0, 'i');
            DBMS_OUTPUT.PUT_LINE(v_ddl);
            DBMS_OUTPUT.PUT_LINE('/');
            DBMS_OUTPUT.PUT_LINE('');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('-- ERROR extrayendo SEQUENCE ' || r.object_name || ': ' || SQLERRM);
        END;
    END LOOP;
END;
/

-- ---------------------------------------------------------------------------
-- 2. TABLES (sin constraints, sin storage)
-- ---------------------------------------------------------------------------
PROMPT -- ==================== TABLES ====================
PROMPT

DECLARE
    v_ddl   CLOB;
    v_owner VARCHAR2(128) := UPPER('&v_schema');
BEGIN
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'CONSTRAINTS', FALSE);

    FOR r IN (
        SELECT object_name
        FROM   dba_objects
        WHERE  owner       = v_owner
          AND  object_type = 'TABLE'
          AND  status      = 'VALID'
          AND  object_name NOT LIKE 'BIN$%'   -- excluir papelera
        ORDER BY object_name
    ) LOOP
        BEGIN
            v_ddl := DBMS_METADATA.GET_DDL('TABLE', r.object_name, v_owner);
            v_ddl := REGEXP_REPLACE(v_ddl, 'TABLESPACE\s+"[^"]+"', 'TABLESPACE "&v_tablespace"', 1, 0, 'i');
            DBMS_OUTPUT.PUT_LINE(v_ddl);
            DBMS_OUTPUT.PUT_LINE('/');
            DBMS_OUTPUT.PUT_LINE('');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('-- ERROR extrayendo TABLE ' || r.object_name || ': ' || SQLERRM);
        END;
    END LOOP;
END;
/

-- ---------------------------------------------------------------------------
-- 3. INDEXES (excluye los generados automáticamente por PK/UK)
-- ---------------------------------------------------------------------------
PROMPT -- ==================== INDEXES ====================
PROMPT

DECLARE
    v_ddl   CLOB;
    v_owner VARCHAR2(128) := UPPER('&v_schema');
BEGIN
    FOR r IN (
        SELECT i.index_name
        FROM   dba_indexes i
        WHERE  i.owner        = v_owner
          AND  i.index_name NOT LIKE 'BIN$%'
          AND  NOT EXISTS (
                SELECT 1
                FROM   dba_constraints c
                WHERE  c.owner           = v_owner
                  AND  c.index_name      = i.index_name
                  AND  c.constraint_type IN ('P','U')
               )
        ORDER BY i.index_name
    ) LOOP
        BEGIN
            v_ddl := DBMS_METADATA.GET_DDL('INDEX', r.index_name, v_owner);
            v_ddl := REGEXP_REPLACE(v_ddl, 'TABLESPACE\s+"[^"]+"', 'TABLESPACE "&v_tablespace"', 1, 0, 'i');
            DBMS_OUTPUT.PUT_LINE(v_ddl);
            DBMS_OUTPUT.PUT_LINE('/');
            DBMS_OUTPUT.PUT_LINE('');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('-- ERROR extrayendo INDEX ' || r.index_name || ': ' || SQLERRM);
        END;
    END LOOP;
END;
/

-- ---------------------------------------------------------------------------
-- 4. PRIMARY KEYS y UNIQUE CONSTRAINTS (ALTER TABLE ADD CONSTRAINT)
-- ---------------------------------------------------------------------------
PROMPT -- ==================== PRIMARY KEYS / UNIQUE CONSTRAINTS ====================
PROMPT

DECLARE
    v_ddl   CLOB;
    v_owner VARCHAR2(128) := UPPER('&v_schema');
BEGIN
    FOR r IN (
        SELECT table_name, constraint_name
        FROM   dba_constraints
        WHERE  owner           = v_owner
          AND  constraint_type IN ('P','U')
          AND  status          = 'ENABLED'
        ORDER BY table_name, constraint_name
    ) LOOP
        BEGIN
            v_ddl := DBMS_METADATA.GET_DDL('CONSTRAINT', r.constraint_name, v_owner);
            DBMS_OUTPUT.PUT_LINE(v_ddl);
            DBMS_OUTPUT.PUT_LINE('/');
            DBMS_OUTPUT.PUT_LINE('');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('-- ERROR extrayendo CONSTRAINT ' || r.constraint_name || ': ' || SQLERRM);
        END;
    END LOOP;
END;
/

-- ---------------------------------------------------------------------------
-- 5. FOREIGN KEYS (al final para evitar dependencias de orden)
-- ---------------------------------------------------------------------------
PROMPT -- ==================== FOREIGN KEYS ====================
PROMPT

DECLARE
    v_ddl   CLOB;
    v_owner VARCHAR2(128) := UPPER('&v_schema');
BEGIN
    FOR r IN (
        SELECT table_name, constraint_name
        FROM   dba_constraints
        WHERE  owner           = v_owner
          AND  constraint_type = 'R'
          AND  status          = 'ENABLED'
        ORDER BY table_name, constraint_name
    ) LOOP
        BEGIN
            v_ddl := DBMS_METADATA.GET_DDL('REF_CONSTRAINT', r.constraint_name, v_owner);
            DBMS_OUTPUT.PUT_LINE(v_ddl);
            DBMS_OUTPUT.PUT_LINE('/');
            DBMS_OUTPUT.PUT_LINE('');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('-- ERROR extrayendo FK ' || r.constraint_name || ': ' || SQLERRM);
        END;
    END LOOP;
END;
/

-- ---------------------------------------------------------------------------
-- 6. CHECK CONSTRAINTS
-- ---------------------------------------------------------------------------
PROMPT -- ==================== CHECK CONSTRAINTS ====================
PROMPT

DECLARE
    v_ddl   CLOB;
    v_owner VARCHAR2(128) := UPPER('&v_schema');
BEGIN
    FOR r IN (
        SELECT table_name, constraint_name
        FROM   dba_constraints
        WHERE  owner           = v_owner
          AND  constraint_type = 'C'
          AND  status          = 'ENABLED'
          AND  generated       = 'USER NAME'   -- excluir NOT NULL implícitos
        ORDER BY table_name, constraint_name
    ) LOOP
        BEGIN
            v_ddl := DBMS_METADATA.GET_DDL('CONSTRAINT', r.constraint_name, v_owner);
            DBMS_OUTPUT.PUT_LINE(v_ddl);
            DBMS_OUTPUT.PUT_LINE('/');
            DBMS_OUTPUT.PUT_LINE('');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('-- ERROR extrayendo CHECK ' || r.constraint_name || ': ' || SQLERRM);
        END;
    END LOOP;
END;
/

-- ---------------------------------------------------------------------------
-- 7. VIEWS
-- ---------------------------------------------------------------------------
PROMPT -- ==================== VIEWS ====================
PROMPT

DECLARE
    v_ddl   CLOB;
    v_owner VARCHAR2(128) := UPPER('&v_schema');
BEGIN
    FOR r IN (
        SELECT object_name
        FROM   dba_objects
        WHERE  owner       = v_owner
          AND  object_type = 'VIEW'
          AND  status      = 'VALID'
        ORDER BY object_name
    ) LOOP
        BEGIN
            v_ddl := DBMS_METADATA.GET_DDL('VIEW', r.object_name, v_owner);
            DBMS_OUTPUT.PUT_LINE('CREATE OR REPLACE ');
            DBMS_OUTPUT.PUT_LINE(v_ddl);
            DBMS_OUTPUT.PUT_LINE('/');
            DBMS_OUTPUT.PUT_LINE('');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('-- ERROR extrayendo VIEW ' || r.object_name || ': ' || SQLERRM);
        END;
    END LOOP;
END;
/

-- ---------------------------------------------------------------------------
-- 8. STORED CODE: PROCEDURES, FUNCTIONS, PACKAGES (SPEC + BODY), TRIGGERS, TYPES
-- ---------------------------------------------------------------------------
PROMPT -- ==================== STORED CODE ====================
PROMPT

DECLARE
    v_ddl        CLOB;
    v_owner      VARCHAR2(128) := UPPER('&v_schema');
    v_meta_type  VARCHAR2(30);
BEGIN
    FOR r IN (
        SELECT object_type, object_name
        FROM   dba_objects
        WHERE  owner       = v_owner
          AND  object_type IN ('PROCEDURE','FUNCTION','PACKAGE','PACKAGE BODY',
                               'TRIGGER','TYPE','TYPE BODY')
          AND  status      = 'VALID'
        ORDER BY
            CASE object_type
                WHEN 'TYPE'         THEN 1
                WHEN 'TYPE BODY'    THEN 2
                WHEN 'PACKAGE'      THEN 3
                WHEN 'PACKAGE BODY' THEN 4
                WHEN 'PROCEDURE'    THEN 5
                WHEN 'FUNCTION'     THEN 6
                WHEN 'TRIGGER'      THEN 7
                ELSE 8
            END,
            object_name
    ) LOOP
        BEGIN
            v_meta_type := REPLACE(r.object_type, ' ', '_');
            -- DBMS_METADATA usa PACKAGE_BODY, TYPE_BODY
            v_ddl := DBMS_METADATA.GET_DDL(v_meta_type, r.object_name, v_owner);
            DBMS_OUTPUT.PUT_LINE(v_ddl);
            DBMS_OUTPUT.PUT_LINE('/');
            DBMS_OUTPUT.PUT_LINE('');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('-- ERROR extrayendo ' || r.object_type || ' ' || r.object_name || ': ' || SQLERRM);
        END;
    END LOOP;
END;
/

-- ---------------------------------------------------------------------------
-- 9. SYNONYMS (privados del esquema)
-- ---------------------------------------------------------------------------
PROMPT -- ==================== SYNONYMS ====================
PROMPT

DECLARE
    v_ddl   CLOB;
    v_owner VARCHAR2(128) := UPPER('&v_schema');
BEGIN
    FOR r IN (
        SELECT object_name
        FROM   dba_objects
        WHERE  owner       = v_owner
          AND  object_type = 'SYNONYM'
          AND  status      = 'VALID'
        ORDER BY object_name
    ) LOOP
        BEGIN
            v_ddl := DBMS_METADATA.GET_DDL('SYNONYM', r.object_name, v_owner);
            DBMS_OUTPUT.PUT_LINE(v_ddl);
            DBMS_OUTPUT.PUT_LINE('/');
            DBMS_OUTPUT.PUT_LINE('');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('-- ERROR extrayendo SYNONYM ' || r.object_name || ': ' || SQLERRM);
        END;
    END LOOP;
END;
/

-- ---------------------------------------------------------------------------
-- 10. DATABASE LINKS
-- ---------------------------------------------------------------------------
PROMPT -- ==================== DATABASE LINKS ====================
PROMPT

DECLARE
    v_ddl   CLOB;
    v_owner VARCHAR2(128) := UPPER('&v_schema');
BEGIN
    FOR r IN (
        SELECT object_name
        FROM   dba_objects
        WHERE  owner       = v_owner
          AND  object_type = 'DATABASE LINK'
        ORDER BY object_name
    ) LOOP
        BEGIN
            v_ddl := DBMS_METADATA.GET_DDL('DB_LINK', r.object_name, v_owner);
            DBMS_OUTPUT.PUT_LINE(v_ddl);
            DBMS_OUTPUT.PUT_LINE('/');
            DBMS_OUTPUT.PUT_LINE('');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('-- ERROR extrayendo DB_LINK ' || r.object_name || ': ' || SQLERRM);
        END;
    END LOOP;
END;
/

-- ---------------------------------------------------------------------------
-- 11. GRANTS sobre objetos del esquema
-- ---------------------------------------------------------------------------
PROMPT -- ==================== GRANTS ====================
PROMPT

DECLARE
    v_ddl   CLOB;
    v_owner VARCHAR2(128) := UPPER('&v_schema');
BEGIN
    FOR r IN (
        SELECT DISTINCT object_name, object_type
        FROM   dba_objects
        WHERE  owner       = v_owner
          AND  object_type IN ('TABLE','VIEW','SEQUENCE','PROCEDURE','FUNCTION','PACKAGE','TYPE')
          AND  status      = 'VALID'
        ORDER BY object_type, object_name
    ) LOOP
        BEGIN
            v_ddl := DBMS_METADATA.GET_DEPENDENT_DDL('OBJECT_GRANT', r.object_name, v_owner);
            IF v_ddl IS NOT NULL THEN
                DBMS_OUTPUT.PUT_LINE(v_ddl);
                DBMS_OUTPUT.PUT_LINE('/');
                DBMS_OUTPUT.PUT_LINE('');
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                NULL; -- Ignorar objetos sin grants
        END;
    END LOOP;
END;
/

PROMPT -- ==================== FIN DEL SCRIPT ====================
PROMPT -- Revisar objetos con estado INVALID tras la ejecución:
PROMPT -- SELECT object_type, object_name, status FROM dba_objects WHERE owner='&v_schema' AND status!='VALID';

SPOOL OFF

SET FEEDBACK  ON
SET HEADING   ON
SET PAGESIZE  14
SET VERIFY    ON
SET ECHO      OFF

PROMPT
PROMPT >>> Script generado en: &v_output_file
PROMPT >>> Ejecutar en DEV: sqlplus / as sysdba  (o /@DEV as sysdba si es remota)
PROMPT >>>   SQL> @&v_output_file
PROMPT
