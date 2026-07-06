- Permisos para usuarios del proyecto EWIS3B
-- Ejecutar como DBA o usuario con privilegios GRANT ANY PRIVILEGE

-- ============================================================
-- USUARIO: adewis3b (admin del proyecto)
-- ============================================================

-- a) Cuota ilimitada en tablespaces del proyecto
ALTER USER adewis3b QUOTA UNLIMITED ON 1EWI_DAT;
ALTER USER adewis3b QUOTA UNLIMITED ON 1EWI_IND;

-- b) Crear sinónimos
--    CREATE ANY SYNONYM permite crear sinónimos en cualquier esquema (necesario
--    si adewis3b debe crear sinónimos apuntando a objetos de otros esquemas o
--    crear sinónimos dentro de los esquemas wdewis3b/rdewis3b).
--    Si solo necesita sinónimos en su propio esquema, usar CREATE SYNONYM.
GRANT CREATE ANY SYNONYM    TO adewis3b;
GRANT CREATE PUBLIC SYNONYM TO adewis3b;

-- c) Crear procedimientos
--    CREATE ANY PROCEDURE permite crear procedures en cualquier esquema.
--    Justificado para un usuario admin que despliega objetos en el proyecto.
GRANT CREATE ANY PROCEDURE  TO adewis3b;


-- ============================================================
-- USUARIO: wdewis3b (lectura/escritura del proyecto)
-- ============================================================
-- Permisos sobre tablas: ajustar la lista de tablas según el proyecto.
-- Ejemplo con tablas del esquema adewis3b (reemplazar TABLE_NAME por los reales):
--
-- GRANT SELECT, INSERT, UPDATE, DELETE ON adewis3b.<tabla1> TO wdewis3b;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON adewis3b.<tabla2> TO wdewis3b;

-- Ejecutar y crear procedures (NO se usan ANY: solo sobre objetos del proyecto)
GRANT CREATE PROCEDURE TO wdewis3b;
-- GRANT EXECUTE ON adewis3b.<procedure1> TO wdewis3b;


-- ============================================================
-- USUARIO: rdewis3b (solo lectura del proyecto)
-- ============================================================
-- Permisos de consulta sobre tablas del proyecto:
--
-- GRANT SELECT ON adewis3b.<tabla1> TO rdewis3b;
-- GRANT SELECT ON adewis3b.<tabla2> TO rdewis3b;

-- Crear y ejecutar procedures en su propio esquema
GRANT CREATE PROCEDURE TO rdewis3b;
-- Ejecutar procedures del proyecto (ajustar según objetos reales):
-- GRANT EXECUTE ON adewis3b.<procedure1> TO rdewis3b;
