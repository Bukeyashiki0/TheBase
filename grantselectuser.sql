SET SERVEROUTPUT ON;

BEGIN
    FOR rec IN (
        SELECT owner, table_name
        FROM   dba_tables
        WHERE  owner IN ('SCHEMA1', 'SCHEMA2')
        ORDER BY owner, table_name
    ) LOOP
        EXECUTE IMMEDIATE
            'GRANT SELECT ON ' || rec.owner || '.' || rec.table_name || ' TO TARGET_USER';
        DBMS_OUTPUT.PUT_LINE(
            'GRANT SELECT ON ' || rec.owner || '.' || rec.table_name || ' TO TARGET_USER; -- OK'
        );
    END LOOP;
END;
/
