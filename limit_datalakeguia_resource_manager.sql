-- Limitar recursos del usuario DATALAKEGUIA sobre la BBDD de guia (Pre).
-- Cada comando va en una sola linea y se puede copiar/pegar y ejecutar por separado.
-- Ejecutar EN ORDEN y en la MISMA sesion (conectado a la PDB de la guia si es CDB).
-- Limites: cpu_p1=20  active_sess_pool_p1=75  max_est_exec_time=900(seg)  undo_pool=51200(KB=50MB)

-- 1. Abrir pending area
EXEC DBMS_RESOURCE_MANAGER.CREATE_PENDING_AREA();

-- 2. Crear consumer group
EXEC DBMS_RESOURCE_MANAGER.CREATE_CONSUMER_GROUP(consumer_group => 'GRP_DATALAKEGUIA', comment => 'Limites para usuario DATALAKEGUIA - guia pre');

-- 3. Crear plan
EXEC DBMS_RESOURCE_MANAGER.CREATE_PLAN(plan => 'PLAN_GUIA_PRE', comment => 'Plan limitacion DATALAKEGUIA');

-- 4. Directiva con los limites para el grupo
EXEC DBMS_RESOURCE_MANAGER.CREATE_PLAN_DIRECTIVE(plan => 'PLAN_GUIA_PRE', group_or_subplan => 'GRP_DATALAKEGUIA', comment => 'Limites DATALAKEGUIA', cpu_p1 => 20, active_sess_pool_p1 => 75, max_est_exec_time => 900, undo_pool => 51200);

-- 5. Directiva OTHER_GROUPS (obligatoria en todo plan)
EXEC DBMS_RESOURCE_MANAGER.CREATE_PLAN_DIRECTIVE(plan => 'PLAN_GUIA_PRE', group_or_subplan => 'OTHER_GROUPS', comment => 'Resto de sesiones', cpu_p1 => 80);

-- 6. Validar y enviar
EXEC DBMS_RESOURCE_MANAGER.VALIDATE_PENDING_AREA();
EXEC DBMS_RESOURCE_MANAGER.SUBMIT_PENDING_AREA();

-- 7. Permitir el switch del usuario al grupo
EXEC DBMS_RESOURCE_MANAGER_PRIVS.GRANT_SWITCH_CONSUMER_GROUP(grantee_name => 'DATALAKEGUIA', consumer_group => 'GRP_DATALAKEGUIA', grant_option => FALSE);

-- 8. Mapear el usuario al grupo (nueva pending area)
EXEC DBMS_RESOURCE_MANAGER.CREATE_PENDING_AREA();
EXEC DBMS_RESOURCE_MANAGER.SET_CONSUMER_GROUP_MAPPING(DBMS_RESOURCE_MANAGER.ORACLE_USER, 'DATALAKEGUIA', 'GRP_DATALAKEGUIA');
EXEC DBMS_RESOURCE_MANAGER.SUBMIT_PENDING_AREA();

-- 9. Activar el plan (usar 'FORCE:PLAN_GUIA_PRE' si hay ventanas que lo sobreescriban)
ALTER SYSTEM SET RESOURCE_MANAGER_PLAN = 'PLAN_GUIA_PRE' SCOPE=BOTH;

-- Verificacion (opcional, ejecutar cada SELECT por separado)
SELECT name FROM v$rsrc_plan WHERE is_top_plan = 'TRUE';
SELECT attribute, value, consumer_group FROM dba_rsrc_group_mappings WHERE value = 'DATALAKEGUIA';
SELECT name, active_sessions, queue_length, consumed_cpu_time FROM v$rsrc_consumer_group WHERE name = 'GRP_DATALAKEGUIA';
