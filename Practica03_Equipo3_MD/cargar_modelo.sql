-- Práctica 03, Equipo 3 (aportación de Santiago)
-- Carga completa del modelo multidimensional, en un solo paso.
--
-- Corre en orden los cinco scripts del modelo y de la carga de prueba, y al final imprime
-- una tabla de comprobaciones: si todas dicen OK, el modelo quedó bien.
--   1. sql/modelo/00_catalogos.sql          los 11 catálogos (no toca los que ya existen)
--   2. sql/modelo/01_esquema_dw.sql         el esquema dw y sus 13 tablas (lo borra y lo crea)
--   3. sql/prueba_carga/10_dimensiones.sql  las 12 dimensiones
--   4. sql/prueba_carga/11_hechos.sql       la tabla de hechos, un caso por fila
--   5. sql/modelo/02_llaves_foraneas.sql    las 16 llaves foráneas y los índices
--
-- Se corre con psql en la base que tiene covid_historica (la del equipo es covid20a23sedi),
-- parado en esta carpeta, porque las rutas de \copy son relativas a ella:
--   psql -h localhost -U postgres -d covid20a23sedi -f cargar_modelo.sql
-- Los pasos para Windows están en README.md. Se puede volver a correr sin duplicar nada.
--
-- Los \echo van sin acentos a propósito: la consola de Windows los muestra mal.

SET client_encoding = 'UTF8';
\set ON_ERROR_STOP on
\pset pager off

-- Antes de tocar nada: la versión de PostgreSQL y la tabla de origen.
SELECT current_setting('server_version_num')::int >= 150000 AS version_ok,
       to_regclass('public.covid_historica') IS NOT NULL AS hay_historica \gset
\if :version_ok
\else
    \echo 'Hace falta PostgreSQL 15 o posterior (por UNIQUE NULLS NOT DISTINCT). No se cambio nada.'
    \quit
\endif
\if :hay_historica
\else
    \echo 'Esta base no tiene public.covid_historica: usen la base de la P2 (covid20a23sedi). No se cambio nada.'
    \quit
\endif

\echo 'Cargando el modelo en la base' :DBNAME
\echo 'Paso 1 de 5: tablas cat_* (no toca las que ya existen)'
\ir sql/modelo/00_catalogos.sql
\echo 'Paso 2 de 5: esquema dw con sus 13 tablas'
\ir sql/modelo/01_esquema_dw.sql
\echo 'Paso 3 de 5: las 12 dimensiones'
\ir sql/prueba_carga/10_dimensiones.sql
\echo 'Paso 4 de 5: tabla de hechos, 2.1 millones de casos'
\ir sql/prueba_carga/11_hechos.sql
\echo 'Paso 5 de 5: las 16 llaves FK'
\ir sql/modelo/02_llaves_foraneas.sql

-- Comprobaciones rápidas (unos segundos). Los valores esperados son los de covid_historica
-- de la Práctica 2; la validación completa está en sql/prueba_carga/12_validacion.sql.
CREATE TEMP VIEW comprobaciones AS
SELECT n AS "#", comprobacion, esperado, obtenido,
       CASE WHEN obtenido = esperado THEN 'OK' ELSE 'REVISAR' END AS resultado
FROM (VALUES
    ( 1, 'Casos en covid_historica',               2099997, (SELECT count(*) FROM public.covid_historica)),
    ( 2, 'Casos en dw.fact_casos_covid',           2099997, (SELECT count(*) FROM dw.fact_casos_covid)),
    ( 3, 'ID_REGISTRO distintos en los hechos',    2099997, (SELECT count(DISTINCT id_registro) FROM dw.fact_casos_covid)),
    ( 4, 'Casos del archivo de 2022',              1999998, (SELECT count(*) FROM dw.fact_casos_covid f
                                                             JOIN dw.dim_extracto x ON x.id_extracto = f.id_extracto
                                                             WHERE x.archivo_origen LIKE '%2022%')),
    ( 5, 'Casos del archivo de 2023',                99999, (SELECT count(*) FROM dw.fact_casos_covid f
                                                             JOIN dw.dim_extracto x ON x.id_extracto = f.id_extracto
                                                             WHERE x.archivo_origen LIKE '%2023%')),
    ( 6, 'Llaves FK declaradas y validadas',            16, (SELECT count(*) FROM pg_constraint
                                                             WHERE conrelid = 'dw.fact_casos_covid'::regclass
                                                               AND contype = 'f' AND convalidated)),
    ( 7, 'Filas en dim_tiempo',                        732, (SELECT count(*) FROM dw.dim_tiempo)),
    ( 8, 'Filas en dim_ubicacion',                    2502, (SELECT count(*) FROM dw.dim_ubicacion)),
    ( 9, 'Filas en dim_entidad',                        36, (SELECT count(*) FROM dw.dim_entidad)),
    (10, 'Filas en dim_unidad_medica',                2481, (SELECT count(*) FROM dw.dim_unidad_medica)),
    (11, 'Filas en dim_paciente',                       87, (SELECT count(*) FROM dw.dim_paciente)),
    (12, 'Filas en dim_pais',                          159, (SELECT count(*) FROM dw.dim_pais)),
    (13, 'Filas en dim_edad',                          123, (SELECT count(*) FROM dw.dim_edad)),
    (14, 'Filas en dim_comorbilidad',                 1315, (SELECT count(*) FROM dw.dim_comorbilidad)),
    (15, 'Filas en dim_atencion',                       25, (SELECT count(*) FROM dw.dim_atencion)),
    (16, 'Filas en dim_diagnostico',                    66, (SELECT count(*) FROM dw.dim_diagnostico)),
    (17, 'Filas en dim_extracto',                        2, (SELECT count(*) FROM dw.dim_extracto)),
    (18, 'Filas en dim_calidad',                        23, (SELECT count(*) FROM dw.dim_calidad)),
    (19, 'Columnas de localidad en el esquema dw',       0, (SELECT count(*) FROM information_schema.columns
                                                             WHERE table_schema = 'dw'
                                                               AND column_name ILIKE '%localidad%'))
) AS c(n, comprobacion, esperado, obtenido);

\echo ''
\echo 'Comprobaciones (todas deben decir OK):'
SELECT * FROM comprobaciones ORDER BY 1;

SELECT count(*) FILTER (WHERE resultado <> 'OK') = 0 AS todo_ok FROM comprobaciones \gset
\if :todo_ok
    \echo 'Listo: el modelo quedo cargado. Siguiente paso: sql/prueba_carga/12_validacion.sql (ver README.md).'
\else
    \echo 'Hay comprobaciones en REVISAR: su covid_historica no es igual a la de la P2. Avisenle a Santiago con esta tabla.'
\endif
