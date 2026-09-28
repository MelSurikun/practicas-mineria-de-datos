-- Práctica 02, Equipo 3
-- Paso 3: ingesta de los CSV con \copy (lado cliente, no requiere permisos
-- especiales del servidor como BULK INSERT / COPY del lado servidor).
--
-- Las rutas de FROM '...' apuntan a la carpeta Covid_Muestras/ dentro de este
-- mismo repositorio. Si alguien tiene los CSV en otra ubicación, ajusta la
-- ruta antes de ejecutar (usa siempre / como separador, funciona en Windows).
--
-- Ejecutar con psql conectado a covid20a23sedi: \c covid20a23sedi
-- Estos comandos \copy solo funcionan dentro de psql, no en pgAdmin (ahí se
-- usa el asistente "Import/Export Data" apuntando al mismo archivo).

-- ---- 2023 (44 columnas, se carga primero por ser el archivo más pequeño) ----
\copy covid_stage_2023 (fecha_actualizacion, id_registro, origen, sector, entidad_um, municipio_um, clues, sexo, entidad_nac, entidad_res, municipio_res, localidad_res, tipo_paciente, fecha_ingreso, fecha_sintomas, fecha_def, intubado, neumonia, edad, nacionalidad, embarazo, habla_lengua_indig, indigena, diabetes, epoc, asma, inmusupr, hipertension, otra_com, cardiovascular, obesidad, renal_cronica, tabaquismo, otro_caso, toma_muestra_lab, resultado_lab, toma_muestra_antigeno, resultado_antigeno, clasificacion_final, fecha_resultado, migrante, pais_nacionalidad, pais_origen, uci) FROM 'Covid_Muestras/muestra100k_COVID19MEXICOLOC2023.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '"', ENCODING 'UTF8');

UPDATE covid_stage_2023
   SET archivo_origen = 'muestra100k_COVID19MEXICOLOC2023.csv'
 WHERE archivo_origen IS NULL;

-- ---- 2022 (41 columnas, archivo grande: ~686 MB, ~4 millones de filas) ----
-- Se carga desde una copia reparada del CSV, no del archivo original.
-- El original trae, exactamente a la mitad del archivo (byte 343,178,461 de
-- 686,356,922), el encabezado repetido pegado sin salto de línea al final de
-- la fila anterior, como si dos extractos se hubieran concatenado sin quitar
-- el segundo encabezado ni insertar el salto de línea entre ambos. El
-- detalle completo, con evidencia de antes y después, está en
-- evidencias/bitacora_errores.md (hallazgo 6). El archivo original no se
-- modifica; la copia reparada se genera con scripts/reparar_csv_2022.py y no
-- se versiona (ver .gitignore), cualquiera puede regenerarla.
\copy covid_stage_2022 (fecha_actualizacion, id_registro, origen, sector, entidad_um, sexo, entidad_nac, entidad_res, municipio_res, localidad_res, tipo_paciente, fecha_ingreso, fecha_sintomas, fecha_def, intubado, neumonia, edad, nacionalidad, embarazo, habla_lengua_indig, indigena, diabetes, epoc, asma, inmusupr, hipertension, otra_com, cardiovascular, obesidad, renal_cronica, tabaquismo, otro_caso, toma_muestra_lab, resultado_lab, toma_muestra_antigeno, resultado_antigeno, clasificacion_final, migrante, pais_nacionalidad, pais_origen, uci) FROM 'Covid_Muestras/muestra200k_COVID19MEXICOLOC2022_reparado.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '"', ENCODING 'UTF8');

UPDATE covid_stage_2022
   SET archivo_origen = 'muestra200k_COVID19MEXICOLOC2022.csv'
 WHERE archivo_origen IS NULL;

-- Verificación de conteos (deben coincidir con las filas reales del CSV, sin encabezado):
--   SELECT count(*) FROM covid_stage_2023;   -- esperado: 99999
--   SELECT count(*) FROM covid_stage_2022;   -- esperado: 3999996
