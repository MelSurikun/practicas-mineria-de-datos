-- Q4 · 3 dimensiones (tiempo + ubicación + resultado): casos por mes de síntomas,
-- entidad de residencia y grupo de clasificación final, contra el modelo.
SELECT t.anio_mes, u.nombre_entidad, d.grupo_clasificacion, sum(f.casos) AS casos
FROM dw.fact_casos_covid f
JOIN dw.dim_tiempo t      ON t.id_tiempo = f.id_fecha_sintomas
JOIN dw.dim_ubicacion u   ON u.id_ubicacion = f.id_ubicacion_residencia
JOIN dw.dim_diagnostico d ON d.id_diagnostico = f.id_diagnostico
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;
