-- Práctica 02, Equipo 3. Aportación de Santiago (Machine Learning).
-- Paso 10: detección simple de valores atípicos en EDAD y en los intervalos entre fechas.
--
-- No borra ni modifica nada de covid_historica. Cada registro que cumple un criterio se
-- anota en covid_atipicos con el criterio, el valor observado y el umbral, de modo que
-- cualquier decisión posterior (excluir, corregir o conservar) quede documentada y se
-- pueda revertir. Así lo pide la sección 4.1 y el capítulo de limpieza de Rahm y Do.
--
-- Tres familias de criterios, de lo más simple a lo más elaborado, siguiendo la
-- clasificación de Han, Kamber y Pei (2011, sec. 12.1.2):
--   1. Regla de dominio (atípicos globales imposibles o valores por omisión): lo que no
--      puede ocurrir, según el diccionario, la biología o el orden de los eventos.
--   2. Estadística robusta (atípicos globales raros): lejos del centro de la distribución,
--      medido con mediana y desviación absoluta mediana (MAD), que no se dejan arrastrar
--      por los propios atípicos, y con las cercas de Tukey sobre el logaritmo en las
--      variables muy sesgadas (Han et al., 2011, sec. 2.2.2 y 12.3.1).
--   3. Contextuales (Han et al., 2011, sec. 12.1.2): valores normales por separado que
--      juntos no son plausibles, como un embarazo a los 5 años.
-- Los umbrales estadísticos se calculan con los propios datos, así que el script se puede
-- volver a correr con otra muestra.
--
-- Requiere sql/05_consolidacion.sql y, para la consulta a6, cat_sector (sql/06_catalogos.sql).
-- Ejecutar conectado a covid20a23sedi. Cada consulta de resultados empieza con "-- @consulta"
-- para scripts/ejecutar_consultas.py, que guarda cada una como CSV en evidencias/atipicos/:
--   python scripts/ejecutar_consultas.py sql/10_atipicos.sql atipicos
-- Con psql -f corre igual y los resultados salen en pantalla. Se puede volver a correr:
-- covid_atipicos se borra y se vuelve a llenar.

-- Los scripts están en UTF-8. En Windows, psql suele leerlos como WIN1252 y los acentos se
-- guardan mal o detienen la carga; con esta línea el resto del archivo se lee como UTF-8.
SET client_encoding = 'UTF8';

DROP TABLE IF EXISTS covid_atipicos;
CREATE TABLE covid_atipicos (
    id_registro text     NOT NULL,
    familia     text     NOT NULL,   -- regla de dominio | estadistica robusta | contextual
    criterio    text     NOT NULL,
    variable    text     NOT NULL,
    valor       numeric,
    umbral      text,
    PRIMARY KEY (id_registro, criterio)
);

-- ---------------------------------------------------------------------------------------
-- Parámetros robustos de EDAD y de los intervalos, calculados con los datos
-- ---------------------------------------------------------------------------------------
CREATE TEMP TABLE parametros AS
WITH intervalos AS (
    SELECT (fecha_ingreso - fecha_sintomas)::numeric AS sint_ingreso,
           (fecha_def - fecha_ingreso)::numeric      AS ingreso_def
    FROM covid_historica
), edad AS (
    SELECT percentile_cont(0.25) WITHIN GROUP (ORDER BY edad) AS q1,
           percentile_cont(0.50) WITHIN GROUP (ORDER BY edad) AS mediana,
           percentile_cont(0.75) WITHIN GROUP (ORDER BY edad) AS q3
    FROM covid_historica
), logs AS (
    -- Tukey sobre ln(1 + días): los intervalos son muy sesgados (mediana de 1 día y cola de
    -- meses), y una IQR en la escala original marcaría casos comunes.
    SELECT percentile_cont(0.25) WITHIN GROUP (ORDER BY ln(1 + sint_ingreso)) AS si_q1,
           percentile_cont(0.75) WITHIN GROUP (ORDER BY ln(1 + sint_ingreso)) AS si_q3,
           percentile_cont(0.25) WITHIN GROUP (ORDER BY ln(1 + ingreso_def))
               FILTER (WHERE ingreso_def >= 0)                                    AS id_q1,
           percentile_cont(0.75) WITHIN GROUP (ORDER BY ln(1 + ingreso_def))
               FILTER (WHERE ingreso_def >= 0)                                    AS id_q3
    FROM intervalos WHERE sint_ingreso >= 0
)
SELECT e.q1::numeric AS q1, e.mediana::numeric AS mediana, e.q3::numeric AS q3,
       (SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY abs(h.edad - e.mediana))
        FROM covid_historica h)::numeric                         AS mad,
       (exp(l.si_q3 + 1.5 * (l.si_q3 - l.si_q1)) - 1)::numeric   AS cerca_sint_ingreso,
       (exp(l.id_q3 + 1.5 * (l.id_q3 - l.id_q1)) - 1)::numeric   AS cerca_ingreso_def
FROM edad e, logs l;

-- ---------------------------------------------------------------------------------------
-- 1. Reglas de dominio
-- ---------------------------------------------------------------------------------------
INSERT INTO covid_atipicos
-- Fuera del rango humano posible (la persona más longeva documentada vivió 122 años)
SELECT id_registro, 'regla de dominio', 'edad_fuera_de_rango', 'edad', edad, '< 0 o > 122'
FROM covid_historica WHERE edad < 0 OR edad > 122
UNION ALL
-- Año de nacimiento implícito de 1900 o antes: la fecha por omisión típica de un sistema
-- de captura (1900-01-01), el equivalente del phone=9999-999999 de Rahm y Do
SELECT id_registro, 'regla de dominio', 'edad_nacimiento_1900', 'edad', edad,
       'año de ingreso - edad <= 1900'
FROM covid_historica
WHERE extract(year FROM fecha_ingreso) - edad <= 1900 AND edad <= 122
UNION ALL
SELECT id_registro, 'regla de dominio', 'defuncion_antes_del_ingreso', 'fecha_def - fecha_ingreso',
       fecha_def - fecha_ingreso, '< 0 días'
FROM covid_historica WHERE fecha_def < fecha_ingreso
UNION ALL
SELECT id_registro, 'regla de dominio', 'defuncion_antes_de_sintomas', 'fecha_def - fecha_sintomas',
       fecha_def - fecha_sintomas, '< 0 días'
FROM covid_historica WHERE fecha_def < fecha_sintomas
UNION ALL
SELECT id_registro, 'regla de dominio', 'sintomas_despues_del_ingreso', 'fecha_ingreso - fecha_sintomas',
       fecha_ingreso - fecha_sintomas, '< 0 días'
FROM covid_historica WHERE fecha_sintomas > fecha_ingreso
UNION ALL
SELECT id_registro, 'regla de dominio', 'fecha_posterior_a_la_actualizacion', 'fechas',
       NULL, '> fecha_actualizacion'
FROM covid_historica
WHERE greatest(fecha_ingreso, fecha_sintomas, fecha_def, fecha_resultado) > fecha_actualizacion
UNION ALL
-- Resultado de laboratorio antes del ingreso (solo 2023 trae FECHA_RESULTADO). No es
-- imposible, pero contradice el flujo normal (se toma la muestra al atender el caso).
SELECT id_registro, 'regla de dominio', 'resultado_antes_del_ingreso', 'fecha_resultado - fecha_ingreso',
       fecha_resultado - fecha_ingreso, '< 0 días'
FROM covid_historica WHERE fecha_resultado < fecha_ingreso
UNION ALL
-- Definición operativa de caso sospechoso (DGE, 2022): síntomas en los últimos 10 días.
-- Más de 10 días entre síntomas e ingreso queda fuera de esa ventana.
SELECT id_registro, 'regla de dominio', 'sintomas_fuera_de_ventana_10_dias', 'fecha_ingreso - fecha_sintomas',
       fecha_ingreso - fecha_sintomas, '> 10 días'
FROM covid_historica WHERE fecha_ingreso - fecha_sintomas > 10;

-- ---------------------------------------------------------------------------------------
-- 2. Estadística robusta
-- ---------------------------------------------------------------------------------------
INSERT INTO covid_atipicos
-- Puntaje z modificado de Iglewicz y Hoaglin (1993): 0.6745 (x - mediana) / MAD; se marca
-- si su valor absoluto pasa de 3.5.
SELECT h.id_registro, 'estadistica robusta', 'edad_z_mad_mayor_3_5', 'edad', h.edad,
       '|0.6745 (edad - ' || p.mediana || ') / ' || p.mad || '| > 3.5'
FROM covid_historica h, parametros p
WHERE abs(0.6745 * (h.edad - p.mediana) / p.mad) > 3.5
UNION ALL
-- Cerca externa de Tukey (Q3 + 3 IQR): "atípico lejano"
SELECT h.id_registro, 'estadistica robusta', 'edad_tukey_3_iqr', 'edad', h.edad,
       '> ' || (p.q3 + 3 * (p.q3 - p.q1))
FROM covid_historica h, parametros p
WHERE h.edad > p.q3 + 3 * (p.q3 - p.q1)
UNION ALL
SELECT h.id_registro, 'estadistica robusta', 'sintomas_a_ingreso_extremo', 'fecha_ingreso - fecha_sintomas',
       h.fecha_ingreso - h.fecha_sintomas, '> ' || round(p.cerca_sint_ingreso, 1) || ' días (Tukey sobre ln)'
FROM covid_historica h, parametros p
WHERE h.fecha_ingreso - h.fecha_sintomas > p.cerca_sint_ingreso
UNION ALL
SELECT h.id_registro, 'estadistica robusta', 'ingreso_a_defuncion_extremo', 'fecha_def - fecha_ingreso',
       h.fecha_def - h.fecha_ingreso, '> ' || round(p.cerca_ingreso_def, 1) || ' días (Tukey sobre ln)'
FROM covid_historica h, parametros p
WHERE h.fecha_def - h.fecha_ingreso > p.cerca_ingreso_def;

-- ---------------------------------------------------------------------------------------
-- 3. Contextuales: la edad es el contexto y el otro campo el comportamiento
-- ---------------------------------------------------------------------------------------
INSERT INTO covid_atipicos
SELECT id_registro, 'contextual', 'embarazo_menor_de_10', 'edad | embarazo = 1', edad, 'edad < 10'
FROM covid_historica WHERE embarazo = 1 AND edad < 10
UNION ALL
SELECT id_registro, 'contextual', 'embarazo_mayor_de_55', 'edad | embarazo = 1', edad, 'edad > 55'
FROM covid_historica WHERE embarazo = 1 AND edad > 55
UNION ALL
SELECT id_registro, 'contextual', 'tabaquismo_menor_de_10', 'edad | tabaquismo = 1', edad, 'edad < 10'
FROM covid_historica WHERE tabaquismo = 1 AND edad < 10;

CREATE INDEX ON covid_atipicos (criterio);

-- @consulta a1_parametros
SELECT q1, mediana, q3, q3 - q1 AS iqr, mad,
       q3 + 1.5 * (q3 - q1)                AS cerca_tukey_1_5,
       q3 + 3 * (q3 - q1)                  AS cerca_tukey_3,
       mediana + 3.5 * mad / 0.6745        AS limite_z_mad_3_5,
       round(cerca_sint_ingreso, 1)        AS cerca_sint_ingreso_dias,
       round(cerca_ingreso_def, 1)         AS cerca_ingreso_def_dias
FROM parametros;

-- @consulta a2_resumen_por_criterio
SELECT familia, criterio, umbral, count(*) AS registros,
       round(100.0 * count(*) / (SELECT count(*) FROM covid_historica), 4) AS pct,
       min(valor) AS valor_min, max(valor) AS valor_max
FROM covid_atipicos
GROUP BY familia, criterio, umbral
ORDER BY CASE familia WHEN 'regla de dominio' THEN 1 WHEN 'estadistica robusta' THEN 2 ELSE 3 END,
         count(*) DESC;

-- @consulta a3_por_que_no_iqr_1_5
-- Por qué NO se usa la regla clásica de 1.5 IQR para EDAD: marcaría a las personas mayores,
-- que son justo las de mayor letalidad. Se compara también con la regla de 3 desviaciones
-- estándar, que depende de la media y la desviación, dos medidas sensibles a los atípicos.
SELECT regla, registros, round(100.0 * registros / total, 2) AS pct_de_registros,
       pct_fallecidos_marcados, pct_fallecidos_resto
FROM (
    SELECT 'Tukey 1.5 IQR (edad > ' || (p.q3 + 1.5 * (p.q3 - p.q1)) || ')' AS regla,
           count(*) FILTER (WHERE h.edad > p.q3 + 1.5 * (p.q3 - p.q1)) AS registros,
           count(*) AS total,
           round(100.0 * count(h.fecha_def) FILTER (WHERE h.edad > p.q3 + 1.5 * (p.q3 - p.q1))
                 / nullif(count(*) FILTER (WHERE h.edad > p.q3 + 1.5 * (p.q3 - p.q1)), 0), 2)
               AS pct_fallecidos_marcados,
           round(100.0 * count(h.fecha_def) FILTER (WHERE h.edad <= p.q3 + 1.5 * (p.q3 - p.q1))
                 / count(*) FILTER (WHERE h.edad <= p.q3 + 1.5 * (p.q3 - p.q1)), 2)
               AS pct_fallecidos_resto
    FROM covid_historica h, parametros p
    GROUP BY p.q1, p.q3
    UNION ALL
    SELECT 'Media + 3 desviaciones estándar (edad > ' || round(avg_e + 3 * de_e, 1) || ')',
           count(*) FILTER (WHERE h.edad > avg_e + 3 * de_e), count(*),
           round(100.0 * count(h.fecha_def) FILTER (WHERE h.edad > avg_e + 3 * de_e)
                 / nullif(count(*) FILTER (WHERE h.edad > avg_e + 3 * de_e), 0), 2),
           round(100.0 * count(h.fecha_def) FILTER (WHERE h.edad <= avg_e + 3 * de_e)
                 / count(*) FILTER (WHERE h.edad <= avg_e + 3 * de_e), 2)
    FROM covid_historica h,
         (SELECT avg(edad) AS avg_e, stddev(edad) AS de_e FROM covid_historica) s
    GROUP BY avg_e, de_e
) x
ORDER BY registros DESC;

-- @consulta a4_cola_de_edad
-- La cola de la distribución: el salto en 122 es la huella de un valor por omisión.
SELECT edad,
       count(*)                                              AS registros,
       min(extract(year FROM fecha_ingreso) - edad)::int     AS anio_nacimiento_implicito,
       count(*) FILTER (WHERE archivo_origen LIKE '%2022%')  AS de_2022,
       count(*) FILTER (WHERE sector = 9)                    AS sector_privado,
       count(*) FILTER (WHERE entidad_um = 9)                AS atendidos_en_cdmx,
       count(fecha_def)                                      AS fallecidos
FROM covid_historica
WHERE edad >= 100
GROUP BY edad
ORDER BY edad;

-- @consulta a5_registros_con_mas_de_un_criterio
SELECT criterios, count(*) AS registros
FROM (SELECT id_registro, string_agg(criterio, ' + ' ORDER BY criterio) AS criterios
      FROM covid_atipicos GROUP BY id_registro HAVING count(*) > 1) x
GROUP BY criterios
ORDER BY registros DESC, criterios;

-- @consulta a6_demora_por_sector
-- La demora entre síntomas e ingreso tiene un techo de 14 a 16 días en 11 de los 14 sectores;
-- solo tres lo rebasan, y de ellos salen todas las demoras extremas.
SELECT s.sector,
       count(*)                                                        AS registros,
       max(h.fecha_ingreso - h.fecha_sintomas)                         AS demora_maxima,
       percentile_cont(0.99) WITHIN GROUP (ORDER BY h.fecha_ingreso - h.fecha_sintomas) AS p99,
       count(*) FILTER (WHERE h.fecha_ingreso - h.fecha_sintomas > 10) AS fuera_de_ventana_10_dias,
       count(a.id_registro)                                            AS demora_extrema
FROM covid_historica h
JOIN cat_sector s ON s.clave_sector = h.sector
LEFT JOIN covid_atipicos a ON a.id_registro = h.id_registro AND a.criterio = 'sintomas_a_ingreso_extremo'
GROUP BY s.sector
ORDER BY demora_maxima DESC, registros DESC;

-- @consulta a7_atipico_colectivo
-- Atípico colectivo (Han et al., 2011, sec. 12.1.2): unidades privadas de la CDMX con demora
-- extrema. Ninguno de estos registros es imposible por sí solo; juntos señalan una captura
-- tardía desde una misma fuente, con año de nacimiento por omisión en casi un tercio.
SELECT (h.edad = 122)                    AS edad_122,
       count(*)                          AS registros,
       min(h.fecha_sintomas)             AS sintomas_desde,
       max(h.fecha_sintomas)             AS sintomas_hasta,
       min(h.fecha_ingreso)              AS ingreso_desde,
       max(h.fecha_ingreso)              AS ingreso_hasta,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY h.fecha_ingreso - h.fecha_sintomas) AS demora_mediana,
       count(h.fecha_def)                AS fallecidos
FROM covid_historica h
JOIN covid_atipicos a ON a.id_registro = h.id_registro AND a.criterio = 'sintomas_a_ingreso_extremo'
WHERE h.sector = 9 AND h.entidad_um = 9
GROUP BY 1
ORDER BY 1;
