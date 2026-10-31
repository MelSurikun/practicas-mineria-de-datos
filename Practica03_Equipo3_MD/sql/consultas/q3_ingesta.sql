-- Q3 · 3 dimensiones (sexo × grupo etario × número de comorbilidades): confirmados,
-- hospitalizados y defunciones entre confirmados, contra la tabla de ingesta.
WITH c AS (
    SELECT h.*,
           (h.diabetes = 1)::int + (h.epoc = 1)::int + (h.asma = 1)::int + (h.inmusupr = 1)::int
         + (h.hipertension = 1)::int + (h.otra_com = 1)::int + (h.cardiovascular = 1)::int
         + (h.obesidad = 1)::int + (h.renal_cronica = 1)::int AS num_comorbilidades
    FROM public.covid_historica h
    WHERE h.edad < 122
)
SELECT s.sexo,
       CASE WHEN c.edad < 18 THEN '0-17 (MENORES DE EDAD)'
            WHEN c.edad < 40 THEN '18-39'
            WHEN c.edad < 60 THEN '40-59'
            ELSE '60 Y MÁS (PERSONAS ADULTAS MAYORES)' END AS grupo_etario,
       CASE c.num_comorbilidades WHEN 0 THEN 'NINGUNA' WHEN 1 THEN 'UNA' WHEN 2 THEN 'DOS' ELSE 'TRES O MÁS' END AS grupo_comorbilidades,
       count(*) FILTER (WHERE c.clasificacion_final IN (1, 2, 3)) AS confirmados,
       count(*) FILTER (WHERE c.clasificacion_final IN (1, 2, 3) AND c.tipo_paciente = 2) AS hospitalizados_confirmados,
       count(*) FILTER (WHERE c.clasificacion_final IN (1, 2, 3) AND c.fecha_def IS NOT NULL) AS defunciones_confirmados
FROM c
JOIN public.cat_sexo s ON s.clave_sexo = c.sexo
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;
