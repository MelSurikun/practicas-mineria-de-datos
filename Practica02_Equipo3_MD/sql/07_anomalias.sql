-- Práctica 02, Equipo 3
-- Paso 7: validación cruzada entre atributos (anomalías de consistencia
-- lógica). Complementa la sección 6 del reporte (a cargo de otro rol del
-- equipo), que revisa cada columna por separado; aquí se revisan relaciones
-- entre columnas que deberían ser consistentes entre sí, por ejemplo que
-- solo las mujeres tengan embarazo positivo, o que las fechas respeten su
-- orden lógico. La vista resultante es también la que alimentaría una
-- dimensión de calidad en el modelo de cubo (ver sección de preparación
-- para el modelo multidimensional del reporte).
--
-- Ejecutar conectado a covid20a23sedi: \c covid20a23sedi

DROP VIEW IF EXISTS v_anomalias;
CREATE VIEW v_anomalias AS
SELECT 'embarazo_en_hombres' AS regla,
       'embarazo = 1 con sexo = 2 (hombre)' AS descripcion,
       count(*) AS registros
FROM covid_historica WHERE embarazo = 1 AND sexo = 2
UNION ALL
SELECT 'embarazo_edad_fuera_rango',
       'embarazo = 1 con edad menor a 10 o mayor a 60 años',
       count(*)
FROM covid_historica WHERE embarazo = 1 AND (edad < 10 OR edad > 60)
UNION ALL
SELECT 'defuncion_en_ambulatorio',
       'fecha_def no nula con tipo_paciente = 1 (ambulatorio)',
       count(*)
FROM covid_historica WHERE fecha_def IS NOT NULL AND tipo_paciente = 1
UNION ALL
SELECT 'sintomas_despues_de_ingreso',
       'fecha_sintomas posterior a fecha_ingreso',
       count(*)
FROM covid_historica
WHERE fecha_sintomas IS NOT NULL AND fecha_ingreso IS NOT NULL
  AND fecha_sintomas > fecha_ingreso
UNION ALL
SELECT 'ingreso_despues_de_defuncion',
       'fecha_ingreso posterior a fecha_def',
       count(*)
FROM covid_historica
WHERE fecha_ingreso IS NOT NULL AND fecha_def IS NOT NULL
  AND fecha_ingreso > fecha_def
UNION ALL
SELECT 'resultado_antes_de_ingreso',
       'fecha_resultado anterior a fecha_ingreso',
       count(*)
FROM covid_historica
WHERE fecha_resultado IS NOT NULL AND fecha_ingreso IS NOT NULL
  AND fecha_resultado < fecha_ingreso
UNION ALL
SELECT 'uci_en_ambulatorio',
       'uci = 1 con tipo_paciente = 1 (ambulatorio)',
       count(*)
FROM covid_historica WHERE uci = 1 AND tipo_paciente = 1
UNION ALL
SELECT 'intubado_sin_uci',
       'intubado = 1 con uci = 2 (no ingresó a terapia intensiva)',
       count(*)
FROM covid_historica WHERE intubado = 1 AND uci = 2
UNION ALL
SELECT 'resultado_lab_sin_muestra',
       'resultado_lab positivo o negativo con toma_muestra_lab = 2 (no se tomó)',
       count(*)
FROM covid_historica WHERE resultado_lab IN (1, 2) AND toma_muestra_lab = 2
UNION ALL
SELECT 'municipio_fuera_de_su_entidad',
       'el par entidad_res/municipio_res no existe en cat_municipios',
       count(*) FILTER (WHERE m.municipio IS NULL)
FROM covid_historica h
LEFT JOIN cat_municipios m
       ON m.clave_entidad = h.entidad_res AND m.clave_municipio = h.municipio_res
;

-- Denominadores usados en el reporte, calculados aparte porque no todas las
-- reglas comparten el mismo universo (algunas aplican solo a mujeres en edad
-- fértil, otras a quienes fueron intubados, etc.):
--   SELECT count(*) FROM covid_historica;                                          -- 2099997, universo general
--   SELECT count(*) FROM covid_historica WHERE sexo = 1 AND edad BETWEEN 12 AND 55; -- mujeres en edad fértil
--   SELECT count(*) FROM covid_historica WHERE intubado = 1;                       -- universo de intubados

-- Verificación: SELECT * FROM v_anomalias ORDER BY registros DESC;
