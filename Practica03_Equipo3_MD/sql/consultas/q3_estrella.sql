-- Q3 · 3 dimensiones (sexo × grupo etario × número de comorbilidades): confirmados,
-- hospitalizados y defunciones entre confirmados, contra el modelo.
SELECT p.sexo_desc, e.grupo_etario, c.grupo_comorbilidades,
       sum(f.confirmados) AS confirmados,
       sum(f.hospitalizados * f.confirmados) AS hospitalizados_confirmados,
       sum(f.defunciones * f.confirmados) AS defunciones_confirmados
FROM dw.fact_casos_covid f
JOIN dw.dim_paciente p     ON p.id_paciente = f.id_paciente
JOIN dw.dim_edad e         ON e.id_edad = f.id_edad
JOIN dw.dim_comorbilidad c ON c.id_comorbilidad = f.id_comorbilidad
WHERE e.es_edad_valida
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;
