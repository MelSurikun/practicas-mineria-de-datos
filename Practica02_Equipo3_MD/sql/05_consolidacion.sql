-- Práctica 02, Equipo 3
-- Paso 5: consolidación de la tabla histórica (sección 5).
-- covid_tipada ya es el superconjunto consolidado de ambos periodos (no se
-- crea una tabla intermedia aparte, ver sql/04_tipado.sql). Lo que falta aquí
-- es verificar los conteos y resolver duplicados.
--
-- Ejecutar conectado a covid20a23sedi: \c covid20a23sedi

-- 5.2 Verificación de conteos: covid_tipada debe igualar la suma de los stages,
-- porque ninguna conversión de tipo descarta filas (solo pone NULL cuando el
-- valor no es convertible).
SELECT
    (SELECT count(*) FROM covid_stage_2022) AS filas_stage_2022,
    (SELECT count(*) FROM covid_stage_2023) AS filas_stage_2023,
    (SELECT count(*) FROM covid_stage_2022) + (SELECT count(*) FROM covid_stage_2023)
        AS suma_esperada,
    (SELECT count(*) FROM covid_tipada) AS filas_covid_tipada;

-- 5.3 Duplicados por ID_REGISTRO.
-- No se aplica la llave primaria simple del anexo del enunciado sin revisar
-- primero, porque un mismo caso podría en principio reaparecer con una
-- FECHA_ACTUALIZACION distinta. Al revisarlo con los datos reales resultó
-- ser otra cosa: 1,999,998 de los 2,099,997 ID_REGISTRO distintos tienen más
-- de una fila, y esas filas son copias exactas, idénticas en las 44
-- columnas, no casos con un estatus actualizado en fecha distinta (ver
-- evidencias/conteos.md para la consulta que lo confirma). Esto es
-- consistente con el hallazgo del encabezado duplicado a la mitad del
-- archivo de 2022 (sql/03_ingesta.sql): si el archivo se armó concatenando
-- dos extractos idénticos, cada caso quedó copiado dos veces. Se conserva,
-- por cada ID_REGISTRO, una sola fila (el desempate por FECHA_ACTUALIZACION
-- más reciente no cambia el resultado, porque las filas que compiten son
-- idénticas), y las demás se mueven a una tabla de auditoría en vez de
-- borrarse sin dejar rastro.

-- Cuántos ID_REGISTRO tienen más de una fila (antes de decidir qué hacer):
SELECT count(*) AS id_registro_duplicados
FROM (
    SELECT id_registro
    FROM covid_tipada
    GROUP BY id_registro
    HAVING count(*) > 1
) d;

DROP TABLE IF EXISTS covid_historica_auditoria;
CREATE TABLE covid_historica_auditoria AS
SELECT *
FROM (
    SELECT
        t.*,
        ROW_NUMBER() OVER (
            PARTITION BY id_registro
            ORDER BY fecha_actualizacion DESC NULLS LAST
        ) AS orden_por_actualizacion
    FROM covid_tipada t
) enumerado
WHERE orden_por_actualizacion > 1;

DROP TABLE IF EXISTS covid_historica;
CREATE TABLE covid_historica AS
SELECT *
FROM (
    SELECT
        t.*,
        ROW_NUMBER() OVER (
            PARTITION BY id_registro
            ORDER BY fecha_actualizacion DESC NULLS LAST
        ) AS orden_por_actualizacion
    FROM covid_tipada t
) enumerado
WHERE orden_por_actualizacion = 1;

ALTER TABLE covid_historica DROP COLUMN orden_por_actualizacion;
ALTER TABLE covid_historica_auditoria DROP COLUMN orden_por_actualizacion;

ALTER TABLE covid_historica ADD CONSTRAINT pk_covid_historica PRIMARY KEY (id_registro);

-- Verificación final:
--   SELECT count(*) FROM covid_historica;                 -- filas únicas por id_registro
--   SELECT count(*) FROM covid_historica_auditoria;        -- filas descartadas por duplicado
--   -- la suma de las dos anteriores debe dar exactamente count(*) FROM covid_tipada
--   SELECT (SELECT count(*) FROM covid_historica) + (SELECT count(*) FROM covid_historica_auditoria)
--          = (SELECT count(*) FROM covid_tipada) AS conteos_cuadran;
