-- Q2 · 2 dimensiones (entidad de residencia × grupo etario): confirmados, defunciones
-- entre confirmados y letalidad, contra el modelo.
SELECT u.nombre_entidad, e.grupo_etario,
       sum(f.confirmados) AS confirmados,
       sum(f.defunciones * f.confirmados) AS defunciones_confirmados,
       round(100.0 * sum(f.defunciones * f.confirmados) / nullif(sum(f.confirmados), 0), 2) AS letalidad_pct
FROM dw.fact_casos_covid f
JOIN dw.dim_ubicacion u ON u.id_ubicacion = f.id_ubicacion_residencia
JOIN dw.dim_edad e      ON e.id_edad = f.id_edad
WHERE e.es_edad_valida
GROUP BY 1, 2
ORDER BY 1, 2;
