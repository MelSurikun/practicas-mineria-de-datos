-- Práctica 02, Equipo 3. Aportación de Santiago (Arquitecto).
-- Paso 9: validación del esquema tipado contra el diccionario y los catálogos (secciones 4.1 y 4.2).
--
-- Solo lectura: no crea ni modifica tablas. Cada bloque responde una pregunta y termina en
-- una tabla de resultados. Requiere que ya existan covid_stage_2022, covid_stage_2023,
-- covid_tipada y covid_historica (sql/01 a 05) y los catálogos (sql/06 y sql/08).
-- Usa pg_input_is_valid(), disponible desde PostgreSQL 16, que es el equivalente de
-- TRY_CONVERT: dice si un texto se puede convertir a un tipo sin intentar la conversión.
--
-- Ejecutar conectado a covid20a23sedi. Cada consulta empieza con un comentario "-- @consulta"
-- para que scripts/ejecutar_consultas.py la guarde como CSV en evidencias/validacion_esquema/:
--   python scripts/ejecutar_consultas.py sql/09_validacion_esquema.sql validacion_esquema
-- Con psql -f corre igual y los resultados salen en pantalla.

-- Los scripts están en UTF-8. En Windows, psql suele leerlos como WIN1252 y los acentos se
-- guardan mal o detienen la carga; con esta línea el resto del archivo se lee como UTF-8.
SET client_encoding = 'UTF8';

-- @consulta v1_nombres_y_tipos
-- ¿Cada variable del diccionario existe en la tabla, con qué nombre y con qué tipo?
WITH dicc AS (
    SELECT num, nombre_variable, formato_o_fuente,
           -- único sinónimo conocido: el diccionario dice OTRAS_COM y el CSV, OTRA_COM
           CASE lower(nombre_variable) WHEN 'otras_com' THEN 'otra_com'
                                       ELSE lower(nombre_variable) END AS columna_esperada
    FROM diccionario_variables
), tabla AS (
    SELECT ordinal_position, column_name,
           CASE WHEN data_type = 'character varying'
                THEN 'varchar(' || character_maximum_length || ')' ELSE data_type END AS tipo
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'covid_historica'
)
SELECT t.ordinal_position AS pos,
       t.column_name       AS columna_tabla,
       t.tipo              AS tipo_en_covid_historica,
       d.nombre_variable   AS nombre_en_diccionario,
       d.formato_o_fuente  AS formato_en_diccionario,
       CASE
           WHEN d.num IS NULL AND t.column_name = 'archivo_origen'
                THEN 'Columna de linaje agregada en la carga'
           WHEN d.num IS NULL THEN 'No está en el diccionario de 2020'
           WHEN t.column_name IS NULL THEN 'Está en el diccionario pero no en la tabla'
           WHEN lower(d.nombre_variable) <> t.column_name THEN 'Sinónimo: nombre distinto'
           ELSE 'Coincide'
       END AS resultado
FROM tabla t
FULL JOIN dicc d ON d.columna_esperada = t.column_name
ORDER BY coalesce(t.ordinal_position, 100 + d.num);

-- @consulta v2_tamanos_texto
-- ¿Cuánto mide el valor más largo de cada columna en el CSV (stage) y cabe en el tamaño
-- que propone el ejemplo de tabla temporal del enunciado?
WITH ejemplo (columna, tamano_ejemplo) AS (VALUES
    ('fecha_actualizacion', 50), ('id_registro', 50), ('origen', 20), ('sector', 20),
    ('entidad_um', 20), ('sexo', 20), ('entidad_nac', 50), ('entidad_res', 50),
    ('municipio_res', 50), ('localidad_res', 50), ('tipo_paciente', 20),
    ('fecha_ingreso', 50), ('fecha_sintomas', 50), ('fecha_def', 50), ('intubado', 20),
    ('neumonia', 20), ('edad', 20), ('nacionalidad', 50), ('embarazo', 20),
    ('habla_lengua_indig', 20), ('indigena', 20), ('diabetes', 20), ('epoc', 20),
    ('asma', 20), ('inmusupr', 20), ('hipertension', 20), ('otra_com', 20),
    ('cardiovascular', 20), ('obesidad', 20), ('renal_cronica', 20), ('tabaquismo', 20),
    ('otro_caso', 20), ('toma_muestra_lab', 20), ('resultado_lab', 20),
    ('toma_muestra_antigeno', 20), ('resultado_antigeno', 20), ('clasificacion_final', 20),
    ('migrante', 20), ('pais_nacionalidad', 100), ('pais_origen', 50), ('uci', 20)
), largo_2022 AS (
    SELECT key AS columna, value::int AS largo_max_2022
    FROM (SELECT
            max(length(fecha_actualizacion)) AS fecha_actualizacion, max(length(id_registro)) AS id_registro,
            max(length(origen)) AS origen, max(length(sector)) AS sector,
            max(length(entidad_um)) AS entidad_um, max(length(sexo)) AS sexo,
            max(length(entidad_nac)) AS entidad_nac, max(length(entidad_res)) AS entidad_res,
            max(length(municipio_res)) AS municipio_res, max(length(localidad_res)) AS localidad_res,
            max(length(tipo_paciente)) AS tipo_paciente, max(length(fecha_ingreso)) AS fecha_ingreso,
            max(length(fecha_sintomas)) AS fecha_sintomas, max(length(fecha_def)) AS fecha_def,
            max(length(intubado)) AS intubado, max(length(neumonia)) AS neumonia,
            max(length(edad)) AS edad, max(length(nacionalidad)) AS nacionalidad,
            max(length(embarazo)) AS embarazo, max(length(habla_lengua_indig)) AS habla_lengua_indig,
            max(length(indigena)) AS indigena, max(length(diabetes)) AS diabetes,
            max(length(epoc)) AS epoc, max(length(asma)) AS asma, max(length(inmusupr)) AS inmusupr,
            max(length(hipertension)) AS hipertension, max(length(otra_com)) AS otra_com,
            max(length(cardiovascular)) AS cardiovascular, max(length(obesidad)) AS obesidad,
            max(length(renal_cronica)) AS renal_cronica, max(length(tabaquismo)) AS tabaquismo,
            max(length(otro_caso)) AS otro_caso, max(length(toma_muestra_lab)) AS toma_muestra_lab,
            max(length(resultado_lab)) AS resultado_lab,
            max(length(toma_muestra_antigeno)) AS toma_muestra_antigeno,
            max(length(resultado_antigeno)) AS resultado_antigeno,
            max(length(clasificacion_final)) AS clasificacion_final, max(length(migrante)) AS migrante,
            max(length(pais_nacionalidad)) AS pais_nacionalidad, max(length(pais_origen)) AS pais_origen,
            max(length(uci)) AS uci
          FROM covid_stage_2022) s, jsonb_each_text(to_jsonb(s))
), largo_2023 AS (
    SELECT key AS columna, value::int AS largo_max_2023
    FROM (SELECT
            max(length(fecha_actualizacion)) AS fecha_actualizacion, max(length(id_registro)) AS id_registro,
            max(length(origen)) AS origen, max(length(sector)) AS sector,
            max(length(entidad_um)) AS entidad_um, max(length(municipio_um)) AS municipio_um,
            max(length(clues)) AS clues, max(length(sexo)) AS sexo,
            max(length(entidad_nac)) AS entidad_nac, max(length(entidad_res)) AS entidad_res,
            max(length(municipio_res)) AS municipio_res, max(length(localidad_res)) AS localidad_res,
            max(length(tipo_paciente)) AS tipo_paciente, max(length(fecha_ingreso)) AS fecha_ingreso,
            max(length(fecha_sintomas)) AS fecha_sintomas, max(length(fecha_def)) AS fecha_def,
            max(length(intubado)) AS intubado, max(length(neumonia)) AS neumonia,
            max(length(edad)) AS edad, max(length(nacionalidad)) AS nacionalidad,
            max(length(embarazo)) AS embarazo, max(length(habla_lengua_indig)) AS habla_lengua_indig,
            max(length(indigena)) AS indigena, max(length(diabetes)) AS diabetes,
            max(length(epoc)) AS epoc, max(length(asma)) AS asma, max(length(inmusupr)) AS inmusupr,
            max(length(hipertension)) AS hipertension, max(length(otra_com)) AS otra_com,
            max(length(cardiovascular)) AS cardiovascular, max(length(obesidad)) AS obesidad,
            max(length(renal_cronica)) AS renal_cronica, max(length(tabaquismo)) AS tabaquismo,
            max(length(otro_caso)) AS otro_caso, max(length(toma_muestra_lab)) AS toma_muestra_lab,
            max(length(resultado_lab)) AS resultado_lab,
            max(length(toma_muestra_antigeno)) AS toma_muestra_antigeno,
            max(length(resultado_antigeno)) AS resultado_antigeno,
            max(length(clasificacion_final)) AS clasificacion_final,
            max(length(fecha_resultado)) AS fecha_resultado, max(length(migrante)) AS migrante,
            max(length(pais_nacionalidad)) AS pais_nacionalidad, max(length(pais_origen)) AS pais_origen,
            max(length(uci)) AS uci
          FROM covid_stage_2023) s, jsonb_each_text(to_jsonb(s))
)
SELECT c.ordinal_position AS pos,
       l23.columna,
       e.tamano_ejemplo,
       l22.largo_max_2022,
       l23.largo_max_2023,
       CASE WHEN e.tamano_ejemplo IS NULL THEN 'La columna no está en el ejemplo'
            WHEN greatest(l22.largo_max_2022, l23.largo_max_2023) > e.tamano_ejemplo
                 THEN 'NO CABE: la carga falla o trunca'
            ELSE 'Cabe' END AS resultado
FROM largo_2023 l23
LEFT JOIN largo_2022 l22 USING (columna)
LEFT JOIN ejemplo e USING (columna)
JOIN information_schema.columns c
  ON c.table_name = 'covid_stage_2023' AND c.column_name = l23.columna
ORDER BY c.ordinal_position;

-- @consulta v3_dominios_catalogo
-- ¿Cada columna codificada usa solo claves de su catálogo? (en covid_historica, una fila por caso)
WITH valores (columna, catalogo, valor, filas) AS (
              SELECT 'origen', 'ORIGEN', origen, count(*) FROM covid_historica GROUP BY origen
    UNION ALL SELECT 'sector', 'SECTOR', sector, count(*) FROM covid_historica GROUP BY sector
    UNION ALL SELECT 'entidad_um', 'ENTIDADES', entidad_um, count(*) FROM covid_historica GROUP BY entidad_um
    UNION ALL SELECT 'sexo', 'SEXO', sexo, count(*) FROM covid_historica GROUP BY sexo
    UNION ALL SELECT 'entidad_nac', 'ENTIDADES', entidad_nac, count(*) FROM covid_historica GROUP BY entidad_nac
    UNION ALL SELECT 'entidad_res', 'ENTIDADES', entidad_res, count(*) FROM covid_historica GROUP BY entidad_res
    UNION ALL SELECT 'tipo_paciente', 'TIPO_PACIENTE', tipo_paciente, count(*) FROM covid_historica GROUP BY tipo_paciente
    UNION ALL SELECT 'intubado', 'SI_NO', intubado, count(*) FROM covid_historica GROUP BY intubado
    UNION ALL SELECT 'neumonia', 'SI_NO', neumonia, count(*) FROM covid_historica GROUP BY neumonia
    UNION ALL SELECT 'nacionalidad', 'NACIONALIDAD', nacionalidad, count(*) FROM covid_historica GROUP BY nacionalidad
    UNION ALL SELECT 'embarazo', 'SI_NO', embarazo, count(*) FROM covid_historica GROUP BY embarazo
    UNION ALL SELECT 'habla_lengua_indig', 'SI_NO', habla_lengua_indig, count(*) FROM covid_historica GROUP BY habla_lengua_indig
    UNION ALL SELECT 'indigena', 'SI_NO', indigena, count(*) FROM covid_historica GROUP BY indigena
    UNION ALL SELECT 'diabetes', 'SI_NO', diabetes, count(*) FROM covid_historica GROUP BY diabetes
    UNION ALL SELECT 'epoc', 'SI_NO', epoc, count(*) FROM covid_historica GROUP BY epoc
    UNION ALL SELECT 'asma', 'SI_NO', asma, count(*) FROM covid_historica GROUP BY asma
    UNION ALL SELECT 'inmusupr', 'SI_NO', inmusupr, count(*) FROM covid_historica GROUP BY inmusupr
    UNION ALL SELECT 'hipertension', 'SI_NO', hipertension, count(*) FROM covid_historica GROUP BY hipertension
    UNION ALL SELECT 'otra_com', 'SI_NO', otra_com, count(*) FROM covid_historica GROUP BY otra_com
    UNION ALL SELECT 'cardiovascular', 'SI_NO', cardiovascular, count(*) FROM covid_historica GROUP BY cardiovascular
    UNION ALL SELECT 'obesidad', 'SI_NO', obesidad, count(*) FROM covid_historica GROUP BY obesidad
    UNION ALL SELECT 'renal_cronica', 'SI_NO', renal_cronica, count(*) FROM covid_historica GROUP BY renal_cronica
    UNION ALL SELECT 'tabaquismo', 'SI_NO', tabaquismo, count(*) FROM covid_historica GROUP BY tabaquismo
    UNION ALL SELECT 'otro_caso', 'SI_NO', otro_caso, count(*) FROM covid_historica GROUP BY otro_caso
    UNION ALL SELECT 'toma_muestra_lab', 'SI_NO', toma_muestra_lab, count(*) FROM covid_historica GROUP BY toma_muestra_lab
    UNION ALL SELECT 'resultado_lab', 'RESULTADO_LAB', resultado_lab, count(*) FROM covid_historica GROUP BY resultado_lab
    UNION ALL SELECT 'toma_muestra_antigeno', 'SI_NO', toma_muestra_antigeno, count(*) FROM covid_historica GROUP BY toma_muestra_antigeno
    UNION ALL SELECT 'resultado_antigeno', 'RESULTADO_ANTIGENO', resultado_antigeno, count(*) FROM covid_historica GROUP BY resultado_antigeno
    UNION ALL SELECT 'clasificacion_final', 'CLASIFICACION_FINAL', clasificacion_final, count(*) FROM covid_historica GROUP BY clasificacion_final
    UNION ALL SELECT 'migrante', 'SI_NO', migrante, count(*) FROM covid_historica GROUP BY migrante
    UNION ALL SELECT 'uci', 'SI_NO', uci, count(*) FROM covid_historica GROUP BY uci
), catalogo (catalogo, clave) AS (
              SELECT 'ORIGEN', clave_origen FROM cat_origen
    UNION ALL SELECT 'SECTOR', clave_sector FROM cat_sector
    UNION ALL SELECT 'SEXO', clave_sexo FROM cat_sexo
    UNION ALL SELECT 'TIPO_PACIENTE', clave_tipo_paciente FROM cat_tipo_paciente
    UNION ALL SELECT 'SI_NO', clave_si_no FROM cat_si_no
    UNION ALL SELECT 'NACIONALIDAD', clave_nacionalidad FROM cat_nacionalidad
    UNION ALL SELECT 'RESULTADO_LAB', clave_resultado_lab FROM cat_resultado_lab
    UNION ALL SELECT 'RESULTADO_ANTIGENO', clave_resultado_antigeno FROM cat_resultado_antigeno
    UNION ALL SELECT 'CLASIFICACION_FINAL', clave_clasificacion FROM cat_clasificacion_final
    UNION ALL SELECT 'ENTIDADES', clave_entidad FROM cat_entidades
)
SELECT v.columna,
       v.catalogo,
       count(*)                                           AS claves_observadas,
       string_agg(v.valor::text || ' (' || v.filas || ')', ', ' ORDER BY v.valor) AS claves_y_filas,
       coalesce(sum(v.filas) FILTER (WHERE c.clave IS NULL), 0) AS filas_fuera_de_catalogo,
       sum(v.filas) FILTER (WHERE v.valor IS NULL)        AS filas_nulas
FROM valores v
LEFT JOIN catalogo c ON c.catalogo = v.catalogo AND c.clave = v.valor
GROUP BY v.columna, v.catalogo
ORDER BY (SELECT ordinal_position FROM information_schema.columns
          WHERE table_name = 'covid_historica' AND column_name = v.columna);

-- @consulta v4_municipios_contra_entidad
-- ¿Cada municipio existe dentro de su entidad? La llave del catálogo es el par
-- (entidad, municipio): el mismo número de municipio se repite en muchas entidades.
SELECT 'municipio_res (con entidad_res)' AS par,
       count(*)                                    AS filas_con_valor,
       count(*) FILTER (WHERE m.municipio IS NULL) AS filas_sin_pareja_en_catalogo,
       string_agg(DISTINCT h.entidad_res || '-' || h.municipio_res, ', ')
           FILTER (WHERE m.municipio IS NULL)      AS pares_invalidos
FROM covid_historica h
LEFT JOIN cat_municipios m ON m.clave_entidad = h.entidad_res AND m.clave_municipio = h.municipio_res
UNION ALL
SELECT 'municipio_um (con entidad_um, solo 2023)',
       count(*),
       count(*) FILTER (WHERE m.municipio IS NULL),
       string_agg(DISTINCT h.entidad_um || '-' || h.municipio_um, ', ') FILTER (WHERE m.municipio IS NULL)
FROM covid_historica h
LEFT JOIN cat_municipios m ON m.clave_entidad = h.entidad_um AND m.clave_municipio = h.municipio_um
WHERE h.municipio_um IS NOT NULL
ORDER BY par;

-- @consulta v5_fechas_en_stage
-- ¿Qué tan limpias vienen las fechas en el texto original? Se separa lo que es fecha válida,
-- el centinela 9999-99-99 y cualquier otra cosa.
WITH f (archivo, columna, valor) AS (
              SELECT '2022', 'fecha_actualizacion', fecha_actualizacion FROM covid_stage_2022
    UNION ALL SELECT '2022', 'fecha_ingreso', fecha_ingreso FROM covid_stage_2022
    UNION ALL SELECT '2022', 'fecha_sintomas', fecha_sintomas FROM covid_stage_2022
    UNION ALL SELECT '2022', 'fecha_def', fecha_def FROM covid_stage_2022
    UNION ALL SELECT '2023', 'fecha_actualizacion', fecha_actualizacion FROM covid_stage_2023
    UNION ALL SELECT '2023', 'fecha_ingreso', fecha_ingreso FROM covid_stage_2023
    UNION ALL SELECT '2023', 'fecha_sintomas', fecha_sintomas FROM covid_stage_2023
    UNION ALL SELECT '2023', 'fecha_def', fecha_def FROM covid_stage_2023
    UNION ALL SELECT '2023', 'fecha_resultado', fecha_resultado FROM covid_stage_2023
)
SELECT archivo, columna,
       count(*)                                                        AS filas,
       count(*) FILTER (WHERE pg_input_is_valid(valor, 'date'))        AS fechas_validas,
       count(*) FILTER (WHERE valor = '9999-99-99')                    AS centinela_9999,
       count(*) FILTER (WHERE valor <> '9999-99-99'
                          AND NOT pg_input_is_valid(valor, 'date'))    AS otros_invalidos,
       min(valor) FILTER (WHERE pg_input_is_valid(valor, 'date'))      AS minima,
       max(valor) FILTER (WHERE pg_input_is_valid(valor, 'date'))      AS maxima
FROM f
GROUP BY archivo, columna
ORDER BY archivo, columna;

-- @consulta v6_conversion_segura
-- ¿Algún valor del stage habría hecho fallar el cast directo a número de sql/04?
-- Si todo da cero, el cast funcionó por los datos, no por construcción (ver la
-- propuesta en sql/propuestas/04_tipado_conversion_segura.sql).
WITH n (archivo, columna, valor) AS (
              SELECT '2022', 'origen', origen FROM covid_stage_2022
    UNION ALL SELECT '2022', 'sector', sector FROM covid_stage_2022
    UNION ALL SELECT '2022', 'entidad_um', entidad_um FROM covid_stage_2022
    UNION ALL SELECT '2022', 'sexo', sexo FROM covid_stage_2022
    UNION ALL SELECT '2022', 'entidad_nac', entidad_nac FROM covid_stage_2022
    UNION ALL SELECT '2022', 'entidad_res', entidad_res FROM covid_stage_2022
    UNION ALL SELECT '2022', 'municipio_res', municipio_res FROM covid_stage_2022
    UNION ALL SELECT '2022', 'localidad_res', localidad_res FROM covid_stage_2022
    UNION ALL SELECT '2022', 'tipo_paciente', tipo_paciente FROM covid_stage_2022
    UNION ALL SELECT '2022', 'edad', edad FROM covid_stage_2022
    UNION ALL SELECT '2022', 'migrante', migrante FROM covid_stage_2022
    UNION ALL SELECT '2022', 'uci', uci FROM covid_stage_2022
    UNION ALL SELECT '2023', 'municipio_um', municipio_um FROM covid_stage_2023
    UNION ALL SELECT '2023', 'edad', edad FROM covid_stage_2023
    UNION ALL SELECT '2023', 'migrante', migrante FROM covid_stage_2023
)
SELECT archivo, columna,
       count(*) FILTER (WHERE NOT pg_input_is_valid(valor, 'smallint')) AS no_convertibles,
       count(*) FILTER (WHERE valor <> btrim(valor, E' \t\r\n'))        AS con_espacios_o_tabuladores,
       count(*) FILTER (WHERE valor !~ '^[0-9]+$')                      AS no_solo_digitos
FROM n
GROUP BY archivo, columna
ORDER BY archivo, columna;

-- @consulta v7_nulos_introducidos_por_el_tipado
-- ¿Cuántos NULL aparecieron al tipar, por archivo de origen? En el stage no hay ningún
-- NULL (ninguna celda vacía en los CSV), así que todo NULL de covid_tipada es una
-- decisión del tipado o una columna que ese archivo no trae.
SELECT archivo_origen,
       count(*)                                          AS filas,
       count(*) FILTER (WHERE fecha_def IS NULL)         AS nulos_fecha_def,
       count(*) FILTER (WHERE fecha_resultado IS NULL)   AS nulos_fecha_resultado,
       count(*) FILTER (WHERE municipio_um IS NULL)      AS nulos_municipio_um,
       count(*) FILTER (WHERE clues IS NULL)             AS nulos_clues,
       count(*) FILTER (WHERE fecha_ingreso IS NULL OR fecha_sintomas IS NULL
                           OR fecha_actualizacion IS NULL)  AS nulos_otras_fechas,
       count(*) FILTER (WHERE edad IS NULL OR sexo IS NULL OR entidad_res IS NULL
                           OR municipio_res IS NULL OR migrante IS NULL) AS nulos_otros_numericos
FROM covid_tipada
GROUP BY archivo_origen
ORDER BY archivo_origen;

-- @consulta v8_llave_id_registro
-- ¿Qué forma tiene ID_REGISTRO y es realmente única en la tabla histórica?
SELECT length(id_registro) AS largo,
       CASE WHEN id_registro ~ '^[0-9a-f]{6}$' THEN '6 caracteres hexadecimales'
            WHEN id_registro ~ '^gz*[0-9a-f]+$' AND length(id_registro) = 7
                 THEN 'g, ' || (length(substring(id_registro from '^gz*')) - 1)
                      || ' z y ' || length(substring(id_registro from '[0-9a-f]+$'))
                      || ' hexadecimales'
            ELSE 'otro' END  AS patron,
       count(*)                     AS filas,
       count(DISTINCT id_registro)  AS distintos,
       min(id_registro)             AS ejemplo_min,
       max(id_registro)             AS ejemplo_max
FROM covid_historica
GROUP BY 1, 2
ORDER BY 1, 2;

-- @consulta v9_restricciones_y_linaje
-- ¿Qué restricciones declara covid_historica y de qué archivo viene cada fila?
SELECT 'restricción' AS tipo, conname AS nombre, pg_get_constraintdef(oid) AS detalle, NULL::bigint AS filas
FROM pg_constraint WHERE conrelid = 'covid_historica'::regclass
UNION ALL
SELECT 'linaje', archivo_origen, NULL, count(*) FROM covid_historica GROUP BY archivo_origen
ORDER BY tipo, nombre;
