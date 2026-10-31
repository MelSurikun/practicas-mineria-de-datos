-- Q1 · 1 dimensión (tiempo): casos, confirmados y defunciones por semana epidemiológica
-- de inicio de síntomas, contra el modelo.
SELECT t.anio_epi, t.semana_epi,
       sum(f.casos) AS casos, sum(f.confirmados) AS confirmados, sum(f.defunciones) AS defunciones
FROM dw.fact_casos_covid f
JOIN dw.dim_tiempo t ON t.id_tiempo = f.id_fecha_sintomas
GROUP BY 1, 2
ORDER BY 1, 2;
