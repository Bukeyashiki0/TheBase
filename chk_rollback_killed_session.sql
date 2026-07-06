SELECT s.sid,
       s.serial#,
       s.status,
       t.used_ublk,
       t.used_urec,
       rs.rssize / 1024 / 1024 AS rollback_mb
FROM   v$session  s
JOIN   v$transaction t  ON t.addr = s.taddr
JOIN   v$rollstat    rs ON rs.usn  = t.xidusn
WHERE  s.status = 'KILLED';
