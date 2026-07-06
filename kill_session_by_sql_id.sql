DEFINE sql_id = '7bmzsjshpu78t'

SELECT 'ALTER SYSTEM KILL SESSION '''||sid||','||serial#||''' IMMEDIATE;'
FROM   v$session
WHERE  sql_id = '&sql_id';
