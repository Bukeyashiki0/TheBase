-- ============================================================
-- 01_workload.sql  -  Configuracion + Crear workload y cargar SQLs
-- ============================================================
-- Sesion origen: USERNAME=GUIA  SID=2297  Serial#=33661
--
-- Edita sql_id, task_name y wkld_name si es necesario.
--
-- Orden de ejecucion (misma sesion SQL*Plus):
--   @access_advisor_pyg/01_workload.sql
--   @access_advisor_pyg/02_advisor.sql
--   @access_advisor_pyg/03_results.sql
-- ============================================================

DEFINE sql_id     = '90zdv03f74mvb'
DEFINE task_name  = 'ACC_ADV_PYG'
DEFINE wkld_name  = 'WKL_PYG'
DEFINE parse_user = 'GUIA'

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LONG          65536
SET LONGCHUNKSIZE 65536
SET LINESIZE      200
SET PAGESIZE      200
SET VERIFY        OFF

DECLARE

  -- Tablas del proceso PYG (owner.tabla o solo tabla)
  TYPE t_varchar_list IS TABLE OF VARCHAR2(200);

  v_tables t_varchar_list := t_varchar_list(
    -- Schema SASGUIA
    'SASGUIA.PYGCONSOLIDACION',
    'SASGUIA.PYGDESCERRORPER',
    'SASGUIA.PYGAJCONT',
    'SASGUIA.PYGGASTOSREP',
    'SASGUIA.PYGEMPRCTCOST',
    'SASGUIA.PYGGASTEMP',
    'SASGUIA.PYGCTRCOST',
    'SASGUIA.PYGTIFGAST',
    'SASGUIA.PYGGASTOSTIPOG',
    'SASGUIA.PYGPRODCOM',
    'SASGUIA.PYGPRODCNICOST',
    'SASGUIA.PYGGASTOSPROD',
    'SASGUIA.PYGVAROP',
    'SASGUIA.PYGIMPORTES',
    'SASGUIA.PYGVAASIGGAST',
    'SASGUIA.PYGCASTOPER',
    'SASGUIA.PYGCERRORES',
    -- Schema GUIA - tablas temporales
    'GUIA.TMP_PERIMETRO_OF',
    'GUIA.PYG_TMP_PERIMETRO_ITACA',
    'GUIA.PYG_TMP_GASTOSPROD_DRIVERS',
    'GUIA.PYG_TMP_VASTIG',
    'GUIA.PYG_TMP_GASTOSPROD_ITACA',
    'GUIA.PYG_TMP_SOCIED_PER',
    'GUIA.PYG_TMP_HOLDING_PER',
    'GUIA.PYG_TMP_GASTOSPROD_SOC',
    'GUIA.PYG_TMP_SUCURS_PER',
    'GUIA.PYG_TMP_ZONA_PER',
    'GUIA.PYG_TMP_REG_PER',
    'GUIA.PYG_TMP_GASTOSPROD_FINAL',
    'GUIA.PYG_TMP_FILTRO_SUC',
    -- Sin schema explicito
    'PYGCUEGAST',
    'DINCWA24',
    'DINUMA25',
    'DINUMA01',
    'TNP_GASTOSREP_PYG',
    'TNP_GASTOSREP_AGRUF',
    'TNP_GASTOSREP_PYG_EMP',
    'SICPPFUR51',
    'SIASGUIA.PYGCONSOLIDACON',
    'PYGREGACTIVIDAD'
  );

  -- Variables para parametros IN OUT de DBMS_ADVISOR
  -- (no se puede pasar un literal '&...' a un parametro IN OUT)
  v_wkld_name  VARCHAR2(100)   := '&wkld_name';
  v_task_name  VARCHAR2(100)   := '&task_name';   -- solo para limpieza idempotente

  v_stmt_count PLS_INTEGER := 0;
  v_skipped    PLS_INTEGER := 0;
  v_last_err   VARCHAR2(4000);
  v_in_list    VARCHAR2(32767);
  v_dyn_sql    VARCHAR2(32767);
  v_obj_name   VARCHAR2(128);

  -- CLOB se busca con SQL estatico por sql_id; BULK COLLECT solo recoge IDs
  TYPE t_id_list IS TABLE OF VARCHAR2(13);
  v_sql_ids    t_id_list := t_id_list();

  v_sql_text   CLOB;
  v_executions NUMBER;
  v_elapsed    NUMBER;
  v_cpu        NUMBER;
  v_gets       NUMBER;

  PROCEDURE add_stmt(
    p_text    IN CLOB,
    p_exec    IN NUMBER,
    p_elapsed IN NUMBER,
    p_cpu     IN NUMBER,
    p_gets    IN NUMBER,
    p_action  IN VARCHAR2 DEFAULT NULL
  ) IS
  BEGIN
    DBMS_ADVISOR.ADD_SQLWKLD_STATEMENT(
      workload_name  => v_wkld_name,
      module         => 'ACC_ADV_PYG',
      action         => p_action,
      cpu_time       => NVL(p_cpu,     0),
      elapsed_time   => NVL(p_elapsed, 0),
      disk_reads     => 0,
      buffer_gets    => NVL(p_gets,    0),
      rows_processed => 0,
      executions     => NVL(p_exec,    1),
      username       => '&parse_user',
      sql_text       => p_text
    );
    v_stmt_count := v_stmt_count + 1;
  EXCEPTION
    -- DML/DDL/recursivo o SQL que no parsea: se descarta y se cuenta
    WHEN OTHERS THEN
      v_skipped  := v_skipped + 1;
      v_last_err := SQLERRM;
  END;

BEGIN
  DBMS_OUTPUT.PUT_LINE('==============================================');
  DBMS_OUTPUT.PUT_LINE(' 01_workload  -  Crear workload y cargar SQLs');
  DBMS_OUTPUT.PUT_LINE('==============================================');
  DBMS_OUTPUT.PUT_LINE(' Workload : &wkld_name');
  DBMS_OUTPUT.PUT_LINE(' sql_id   : &sql_id');

  -- Limpieza idempotente: si se re-ejecuta, elimina restos previos.
  -- Primero la tarea (libera el link) y luego el workload.
  BEGIN DBMS_ADVISOR.DELETE_TASK(v_task_name);     EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN DBMS_ADVISOR.DELETE_SQLWKLD(v_wkld_name);  EXCEPTION WHEN OTHERS THEN NULL; END;

  DBMS_ADVISOR.CREATE_SQLWKLD(workload_name => v_wkld_name);
  DBMS_OUTPUT.PUT_LINE(' Workload creado.');

  -- A) SQL principal por sql_id
  BEGIN
    SELECT sql_fulltext, executions, elapsed_time, cpu_time, buffer_gets
    INTO   v_sql_text, v_executions, v_elapsed, v_cpu, v_gets
    FROM   v$sql
    WHERE  sql_id = '&sql_id'
    AND    ROWNUM  = 1;

    add_stmt(v_sql_text, v_executions, v_elapsed, v_cpu, v_gets,
             'SQL_ID_&sql_id');
    DBMS_OUTPUT.PUT_LINE(' SQL principal cargado (sql_id=&sql_id)');
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      DBMS_OUTPUT.PUT_LINE(' AVISO: sql_id &sql_id no esta en cursor cache.');
      DBMS_OUTPUT.PUT_LINE('        Continuando con busqueda por tablas...');
  END;

  -- B) SQLs adicionales filtrando por nombre de tabla en v$sql_plan
  FOR i IN 1..v_tables.COUNT LOOP
    v_obj_name := SUBSTR(v_tables(i), INSTR(v_tables(i), '.') + 1);
    IF i = 1 THEN
      v_in_list := '''' || v_obj_name || '''';
    ELSE
      v_in_list := v_in_list || ',''' || v_obj_name || '''';
    END IF;
  END LOOP;

  -- Recoge solo sql_id (VARCHAR2) para evitar ORA-00932 con CLOB en BULK COLLECT
  v_dyn_sql :=
    'SELECT DISTINCT s.sql_id ' ||
    'FROM   v$sql s ' ||
    'WHERE  s.executions > 0 ' ||
    '  AND  s.sql_id != :1 ' ||
    '  AND  EXISTS ( ' ||
    '    SELECT 1 FROM v$sql_plan p ' ||
    '    WHERE  p.sql_id = s.sql_id ' ||
    '    AND    p.object_name IN (' || v_in_list || ') ' ||
    '  )';

  EXECUTE IMMEDIATE v_dyn_sql BULK COLLECT INTO v_sql_ids USING '&sql_id';
  DBMS_OUTPUT.PUT_LINE(' SQLs adicionales encontrados: ' || v_sql_ids.COUNT);

  -- Busca el texto completo (CLOB) con SQL estatico, uno a uno
  FOR i IN 1..v_sql_ids.COUNT LOOP
    BEGIN
      SELECT sql_fulltext, executions, elapsed_time, cpu_time, buffer_gets
      INTO   v_sql_text, v_executions, v_elapsed, v_cpu, v_gets
      FROM   v$sql
      WHERE  sql_id = v_sql_ids(i)
      AND    ROWNUM  = 1;

      add_stmt(v_sql_text, v_executions, v_elapsed, v_cpu, v_gets);
    EXCEPTION
      WHEN NO_DATA_FOUND THEN NULL;
    END;
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('----------------------------------------------');
  DBMS_OUTPUT.PUT_LINE(' Total SQLs en workload: ' || v_stmt_count);

  IF v_skipped > 0 THEN
    DBMS_OUTPUT.PUT_LINE(' SQLs descartados      : ' || v_skipped ||
                         ' (DML/DDL/no parseables)');
    DBMS_OUTPUT.PUT_LINE(' Ultimo motivo         : ' || v_last_err);
  END IF;

  IF v_stmt_count = 0 THEN
    DBMS_OUTPUT.PUT_LINE(' ERROR: Workload vacio. Verifica cursor cache.');
    DBMS_ADVISOR.DELETE_SQLWKLD(workload_name => v_wkld_name);
    RETURN;
  END IF;

  DBMS_OUTPUT.PUT_LINE(' OK - Siguiente: @access_advisor_pyg/02_advisor.sql');
  DBMS_OUTPUT.PUT_LINE('==============================================');

EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
    BEGIN DBMS_ADVISOR.DELETE_SQLWKLD(v_wkld_name); EXCEPTION WHEN OTHERS THEN NULL; END;
    RAISE;
END;
/
