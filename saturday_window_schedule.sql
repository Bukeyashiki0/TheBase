-- Saltarse SOLO la apertura del sabado 13-jun-2026 01:00 (Europe/Vienna).
-- Se fija START_DATE exactamente al siguiente sabado deseado: 20-jun-2026 01:00.
-- La primera apertura valida pasa a ser ese instante; las posteriores siguen
-- la cadencia semanal normal del REPEAT_INTERVAL.
BEGIN
  DBMS_SCHEDULER.SET_ATTRIBUTE(
    name      => 'SATURDAY_WINDOW',
    attribute => 'START_DATE',
    value     => TIMESTAMP '2026-06-20 01:00:00 Europe/Vienna'
  );
END;
/
