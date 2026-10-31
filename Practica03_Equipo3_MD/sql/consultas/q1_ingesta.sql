-- Q1 · 1 dimensión (tiempo): casos, confirmados y defunciones por semana epidemiológica
-- de inicio de síntomas, contra la tabla de ingesta. La semana hay que calcularla aquí.
WITH s AS (
    SELECT h.clasificacion_final, h.fecha_def,
           h.fecha_sintomas - extract(dow FROM h.fecha_sintomas)::int AS inicio
    FROM public.covid_historica h
), e AS (
    SELECT s.*, extract(year FROM s.inicio + 3)::int AS anio_epi FROM s
)
SELECT e.anio_epi,
       (e.inicio - (make_date(e.anio_epi, 1, 4) - extract(dow FROM make_date(e.anio_epi, 1, 4))::int)) / 7 + 1 AS semana_epi,
       count(*) AS casos,
       count(*) FILTER (WHERE e.clasificacion_final IN (1, 2, 3)) AS confirmados,
       count(*) FILTER (WHERE e.fecha_def IS NOT NULL) AS defunciones
FROM e
GROUP BY 1, 2
ORDER BY 1, 2;
