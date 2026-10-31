-- Q4 · 3 dimensiones (tiempo + ubicación + resultado): casos por mes de síntomas,
-- entidad de residencia y grupo de clasificación final, contra la tabla de ingesta.
SELECT to_char(h.fecha_sintomas, 'YYYY-MM') AS anio_mes,
       e.entidad_federativa,
       CASE WHEN h.clasificacion_final IN (1, 2, 3) THEN 'CONFIRMADO'
            WHEN h.clasificacion_final = 6 THEN 'SOSPECHOSO'
            WHEN h.clasificacion_final = 7 THEN 'NEGATIVO'
            ELSE 'NO CONCLUYENTE' END AS grupo_clasificacion,
       count(*) AS casos
FROM public.covid_historica h
JOIN public.cat_entidades e ON e.clave_entidad = h.entidad_res
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;
