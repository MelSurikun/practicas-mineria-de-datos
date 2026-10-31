-- Práctica 02, Equipo 3. Aportación de Santiago (apoyo a la sección 6.2, a cargo de Juan).
-- Paso 11: anomalías de covid_historica contrastadas con el diccionario y los catálogos.
--
-- Solo lectura. Las consultas siguen la clasificación del capítulo de limpieza que acompaña
-- la práctica (Rahm y Do, 2000): valores faltantes disfrazados de código, errores de
-- escritura y representaciones distintas del mismo dato, dependencias entre atributos que no
-- se cumplen, ruido embebido y, entre los dos archivos, conflictos de esquema y de tiempo.
-- Los duplicados ya están resueltos y documentados en sql/05_consolidacion.sql.
--
-- Requiere sql/05 (covid_historica) y sql/06 (cat_entidades y cat_municipios). Ejecutar
-- conectado a covid20a23sedi. Cada consulta empieza con "-- @consulta" para
-- scripts/ejecutar_consultas.py, que la guarda como CSV en evidencias/apoyo_anomalias/:
--   python scripts/ejecutar_consultas.py sql/11_apoyo_anomalias.sql apoyo_anomalias
-- Con psql -f corre igual y los resultados salen en pantalla.

-- Los scripts están en UTF-8. En Windows, psql suele leerlos como WIN1252 y los acentos se
-- guardan mal o detienen la carga; con esta línea el resto del archivo se lee como UTF-8.
SET client_encoding = 'UTF8';

-- @consulta n1_centinelas_por_columna
-- En esta base casi nada falta como NULL: lo que falta viene codificado. 97 = no aplica
-- (la pregunta no corresponde), 98 = se ignora y 99 = no especificado (el dato existe
-- pero no se capturó). Tratar esos códigos como números (por ejemplo, promediarlos) o
-- como faltantes sin distinguirlos lleva a conclusiones distintas.
WITH v AS (
    SELECT c.columna, c.valor
    FROM covid_historica h
    CROSS JOIN LATERAL (VALUES
        ('origen', h.origen), ('sector', h.sector), ('sexo', h.sexo),
        ('entidad_um', h.entidad_um), ('entidad_nac', h.entidad_nac), ('entidad_res', h.entidad_res),
        ('tipo_paciente', h.tipo_paciente), ('intubado', h.intubado), ('neumonia', h.neumonia),
        ('nacionalidad', h.nacionalidad), ('embarazo', h.embarazo),
        ('habla_lengua_indig', h.habla_lengua_indig), ('indigena', h.indigena),
        ('diabetes', h.diabetes), ('epoc', h.epoc), ('asma', h.asma), ('inmusupr', h.inmusupr),
        ('hipertension', h.hipertension), ('otra_com', h.otra_com),
        ('cardiovascular', h.cardiovascular), ('obesidad', h.obesidad),
        ('renal_cronica', h.renal_cronica), ('tabaquismo', h.tabaquismo),
        ('otro_caso', h.otro_caso), ('toma_muestra_lab', h.toma_muestra_lab),
        ('resultado_lab', h.resultado_lab), ('toma_muestra_antigeno', h.toma_muestra_antigeno),
        ('resultado_antigeno', h.resultado_antigeno), ('clasificacion_final', h.clasificacion_final),
        ('migrante', h.migrante), ('uci', h.uci)
    ) AS c (columna, valor)
)
SELECT columna,
       count(*) FILTER (WHERE valor IS NULL) AS nulos,
       count(*) FILTER (WHERE valor = 97)    AS c97_no_aplica,
       count(*) FILTER (WHERE valor = 98)    AS c98_se_ignora,
       count(*) FILTER (WHERE valor = 99)    AS c99_no_especificado,
       round(100.0 * count(*) FILTER (WHERE valor IN (98, 99)) / count(*), 3) AS pct_sin_dato,
       round(100.0 * count(*) FILTER (WHERE valor = 97) / count(*), 3)        AS pct_no_aplica
FROM v
GROUP BY columna
ORDER BY pct_sin_dato DESC, pct_no_aplica DESC, columna;

-- @consulta n2_centinelas_en_texto
-- El diccionario dice PAIS_NACIONALIDAD: "TEXTO, 99 = SE IGNORA" y PAIS_ORIGEN: "TEXTO,
-- 97 = NO APLICA". En los datos, el 97 sí se usa; el 99 nunca aparece, y lo desconocido
-- viene escrito como texto ("SE DESCONOCE") o en una categoría genérica ("Otro").
SELECT 'pais_nacionalidad' AS columna,
       count(*) FILTER (WHERE pais_nacionalidad = '99')           AS valor_99,
       count(*) FILTER (WHERE pais_nacionalidad = '97')           AS valor_97,
       count(*) FILTER (WHERE pais_nacionalidad = 'SE DESCONOCE') AS se_desconoce,
       count(*) FILTER (WHERE pais_nacionalidad = 'Otro')         AS otro,
       count(*) FILTER (WHERE pais_nacionalidad = 'México')       AS mexico,
       count(DISTINCT pais_nacionalidad)                           AS valores_distintos,
       min(pais_nacionalidad) AS minimo_alfabetico, max(pais_nacionalidad) AS maximo_alfabetico
FROM covid_historica
UNION ALL
SELECT 'pais_origen',
       count(*) FILTER (WHERE pais_origen = '99'),
       count(*) FILTER (WHERE pais_origen = '97'),
       count(*) FILTER (WHERE pais_origen = 'SE DESCONOCE'),
       count(*) FILTER (WHERE pais_origen = 'Otro'),
       count(*) FILTER (WHERE pais_origen = 'México'),
       count(DISTINCT pais_origen),
       min(pais_origen), max(pais_origen)
FROM covid_historica
ORDER BY columna;

-- @consulta n3_fechas_centinela
-- 9999-99-99 no es fecha: en FECHA_DEF significa que no hubo defunción y en FECHA_RESULTADO
-- que no hay resultado. El texto original queda en el stage; en la tabla tipada es NULL.
SELECT 'covid_stage_2022' AS origen, 'fecha_def' AS columna,
       count(*) FILTER (WHERE fecha_def = '9999-99-99') AS centinela, count(*) AS filas
FROM covid_stage_2022
UNION ALL
SELECT 'covid_stage_2023', 'fecha_def', count(*) FILTER (WHERE fecha_def = '9999-99-99'), count(*)
FROM covid_stage_2023
UNION ALL
SELECT 'covid_stage_2023', 'fecha_resultado', count(*) FILTER (WHERE fecha_resultado = '9999-99-99'), count(*)
FROM covid_stage_2023
UNION ALL
SELECT 'covid_historica', 'fecha_def (NULL)', count(*) FILTER (WHERE fecha_def IS NULL), count(*)
FROM covid_historica
UNION ALL
SELECT 'covid_historica', 'fecha_resultado (NULL, solo 2023)',
       count(*) FILTER (WHERE fecha_resultado IS NULL AND archivo_origen LIKE '%2023%'),
       count(*) FILTER (WHERE archivo_origen LIKE '%2023%')
FROM covid_historica
ORDER BY 1, 2;

-- @consulta n4_codigos_no_documentados
-- Valores que se comportan como centinelas sin que el diccionario de 2020 los describa.
SELECT 'municipio_res = 999' AS valor, 'NO ESPECIFICADO en el catálogo de municipios' AS lectura,
       count(*) AS registros FROM covid_historica WHERE municipio_res = 999
UNION ALL
SELECT 'localidad_res = 9999', 'LOCALIDAD_RES no tiene catálogo; 9999 se repite mucho más que cualquier clave alta',
       count(*) FROM covid_historica WHERE localidad_res = 9999
UNION ALL
SELECT 'clues = ' || clues, 'Una sola CLUES ficticia (XXX), toda con sector 99 en Chihuahua',
       count(*) FROM covid_historica WHERE clues LIKE '__XXX%' GROUP BY clues
UNION ALL
SELECT 'edad = 122', 'Año de nacimiento implícito 1900 (ver sql/10_atipicos.sql)',
       count(*) FROM covid_historica WHERE edad = 122
UNION ALL
SELECT 'entidad_nac = 99 con nacionalidad extranjera', 'Se usa 99 (no especificado) donde correspondería 97 (no aplica)',
       count(*) FROM covid_historica WHERE nacionalidad = 2 AND entidad_nac = 99
UNION ALL
SELECT 'entidad_nac = 99 con nacionalidad mexicana', 'Entidad de nacimiento sin capturar',
       count(*) FROM covid_historica WHERE nacionalidad = 1 AND entidad_nac = 99
ORDER BY 1;

-- @consulta n5_valores_de_pais_con_problema
-- Valores de país que no son un país vigente o están mal escritos. La lista se armó
-- revisando los 152 valores distintos de PAIS_NACIONALIDAD y los 94 de PAIS_ORIGEN; los
-- conteos salen de la tabla.
WITH lista (valor, problema) AS (VALUES
    ('SE DESCONOCE', 'Valor faltante escrito como texto, no como el 99 del diccionario'),
    ('Otro', 'Categoría genérica: no identifica un país'),
    ('Rhuanda', 'Error de escritura (Ruanda)'),
    ('Thailandia', 'Error de escritura (Tailandia)'),
    ('Campione DItalia', 'Apóstrofo perdido (Campione d''Italia)'),
    ('Países de la Ex-U.R.S.S., excepto Ucrania y Bielorusia',
        'Agrupación de países, no un país; escribe Bielorusia, y el valor suelto dice Bielorrusia'),
    ('Republica Democrática del Congo', 'Sin acento, a diferencia del resto de "República ..."'),
    ('Azerbaiyán - Islas Azores', 'Dos lugares distintos en un solo valor'),
    ('Yemen Democrática', 'Estado que dejó de existir en 1990'),
    ('República Checa y República Eslovaca', 'Estado que se dividió en 1993'),
    ('Zona Neutral', 'Territorio, no un país vigente'),
    ('Antártica', 'Continente, no un país'),
    ('Zona Especial Canaria', 'Régimen fiscal de España, no un país')
)
SELECT valor, problema, en_pais_nacionalidad, en_pais_origen
FROM (SELECT l.valor, l.problema,
             (SELECT count(*) FROM covid_historica WHERE pais_nacionalidad = l.valor) AS en_pais_nacionalidad,
             (SELECT count(*) FROM covid_historica WHERE pais_origen = l.valor)       AS en_pais_origen
      FROM lista l) x
ORDER BY en_pais_nacionalidad + en_pais_origen DESC, valor;

-- @consulta n6_dependencias_entre_atributos
-- Reglas que se desprenden del diccionario y de los catálogos. Las que dan cero parecen
-- validarse al capturar; las que no, son las anomalías a discutir.
WITH conteos AS (
    SELECT
        count(*) FILTER (WHERE m.municipio IS NULL)                                         AS r01,
        count(*) FILTER (WHERE h.municipio_um IS NOT NULL AND mu.municipio IS NULL)         AS r02,
        count(*) FILTER (WHERE h.clues IS NOT NULL AND left(h.clues, 2) <> e.abreviatura)   AS r03,
        count(*) FILTER (WHERE h.clues IS NOT NULL AND substr(h.clues, 3, 3) = 'IMO' AND h.sector <> 5) AS r04,
        count(*) FILTER (WHERE (h.nacionalidad = 1) <> (h.pais_nacionalidad = 'México'))    AS r05,
        count(*) FILTER (WHERE h.nacionalidad = 2 AND h.entidad_nac <> 97)                  AS r06,
        count(*) FILTER (WHERE h.nacionalidad = 1 AND h.entidad_nac NOT BETWEEN 1 AND 32)   AS r07,
        count(*) FILTER (WHERE (h.migrante = 1) <> (h.pais_origen <> '97'))                 AS r08,
        count(*) FILTER (WHERE h.sexo = 2 AND h.embarazo <> 97)                             AS r09,
        count(*) FILTER (WHERE h.sexo = 1 AND h.embarazo = 97)                              AS r10,
        count(*) FILTER (WHERE (h.tipo_paciente = 1) <> (h.intubado = 97))                  AS r11,
        count(*) FILTER (WHERE (h.tipo_paciente = 1) <> (h.uci = 97))                       AS r12,
        count(*) FILTER (WHERE (h.toma_muestra_lab = 2) <> (h.resultado_lab = 97))          AS r13,
        count(*) FILTER (WHERE (h.toma_muestra_antigeno = 2) <> (h.resultado_antigeno = 97)) AS r14,
        count(*) FILTER (WHERE h.clasificacion_final = 2 AND h.fecha_def IS NULL)           AS r15,
        count(*) FILTER (WHERE h.clasificacion_final = 3
                           AND h.resultado_lab <> 1 AND h.resultado_antigeno <> 1)          AS r16,
        count(*) FILTER (WHERE (h.resultado_lab = 1 OR h.resultado_antigeno = 1)
                           AND h.clasificacion_final <> 3)                                  AS r17,
        count(*) FILTER (WHERE h.fecha_def < h.fecha_ingreso)                               AS r18,
        count(*) FILTER (WHERE h.fecha_sintomas > h.fecha_ingreso)                          AS r19,
        count(*) FILTER (WHERE greatest(h.fecha_ingreso, h.fecha_sintomas, h.fecha_def,
                                        h.fecha_resultado) > h.fecha_actualizacion)         AS r20
    FROM covid_historica h
    LEFT JOIN cat_municipios m  ON m.clave_entidad = h.entidad_res AND m.clave_municipio = h.municipio_res
    LEFT JOIN cat_municipios mu ON mu.clave_entidad = h.entidad_um AND mu.clave_municipio = h.municipio_um
    LEFT JOIN cat_entidades e   ON e.clave_entidad = h.entidad_um
)
SELECT r.num, r.regla, r.origen_de_la_regla, r.violaciones
FROM conteos c
CROSS JOIN LATERAL (VALUES
    (1,  'MUNICIPIO_RES existe dentro de ENTIDAD_RES', 'Catálogo de municipios', c.r01),
    (2,  'MUNICIPIO_UM existe dentro de ENTIDAD_UM (2023)', 'Catálogo de municipios', c.r02),
    (3,  'Las dos letras iniciales de CLUES son la abreviatura de ENTIDAD_UM (2023)', 'Catálogo de entidades', c.r03),
    (4,  'CLUES de IMSS-Oportunidades (IMO) con SECTOR = IMSS-BIENESTAR (2023)', 'Catálogo de sectores', c.r04),
    (5,  'NACIONALIDAD = 1 (mexicana) si y solo si PAIS_NACIONALIDAD = México', 'Diccionario', c.r05),
    (6,  'Extranjeros con ENTIDAD_NAC = 97 (no aplica)', 'Catálogo de entidades', c.r06),
    (7,  'Mexicanos con ENTIDAD_NAC entre 01 y 32', 'Catálogo de entidades', c.r07),
    (8,  'MIGRANTE = 1 si y solo si PAIS_ORIGEN distinto de 97', 'Diccionario', c.r08),
    (9,  'Hombres con EMBARAZO = 97 (no aplica)', 'Catálogo SI_NO', c.r09),
    (10, 'Mujeres con EMBARAZO distinto de 97', 'Catálogo SI_NO', c.r10),
    (11, 'Ambulatorio si y solo si INTUBADO = 97', 'Diccionario (TIPO_PACIENTE)', c.r11),
    (12, 'Ambulatorio si y solo si UCI = 97', 'Diccionario (TIPO_PACIENTE)', c.r12),
    (13, 'Sin muestra de laboratorio si y solo si RESULTADO_LAB = 97', 'Catálogo RESULTADO_LAB', c.r13),
    (14, 'Sin muestra de antígeno si y solo si RESULTADO_ANTIGENO = 97', 'Catálogo RESULTADO_ANTIGENO', c.r14),
    (15, 'CLASIFICACION_FINAL = 2 (dictaminación) solo en defunciones', 'Catálogo CLASIFICACION_FINAL', c.r15),
    (16, 'CLASIFICACION_FINAL = 3 (confirmado) con una prueba positiva', 'Catálogo CLASIFICACION_FINAL', c.r16),
    (17, 'Una prueba positiva lleva a CLASIFICACION_FINAL = 3', 'Catálogo CLASIFICACION_FINAL', c.r17),
    (18, 'FECHA_DEF no es anterior a FECHA_INGRESO', 'Orden de los eventos', c.r18),
    (19, 'FECHA_SINTOMAS no es posterior a FECHA_INGRESO', 'Orden de los eventos', c.r19),
    (20, 'Ninguna fecha es posterior a FECHA_ACTUALIZACION', 'Orden de los eventos', c.r20)
) AS r (num, regla, origen_de_la_regla, violaciones)
ORDER BY r.num;

-- @consulta n7_ruido_embebido
-- Un tabulador dentro de MIGRANTE en el CSV de 2022: un solo registro, que aparece dos
-- veces en el stage por la duplicación del archivo.
SELECT id_registro, migrante AS valor_en_stage, encode(convert_to(migrante, 'UTF8'), 'hex') AS bytes_hex,
       count(*) AS filas_en_stage
FROM covid_stage_2022
WHERE migrante ~ '\s'
GROUP BY id_registro, migrante;

-- @consulta n8_cobertura_temporal
-- Tiempo inconsistente entre las dos fuentes: cortes de actualización distintos y periodos
-- cubiertos muy distintos. Lo que se llama 2022 es, en la práctica, enero a junio de 2022,
-- y lo que se llama 2023 es casi solo enero de 2023.
SELECT CASE WHEN archivo_origen LIKE '%2022%' THEN '2022' ELSE '2023' END AS archivo,
       min(fecha_actualizacion) AS fecha_actualizacion,
       to_char(fecha_sintomas, 'YYYY-MM') AS mes_de_sintomas,
       count(*) AS registros,
       count(fecha_def) AS defunciones
FROM covid_historica
GROUP BY 1, 3
ORDER BY 1, 3;

-- @consulta n9_conflictos_de_esquema_entre_archivos
-- Columnas que solo trae uno de los dos archivos (conflicto estructural entre fuentes).
SELECT column_name AS columna,
       bool_or(table_name = 'covid_stage_2022') AS en_2022,
       bool_or(table_name = 'covid_stage_2023') AS en_2023
FROM information_schema.columns
WHERE table_name IN ('covid_stage_2022', 'covid_stage_2023') AND column_name <> 'archivo_origen'
GROUP BY column_name
HAVING count(*) = 1
ORDER BY column_name;
