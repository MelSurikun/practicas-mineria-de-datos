-- Práctica 03, Equipo 3 (Melanie, Análisis y Visualización). Punto 6: exploración analítica
-- de una, dos y tres dimensiones sobre el modelo estrella. Solo lectura.
--
-- Cada bloque se guarda como CSV en evidencias/exploracion/ con
--   python scripts/exportar_consultas.py sql/10_exploracion.sql exploracion
-- y scripts/graficar_p3.py dibuja a partir de esos CSV. Reemplaza a sql/apoyo_graficas.sql.
--
-- Convenciones:
--   * Fecha: inicio de síntomas (id_fecha_sintomas), salvo que se indique otra.
--   * Se compara por mes o semana epidemiológica, no por año: el archivo «2022» cubre casi
--     solo enero a junio de 2022 y el «2023», casi solo enero de 2023.
--   * Positividad = confirmados / (confirmados + negativos); sospechosos y no concluyentes
--     no tienen resultado y quedan fuera.
--   * Letalidad = defunciones de confirmados / confirmados = sum(defunciones * confirmados) /
--     sum(confirmados). sum(defunciones) contaría muertes de casos no confirmados.
--   * Hospitalización = hospitalizados / casos.
--   * Prevalencia de una comorbilidad: denominador = casos con 1 (SÍ) o 2 (NO); los 97, 98
--     y 99 se reportan aparte.
--   * Edad: se excluyen las 34 edades no válidas (122 años) solo donde se usa la edad.
--   * Son conteos de una muestra sin población de referencia: no son tasas de incidencia.

-- =======================================================================================
-- 6a. UNA DIMENSIÓN: qué, cuándo, dónde y con qué características
-- =======================================================================================

-- @consulta x01_curva_semanal
-- Cuándo: la curva epidémica por semana epidemiológica, con positividad y gravedad.
SELECT t.anio_epi, t.semana_epi, min(t.inicio_semana_epi) AS inicio_semana,
       sum(f.casos) AS casos,
       sum(f.confirmados) AS confirmados,
       sum(f.casos) FILTER (WHERE d.grupo_clasificacion = 'NEGATIVO') AS negativos,
       round(100.0 * sum(f.confirmados)
             / nullif(sum(f.confirmados) + sum(f.casos) FILTER (WHERE d.grupo_clasificacion = 'NEGATIVO'), 0), 2) AS positividad,
       sum(f.hospitalizados) AS hospitalizados,
       sum(f.defunciones * f.confirmados) AS defunciones_confirmados
FROM dw.fact_casos_covid f
JOIN dw.dim_tiempo t      ON t.id_tiempo = f.id_fecha_sintomas
JOIN dw.dim_diagnostico d ON d.id_diagnostico = f.id_diagnostico
GROUP BY 1, 2
ORDER BY 1, 2;

-- @consulta x02_por_mes
-- Cuándo, a nivel mes. fuera_de_periodo marca los meses que casi no tienen casos.
SELECT t.anio_mes, sum(f.casos) AS casos, sum(f.confirmados) AS confirmados,
       t.anio_mes NOT IN ('2022-01', '2022-02', '2022-03', '2022-04', '2022-05', '2022-06', '2023-01') AS fuera_de_periodo
FROM dw.fact_casos_covid f
JOIN dw.dim_tiempo t ON t.id_tiempo = f.id_fecha_sintomas
GROUP BY 1
ORDER BY 1;

-- @consulta x03_por_entidad
-- Dónde: ranking por entidad de residencia, con la clave del INEGI para un mapa.
SELECT u.cve_entidad, lpad(u.cve_entidad::text, 2, '0') AS cvegeo_entidad, u.nombre_entidad,
       sum(f.casos) AS casos,
       round(100.0 * sum(f.casos) / sum(sum(f.casos)) OVER (), 2) AS pct_del_total,
       round(100.0 * sum(f.confirmados)
             / nullif(sum(f.confirmados) + sum(f.casos) FILTER (WHERE d.grupo_clasificacion = 'NEGATIVO'), 0), 2) AS positividad,
       round(100.0 * sum(f.hospitalizados) / sum(f.casos), 2) AS pct_hospitalizados,
       sum(f.confirmados) AS confirmados,
       round(100.0 * sum(f.defunciones * f.confirmados) / nullif(sum(f.confirmados), 0), 3) AS letalidad
FROM dw.fact_casos_covid f
JOIN dw.dim_ubicacion u   ON u.id_ubicacion = f.id_ubicacion_residencia
JOIN dw.dim_diagnostico d ON d.id_diagnostico = f.id_diagnostico
GROUP BY 1, 2, 3
ORDER BY casos DESC;

-- @consulta x04_por_sexo
-- Con qué características: sexo.
SELECT p.sexo_desc,
       sum(f.casos) AS casos,
       round(100.0 * sum(f.casos) / sum(sum(f.casos)) OVER (), 2) AS pct_del_total,
       round(100.0 * sum(f.confirmados)
             / nullif(sum(f.confirmados) + sum(f.casos) FILTER (WHERE d.grupo_clasificacion = 'NEGATIVO'), 0), 2) AS positividad,
       round(100.0 * sum(f.hospitalizados) / sum(f.casos), 2) AS pct_hospitalizados,
       sum(f.confirmados) AS confirmados,
       round(100.0 * sum(f.defunciones * f.confirmados) / nullif(sum(f.confirmados), 0), 3) AS letalidad
FROM dw.fact_casos_covid f
JOIN dw.dim_paciente p    ON p.id_paciente = f.id_paciente
JOIN dw.dim_diagnostico d ON d.id_diagnostico = f.id_diagnostico
GROUP BY 1
ORDER BY 1;

-- @consulta x05_por_grupo_etario
-- Con qué características: los cuatro grupos etarios del modelo.
SELECT e.grupo_etario,
       sum(f.casos) AS casos,
       round(100.0 * sum(f.casos) / sum(sum(f.casos)) OVER (), 2) AS pct_del_total,
       round(100.0 * sum(f.confirmados)
             / nullif(sum(f.confirmados) + sum(f.casos) FILTER (WHERE d.grupo_clasificacion = 'NEGATIVO'), 0), 2) AS positividad,
       round(100.0 * sum(f.hospitalizados) / sum(f.casos), 2) AS pct_hospitalizados,
       round(100.0 * sum(f.ingresos_uci) / sum(f.casos), 3) AS pct_uci,
       sum(f.confirmados) AS confirmados,
       round(100.0 * sum(f.defunciones * f.confirmados) / nullif(sum(f.confirmados), 0), 3) AS letalidad
FROM dw.fact_casos_covid f
JOIN dw.dim_edad e        ON e.id_edad = f.id_edad
JOIN dw.dim_diagnostico d ON d.id_diagnostico = f.id_diagnostico
WHERE e.es_edad_valida
GROUP BY 1
ORDER BY 1;

-- @consulta x06_por_grupo_decenal
-- Lo mismo con grupos de 10 años, para las gráficas.
SELECT e.grupo_decenal,
       sum(f.casos) AS casos,
       round(100.0 * sum(f.hospitalizados) / sum(f.casos), 2) AS pct_hospitalizados,
       sum(f.confirmados) AS confirmados,
       round(100.0 * sum(f.defunciones * f.confirmados) / nullif(sum(f.confirmados), 0), 3) AS letalidad
FROM dw.fact_casos_covid f
JOIN dw.dim_edad e ON e.id_edad = f.id_edad
WHERE e.es_edad_valida
GROUP BY 1
ORDER BY 1;

-- @consulta x07_por_clasificacion
-- Qué ocurrió: la clasificación final y su grupo.
SELECT d.clasificacion_final, d.clasificacion_final_desc, d.grupo_clasificacion,
       sum(f.casos) AS casos,
       round(100.0 * sum(f.casos) / sum(sum(f.casos)) OVER (), 2) AS pct_del_total
FROM dw.fact_casos_covid f
JOIN dw.dim_diagnostico d ON d.id_diagnostico = f.id_diagnostico
GROUP BY 1, 2, 3
ORDER BY casos DESC;

-- @consulta x08_prevalencia_comorbilidad
-- Con qué características: cada comorbilidad entre los casos con dato.
WITH por_combinacion AS (
    SELECT id_comorbilidad, sum(casos) AS casos FROM dw.fact_casos_covid GROUP BY 1
)
SELECT v.comorbilidad,
       sum(p.casos) FILTER (WHERE v.valor = 1) AS con_comorbilidad,
       sum(p.casos) FILTER (WHERE v.valor IN (1, 2)) AS denominador,
       sum(p.casos) FILTER (WHERE v.valor NOT IN (1, 2)) AS sin_dato,
       round(100.0 * sum(p.casos) FILTER (WHERE v.valor = 1)
             / sum(p.casos) FILTER (WHERE v.valor IN (1, 2)), 2) AS prevalencia
FROM por_combinacion p
JOIN dw.dim_comorbilidad c USING (id_comorbilidad)
CROSS JOIN LATERAL (VALUES ('Diabetes', c.diabetes), ('EPOC', c.epoc), ('Asma', c.asma),
                           ('Inmunosupresión', c.inmusupr), ('Hipertensión', c.hipertension),
                           ('Otra', c.otra_com), ('Cardiovascular', c.cardiovascular),
                           ('Obesidad', c.obesidad), ('Renal crónica', c.renal_cronica),
                           ('Tabaquismo', c.tabaquismo)) AS v (comorbilidad, valor)
GROUP BY 1
ORDER BY prevalencia DESC;

-- @consulta x09_por_gravedad
-- Qué tan grave: el nivel de gravedad de dim_atencion.
SELECT a.nivel_gravedad, a.gravedad_desc,
       sum(f.casos) AS casos,
       round(100.0 * sum(f.casos) / sum(sum(f.casos)) OVER (), 3) AS pct_del_total
FROM dw.fact_casos_covid f
JOIN dw.dim_atencion a ON a.id_atencion = f.id_atencion
GROUP BY 1, 2
ORDER BY 1;

-- @consulta x10_indicadores_nacionales
-- Referencia para todo lo demás: los indicadores sin cruzar y la letalidad mal calculada.
SELECT sum(f.casos) AS casos,
       sum(f.confirmados) AS confirmados,
       round(100.0 * sum(f.confirmados)
             / (sum(f.confirmados) + sum(f.casos) FILTER (WHERE d.grupo_clasificacion = 'NEGATIVO')), 2) AS positividad,
       round(100.0 * sum(f.hospitalizados) / sum(f.casos), 2) AS pct_hospitalizados,
       round(100.0 * sum(f.defunciones * f.confirmados) / sum(f.confirmados), 3) AS letalidad,
       round(100.0 * sum(f.defunciones) / sum(f.confirmados), 3) AS letalidad_formula_incorrecta
FROM dw.fact_casos_covid f
JOIN dw.dim_diagnostico d ON d.id_diagnostico = f.id_diagnostico;

-- =======================================================================================
-- 6b. DOS DIMENSIONES: cómo cambia la lectura al cruzar
-- =======================================================================================

-- @consulta x11_mes_por_entidad
-- Tiempo × espacio: casos por mes y entidad (el mapa de calor usa el % dentro de la entidad).
SELECT t.anio_mes, u.nombre_entidad, sum(f.casos) AS casos,
       round(100.0 * sum(f.casos) / sum(sum(f.casos)) OVER (PARTITION BY u.nombre_entidad), 2) AS pct_de_la_entidad
FROM dw.fact_casos_covid f
JOIN dw.dim_tiempo t    ON t.id_tiempo = f.id_fecha_sintomas
JOIN dw.dim_ubicacion u ON u.id_ubicacion = f.id_ubicacion_residencia
WHERE t.anio_mes IN ('2022-01', '2022-02', '2022-03', '2022-04', '2022-05', '2022-06', '2023-01')
  AND u.es_entidad_federativa
GROUP BY 1, 2
ORDER BY 1, 2;

-- @consulta x12_pico_por_entidad
-- Tiempo × espacio: la semana epidemiológica de máximo de casos en cada entidad, en 2022.
-- Si el pico no cae en la misma semana en todas, la ola no llegó al mismo tiempo.
WITH semanal AS (
    SELECT u.nombre_entidad, t.anio_epi, t.semana_epi, min(t.inicio_semana_epi) AS inicio_semana,
           sum(f.casos) AS casos
    FROM dw.fact_casos_covid f
    JOIN dw.dim_tiempo t    ON t.id_tiempo = f.id_fecha_sintomas
    JOIN dw.dim_ubicacion u ON u.id_ubicacion = f.id_ubicacion_residencia
    WHERE u.es_entidad_federativa AND t.anio_epi = 2022
    GROUP BY 1, 2, 3
)
SELECT DISTINCT ON (nombre_entidad)
       nombre_entidad, anio_epi, semana_epi AS semana_pico, inicio_semana, casos AS casos_semana_pico,
       round(100.0 * casos / sum(casos) OVER (PARTITION BY nombre_entidad), 2) AS pct_en_semana_pico
FROM semanal
ORDER BY nombre_entidad, casos DESC;

-- @consulta x13_edad_por_clasificacion
-- Edad × resultado: composición de la clasificación final dentro de cada grupo etario.
SELECT e.grupo_etario, d.grupo_clasificacion, sum(f.casos) AS casos,
       round(100.0 * sum(f.casos) / sum(sum(f.casos)) OVER (PARTITION BY e.grupo_etario), 2) AS pct_del_grupo
FROM dw.fact_casos_covid f
JOIN dw.dim_edad e        ON e.id_edad = f.id_edad
JOIN dw.dim_diagnostico d ON d.id_diagnostico = f.id_diagnostico
WHERE e.es_edad_valida
GROUP BY 1, 2
ORDER BY 1, 2;

-- @consulta x14_sexo_por_comorbilidad
-- Sexo × comorbilidad: prevalencia de cada una en hombres y en mujeres.
WITH por_combinacion AS (
    SELECT id_paciente, id_comorbilidad, sum(casos) AS casos FROM dw.fact_casos_covid GROUP BY 1, 2
)
SELECT p.sexo_desc, v.comorbilidad,
       sum(x.casos) FILTER (WHERE v.valor IN (1, 2)) AS denominador,
       round(100.0 * sum(x.casos) FILTER (WHERE v.valor = 1)
             / sum(x.casos) FILTER (WHERE v.valor IN (1, 2)), 2) AS prevalencia
FROM por_combinacion x
JOIN dw.dim_paciente p     USING (id_paciente)
JOIN dw.dim_comorbilidad c USING (id_comorbilidad)
CROSS JOIN LATERAL (VALUES ('Diabetes', c.diabetes), ('EPOC', c.epoc), ('Asma', c.asma),
                           ('Inmunosupresión', c.inmusupr), ('Hipertensión', c.hipertension),
                           ('Otra', c.otra_com), ('Cardiovascular', c.cardiovascular),
                           ('Obesidad', c.obesidad), ('Renal crónica', c.renal_cronica),
                           ('Tabaquismo', c.tabaquismo)) AS v (comorbilidad, valor)
GROUP BY 1, 2
ORDER BY 2, 1;

-- @consulta x15_riesgo_por_comorbilidad
-- Comorbilidad × desenlace, entre confirmados: letalidad y hospitalización con y sin cada
-- comorbilidad, y su riesgo relativo (RR) con intervalo de confianza del 95% por el método
-- logarítmico. Es un RR crudo: x21 muestra cuánto cambia al ajustar por edad.
WITH confirmados AS (
    SELECT id_comorbilidad, sum(confirmados) AS n, sum(defunciones * confirmados) AS def,
           sum(hospitalizados * confirmados) AS hosp
    FROM dw.fact_casos_covid
    WHERE confirmados = 1
    GROUP BY 1
),
por_valor AS (
    SELECT v.comorbilidad,
           sum(x.n)    FILTER (WHERE v.valor = 1) AS n1, sum(x.def)  FILTER (WHERE v.valor = 1) AS def1,
           sum(x.hosp) FILTER (WHERE v.valor = 1) AS hosp1,
           sum(x.n)    FILTER (WHERE v.valor = 2) AS n0, sum(x.def)  FILTER (WHERE v.valor = 2) AS def0,
           sum(x.hosp) FILTER (WHERE v.valor = 2) AS hosp0
    FROM confirmados x
    JOIN dw.dim_comorbilidad c USING (id_comorbilidad)
    CROSS JOIN LATERAL (VALUES ('Diabetes', c.diabetes), ('EPOC', c.epoc), ('Asma', c.asma),
                               ('Inmunosupresión', c.inmusupr), ('Hipertensión', c.hipertension),
                               ('Otra', c.otra_com), ('Cardiovascular', c.cardiovascular),
                               ('Obesidad', c.obesidad), ('Renal crónica', c.renal_cronica),
                               ('Tabaquismo', c.tabaquismo)) AS v (comorbilidad, valor)
    GROUP BY 1
)
SELECT comorbilidad, n1 AS confirmados_con, n0 AS confirmados_sin,
       round(100.0 * def1 / n1, 3) AS letalidad_con,
       round(100.0 * def0 / n0, 3) AS letalidad_sin,
       round((def1::numeric / n1) / (def0::numeric / n0), 2) AS rr_letalidad,
       round(exp(ln((def1::numeric / n1) / (def0::numeric / n0))
                 - 1.96 * sqrt(1.0 / def1 - 1.0 / n1 + 1.0 / def0 - 1.0 / n0)), 2) AS rr_letalidad_ic_inf,
       round(exp(ln((def1::numeric / n1) / (def0::numeric / n0))
                 + 1.96 * sqrt(1.0 / def1 - 1.0 / n1 + 1.0 / def0 - 1.0 / n0)), 2) AS rr_letalidad_ic_sup,
       round(100.0 * hosp1 / n1, 2) AS pct_hosp_con,
       round(100.0 * hosp0 / n0, 2) AS pct_hosp_sin,
       round((hosp1::numeric / n1) / (hosp0::numeric / n0), 2) AS rr_hospitalizacion
FROM por_valor
ORDER BY rr_letalidad DESC;

-- @consulta x16_institucion_por_gravedad
-- Institución × gravedad: cómo se reparte la gravedad de la atención entre tipos de institución.
SELECT um.tipo_institucion, a.gravedad_desc, a.nivel_gravedad,
       sum(f.casos) AS casos,
       round(100.0 * sum(f.casos) / sum(sum(f.casos)) OVER (PARTITION BY um.tipo_institucion), 2) AS pct_de_la_institucion
FROM dw.fact_casos_covid f
JOIN dw.dim_unidad_medica um ON um.id_unidad_medica = f.id_unidad_medica
JOIN dw.dim_atencion a       ON a.id_atencion = f.id_atencion
GROUP BY 1, 2, 3
ORDER BY 1, 3;

-- @consulta x17_institucion_desenlace
-- Institución × indicadores: hospitalización y letalidad, con la edad media para leerlos
-- con cuidado (una institución que atiende a gente mayor tendrá más letalidad).
SELECT um.tipo_institucion,
       sum(f.casos) AS casos,
       round(100.0 * sum(f.hospitalizados) / sum(f.casos), 2) AS pct_hospitalizados,
       sum(f.confirmados) AS confirmados,
       round(100.0 * sum(f.defunciones * f.confirmados) / nullif(sum(f.confirmados), 0), 3) AS letalidad,
       round(avg(f.edad_anios), 1) AS edad_media
FROM dw.fact_casos_covid f
JOIN dw.dim_unidad_medica um ON um.id_unidad_medica = f.id_unidad_medica
GROUP BY 1
ORDER BY casos DESC;

-- @consulta x18_demora_por_desenlace
-- Oportunidad de la atención × desenlace: días de síntomas a ingreso, en rangos.
-- Sin las fechas en desorden (la medida queda en NULL para ellas).
SELECT CASE WHEN f.dias_sintomas_a_ingreso = 0 THEN '0'
            WHEN f.dias_sintomas_a_ingreso <= 2 THEN '1-2'
            WHEN f.dias_sintomas_a_ingreso <= 5 THEN '3-5'
            WHEN f.dias_sintomas_a_ingreso <= 10 THEN '6-10'
            ELSE 'MÁS DE 10' END AS dias_sintomas_a_ingreso,
       sum(f.casos) AS casos,
       round(100.0 * sum(f.hospitalizados) / sum(f.casos), 2) AS pct_hospitalizados,
       sum(f.confirmados) AS confirmados,
       round(100.0 * sum(f.defunciones * f.confirmados) / nullif(sum(f.confirmados), 0), 3) AS letalidad,
       round(avg(f.edad_anios), 1) AS edad_media
FROM dw.fact_casos_covid f
WHERE f.dias_sintomas_a_ingreso IS NOT NULL
GROUP BY 1
ORDER BY min(f.dias_sintomas_a_ingreso);

-- =======================================================================================
-- 6c. TRES DIMENSIONES: patrones que no aparecen con menos
-- =======================================================================================

-- @consulta x19_mes_entidad_clasificacion
-- Tiempo × espacio × resultado, en las 6 entidades con más casos.
WITH principales AS (
    SELECT u.nombre_entidad
    FROM dw.fact_casos_covid f
    JOIN dw.dim_ubicacion u ON u.id_ubicacion = f.id_ubicacion_residencia
    GROUP BY 1
    ORDER BY sum(f.casos) DESC
    LIMIT 6
)
SELECT t.anio_mes, u.nombre_entidad, d.grupo_clasificacion, sum(f.casos) AS casos,
       round(100.0 * sum(f.casos) / sum(sum(f.casos)) OVER (PARTITION BY t.anio_mes, u.nombre_entidad), 2) AS pct_del_mes
FROM dw.fact_casos_covid f
JOIN dw.dim_ubicacion u   ON u.id_ubicacion = f.id_ubicacion_residencia
JOIN dw.dim_tiempo t      ON t.id_tiempo = f.id_fecha_sintomas
JOIN dw.dim_diagnostico d ON d.id_diagnostico = f.id_diagnostico
WHERE u.nombre_entidad IN (SELECT nombre_entidad FROM principales)
  AND t.anio_mes IN ('2022-01', '2022-02', '2022-03', '2022-04', '2022-05', '2022-06', '2023-01')
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;

-- @consulta x20_matriz_letalidad
-- Sexo × grupo etario × número de comorbilidades: la matriz de riesgo entre confirmados.
SELECT p.sexo_desc, e.grupo_etario, c.grupo_comorbilidades,
       sum(f.confirmados) AS confirmados,
       sum(f.defunciones * f.confirmados) AS defunciones_confirmados,
       round(100.0 * sum(f.defunciones * f.confirmados) / nullif(sum(f.confirmados), 0), 2) AS letalidad
FROM dw.fact_casos_covid f
JOIN dw.dim_paciente p     ON p.id_paciente = f.id_paciente
JOIN dw.dim_edad e         ON e.id_edad = f.id_edad
JOIN dw.dim_comorbilidad c ON c.id_comorbilidad = f.id_comorbilidad
WHERE e.es_edad_valida
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;

-- @consulta x21_riesgo_ajustado_por_edad
-- Comorbilidad × desenlace × edad: el RR de letalidad crudo (x15) contra el ajustado por
-- grupo decenal con el estimador de Mantel-Haenszel. Si baja mucho al ajustar, parte del
-- riesgo crudo era la edad: las comorbilidades son más comunes en personas mayores.
WITH base AS (
    SELECT e.grupo_decenal, f.id_comorbilidad,
           sum(f.confirmados) AS n, sum(f.defunciones * f.confirmados) AS def
    FROM dw.fact_casos_covid f
    JOIN dw.dim_edad e ON e.id_edad = f.id_edad
    WHERE f.confirmados = 1 AND e.es_edad_valida
    GROUP BY 1, 2
),
estratos AS (
    SELECT v.comorbilidad, b.grupo_decenal,
           sum(b.n)   FILTER (WHERE v.valor = 1) AS n1, sum(b.def) FILTER (WHERE v.valor = 1) AS a,
           sum(b.n)   FILTER (WHERE v.valor = 2) AS n0, sum(b.def) FILTER (WHERE v.valor = 2) AS c
    FROM base b
    JOIN dw.dim_comorbilidad cm USING (id_comorbilidad)
    CROSS JOIN LATERAL (VALUES ('Diabetes', cm.diabetes), ('EPOC', cm.epoc), ('Asma', cm.asma),
                               ('Inmunosupresión', cm.inmusupr), ('Hipertensión', cm.hipertension),
                               ('Otra', cm.otra_com), ('Cardiovascular', cm.cardiovascular),
                               ('Obesidad', cm.obesidad), ('Renal crónica', cm.renal_cronica),
                               ('Tabaquismo', cm.tabaquismo)) AS v (comorbilidad, valor)
    GROUP BY 1, 2
)
SELECT comorbilidad,
       round((sum(a)::numeric / sum(n1)) / (sum(c)::numeric / sum(n0)), 2) AS rr_crudo,
       round(sum(coalesce(a, 0) * coalesce(n0, 0)::numeric / (coalesce(n1, 0) + coalesce(n0, 0)))
             / sum(coalesce(c, 0) * coalesce(n1, 0)::numeric / (coalesce(n1, 0) + coalesce(n0, 0))), 2) AS rr_ajustado_edad,
       round(avg(n1), 0) AS confirmados_con_promedio_por_estrato
FROM estratos
WHERE coalesce(n1, 0) + coalesce(n0, 0) > 0
GROUP BY 1
ORDER BY rr_ajustado_edad DESC;

-- @consulta x22_periodo_edad_desenlace
-- Tiempo × edad × desenlace: ¿cambió la gravedad entre periodos con la misma edad?
-- Periodos por mes de inicio de síntomas.
SELECT CASE WHEN t.anio_mes IN ('2022-01', '2022-02') THEN '1. ENE-FEB 2022 (OLA)'
            WHEN t.anio_mes IN ('2022-03', '2022-04', '2022-05') THEN '2. MAR-MAY 2022'
            WHEN t.anio_mes = '2022-06' THEN '3. JUN 2022'
            ELSE '4. ENE 2023' END AS periodo,
       e.grupo_etario,
       sum(f.casos) AS casos,
       round(100.0 * sum(f.hospitalizados) / sum(f.casos), 2) AS pct_hospitalizados,
       sum(f.confirmados) AS confirmados,
       round(100.0 * sum(f.defunciones * f.confirmados) / nullif(sum(f.confirmados), 0), 3) AS letalidad
FROM dw.fact_casos_covid f
JOIN dw.dim_tiempo t ON t.id_tiempo = f.id_fecha_sintomas
JOIN dw.dim_edad e   ON e.id_edad = f.id_edad
WHERE e.es_edad_valida
  AND t.anio_mes IN ('2022-01', '2022-02', '2022-03', '2022-04', '2022-05', '2022-06', '2023-01')
GROUP BY 1, 2
ORDER BY 1, 2;

-- @consulta x23_reglas_comorbilidad
-- Reglas de asociación {combinación de comorbilidades} => {defunción}, entre confirmados:
--   soporte   = confirmados con la combinación / total de confirmados
--   confianza = letalidad dentro de la combinación
--   lift      = confianza / letalidad nacional (lift > 1: más riesgo que el promedio)
-- Solo combinaciones con al menos 100 confirmados. Incluye la edad media porque el lift
-- crudo mezcla el efecto de la combinación con el de la edad.
WITH por_combinacion AS (
    SELECT c.descripcion, c.num_comorbilidades,
           sum(f.confirmados) AS confirmados,
           sum(f.defunciones * f.confirmados) AS defunciones,
           avg(f.edad_anios) FILTER (WHERE f.confirmados = 1) AS edad_media
    FROM dw.fact_casos_covid f
    JOIN dw.dim_comorbilidad c ON c.id_comorbilidad = f.id_comorbilidad
    GROUP BY 1, 2
),
total AS (
    SELECT sum(confirmados) AS confirmados, sum(defunciones)::numeric / sum(confirmados) AS letalidad
    FROM por_combinacion
)
SELECT p.descripcion, p.num_comorbilidades, p.confirmados, p.defunciones,
       round(100.0 * p.confirmados / t.confirmados, 3) AS soporte_pct,
       round(100.0 * p.defunciones / p.confirmados, 2) AS confianza_pct,
       round((p.defunciones::numeric / p.confirmados) / t.letalidad, 2) AS lift,
       round(p.edad_media, 1) AS edad_media
FROM por_combinacion p CROSS JOIN total t
WHERE p.confirmados >= 100
ORDER BY lift DESC;

-- =======================================================================================
-- OPERACIONES OLAP sobre las jerarquías del modelo (punto 1): roll-up y drill-down
-- =======================================================================================

-- @consulta x24_rollup_tiempo
-- Jerarquía de calendario: año → trimestre → mes, con subtotales en un solo GROUP BY.
-- nivel_bits: 0 = mes, 1 = subtotal del trimestre, 3 = subtotal del año, 7 = total.
SELECT t.anio, t.trimestre, t.anio_mes,
       GROUPING(t.anio, t.trimestre, t.anio_mes) AS nivel_bits,
       sum(f.casos) AS casos, sum(f.confirmados) AS confirmados,
       round(100.0 * sum(f.defunciones * f.confirmados) / nullif(sum(f.confirmados), 0), 3) AS letalidad
FROM dw.fact_casos_covid f
JOIN dw.dim_tiempo t ON t.id_tiempo = f.id_fecha_sintomas
GROUP BY ROLLUP (t.anio, t.trimestre, t.anio_mes)
ORDER BY t.anio NULLS LAST, t.trimestre NULLS LAST, t.anio_mes NULLS LAST;

-- @consulta x25_rollup_espacio
-- Jerarquía espacial: municipio → entidad → nacional. Drill-down de la entidad con más casos
-- a sus municipios; el resto solo a nivel entidad para no generar 2,500 filas.
SELECT u.nombre_entidad, u.nombre_municipio, u.cvegeo,
       GROUPING(u.nombre_entidad, u.nombre_municipio, u.cvegeo) AS nivel_bits,
       sum(f.casos) AS casos, sum(f.confirmados) AS confirmados,
       round(100.0 * sum(f.defunciones * f.confirmados) / nullif(sum(f.confirmados), 0), 3) AS letalidad
FROM dw.fact_casos_covid f
JOIN dw.dim_ubicacion u ON u.id_ubicacion = f.id_ubicacion_residencia
GROUP BY ROLLUP (u.nombre_entidad, (u.nombre_municipio, u.cvegeo))
HAVING GROUPING(u.nombre_municipio, u.cvegeo) = 3
    OR u.nombre_entidad = (SELECT u2.nombre_entidad
                           FROM dw.fact_casos_covid f2
                           JOIN dw.dim_ubicacion u2 ON u2.id_ubicacion = f2.id_ubicacion_residencia
                           GROUP BY 1 ORDER BY count(*) DESC LIMIT 1)
ORDER BY u.nombre_entidad NULLS LAST, casos DESC;

-- @consulta x26_concentracion_municipal
-- Pareto: cuántos municipios concentran el 50%, el 80% y el 95% de los casos.
WITH por_municipio AS (
    SELECT u.id_ubicacion, sum(f.casos) AS casos
    FROM dw.fact_casos_covid f
    JOIN dw.dim_ubicacion u ON u.id_ubicacion = f.id_ubicacion_residencia
    GROUP BY 1
),
acumulado AS (
    SELECT casos,
           row_number() OVER (ORDER BY casos DESC) AS rango,
           count(*) OVER () AS municipios_con_casos,
           sum(casos) OVER (ORDER BY casos DESC ROWS UNBOUNDED PRECEDING)::numeric / sum(casos) OVER () AS pct_acumulado
    FROM por_municipio
)
SELECT m.meta AS pct_de_casos,
       min(a.rango) AS municipios_necesarios,
       max(a.municipios_con_casos) AS municipios_con_casos,
       round(100.0 * min(a.rango) / max(a.municipios_con_casos), 2) AS pct_de_municipios
FROM (VALUES (0.50), (0.80), (0.95)) AS m (meta)
JOIN acumulado a ON a.pct_acumulado >= m.meta
GROUP BY 1
ORDER BY 1;

-- =======================================================================================
-- DISTRIBUCIONES para la revisión de calidad (punto 7, Juan)
-- =======================================================================================

-- @consulta x27_distribucion_edad
-- Sin filtrar la edad: la distribución debe mostrar los atípicos. Usa id_edad, porque la
-- medida edad_anios deja en NULL las edades no válidas.
SELECT f.id_edad AS edad, sum(f.casos) AS casos
FROM dw.fact_casos_covid f
GROUP BY 1
ORDER BY 1;

-- @consulta x28_distribucion_demoras
SELECT 'Síntomas a ingreso' AS demora, dias_sintomas_a_ingreso AS dias, count(*) AS casos
FROM dw.fact_casos_covid WHERE dias_sintomas_a_ingreso IS NOT NULL GROUP BY 2
UNION ALL
SELECT 'Ingreso a resultado', dias_ingreso_a_resultado, count(*)
FROM dw.fact_casos_covid WHERE dias_ingreso_a_resultado IS NOT NULL GROUP BY 2
UNION ALL
SELECT 'Ingreso a defunción', dias_ingreso_a_defuncion, count(*)
FROM dw.fact_casos_covid WHERE dias_ingreso_a_defuncion IS NOT NULL GROUP BY 2
ORDER BY 1, 2;
