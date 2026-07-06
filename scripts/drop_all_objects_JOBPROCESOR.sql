-- Borra todos los objetos del esquema JOBPROCESOR sin borrar el usuario
-- Ejecutar como SYSDBA en el entorno destino (DEV)
-- Orden: FK -> Triggers -> MViews -> Views -> Procedures/Functions/Packages -> Synonyms -> Tables -> Sequences -> Types -> DB Links

DECLARE
    v_schema VARCHAR2(30) := 'JOBPROCESOR';
    v_sql    VARCHAR2(500);
BEGIN
    -- 1. Foreign Keys (para evitar errores al borrar tablas)
    FOR r IN (
        SELECT table_name, constraint_name
        FROM   dba_constraints
        WHERE  owner = v_schema
        AND    constraint_type = 'R'
    ) LOOP
        v_sql := 'ALTER TABLE ' || v_schema || '.' || r.table_name
                 || ' DROP CONSTRAINT ' || r.constraint_name;
        EXECUTE IMMEDIATE v_sql;
        DBMS_OUTPUT.PUT_LINE('DROP FK: ' || r.constraint_name);
    END LOOP;

    -- 2. Triggers
    FOR r IN (
        SELECT trigger_name FROM dba_triggers WHERE owner = v_schema
    ) LOOP
        v_sql := 'DROP TRIGGER ' || v_schema || '.' || r.trigger_name;
        EXECUTE IMMEDIATE v_sql;
        DBMS_OUTPUT.PUT_LINE('DROP TRIGGER: ' || r.trigger_name);
    END LOOP;

    -- 3. Materialized Views
    FOR r IN (
        SELECT mview_name FROM dba_mviews WHERE owner = v_schema
    ) LOOP
        v_sql := 'DROP MATERIALIZED VIEW ' || v_schema || '.' || r.mview_name;
        EXECUTE IMMEDIATE v_sql;
        DBMS_OUTPUT.PUT_LINE('DROP MVIEW: ' || r.mview_name);
    END LOOP;

    -- 4. Views
    FOR r IN (
        SELECT view_name FROM dba_views WHERE owner = v_schema
    ) LOOP
        v_sql := 'DROP VIEW ' || v_schema || '.' || r.view_name;
        EXECUTE IMMEDIATE v_sql;
        DBMS_OUTPUT.PUT_LINE('DROP VIEW: ' || r.view_name);
    END LOOP;

    -- 5. Procedures, Functions, Packages
    FOR r IN (
        SELECT object_type, object_name
        FROM   dba_objects
        WHERE  owner = v_schema
        AND    object_type IN ('PROCEDURE','FUNCTION','PACKAGE','PACKAGE BODY')
        AND    object_type != 'PACKAGE BODY'  -- se borra con el PACKAGE
        ORDER BY DECODE(object_type,'PACKAGE BODY',2,1)
    ) LOOP
        v_sql := 'DROP ' || r.object_type || ' ' || v_schema || '.' || r.object_name;
        EXECUTE IMMEDIATE v_sql;
        DBMS_OUTPUT.PUT_LINE('DROP ' || r.object_type || ': ' || r.object_name);
    END LOOP;

    -- 6. Synonyms
    FOR r IN (
        SELECT synonym_name FROM dba_synonyms WHERE owner = v_schema
    ) LOOP
        v_sql := 'DROP SYNONYM ' || v_schema || '.' || r.synonym_name;
        EXECUTE IMMEDIATE v_sql;
        DBMS_OUTPUT.PUT_LINE('DROP SYNONYM: ' || r.synonym_name);
    END LOOP;

    -- 7. Tablas (CASCADE CONSTRAINTS para cualquier FK residual)
    FOR r IN (
        SELECT table_name FROM dba_tables WHERE owner = v_schema
    ) LOOP
        v_sql := 'DROP TABLE ' || v_schema || '.' || r.table_name || ' CASCADE CONSTRAINTS PURGE';
        EXECUTE IMMEDIATE v_sql;
        DBMS_OUTPUT.PUT_LINE('DROP TABLE: ' || r.table_name);
    END LOOP;

    -- 8. Sequences (excluye las IDENTITY internas ISEQ$_/ISEQS_)
    FOR r IN (
        SELECT sequence_name FROM dba_sequences
        WHERE  sequence_owner = v_schema
        AND    sequence_name NOT LIKE 'ISEQ$_%'
        AND    sequence_name NOT LIKE 'ISEQS_%'
    ) LOOP
        v_sql := 'DROP SEQUENCE ' || v_schema || '.' || r.sequence_name;
        EXECUTE IMMEDIATE v_sql;
        DBMS_OUTPUT.PUT_LINE('DROP SEQUENCE: ' || r.sequence_name);
    END LOOP;

    -- 9. Types
    FOR r IN (
        SELECT type_name FROM dba_types
        WHERE  owner = v_schema
        AND    predefined = 'NO'
    ) LOOP
        BEGIN
            v_sql := 'DROP TYPE ' || v_schema || '.' || r.type_name || ' FORCE';
            EXECUTE IMMEDIATE v_sql;
            DBMS_OUTPUT.PUT_LINE('DROP TYPE: ' || r.type_name);
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('SKIP TYPE (dep): ' || r.type_name || ' - ' || SQLERRM);
        END;
    END LOOP;

    -- 10. DB Links
    FOR r IN (
        SELECT db_link FROM dba_db_links WHERE owner = v_schema
    ) LOOP
        v_sql := 'DROP DATABASE LINK ' || v_schema || '.' || r.db_link;
        EXECUTE IMMEDIATE v_sql;
        DBMS_OUTPUT.PUT_LINE('DROP DB LINK: ' || r.db_link);
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('--- Limpieza completada para esquema: ' || v_schema || ' ---');
END;
/

-- Verificacion: debe devolver 0 filas (o solo objetos del sistema)
SELECT object_type, COUNT(*) AS total
FROM   dba_objects
WHERE  owner = 'JOBPROCESOR'
GROUP BY object_type
ORDER BY object_type;
