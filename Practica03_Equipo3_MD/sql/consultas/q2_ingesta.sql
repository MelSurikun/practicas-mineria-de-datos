-- Q2 · 2 dimensiones (entidad de residencia × grupo etario): confirmados, defunciones
-- entre confirmados y letalidad, contra la tabla de ingesta.
SELECT e.entidad_federativa,
       CASE WHEN h.edad < 18 THEN '0-17 (MENORES DE EDAD)'
            WHEN h.edad < 40 THEN '18-39'
            WHEN h.edad < 60 THEN '40-59'
            ELSE '60 Y MÁS (PERSONAS ADULTAS MAYORES)' END AS grupo_etario,
       count(*) FILTER (WHERE h.clasificacion_final IN (1, 2, 3)) AS confirmados,
       count(*) FILTER (WHERE h.clasificacion_final IN (1, 2, 3) AND h.fecha_def IS NOT NULL) AS defunciones_confirmados,
       round(100.0 * count(*) FILTER (WHERE h.clasificacion_final IN (1, 2, 3) AND h.fecha_def IS NOT NULL)
             / nullif(count(*) FILTER (WHERE h.clasificacion_final IN (1, 2, 3)), 0), 2) AS letalidad_pct
FROM public.covid_historica h
JOIN public.cat_entidades e ON e.clave_entidad = h.entidad_res
WHERE h.edad < 122
GROUP BY 1, 2
ORDER BY 1, 2;
