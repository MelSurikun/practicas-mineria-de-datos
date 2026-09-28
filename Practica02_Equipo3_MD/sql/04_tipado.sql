-- Práctica 02, Equipo 3
-- Paso 4: tabla tipada final (sección 4.2).
-- Superconjunto de 44 columnas de datos, tipos validados contra el anexo del
-- enunciado y contra el diccionario oficial. PostgreSQL no tiene TRY_CONVERT,
-- así que cada conversión usa CASE para validar el formato antes de convertir:
-- si el valor no cumple el patrón esperado, el resultado es NULL, documentado,
-- en vez de descartar la fila o detener la carga.
--
-- Regla de fechas: 9999-99-99 es el centinela oficial de "no aplica" (por
-- ejemplo, FECHA_DEF cuando no hubo defunción). Se convierte a NULL en esta
-- tabla, pero el valor original sigue intacto en covid_stage_2022 y
-- covid_stage_2023, que nunca se modifican.
--
-- Regla de códigos centinela (97, 98, 99): se CONSERVAN como valor numérico,
-- no se convierten a NULL aquí, porque la sección 6 del reporte (a cargo de
-- otro rol del equipo) los necesita para el análisis de anomalías.
--
-- Ejecutar conectado a covid20a23sedi: \c covid20a23sedi

CREATE TABLE IF NOT EXISTS covid_tipada (
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
INSERT INTO covid_tipada (
    fecha_actualizacion, id_registro, origen, sector, entidad_um, municipio_um, clues,
    sexo, entidad_nac, entidad_res, municipio_res, localidad_res, tipo_paciente,
    fecha_ingreso, fecha_sintomas, fecha_def, intubado, neumonia, edad, nacionalidad,
    embarazo, habla_lengua_indig, indigena, diabetes, epoc, asma, inmusupr, hipertension,
    otra_com, cardiovascular, obesidad, renal_cronica, tabaquismo, otro_caso,
    toma_muestra_lab, resultado_lab, toma_muestra_antigeno, resultado_antigeno,
    clasificacion_final, fecha_resultado, migrante, pais_nacionalidad, pais_origen, uci,
    archivo_origen
)
SELECT
    CASE WHEN fecha_actualizacion ~ '^\d{4}-\d{2}-\d{2}$' THEN fecha_actualizacion::date END,
    id_registro,
    NULLIF(btrim(origen), '')::smallint,
    NULLIF(btrim(sector), '')::smallint,
    NULLIF(btrim(entidad_um), '')::smallint,
    NULL, -- municipio_um no existe en el CSV de 2022
    NULL, -- clues no existe en el CSV de 2022
    NULLIF(btrim(sexo), '')::smallint,
    NULLIF(btrim(entidad_nac), '')::smallint,
    NULLIF(btrim(entidad_res), '')::smallint,
    NULLIF(btrim(municipio_res), '')::smallint,
    NULLIF(btrim(localidad_res), '')::integer,
    NULLIF(btrim(tipo_paciente), '')::smallint,
    CASE WHEN fecha_ingreso ~ '^\d{4}-\d{2}-\d{2}$' THEN fecha_ingreso::date END,
    CASE WHEN fecha_sintomas ~ '^\d{4}-\d{2}-\d{2}$' THEN fecha_sintomas::date END,
    CASE WHEN fecha_def ~ '^\d{4}-\d{2}-\d{2}$' AND fecha_def <> '9999-99-99'
         THEN fecha_def::date END,
    NULLIF(btrim(intubado), '')::smallint,
    NULLIF(btrim(neumonia), '')::smallint,
    NULLIF(btrim(edad), '')::smallint,
    NULLIF(btrim(nacionalidad), '')::smallint,
    NULLIF(btrim(embarazo), '')::smallint,
    NULLIF(btrim(habla_lengua_indig), '')::smallint,
    NULLIF(btrim(indigena), '')::smallint,
    NULLIF(btrim(diabetes), '')::smallint,
    NULLIF(btrim(epoc), '')::smallint,
    NULLIF(btrim(asma), '')::smallint,
    NULLIF(btrim(inmusupr), '')::smallint,
    NULLIF(btrim(hipertension), '')::smallint,
    NULLIF(btrim(otra_com), '')::smallint,
    NULLIF(btrim(cardiovascular), '')::smallint,
    NULLIF(btrim(obesidad), '')::smallint,
    NULLIF(btrim(renal_cronica), '')::smallint,
    NULLIF(btrim(tabaquismo), '')::smallint,
    NULLIF(btrim(otro_caso), '')::smallint,
    NULLIF(btrim(toma_muestra_lab), '')::smallint,
    NULLIF(btrim(resultado_lab), '')::smallint,
    NULLIF(btrim(toma_muestra_antigeno), '')::smallint,
    NULLIF(btrim(resultado_antigeno), '')::smallint,
    NULLIF(btrim(clasificacion_final), '')::smallint,
    NULL, -- fecha_resultado no existe en el CSV de 2022
    NULLIF(btrim(migrante), '')::smallint,  -- btrim quita el tabulador suelto ("\t99")
    pais_nacionalidad,
    pais_origen,
    NULLIF(btrim(uci), '')::smallint,
    archivo_origen
FROM covid_stage_2022;

-- ---- Desde el stage de 2023 (trae las 3 columnas adicionales) ----
INSERT INTO covid_tipada (
    fecha_actualizacion, id_registro, origen, sector, entidad_um, municipio_um, clues,
    sexo, entidad_nac, entidad_res, municipio_res, localidad_res, tipo_paciente,
    fecha_ingreso, fecha_sintomas, fecha_def, intubado, neumonia, edad, nacionalidad,
    embarazo, habla_lengua_indig, indigena, diabetes, epoc, asma, inmusupr, hipertension,
    otra_com, cardiovascular, obesidad, renal_cronica, tabaquismo, otro_caso,
    toma_muestra_lab, resultado_lab, toma_muestra_antigeno, resultado_antigeno,
    clasificacion_final, fecha_resultado, migrante, pais_nacionalidad, pais_origen, uci,
    archivo_origen
)
SELECT
    CASE WHEN fecha_actualizacion ~ '^\d{4}-\d{2}-\d{2}$' THEN fecha_actualizacion::date END,
    id_registro,
    NULLIF(btrim(origen), '')::smallint,
    NULLIF(btrim(sector), '')::smallint,
    NULLIF(btrim(entidad_um), '')::smallint,
    NULLIF(btrim(municipio_um), '')::smallint,
    clues,
    NULLIF(btrim(sexo), '')::smallint,
    NULLIF(btrim(entidad_nac), '')::smallint,
    NULLIF(btrim(entidad_res), '')::smallint,
    NULLIF(btrim(municipio_res), '')::smallint,
    NULLIF(btrim(localidad_res), '')::integer,
    NULLIF(btrim(tipo_paciente), '')::smallint,
    CASE WHEN fecha_ingreso ~ '^\d{4}-\d{2}-\d{2}$' THEN fecha_ingreso::date END,
    CASE WHEN fecha_sintomas ~ '^\d{4}-\d{2}-\d{2}$' THEN fecha_sintomas::date END,
    CASE WHEN fecha_def ~ '^\d{4}-\d{2}-\d{2}$' AND fecha_def <> '9999-99-99'
         THEN fecha_def::date END,
    NULLIF(btrim(intubado), '')::smallint,
    NULLIF(btrim(neumonia), '')::smallint,
    NULLIF(btrim(edad), '')::smallint,
    NULLIF(btrim(nacionalidad), '')::smallint,
    NULLIF(btrim(embarazo), '')::smallint,
    NULLIF(btrim(habla_lengua_indig), '')::smallint,
    NULLIF(btrim(indigena), '')::smallint,
    NULLIF(btrim(diabetes), '')::smallint,
    NULLIF(btrim(epoc), '')::smallint,
    NULLIF(btrim(asma), '')::smallint,
    NULLIF(btrim(inmusupr), '')::smallint,
    NULLIF(btrim(hipertension), '')::smallint,
    NULLIF(btrim(otra_com), '')::smallint,
    NULLIF(btrim(cardiovascular), '')::smallint,
    NULLIF(btrim(obesidad), '')::smallint,
    NULLIF(btrim(renal_cronica), '')::smallint,
    NULLIF(btrim(tabaquismo), '')::smallint,
    NULLIF(btrim(otro_caso), '')::smallint,
    NULLIF(btrim(toma_muestra_lab), '')::smallint,
    NULLIF(btrim(resultado_lab), '')::smallint,
    NULLIF(btrim(toma_muestra_antigeno), '')::smallint,
    NULLIF(btrim(resultado_antigeno), '')::smallint,
    NULLIF(btrim(clasificacion_final), '')::smallint,
    CASE WHEN fecha_resultado ~ '^\d{4}-\d{2}-\d{2}$' AND fecha_resultado <> '9999-99-99'
         THEN fecha_resultado::date END,
    NULLIF(btrim(migrante), '')::smallint,
    pais_nacionalidad,
    pais_origen,
    NULLIF(btrim(uci), '')::smallint,
    archivo_origen
FROM covid_stage_2023;

-- Verificación:
--   SELECT count(*) FROM covid_tipada;                              -- esperado: 4099995
--   SELECT count(*) FROM covid_tipada WHERE fecha_def IS NOT NULL;   -- > 0, confirma que no se anuló todo
--   SELECT count(*) FROM covid_tipada WHERE municipio_um IS NOT NULL;-- solo filas de 2023
