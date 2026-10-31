-- Práctica 03, Equipo 3. Evaluación del punto 2: ¿el SQL de cada LLM puede guardar los datos reales?
--
-- Que un CREATE TABLE compile no dice si las tablas aceptan los datos. Esta consulta cuenta,
-- sobre covid_historica, cuántos casos violarían las restricciones y los tipos del SQL final
-- de cada modelo (turno 2). Qwen3 no declara CHECK y sus tipos alcanzan: 0 casos.
--
-- Ejecutar:  psql -d covid_p3 -f llm/evaluacion/casos_que_no_caben.sql
WITH granite AS (   -- los CHECK de su script final (llm/respuestas/granite4.2_8b/turno_2.md, l. 150-186)
    SELECT (intubado NOT IN (1,2,99) OR uci NOT IN (1,2,99) OR neumonia NOT IN (1,2,99) OR otro_caso NOT IN (1,2,99)
            OR origen NOT IN (1,2,99) OR tipo_paciente NOT IN (1,2,99) OR resultado_lab NOT IN (1,2,3,4,97)
            OR resultado_antigeno NOT IN (1,2,97) OR clasificacion_final NOT IN (1,2,3,4,5,6,7)) AS dim_resultado,
           (edad > 120 OR embarazo NOT IN (1,2,99) OR habla_lengua_indig NOT IN (1,2,99) OR indigena NOT IN (1,2,99)
            OR nacionalidad NOT IN (1,2,99) OR migrante NOT IN (1,2,99)) AS dim_paciente,
           (diabetes NOT IN (1,2,99) OR epoc NOT IN (1,2,99) OR asma NOT IN (1,2,99) OR inmusupr NOT IN (1,2,99)
            OR hipertension NOT IN (1,2,99) OR obesidad NOT IN (1,2,99) OR renal_cronica NOT IN (1,2,99)
            OR cardiovascular NOT IN (1,2,99) OR tabaquismo NOT IN (1,2,99) OR otra_com NOT IN (1,2,99)) AS dim_comorbilidad
    FROM public.covid_historica
)
SELECT 'granite4.2_8b' AS corrida, 'CHECK que no aceptan 97 ni 98, y edad <= 120' AS motivo,
       count(*) FILTER (WHERE dim_resultado) AS por_dim_resultado,
       count(*) FILTER (WHERE dim_paciente) AS por_dim_paciente,
       count(*) FILTER (WHERE dim_comorbilidad) AS por_dim_comorbilidad,
       count(*) FILTER (WHERE dim_resultado OR dim_paciente OR dim_comorbilidad) AS casos_rechazados,
       round(100.0 * count(*) FILTER (WHERE dim_resultado OR dim_paciente OR dim_comorbilidad) / count(*), 1) AS porcentaje
FROM granite
UNION ALL
SELECT 'mistral-nemo_12b', 'pais_nacionalidad y pais_origen como VARCHAR(50)', NULL, NULL, NULL,
       count(*) FILTER (WHERE length(pais_nacionalidad) > 50 OR length(pais_origen) > 50),
       round(100.0 * count(*) FILTER (WHERE length(pais_nacionalidad) > 50 OR length(pais_origen) > 50) / count(*), 4)
FROM public.covid_historica
ORDER BY 1;
