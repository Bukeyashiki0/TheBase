-- List available AWR snapshots (most recent first):
-- SELECT snap_id, begin_interval_time, end_interval_time
-- FROM dba_hist_snapshot
-- ORDER BY snap_id DESC;

SELECT instance_number, sql_id,
       SUM(elapsed_time_delta)/1e6 AS elapsed_sec,
       SUM(cpu_time_delta)/1e6     AS cpu_sec,
       SUM(buffer_gets_delta)      AS gets,
       SUM(executions_delta)       AS execs
FROM dba_hist_sqlstat
WHERE snap_id BETWEEN (SELECT MAX(snap_id) - 1 FROM dba_hist_snapshot)
                   AND (SELECT MAX(snap_id)     FROM dba_hist_snapshot)
GROUP BY instance_number, sql_id
ORDER BY instance_number, elapsed_sec DESC;
