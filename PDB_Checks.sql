-- ¿Existe y está enabled?
SELECT name, network_name, pdb, enabled 
FROM cdb_services 
WHERE pdb = 'PDB_X';

-- ¿Está realmente activo en el listener?
SELECT inst_id, name, network_name 
FROM gv$active_services 
WHERE con_id = (SELECT con_id FROM v$pdbs WHERE name = 'PDB_X');