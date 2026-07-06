-- Instancia: oesaobcc@sanlccoracp0041
-- Objetivo: saltarse SATURDAY_WINDOW (13-jun-2026) y SUNDAY_WINDOW (14-jun-2026)
-- para no afectar la historificacion de CSI.
-- Las ventanas reanudan su cadencia semanal normal a partir del siguiente fin de semana.

-- 1. Verificar estado actual antes de ejecutar
SELECT window_name, enabled, next_start_date
FROM   dba_scheduler_windows
WHERE  window_name IN ('SATURDAY_WINDOW','SUNDAY_WINDOW','WEEKEND_WINDOW');

-- 2. Saltar sabado 13-jun-2026 (proxima apertura => sabado 20-jun-2026 06:00)
BEGIN
  DBMS_SCHEDULER.SET_ATTRIBUTE(
    name      => 'SATURDAY_WINDOW',
    attribute => 'START_DATE',
    value     => TIMESTAMP '2026-06-20 06:00:00 Europe/Vienna'
  );
END;
/

-- 3. Saltar domingo 14-jun-2026 (proxima apertura => domingo 21-jun-2026 06:00)
BEGIN
  DBMS_SCHEDULER.SET_ATTRIBUTE(
    name      => 'SUNDAY_WINDOW',
    attribute => 'START_DATE',
    value     => TIMESTAMP '2026-06-21 06:00:00 Europe/Vienna'
  );
END;
/

-- 4. Confirmar que next_start_date quedo en la semana del 20/21-jun-2026
SELECT window_name, enabled, next_start_date
FROM   dba_scheduler_windows
WHERE  window_name IN ('SATURDAY_WINDOW','SUNDAY_WINDOW','WEEKEND_WINDOW');
