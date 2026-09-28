-- Práctica 02 — Equipo 3
-- Paso 2: tablas de paso ("stage"), todo en texto.
-- Se crean DOS tablas porque los CSV de origen no comparten el mismo esquema:
--   - 2022: 41 columnas
--   - 2023: 44 columnas (agrega MUNICIPIO_UM, CLUES, FECHA_RESULTADO)
-- Se usa "text" (sin límite de longitud) y no varchar(n) porque PAIS_ORIGEN llega
-- a tener valores de 54 caracteres que desbordarían un varchar(50) como el del
-- ejemplo del enunciado.
-- Ejecutar conectado a la base covid20a23sedi: \c covid20a23sedi

CREATE TABLE IF NOT EXISTS covid_stage_2022 (
    fecha_actualizacion   text,
    id_registro           text,
    origen                text,
    sector                text,
    entidad_um            text,
    sexo                  text,
    entidad_nac           text,
    entidad_res           text,
    municipio_res         text,
    localidad_res         text,
    tipo_paciente         text,
    fecha_ingreso         text,
    fecha_sintomas        text,
    fecha_def             text,
    intubado              text,
    neumonia              text,
    edad                  text,
    nacionalidad          text,
    embarazo              text,
    habla_lengua_indig    text,
    indigena              text,
    diabetes              text,
    epoc                  text,
    asma                  text,
    inmusupr              text,
    hipertension          text,
    otra_com              text,
    cardiovascular        text,
    obesidad              text,
    renal_cronica         text,
    tabaquismo            text,
    otro_caso             text,
    toma_muestra_lab      text,
    resultado_lab         text,
    toma_muestra_antigeno text,
    resultado_antigeno    text,
    clasificacion_final   text,
    migrante              text,
    pais_nacionalidad     text,
    pais_origen           text,
    uci                   text,
    archivo_origen        text
);

CREATE TABLE IF NOT EXISTS covid_stage_2023 (
    fecha_actualizacion   text,
    id_registro           text,
    origen                text,
    sector                text,
    entidad_um            text,
    municipio_um          text,
    clues                 text,
    sexo                  text,
    entidad_nac           text,
    entidad_res           text,
    municipio_res         text,
    localidad_res         text,
    tipo_paciente         text,
    fecha_ingreso         text,
    fecha_sintomas        text,
    fecha_def             text,
    intubado              text,
    neumonia              text,
    edad                  text,
    nacionalidad          text,
    embarazo              text,
    habla_lengua_indig    text,
    indigena              text,
    diabetes              text,
    epoc                  text,
    asma                  text,
    inmusupr              text,
    hipertension          text,
    otra_com              text,
    cardiovascular        text,
    obesidad              text,
    renal_cronica         text,
    tabaquismo            text,
    otro_caso             text,
    toma_muestra_lab      text,
    resultado_lab         text,
    toma_muestra_antigeno text,
    resultado_antigeno    text,
    clasificacion_final   text,
    fecha_resultado       text,
    migrante              text,
    pais_nacionalidad     text,
    pais_origen           text,
    uci                   text,
    archivo_origen        text
);

-- Verificación:
--   \d covid_stage_2022   (debe listar 42 columnas: 41 + archivo_origen)
--   \d covid_stage_2023   (debe listar 45 columnas: 44 + archivo_origen)
