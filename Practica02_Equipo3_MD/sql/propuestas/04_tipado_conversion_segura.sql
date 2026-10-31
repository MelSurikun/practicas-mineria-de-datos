-- Práctica 02, Equipo 3. Aportación de Santiago (Arquitecto).
-- PROPUESTA para sql/04_tipado.sql (sección 4.2). No reemplaza el archivo de Melanie:
-- produce exactamente la misma tabla covid_tipada, con las mismas 45 columnas y los mismos
-- tipos, pero con conversiones que no pueden abortar la carga.
--
-- Por qué. En sql/04_tipado.sql los números se convierten con NULLIF(btrim(x), '')::smallint
-- y las fechas con una expresión regular seguida de ::date. Con estos CSV funciona, porque
-- no traen ningún valor sucio, pero un solo 'N/A' en EDAD o una fecha como 2023-02-30 (pasa
-- la expresión regular) detiene toda la inserción (ver sql/pruebas/prueba_conversion_segura.sql).
-- La sección 4.2 pide conversiones seguras, y la 4.1 pide identificar y reportar los valores
-- problemáticos antes de decidir qué hacer con ellos.
--
-- Qué cambia:
--   1. Dos funciones, a_smallint() y a_fecha(), que usan pg_input_is_valid() (PostgreSQL 16
--      o posterior) igual que TRY_CONVERT: si el texto no se puede convertir, devuelven NULL.
--      Son funciones definidas por el usuario para transformar datos, como propone el
--      capítulo de limpieza de Rahm y Do que acompaña la práctica.
--   2. Una tabla covid_tipado_rechazos que guarda, con su valor original, cada dato que no
--      se pudo convertir y que no es un centinela documentado. Así un NULL de covid_tipada
--      siempre tiene explicación: o es la regla del 9999-99-99, o está en esta tabla.
--
-- Se mantienen todas las reglas de sql/04: 9999-99-99 -> NULL (el original sigue en el stage),
-- los códigos 97, 98 y 99 se conservan como número, y las columnas que 2022 no trae quedan NULL.
--
-- Ejecutar en lugar de sql/04_tipado.sql, conectado a covid20a23sedi. Con estos CSV el
-- resultado es idéntico fila por fila al de sql/04 (lo comprueba la última consulta) y
-- covid_tipado_rechazos queda vacía.

-- Los scripts están en UTF-8. En Windows, psql suele leerlos como WIN1252 y los acentos se
-- guardan mal o detienen la carga; con esta línea el resto del archivo se lee como UTF-8.
SET client_encoding = 'UTF8';

CREATE OR REPLACE FUNCTION a_smallint(valor text) RETURNS smallint
LANGUAGE sql STABLE AS $$
    SELECT CASE WHEN pg_input_is_valid(btrim(valor, E' \t\r\n'), 'smallint')
                THEN btrim(valor, E' \t\r\n')::smallint END
$$;

CREATE OR REPLACE FUNCTION a_integer(valor text) RETURNS integer
LANGUAGE sql STABLE AS $$
    SELECT CASE WHEN pg_input_is_valid(btrim(valor, E' \t\r\n'), 'integer')
                THEN btrim(valor, E' \t\r\n')::integer END
$$;

-- 9999-99-99 no es una fecha válida, así que también devuelve NULL; la diferencia con un
-- valor sucio la marca la tabla de rechazos, que excluye solo ese centinela.
CREATE OR REPLACE FUNCTION a_fecha(valor text) RETURNS date
LANGUAGE sql STABLE AS $$
    SELECT CASE WHEN pg_input_is_valid(valor, 'date') THEN valor::date END
$$;

DROP TABLE IF EXISTS covid_tipada;
CREATE TABLE covid_tipada (
    fecha_actualizacion    date,
    id_registro            text NOT NULL,
    origen                 smallint,
    sector                 smallint,
    entidad_um             smallint,
    municipio_um           smallint,
    clues                  text,
    sexo                   smallint,
    entidad_nac            smallint,
    entidad_res            smallint,
    municipio_res          smallint,
    localidad_res          integer,
    tipo_paciente          smallint,
    fecha_ingreso          date,
    fecha_sintomas         date,
    fecha_def              date,
    intubado               smallint,
    neumonia               smallint,
    edad                   smallint,
    nacionalidad           smallint,
    embarazo               smallint,
    habla_lengua_indig     smallint,
    indigena               smallint,
    diabetes               smallint,
    epoc                   smallint,
    asma                   smallint,
    inmusupr               smallint,
    hipertension           smallint,
    otra_com               smallint,
    cardiovascular         smallint,
    obesidad               smallint,
    renal_cronica          smallint,
    tabaquismo             smallint,
    otro_caso              smallint,
    toma_muestra_lab       smallint,
    resultado_lab          smallint,
    toma_muestra_antigeno  smallint,
    resultado_antigeno     smallint,
    clasificacion_final    smallint,
    fecha_resultado        date,
    migrante               smallint,
    pais_nacionalidad      text,
    pais_origen            text,
    uci                    smallint,
    archivo_origen         text
);

-- ---- Desde el stage de 2022 (no tiene municipio_um, clues ni fecha_resultado) ----
INSERT INTO covid_tipada
SELECT a_fecha(fecha_actualizacion), id_registro,
       a_smallint(origen), a_smallint(sector), a_smallint(entidad_um),
       NULL, NULL,                                   -- municipio_um y clues no existen en 2022
       a_smallint(sexo), a_smallint(entidad_nac), a_smallint(entidad_res),
       a_smallint(municipio_res), a_integer(localidad_res), a_smallint(tipo_paciente),
       a_fecha(fecha_ingreso), a_fecha(fecha_sintomas), a_fecha(fecha_def),
       a_smallint(intubado), a_smallint(neumonia), a_smallint(edad), a_smallint(nacionalidad),
       a_smallint(embarazo), a_smallint(habla_lengua_indig), a_smallint(indigena),
       a_smallint(diabetes), a_smallint(epoc), a_smallint(asma), a_smallint(inmusupr),
       a_smallint(hipertension), a_smallint(otra_com), a_smallint(cardiovascular),
       a_smallint(obesidad), a_smallint(renal_cronica), a_smallint(tabaquismo),
       a_smallint(otro_caso), a_smallint(toma_muestra_lab), a_smallint(resultado_lab),
       a_smallint(toma_muestra_antigeno), a_smallint(resultado_antigeno),
       a_smallint(clasificacion_final),
       NULL,                                         -- fecha_resultado no existe en 2022
       a_smallint(migrante),                         -- el recorte quita el tabulador de "\t99"
       pais_nacionalidad, pais_origen, a_smallint(uci), archivo_origen
FROM covid_stage_2022;

-- ---- Desde el stage de 2023 (trae las 3 columnas adicionales) ----
INSERT INTO covid_tipada
SELECT a_fecha(fecha_actualizacion), id_registro,
       a_smallint(origen), a_smallint(sector), a_smallint(entidad_um),
       a_smallint(municipio_um), clues,
       a_smallint(sexo), a_smallint(entidad_nac), a_smallint(entidad_res),
       a_smallint(municipio_res), a_integer(localidad_res), a_smallint(tipo_paciente),
       a_fecha(fecha_ingreso), a_fecha(fecha_sintomas), a_fecha(fecha_def),
       a_smallint(intubado), a_smallint(neumonia), a_smallint(edad), a_smallint(nacionalidad),
       a_smallint(embarazo), a_smallint(habla_lengua_indig), a_smallint(indigena),
       a_smallint(diabetes), a_smallint(epoc), a_smallint(asma), a_smallint(inmusupr),
       a_smallint(hipertension), a_smallint(otra_com), a_smallint(cardiovascular),
       a_smallint(obesidad), a_smallint(renal_cronica), a_smallint(tabaquismo),
       a_smallint(otro_caso), a_smallint(toma_muestra_lab), a_smallint(resultado_lab),
       a_smallint(toma_muestra_antigeno), a_smallint(resultado_antigeno),
       a_smallint(clasificacion_final),
       a_fecha(fecha_resultado),
       a_smallint(migrante),
       pais_nacionalidad, pais_origen, a_smallint(uci), archivo_origen
FROM covid_stage_2023;

-- ---- Rechazos: todo valor que no se pudo convertir y que no es un centinela documentado ----
DROP TABLE IF EXISTS covid_tipado_rechazos;
CREATE TABLE covid_tipado_rechazos (
    archivo_origen  text,
    id_registro     text,
    columna         text,
    tipo_destino    text,
    valor_original  text
);

INSERT INTO covid_tipado_rechazos
SELECT s.archivo_origen, s.id_registro, v.columna, v.tipo, v.valor
FROM (SELECT archivo_origen, id_registro, fecha_actualizacion, origen, sector, entidad_um,
             NULL::text AS municipio_um, sexo, entidad_nac, entidad_res, municipio_res,
             localidad_res, tipo_paciente, fecha_ingreso, fecha_sintomas, fecha_def, intubado,
             neumonia, edad, nacionalidad, embarazo, habla_lengua_indig, indigena, diabetes,
             epoc, asma, inmusupr, hipertension, otra_com, cardiovascular, obesidad,
             renal_cronica, tabaquismo, otro_caso, toma_muestra_lab, resultado_lab,
             toma_muestra_antigeno, resultado_antigeno, clasificacion_final,
             NULL::text AS fecha_resultado, migrante, uci
      FROM covid_stage_2022
      UNION ALL
      SELECT archivo_origen, id_registro, fecha_actualizacion, origen, sector, entidad_um,
             municipio_um, sexo, entidad_nac, entidad_res, municipio_res, localidad_res,
             tipo_paciente, fecha_ingreso, fecha_sintomas, fecha_def, intubado, neumonia, edad,
             nacionalidad, embarazo, habla_lengua_indig, indigena, diabetes, epoc, asma,
             inmusupr, hipertension, otra_com, cardiovascular, obesidad, renal_cronica,
             tabaquismo, otro_caso, toma_muestra_lab, resultado_lab, toma_muestra_antigeno,
             resultado_antigeno, clasificacion_final, fecha_resultado, migrante, uci
      FROM covid_stage_2023) s
CROSS JOIN LATERAL (VALUES
    ('fecha_actualizacion', 'date', s.fecha_actualizacion), ('origen', 'smallint', s.origen),
    ('sector', 'smallint', s.sector), ('entidad_um', 'smallint', s.entidad_um),
    ('municipio_um', 'smallint', s.municipio_um), ('sexo', 'smallint', s.sexo),
    ('entidad_nac', 'smallint', s.entidad_nac), ('entidad_res', 'smallint', s.entidad_res),
    ('municipio_res', 'smallint', s.municipio_res), ('localidad_res', 'integer', s.localidad_res),
    ('tipo_paciente', 'smallint', s.tipo_paciente), ('fecha_ingreso', 'date', s.fecha_ingreso),
    ('fecha_sintomas', 'date', s.fecha_sintomas), ('fecha_def', 'date', s.fecha_def),
    ('intubado', 'smallint', s.intubado), ('neumonia', 'smallint', s.neumonia),
    ('edad', 'smallint', s.edad), ('nacionalidad', 'smallint', s.nacionalidad),
    ('embarazo', 'smallint', s.embarazo), ('habla_lengua_indig', 'smallint', s.habla_lengua_indig),
    ('indigena', 'smallint', s.indigena), ('diabetes', 'smallint', s.diabetes),
    ('epoc', 'smallint', s.epoc), ('asma', 'smallint', s.asma),
    ('inmusupr', 'smallint', s.inmusupr), ('hipertension', 'smallint', s.hipertension),
    ('otra_com', 'smallint', s.otra_com), ('cardiovascular', 'smallint', s.cardiovascular),
    ('obesidad', 'smallint', s.obesidad), ('renal_cronica', 'smallint', s.renal_cronica),
    ('tabaquismo', 'smallint', s.tabaquismo), ('otro_caso', 'smallint', s.otro_caso),
    ('toma_muestra_lab', 'smallint', s.toma_muestra_lab),
    ('resultado_lab', 'smallint', s.resultado_lab),
    ('toma_muestra_antigeno', 'smallint', s.toma_muestra_antigeno),
    ('resultado_antigeno', 'smallint', s.resultado_antigeno),
    ('clasificacion_final', 'smallint', s.clasificacion_final),
    ('fecha_resultado', 'date', s.fecha_resultado), ('migrante', 'smallint', s.migrante),
    ('uci', 'smallint', s.uci)
) AS v (columna, tipo, valor)
WHERE v.valor IS NOT NULL
  AND NOT pg_input_is_valid(CASE WHEN v.tipo = 'date' THEN v.valor
                                 ELSE btrim(v.valor, E' \t\r\n') END, v.tipo)
  AND NOT (v.tipo = 'date' AND v.valor = '9999-99-99');

-- Verificación:
--   SELECT count(*) FROM covid_tipada;            -- esperado: 4099995
--   SELECT count(*) FROM covid_tipado_rechazos;   -- esperado con estos CSV: 0
--   SELECT columna, count(*) FROM covid_tipado_rechazos GROUP BY 1;  -- si algún día hay rechazos
SELECT (SELECT count(*) FROM covid_tipada)          AS filas_covid_tipada,
       (SELECT count(*) FROM covid_tipado_rechazos) AS valores_rechazados;
