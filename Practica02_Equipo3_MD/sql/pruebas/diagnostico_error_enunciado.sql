-- Práctica 02, Equipo 3. Aportación de Santiago (Arquitecto).
-- Diagnóstico del error de BULK INSERT que muestra la captura del enunciado
-- (Msg 4864 en la columna 40, PAIS_ORIGEN, filas 6968, 10139, 10675, 15328 y 17218).
--
-- No forma parte del proceso de carga: son pruebas sobre tablas temporales que
-- desaparecen al cerrar la sesión. Se ejecuta con psql desde la carpeta que contiene
-- Covid_Muestras/ (la misma convención que sql/03_ingesta.sql), conectado a covid20a23sedi.
-- Usa el CSV ORIGINAL de 2022, como en la captura; los errores aparecen mucho antes de la
-- línea 1,999,999, donde está el encabezado duplicado.
\set ON_ERROR_STOP 0
-- Los scripts están en UTF-8. En Windows, psql suele leerlos como WIN1252 y los acentos se
-- guardan mal o detienen la carga; con esta línea el resto del archivo se lee como UTF-8.
SET client_encoding = 'UTF8';

-- Prueba A. Stage con los tamaños del ejemplo del enunciado (nvarchar -> varchar;
-- ambos cuentan caracteres, no bytes).
CREATE TEMP TABLE stage_ejemplo_enunciado (
    fecha_actualizacion varchar(50), id_registro varchar(50), origen varchar(20),
    sector varchar(20), entidad_um varchar(20), sexo varchar(20), entidad_nac varchar(50),
    entidad_res varchar(50), municipio_res varchar(50), localidad_res varchar(50),
    tipo_paciente varchar(20), fecha_ingreso varchar(50), fecha_sintomas varchar(50),
    fecha_def varchar(50), intubado varchar(20), neumonia varchar(20), edad varchar(20),
    nacionalidad varchar(50), embarazo varchar(20), habla_lengua_indig varchar(20),
    indigena varchar(20), diabetes varchar(20), epoc varchar(20), asma varchar(20),
    inmusupr varchar(20), hipertension varchar(20), otra_com varchar(20),
    cardiovascular varchar(20), obesidad varchar(20), renal_cronica varchar(20),
    tabaquismo varchar(20), otro_caso varchar(20), toma_muestra_lab varchar(20),
    resultado_lab varchar(20), toma_muestra_antigeno varchar(20), resultado_antigeno varchar(20),
    clasificacion_final varchar(20), migrante varchar(20), pais_nacionalidad varchar(100),
    pais_origen varchar(50), uci varchar(20)
);
\echo '--- Prueba A: stage del ejemplo del enunciado (pais_origen varchar(50))'
\copy stage_ejemplo_enunciado FROM 'Covid_Muestras/muestra200k_COVID19MEXICOLOC2022.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '"', ENCODING 'UTF8')

-- Prueba B. El mismo stage, pero con PAIS_ORIGEN numérico, que es el tipo que resulta
-- si se infiere a partir de las primeras filas: hasta la línea 6967 todos los valores son 97.
CREATE TEMP TABLE stage_pais_origen_numerico (LIKE stage_ejemplo_enunciado);
ALTER TABLE stage_pais_origen_numerico ALTER COLUMN pais_origen TYPE smallint USING NULL;
\echo '--- Prueba B: pais_origen smallint'
\copy stage_pais_origen_numerico FROM 'Covid_Muestras/muestra200k_COVID19MEXICOLOC2022.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '"', ENCODING 'UTF8')

-- Prueba C. Cuántas líneas fallarían con cada definición (se leen como texto y se evalúa
-- la conversión fila por fila con pg_input_is_valid, disponible desde PostgreSQL 16).
\echo '--- Prueba C: filas que fallarían en todo el archivo'
SELECT
    count(*) FILTER (WHERE NOT pg_input_is_valid(pais_origen, 'smallint'))    AS fallan_como_smallint,
    count(*) FILTER (WHERE NOT pg_input_is_valid(pais_origen, 'varchar(50)')) AS fallan_como_varchar50,
    count(*) FILTER (WHERE NOT pg_input_is_valid(pais_origen, 'varchar(100)')) AS fallan_como_varchar100,
    count(*)                                                                    AS filas_stage_2022
FROM covid_stage_2022;
