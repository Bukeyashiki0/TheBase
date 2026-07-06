SELECT grantee, owner, table_name, privilege
FROM   dba_tab_privs
WHERE  owner IN ('USER1', 'USER2')
  AND  grantee = 'USER3'
  AND  privilege = 'SELECT';
