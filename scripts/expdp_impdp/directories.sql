-- Ver tamaño del esquema por tipo de segmento
SELECT segment_type,
       ROUND(SUM(bytes)/1024/1024/1024, 2) AS gb,
       ROUND(SUM(bytes)/1024/1024, 2)      AS mb
FROM   dba_segments
WHERE  owner = 'JOBPROCESOR'
GROUP BY segment_type
ORDER BY gb DESC;

-- Total global del esquema
SELECT ROUND(SUM(bytes)/1024/1024/1024, 2) AS total_gb,
       ROUND(SUM(bytes)/1024/1024, 2)      AS total_mb
FROM   dba_segments
WHERE  owner = 'JOBPROCESOR';

-- Ver DBA Directories existentes
SELECT directory_name, directory_path
FROM   dba_directories
ORDER BY directory_name;

-- Crear un DBA Directory
-- Sustituir NOMBRE_DIRECTORIO y la ruta del sistema de ficheros
CREATE OR REPLACE DIRECTORY NOMBRE_DIRECTORIO AS '/ruta/en/el/servidor';

-- Dar permisos de lectura y escritura al usuario que lanzara el expdp/impdp
GRANT READ, WRITE ON DIRECTORY NOMBRE_DIRECTORIO TO JOBPROCESOR;
