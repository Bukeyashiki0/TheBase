-- ============================================================
-- 03_results.sql  -  Consultar recomendaciones
-- ============================================================
-- Requiere haber ejecutado 02_advisor.sql en la misma sesion
-- (la variable &task_name debe estar definida).
--
-- Si abres una sesion nueva, define la variable antes:
--   DEFINE task_name = 'ACC_ADV_PYG'
-- ============================================================

SET LONG          1000000
SET LONGCHUNKSIZE 1000000
SET PAGESIZE      50000
SET LINESIZE      200

PROMPT ==============================================
PROMPT  03_results  -  Recomendaciones del advisor
PROMPT  Task: &task_name
PROMPT ==============================================

-- ------------------------------------------------------------
-- 1. Resumen de recomendaciones
--    Columnas reales de *_advisor_recommendations:
--    rec_id, type, rank, benefit  (NO existen benefit_value/message)
-- ------------------------------------------------------------
PROMPT
PROMPT --- 1. Resumen de recomendaciones ---

COLUMN rec_id  FORMAT 9999          HEADING 'REC'
COLUMN type    FORMAT A22           HEADING 'Tipo'
COLUMN rank    FORMAT 9999          HEADING 'Rank'
COLUMN benefit FORMAT 999999999999  HEADING 'Beneficio'

SELECT rec_id, type, rank, benefit
FROM   user_advisor_recommendations
WHERE  task_name = '&task_name'
ORDER BY benefit DESC NULLS LAST;


-- ------------------------------------------------------------
-- 2. Acciones detalladas (DDLs sugeridos)
-- ------------------------------------------------------------
PROMPT
PROMPT --- 2. Acciones recomendadas (DDLs) ---

COLUMN rec_id   FORMAT 9999     HEADING 'REC'
COLUMN command  FORMAT A14      HEADING 'Comando'
COLUMN attr1    FORMAT A50 WRAP HEADING 'Objeto / Definicion'
COLUMN attr2    FORMAT A20 WRAP HEADING 'Tablespace / Cols'
COLUMN attr3    FORMAT A12      HEADING 'Extra'

SELECT a.rec_id,
       a.command,
       a.attr1,
       a.attr2,
       a.attr3
FROM   user_advisor_actions a
WHERE  a.task_name = '&task_name'
ORDER BY a.rec_id, a.action_id;


-- ------------------------------------------------------------
-- 3. Informe formateado completo (legible)
--    Mas fiable que consultar las vistas a mano.
-- ------------------------------------------------------------
PROMPT
PROMPT --- 3. Informe del advisor (GET_TASK_REPORT) ---

SELECT DBMS_ADVISOR.GET_TASK_REPORT('&task_name', 'TEXT', 'ALL') AS report
FROM   DUAL;


-- ------------------------------------------------------------
-- 4. Script SQL completo listo para implementar
-- ------------------------------------------------------------
PROMPT
PROMPT --- 4. Script DDL completo (GET_TASK_SCRIPT) ---

SELECT DBMS_ADVISOR.GET_TASK_SCRIPT('&task_name') AS ddl_script
FROM   DUAL;


-- ------------------------------------------------------------
-- 5. Limpieza (descomentar cuando ya no se necesite)
-- ------------------------------------------------------------
-- EXEC DBMS_ADVISOR.DELETE_TASK('&task_name');
-- EXEC DBMS_ADVISOR.DELETE_SQLWKLD('&wkld_name');
