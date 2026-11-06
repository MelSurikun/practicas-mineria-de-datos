-- Práctica 03, Equipo 3 (Melanie, Ingeniería de Datos). Punto 5: validación de la carga. Solo lectura.
-- Las consultas v01 a v15 son las de sql/prueba_carga/12_validacion.sql (Santiago). Se agregan
-- e01 (perfil de extracción), r01 (registros rechazados) y c01 (control de la carga).
--
-- Cada bloque "-- @consulta <nombre>" se guarda como CSV en evidencias/etl/ con
--   python scripts/exportar_consultas.py sql/08_validacion.sql etl
-- El valor esperado de cada consulta está en su comentario.

-- Los scripts están en UTF-8. En Windows, psql suele leerlos como WIN1252 y los acentos
-- detienen la carga (character with byte sequence 0x81 in encoding "WIN1252"...).
-- Esta línea lo evita: el resto del archivo se interpreta como UTF-8.
SET client_encoding = 'UTF8';

-- @consulta e01_perfil_extraccion
-- Pasos 1 a 3 del ETL. Esperado: 45 columnas, 44 usadas (todas menos localidad_res),
-- 2,099,997 filas y ningún filtro de filas.
SELECT 'public.covid_historica' AS tabla_origen,
       (SELECT count(*) FROM public.covid_historica) AS filas,
       (SELECT count(*) FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'covid_historica') AS columnas,
       (SELECT count(*) FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'covid_historica' AND column_name <> 'localidad_res') AS columnas_usadas,
       'localidad_res' AS columna_excluida,
       'ninguno' AS filtros_de_filas;

-- @consulta r01_registros_rechazados
-- Esperado: 0 y 0. Un caso rechazado estaría en el origen y no en los hechos.
SELECT (SELECT count(*) FROM public.covid_historica h
        WHERE NOT EXISTS (SELECT 1 FROM dw.fact_casos_covid f WHERE f.id_registro = h.id_registro)) AS en_origen_y_no_en_hechos,
       (SELECT count(*) FROM dw.fact_casos_covid f
        WHERE NOT EXISTS (SELECT 1 FROM public.covid_historica h WHERE h.id_registro = f.id_registro)) AS en_hechos_y_no_en_origen;

-- @consulta c01_control_carga
-- Filas y tiempo de cada paso de la última corrida. Esperado: diferencia 0, salvo
-- dim_ubicacion (+1, el miembro inferido de Chihuahua 113).
SELECT paso, etapa, tabla, filas_origen, filas_destino, diferencia, segundos, nota
FROM etl.control_carga
ORDER BY id_control;

-- @consulta v01_conteos
-- Esperado: 2,099,997 filas y 2,099,997 ID_REGISTRO distintos en las dos tablas.
SELECT 'covid_historica' AS tabla, count(*) AS filas, count(DISTINCT id_registro) AS id_registro_distintos
FROM public.covid_historica
UNION ALL
SELECT 'dw.fact_casos_covid', count(*), count(DISTINCT id_registro)
FROM dw.fact_casos_covid
ORDER BY 1;

-- @consulta v02_conteos_por_extracto
-- Esperado: 1,999,998 (2022) y 99,999 (2023), iguales en origen, dimensión y hechos.
SELECT x.archivo_origen,
       (SELECT count(*) FROM public.covid_historica h WHERE h.archivo_origen = x.archivo_origen) AS casos_origen,
       x.casos_unicos AS casos_dim_extracto,
       count(f.id_fact_covid) AS casos_hechos
FROM dw.dim_extracto x
LEFT JOIN dw.fact_casos_covid f ON f.id_extracto = x.id_extracto
GROUP BY x.id_extracto, x.archivo_origen, x.casos_unicos
ORDER BY x.archivo_origen;

-- @consulta v03_duplicados_en_dimensiones
-- Esperado: 0 en todas. La llave natural de cada dimensión (lo que la identifica en el
-- negocio) no se repite; además está protegida con UNIQUE.
SELECT 'dim_tiempo' AS dimension, 'fecha' AS llave_natural,
       (SELECT count(*) FROM (SELECT fecha FROM dw.dim_tiempo WHERE fecha IS NOT NULL GROUP BY fecha HAVING count(*) > 1) d) AS duplicados
UNION ALL SELECT 'dim_ubicacion', 'cve_entidad, cve_municipio',
       (SELECT count(*) FROM (SELECT 1 FROM dw.dim_ubicacion GROUP BY cve_entidad, cve_municipio HAVING count(*) > 1) d)
UNION ALL SELECT 'dim_entidad', 'cve_entidad',
       (SELECT count(*) FROM (SELECT 1 FROM dw.dim_entidad GROUP BY cve_entidad HAVING count(*) > 1) d)
UNION ALL SELECT 'dim_unidad_medica', 'clues, cve_sector, cve_entidad_um',
       (SELECT count(*) FROM (SELECT 1 FROM dw.dim_unidad_medica GROUP BY clues, cve_sector, cve_entidad_um HAVING count(*) > 1) d)
UNION ALL SELECT 'dim_unidad_medica', 'clues (solo identificadas)',
       (SELECT count(*) FROM (SELECT 1 FROM dw.dim_unidad_medica WHERE clues IS NOT NULL GROUP BY clues HAVING count(*) > 1) d)
UNION ALL SELECT 'dim_paciente', '6 códigos',
       (SELECT count(*) FROM (SELECT 1 FROM dw.dim_paciente GROUP BY sexo, embarazo, habla_lengua_indig, indigena, nacionalidad, migrante HAVING count(*) > 1) d)
UNION ALL SELECT 'dim_pais', 'pais_original',
       (SELECT count(*) FROM (SELECT 1 FROM dw.dim_pais GROUP BY pais_original HAVING count(*) > 1) d)
UNION ALL SELECT 'dim_edad', 'edad',
       (SELECT count(*) FROM (SELECT 1 FROM dw.dim_edad GROUP BY edad HAVING count(*) > 1) d)
UNION ALL SELECT 'dim_comorbilidad', '10 banderas',
       (SELECT count(*) FROM (SELECT 1 FROM dw.dim_comorbilidad GROUP BY diabetes, epoc, asma, inmusupr, hipertension, otra_com, cardiovascular, obesidad, renal_cronica, tabaquismo HAVING count(*) > 1) d)
UNION ALL SELECT 'dim_atencion', '5 códigos',
       (SELECT count(*) FROM (SELECT 1 FROM dw.dim_atencion GROUP BY origen, tipo_paciente, neumonia, intubado, uci HAVING count(*) > 1) d)
UNION ALL SELECT 'dim_diagnostico', '6 códigos',
       (SELECT count(*) FROM (SELECT 1 FROM dw.dim_diagnostico GROUP BY otro_caso, toma_muestra_lab, resultado_lab, toma_muestra_antigeno, resultado_antigeno, clasificacion_final HAVING count(*) > 1) d)
UNION ALL SELECT 'dim_extracto', 'archivo_origen',
       (SELECT count(*) FROM (SELECT 1 FROM dw.dim_extracto GROUP BY archivo_origen HAVING count(*) > 1) d)
UNION ALL SELECT 'dim_calidad', '11 banderas',
       (SELECT count(*) FROM (SELECT 1 FROM dw.dim_calidad GROUP BY edad_no_valida, fechas_en_desorden, sintomas_mas_de_10_dias, demora_extrema, embarazo_edad_atipica, tabaquismo_menor_10, municipio_fuera_catalogo, entidad_nac_inconsistente, clues_ficticia, defuncion_ambulatoria, intubado_sin_uci HAVING count(*) > 1) d)
ORDER BY 1, 2;

-- @consulta v04_llaves_huerfanas
-- Esperado: 0 en las 16 llaves (las llaves foráneas declaradas ya lo garantizan; esto
-- lo muestra con un anti-join, que es como se revisaría sin restricciones).
-- UNION ALL no garantiza el orden de las filas: "orden" lo fija para que el CSV salga
-- idéntico en cada corrida.
SELECT llave, huerfanas FROM (
SELECT 1 AS orden, 'id_fecha_sintomas' AS llave, count(*) FILTER (WHERE d.id_tiempo IS NULL) AS huerfanas
FROM dw.fact_casos_covid f LEFT JOIN dw.dim_tiempo d ON d.id_tiempo = f.id_fecha_sintomas
UNION ALL SELECT 2, 'id_fecha_ingreso', count(*) FILTER (WHERE d.id_tiempo IS NULL)
FROM dw.fact_casos_covid f LEFT JOIN dw.dim_tiempo d ON d.id_tiempo = f.id_fecha_ingreso
UNION ALL SELECT 3, 'id_fecha_resultado', count(*) FILTER (WHERE d.id_tiempo IS NULL)
FROM dw.fact_casos_covid f LEFT JOIN dw.dim_tiempo d ON d.id_tiempo = f.id_fecha_resultado
UNION ALL SELECT 4, 'id_fecha_defuncion', count(*) FILTER (WHERE d.id_tiempo IS NULL)
FROM dw.fact_casos_covid f LEFT JOIN dw.dim_tiempo d ON d.id_tiempo = f.id_fecha_defuncion
UNION ALL SELECT 5, 'id_ubicacion_residencia', count(*) FILTER (WHERE d.id_ubicacion IS NULL)
FROM dw.fact_casos_covid f LEFT JOIN dw.dim_ubicacion d ON d.id_ubicacion = f.id_ubicacion_residencia
UNION ALL SELECT 6, 'id_entidad_nacimiento', count(*) FILTER (WHERE d.id_entidad IS NULL)
FROM dw.fact_casos_covid f LEFT JOIN dw.dim_entidad d ON d.id_entidad = f.id_entidad_nacimiento
UNION ALL SELECT 7, 'id_unidad_medica', count(*) FILTER (WHERE d.id_unidad_medica IS NULL)
FROM dw.fact_casos_covid f LEFT JOIN dw.dim_unidad_medica d ON d.id_unidad_medica = f.id_unidad_medica
UNION ALL SELECT 8, 'id_paciente', count(*) FILTER (WHERE d.id_paciente IS NULL)
FROM dw.fact_casos_covid f LEFT JOIN dw.dim_paciente d ON d.id_paciente = f.id_paciente
UNION ALL SELECT 9, 'id_pais_nacionalidad', count(*) FILTER (WHERE d.id_pais IS NULL)
FROM dw.fact_casos_covid f LEFT JOIN dw.dim_pais d ON d.id_pais = f.id_pais_nacionalidad
UNION ALL SELECT 10, 'id_pais_origen', count(*) FILTER (WHERE d.id_pais IS NULL)
FROM dw.fact_casos_covid f LEFT JOIN dw.dim_pais d ON d.id_pais = f.id_pais_origen
UNION ALL SELECT 11, 'id_edad', count(*) FILTER (WHERE d.id_edad IS NULL)
FROM dw.fact_casos_covid f LEFT JOIN dw.dim_edad d ON d.id_edad = f.id_edad
UNION ALL SELECT 12, 'id_comorbilidad', count(*) FILTER (WHERE d.id_comorbilidad IS NULL)
FROM dw.fact_casos_covid f LEFT JOIN dw.dim_comorbilidad d ON d.id_comorbilidad = f.id_comorbilidad
UNION ALL SELECT 13, 'id_atencion', count(*) FILTER (WHERE d.id_atencion IS NULL)
FROM dw.fact_casos_covid f LEFT JOIN dw.dim_atencion d ON d.id_atencion = f.id_atencion
UNION ALL SELECT 14, 'id_diagnostico', count(*) FILTER (WHERE d.id_diagnostico IS NULL)
FROM dw.fact_casos_covid f LEFT JOIN dw.dim_diagnostico d ON d.id_diagnostico = f.id_diagnostico
UNION ALL SELECT 15, 'id_extracto', count(*) FILTER (WHERE d.id_extracto IS NULL)
FROM dw.fact_casos_covid f LEFT JOIN dw.dim_extracto d ON d.id_extracto = f.id_extracto
UNION ALL SELECT 16, 'id_calidad', count(*) FILTER (WHERE d.id_calidad IS NULL)
FROM dw.fact_casos_covid f LEFT JOIN dw.dim_calidad d ON d.id_calidad = f.id_calidad
) t ORDER BY orden;

-- @consulta v05_miembros_especiales
-- Cuántos casos apuntan a cada miembro especial o inferido. Esperado: los huecos de la
-- Práctica 2 (1,999,998 sin columnas de 2023; 82,283 sin resultado; 2,082,438 sin
-- defunción; 1 municipio fuera de catálogo; 26 con municipio 999; 34 edades no válidas).
SELECT uso, casos FROM (
SELECT 1 AS orden, 'fecha de resultado: no disponible en el extracto (-1)' AS uso, count(*) AS casos FROM dw.fact_casos_covid WHERE id_fecha_resultado = -1
UNION ALL SELECT 2, 'fecha de resultado: sin resultado (-2)', count(*) FROM dw.fact_casos_covid WHERE id_fecha_resultado = -2
UNION ALL SELECT 3, 'fecha de resultado: con fecha', count(*) FROM dw.fact_casos_covid WHERE id_fecha_resultado > 0
UNION ALL SELECT 4, 'fecha de defunción: sin defunción (-2)', count(*) FROM dw.fact_casos_covid WHERE id_fecha_defuncion = -2
UNION ALL SELECT 5, 'fecha de defunción: con fecha', count(*) FROM dw.fact_casos_covid WHERE id_fecha_defuncion > 0
UNION ALL SELECT 6, 'unidad médica no identificada (extracto 2022)', count(*) FROM dw.fact_casos_covid f JOIN dw.dim_unidad_medica u USING (id_unidad_medica) WHERE NOT u.es_unidad_identificada
UNION ALL SELECT 7, 'unidad médica con CLUES ficticia', count(*) FROM dw.fact_casos_covid f JOIN dw.dim_unidad_medica u USING (id_unidad_medica) WHERE u.es_clues_ficticia
UNION ALL SELECT 8, 'residencia: municipio FUERA DE CATÁLOGO', count(*) FROM dw.fact_casos_covid f JOIN dw.dim_ubicacion u ON u.id_ubicacion = f.id_ubicacion_residencia WHERE u.tipo_miembro = 'FUERA DE CATÁLOGO'
UNION ALL SELECT 9, 'residencia: municipio NO ESPECIFICADO (999)', count(*) FROM dw.fact_casos_covid f JOIN dw.dim_ubicacion u ON u.id_ubicacion = f.id_ubicacion_residencia WHERE u.tipo_miembro = 'NO ESPECIFICADO'
UNION ALL SELECT 10, 'nacimiento: entidad NO ESPECIFICADO (99)', count(*) FROM dw.fact_casos_covid f JOIN dw.dim_entidad e ON e.id_entidad = f.id_entidad_nacimiento WHERE e.cve_entidad = 99
UNION ALL SELECT 11, 'edad no válida (medida edad_anios en NULL)', count(*) FROM dw.fact_casos_covid WHERE edad_anios IS NULL
UNION ALL SELECT 12, 'país de origen: NO APLICA (97)', count(*) FROM dw.fact_casos_covid f JOIN dw.dim_pais p ON p.id_pais = f.id_pais_origen WHERE p.tipo_valor = 'NO APLICA'
) t ORDER BY orden;

-- @consulta v06_ida_y_vuelta
-- La prueba más fuerte: reconstruir las 44 columnas de covid_historica (todas menos
-- LOCALIDAD_RES) SOLO desde el modelo, y compararlas fila por fila con EXCEPT en los dos
-- sentidos. EXCEPT trata dos NULL como iguales, que es lo que queremos aquí.
-- Esperado: 0 y 0, con 2,099,997 filas reconstruidas.
WITH reconstruida AS (
    SELECT x.fecha_actualizacion, f.id_registro::text AS id_registro, a.origen, um.cve_sector AS sector,
           um.cve_entidad_um AS entidad_um, um.cve_municipio_um AS municipio_um, um.clues::text AS clues,
           p.sexo, en.cve_entidad AS entidad_nac, u.cve_entidad AS entidad_res, u.cve_municipio AS municipio_res,
           a.tipo_paciente, ti.fecha AS fecha_ingreso, ts.fecha AS fecha_sintomas, td.fecha AS fecha_def,
           a.intubado, a.neumonia, de.edad, p.nacionalidad, p.embarazo, p.habla_lengua_indig, p.indigena,
           c.diabetes, c.epoc, c.asma, c.inmusupr, c.hipertension, c.otra_com, c.cardiovascular, c.obesidad,
           c.renal_cronica, c.tabaquismo, d.otro_caso, d.toma_muestra_lab, d.resultado_lab,
           d.toma_muestra_antigeno, d.resultado_antigeno, d.clasificacion_final, tr.fecha AS fecha_resultado,
           p.migrante, pn.pais_original::text AS pais_nacionalidad, po.pais_original::text AS pais_origen, a.uci,
           x.archivo_origen::text AS archivo_origen
    FROM dw.fact_casos_covid f
    JOIN dw.dim_extracto x       ON x.id_extracto = f.id_extracto
    JOIN dw.dim_atencion a       ON a.id_atencion = f.id_atencion
    JOIN dw.dim_unidad_medica um ON um.id_unidad_medica = f.id_unidad_medica
    JOIN dw.dim_paciente p       ON p.id_paciente = f.id_paciente
    JOIN dw.dim_entidad en       ON en.id_entidad = f.id_entidad_nacimiento
    JOIN dw.dim_ubicacion u      ON u.id_ubicacion = f.id_ubicacion_residencia
    JOIN dw.dim_tiempo ti        ON ti.id_tiempo = f.id_fecha_ingreso
    JOIN dw.dim_tiempo ts        ON ts.id_tiempo = f.id_fecha_sintomas
    JOIN dw.dim_tiempo td        ON td.id_tiempo = f.id_fecha_defuncion
    JOIN dw.dim_tiempo tr        ON tr.id_tiempo = f.id_fecha_resultado
    JOIN dw.dim_edad de          ON de.id_edad = f.id_edad
    JOIN dw.dim_comorbilidad c   ON c.id_comorbilidad = f.id_comorbilidad
    JOIN dw.dim_diagnostico d    ON d.id_diagnostico = f.id_diagnostico
    JOIN dw.dim_pais pn          ON pn.id_pais = f.id_pais_nacionalidad
    JOIN dw.dim_pais po          ON po.id_pais = f.id_pais_origen
),
origen AS (
    SELECT fecha_actualizacion, id_registro, origen, sector, entidad_um, municipio_um, clues, sexo, entidad_nac,
           entidad_res, municipio_res, tipo_paciente, fecha_ingreso, fecha_sintomas, fecha_def, intubado, neumonia,
           edad, nacionalidad, embarazo, habla_lengua_indig, indigena, diabetes, epoc, asma, inmusupr, hipertension,
           otra_com, cardiovascular, obesidad, renal_cronica, tabaquismo, otro_caso, toma_muestra_lab, resultado_lab,
           toma_muestra_antigeno, resultado_antigeno, clasificacion_final, fecha_resultado, migrante,
           pais_nacionalidad, pais_origen, uci, archivo_origen
    FROM public.covid_historica
)
SELECT (SELECT count(*) FROM reconstruida) AS filas_reconstruidas,
       (SELECT count(*) FROM (SELECT * FROM origen EXCEPT SELECT * FROM reconstruida) a) AS en_origen_y_no_en_modelo,
       (SELECT count(*) FROM (SELECT * FROM reconstruida EXCEPT SELECT * FROM origen) b) AS en_modelo_y_no_en_origen,
       44 AS columnas_comparadas;

-- @consulta v07_cobertura_columnas
-- Esperado: 45 columnas en covid_historica, 44 comparadas en v06 y ninguna columna de
-- localidad en el esquema dw.
SELECT (SELECT count(*) FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'covid_historica') AS columnas_covid_historica,
       (SELECT count(*) FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'covid_historica' AND column_name <> 'localidad_res') AS columnas_exigidas,
       (SELECT count(*) FROM information_schema.columns
        WHERE table_schema = 'dw' AND column_name ILIKE '%localidad%') AS columnas_localidad_en_dw,
       (SELECT count(*) FROM information_schema.tables WHERE table_schema = 'dw') AS tablas_en_dw,
       (SELECT count(*) FROM information_schema.columns WHERE table_schema = 'dw') AS columnas_en_dw;

-- @consulta v08_medidas_contra_origen
-- Esperado: modelo = origen en cada medida.
SELECT medida, modelo, origen FROM (
SELECT 1 AS orden, 'casos' AS medida, sum(casos)::numeric AS modelo, (SELECT count(*) FROM public.covid_historica)::numeric AS origen FROM dw.fact_casos_covid
UNION ALL SELECT 2, 'confirmados (clasificación 1, 2, 3)', sum(confirmados), (SELECT count(*) FROM public.covid_historica WHERE clasificacion_final IN (1, 2, 3)) FROM dw.fact_casos_covid
UNION ALL SELECT 3, 'hospitalizados (tipo_paciente = 2)', sum(hospitalizados), (SELECT count(*) FROM public.covid_historica WHERE tipo_paciente = 2) FROM dw.fact_casos_covid
UNION ALL SELECT 4, 'ingresos a UCI (uci = 1)', sum(ingresos_uci), (SELECT count(*) FROM public.covid_historica WHERE uci = 1) FROM dw.fact_casos_covid
UNION ALL SELECT 5, 'intubados (intubado = 1)', sum(intubados), (SELECT count(*) FROM public.covid_historica WHERE intubado = 1) FROM dw.fact_casos_covid
UNION ALL SELECT 6, 'con neumonía (neumonia = 1)', sum(con_neumonia), (SELECT count(*) FROM public.covid_historica WHERE neumonia = 1) FROM dw.fact_casos_covid
UNION ALL SELECT 7, 'defunciones (fecha_def con valor)', sum(defunciones), (SELECT count(*) FROM public.covid_historica WHERE fecha_def IS NOT NULL) FROM dw.fact_casos_covid
UNION ALL SELECT 8, 'edad promedio, edades válidas', round(avg(edad_anios), 4), (SELECT round(avg(edad), 4) FROM public.covid_historica WHERE edad < 122) FROM dw.fact_casos_covid
UNION ALL SELECT 9, 'demora síntomas-ingreso promedio (días)', round(avg(dias_sintomas_a_ingreso), 4), (SELECT round(avg(fecha_ingreso - fecha_sintomas), 4) FROM public.covid_historica WHERE fecha_ingreso >= fecha_sintomas) FROM dw.fact_casos_covid
) t ORDER BY orden;

-- @consulta v09_conformidad_entidades
-- Esperado: 0. La clave, el nombre y la abreviatura de cada entidad son idénticos en las
-- tres dimensiones que la usan (dimensión conformada).
SELECT 'dim_ubicacion contra dim_entidad' AS comparacion, count(*) AS diferencias
FROM (SELECT DISTINCT cve_entidad, nombre_entidad, abrev_entidad FROM dw.dim_ubicacion WHERE tipo_miembro <> 'FUERA DE CATÁLOGO'
      EXCEPT SELECT cve_entidad, nombre_entidad, abrev_entidad FROM dw.dim_entidad) x
UNION ALL
SELECT 'dim_unidad_medica contra dim_entidad', count(*)
FROM (SELECT DISTINCT cve_entidad_um, nombre_entidad_um, abrev_entidad_um FROM dw.dim_unidad_medica
      EXCEPT SELECT cve_entidad, nombre_entidad, abrev_entidad FROM dw.dim_entidad) y
ORDER BY 1;

-- @consulta v10_banderas_calidad
-- Casos por bandera. Esperado (Práctica 2): 34, 18,725, 355, 117, 116, 1, 27,186, 36, 22 y 2,871.
SELECT bandera, nivel, casos FROM (
    SELECT 1 AS orden, 'edad_no_valida' AS bandera, 'ERROR' AS nivel, count(*) FILTER (WHERE q.edad_no_valida) AS casos FROM dw.fact_casos_covid f JOIN dw.dim_calidad q USING (id_calidad)
    UNION ALL SELECT 2, 'fechas_en_desorden', 'ERROR', count(*) FILTER (WHERE q.fechas_en_desorden) FROM dw.fact_casos_covid f JOIN dw.dim_calidad q USING (id_calidad)
    UNION ALL SELECT 3, 'municipio_fuera_catalogo', 'ERROR', count(*) FILTER (WHERE q.municipio_fuera_catalogo) FROM dw.fact_casos_covid f JOIN dw.dim_calidad q USING (id_calidad)
    UNION ALL SELECT 4, 'entidad_nac_inconsistente', 'ERROR', count(*) FILTER (WHERE q.entidad_nac_inconsistente) FROM dw.fact_casos_covid f JOIN dw.dim_calidad q USING (id_calidad)
    UNION ALL SELECT 5, 'clues_ficticia', 'ERROR', count(*) FILTER (WHERE q.clues_ficticia) FROM dw.fact_casos_covid f JOIN dw.dim_calidad q USING (id_calidad)
    UNION ALL SELECT 6, 'sintomas_mas_de_10_dias', 'POR REVISAR', count(*) FILTER (WHERE q.sintomas_mas_de_10_dias) FROM dw.fact_casos_covid f JOIN dw.dim_calidad q USING (id_calidad)
    UNION ALL SELECT 7, 'demora_extrema', 'POR REVISAR', count(*) FILTER (WHERE q.demora_extrema) FROM dw.fact_casos_covid f JOIN dw.dim_calidad q USING (id_calidad)
    UNION ALL SELECT 8, 'embarazo_edad_atipica', 'POR REVISAR', count(*) FILTER (WHERE q.embarazo_edad_atipica) FROM dw.fact_casos_covid f JOIN dw.dim_calidad q USING (id_calidad)
    UNION ALL SELECT 9, 'tabaquismo_menor_10', 'POR REVISAR', count(*) FILTER (WHERE q.tabaquismo_menor_10) FROM dw.fact_casos_covid f JOIN dw.dim_calidad q USING (id_calidad)
    UNION ALL SELECT 10, 'defuncion_ambulatoria', 'POR REVISAR', count(*) FILTER (WHERE q.defuncion_ambulatoria) FROM dw.fact_casos_covid f JOIN dw.dim_calidad q USING (id_calidad)
    UNION ALL SELECT 11, 'intubado_sin_uci', 'POR REVISAR', count(*) FILTER (WHERE q.intubado_sin_uci) FROM dw.fact_casos_covid f JOIN dw.dim_calidad q USING (id_calidad)
    UNION ALL SELECT 12, '(casos con nivel máximo ERROR)', '', count(*) FILTER (WHERE q.nivel_maximo = 'ERROR') FROM dw.fact_casos_covid f JOIN dw.dim_calidad q USING (id_calidad)
    UNION ALL SELECT 13, '(casos con nivel máximo POR REVISAR)', '', count(*) FILTER (WHERE q.nivel_maximo = 'POR REVISAR') FROM dw.fact_casos_covid f JOIN dw.dim_calidad q USING (id_calidad)
    UNION ALL SELECT 14, '(casos sin banderas)', '', count(*) FILTER (WHERE q.nivel_maximo = 'SIN BANDERAS') FROM dw.fact_casos_covid f JOIN dw.dim_calidad q USING (id_calidad)
) t ORDER BY orden;

-- @consulta v11_anclas_semana_epidemiologica
-- Esperado: 2022-01-01 en la semana 52 de 2021; SE01 2022 del 2 al 8 de enero; SE01 2023
-- del 1 al 7 de enero (boletín SUIVE); 2023-12-31 ya es la semana 1 de 2024.
SELECT fecha, nombre_dia, anio_epi, semana_epi, inicio_semana_epi, temporada_influenza
FROM dw.dim_tiempo
WHERE fecha IN (DATE '2022-01-01', DATE '2022-01-02', DATE '2022-01-08', DATE '2022-12-31',
                DATE '2023-01-01', DATE '2023-01-07', DATE '2023-12-30', DATE '2023-12-31')
ORDER BY fecha;

-- @consulta v12_festivos
-- Esperado: 7 por año, con los lunes de febrero, marzo y noviembre bien calculados.
SELECT fecha, nombre_dia, nombre_festivo FROM dw.dim_tiempo WHERE es_festivo ORDER BY fecha;

-- @consulta v13_temporadas_de_influenza
SELECT temporada_influenza, min(fecha) AS desde, max(fecha) AS hasta, count(*) AS dias
FROM dw.dim_tiempo WHERE fecha IS NOT NULL GROUP BY temporada_influenza ORDER BY min(fecha);

-- @consulta v14_tamanos
-- Espacio en disco y ancho promedio de una fila: la tabla de ingesta contra el modelo.
SELECT objeto, bytes_tabla, bytes_con_indices, bytes_promedio_por_fila FROM (
SELECT 1 AS orden, 'public.covid_historica' AS objeto,
       pg_relation_size('public.covid_historica') AS bytes_tabla,
       pg_total_relation_size('public.covid_historica') AS bytes_con_indices,
       (SELECT round(avg(pg_column_size(t.*)), 1) FROM public.covid_historica t) AS bytes_promedio_por_fila
UNION ALL
SELECT 2, 'dw.fact_casos_covid',
       pg_relation_size('dw.fact_casos_covid'),
       pg_total_relation_size('dw.fact_casos_covid'),
       (SELECT round(avg(pg_column_size(t.*)), 1) FROM dw.fact_casos_covid t)
UNION ALL
SELECT 3, 'las 12 dimensiones de dw',
       sum(pg_relation_size(c.oid)),
       sum(pg_total_relation_size(c.oid)),
       NULL
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'dw' AND c.relkind = 'r' AND c.relname LIKE 'dim\_%'
) t ORDER BY orden;

-- @consulta v15_filas_por_tabla
SELECT c.relname AS tabla,
       (xpath('/row/n/text()', query_to_xml(format('SELECT count(*) AS n FROM dw.%I', c.relname), false, true, '')))[1]::text::bigint AS filas,
       pg_size_pretty(pg_total_relation_size(c.oid)) AS tamano,
       obj_description(c.oid) AS descripcion
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'dw' AND c.relkind = 'r'
ORDER BY c.relname LIKE 'fact%' DESC, c.relname;
