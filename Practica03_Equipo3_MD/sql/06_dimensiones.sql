-- Práctica 03, Equipo 3 (Melanie, Ingeniería de Datos). Punto 5: carga de las dimensiones.
-- Parte de sql/prueba_carga/10_dimensiones.sql (Santiago). Cambios respecto a ese archivo:
--   1. dim_extracto reconoce el archivo de 2022 aunque covid_historica lo guarde con la
--      etiqueta " (reparado)" (error 1 de evidencias/bitacora_errores_p3.md).
--   2. etl.control_carga registra filas de origen y destino y segundos de cada paso.
--
-- Tres familias de dimensiones, tres formas de llenarlas:
--   1. Generadas: dim_tiempo (un calendario) y dim_edad (una fila por edad observada).
--   2. De catálogo: dim_ubicacion, dim_entidad (el catálogo completo, aunque haya
--      municipios sin casos) más los miembros inferidos de códigos fuera de catálogo.
--   3. De combinaciones observadas (SELECT DISTINCT): paciente, comorbilidad, atención,
--      diagnóstico, unidad médica, país y calidad.
--
-- Se corre desde correr_etl.sql, después de sql/modelo/00_catalogos.sql y 01_esquema_dw.sql.

-- Los scripts están en UTF-8. En Windows, psql suele leerlos como WIN1252 y los acentos
-- detienen la carga (character with byte sequence 0x81 in encoding "WIN1252"...).
-- Esta línea lo evita: el resto del archivo se interpreta como UTF-8.
SET client_encoding = 'UTF8';

CREATE SCHEMA IF NOT EXISTS etl;

-- Control de la carga: una fila por paso, con la numeración del punto 4. Se reinicia en
-- cada corrida. Si un paso falla, su transacción se deshace y sus filas no quedan aquí:
-- el mensaje del error está en la salida de psql.
DROP TABLE IF EXISTS etl.control_carga;
CREATE TABLE etl.control_carga (
    id_control    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    paso          smallint NOT NULL,
    etapa         text NOT NULL,
    tabla         text NOT NULL,
    filas_origen  bigint,
    filas_destino bigint NOT NULL,
    diferencia    bigint GENERATED ALWAYS AS (filas_destino - filas_origen) STORED,
    fin           timestamptz NOT NULL,
    segundos      numeric(10, 2) NOT NULL,
    nota          text
);
COMMENT ON TABLE etl.control_carga IS 'Filas de origen y destino y tiempo de cada paso del ETL (última corrida).';

-- Los segundos se toman antes de contar, para que el conteo no se sume al tiempo del paso;
-- fin se toma después, por la misma razón con el paso siguiente.
CREATE OR REPLACE PROCEDURE etl.registrar(p_paso int, p_etapa text, p_tabla text,
                                          p_sql_origen text DEFAULT NULL, p_nota text DEFAULT NULL)
LANGUAGE plpgsql AS $$
DECLARE
    v_segundos numeric := extract(epoch FROM clock_timestamp()
        - coalesce((SELECT max(fin) FROM etl.control_carga), transaction_timestamp()));
    v_origen bigint;
    v_destino bigint;
BEGIN
    IF p_sql_origen IS NOT NULL THEN
        EXECUTE p_sql_origen INTO v_origen;
    END IF;
    EXECUTE format('SELECT count(*) FROM %s', p_tabla) INTO v_destino;
    INSERT INTO etl.control_carga (paso, etapa, tabla, filas_origen, filas_destino, fin, segundos, nota)
    VALUES (p_paso, p_etapa, p_tabla, v_origen, v_destino, clock_timestamp(), v_segundos, p_nota);
END $$;

\timing on
BEGIN;

CALL etl.registrar(3, 'Extracción', 'public.covid_historica', NULL, 'Sin filtros de filas: lo dudoso se marca en dim_calidad');

-- Se vacía también la tabla de hechos: si ya se corrió 02_llaves_foraneas, sus llaves
-- apuntan a estas dimensiones y PostgreSQL no deja vaciar una dimensión referenciada
-- a menos que la tabla que la referencia se vacíe en el mismo TRUNCATE. Así el archivo se
-- puede volver a correr en cualquier momento.
TRUNCATE dw.fact_casos_covid, dw.dim_tiempo, dw.dim_ubicacion, dw.dim_entidad, dw.dim_unidad_medica,
         dw.dim_paciente, dw.dim_pais, dw.dim_edad, dw.dim_comorbilidad, dw.dim_atencion,
         dw.dim_diagnostico, dw.dim_extracto, dw.dim_calidad RESTART IDENTITY;

-- ---------------------------------------------------------------------------------------
-- 1. dim_tiempo: 2022-01-01 a 2023-12-31 (730 días) y dos miembros especiales
-- ---------------------------------------------------------------------------------------
INSERT INTO dw.dim_tiempo (id_tiempo, fecha, tipo_miembro) VALUES
    (-1, NULL, 'NO DISPONIBLE EN EL EXTRACTO'),
    (-2, NULL, 'NO APLICA (SIN EVENTO)');

WITH dias AS (
    SELECT g::date AS fecha
    FROM generate_series(DATE '2022-01-01', DATE '2023-12-31', INTERVAL '1 day') AS g
),
-- Días de descanso obligatorio nacionales, LFT artículo 74. Los "lunes" se calculan:
-- desde el día 1 del mes se avanza hasta el primer lunes ((8 - isodow) % 7 días) y,
-- para el tercero, dos semanas más. La fracción VII (transmisión del Ejecutivo) no cae
-- en 2022-2023 y la IX (jornadas electorales) varía por entidad, así que no entra.
festivos AS (
    SELECT make_date(a, 1, 1) AS fecha, '1 DE ENERO' AS nombre FROM generate_series(2022, 2023) AS a
    UNION ALL
    SELECT make_date(a, 2, 1) + (8 - extract(isodow FROM make_date(a, 2, 1))::int) % 7,
           'PRIMER LUNES DE FEBRERO (5 DE FEBRERO)' FROM generate_series(2022, 2023) AS a
    UNION ALL
    SELECT make_date(a, 3, 1) + (8 - extract(isodow FROM make_date(a, 3, 1))::int) % 7 + 14,
           'TERCER LUNES DE MARZO (21 DE MARZO)' FROM generate_series(2022, 2023) AS a
    UNION ALL
    SELECT make_date(a, 5, 1), '1 DE MAYO' FROM generate_series(2022, 2023) AS a
    UNION ALL
    SELECT make_date(a, 9, 16), '16 DE SEPTIEMBRE' FROM generate_series(2022, 2023) AS a
    UNION ALL
    SELECT make_date(a, 11, 1) + (8 - extract(isodow FROM make_date(a, 11, 1))::int) % 7 + 14,
           'TERCER LUNES DE NOVIEMBRE (20 DE NOVIEMBRE)' FROM generate_series(2022, 2023) AS a
    UNION ALL
    SELECT make_date(a, 12, 25), '25 DE DICIEMBRE' FROM generate_series(2022, 2023) AS a
),
-- Semana epidemiológica: de domingo a sábado. extract(dow) vale 0 en domingo, así que
-- fecha - dow es el domingo que abre la semana. La semana pertenece al año que tiene al
-- menos 4 de sus 7 días, que es el año de su miércoles (domingo + 3). La semana 1 de
-- un año es la que contiene el 4 de enero.
semanas AS (
    SELECT d.fecha,
           d.fecha - extract(dow FROM d.fecha)::int AS inicio_semana_epi,
           extract(year FROM d.fecha - extract(dow FROM d.fecha)::int + 3)::int AS anio_epi
    FROM dias d
),
calendario AS (
    SELECT s.*,
           ((s.inicio_semana_epi - (make_date(s.anio_epi, 1, 4)
                                     - extract(dow FROM make_date(s.anio_epi, 1, 4))::int)) / 7 + 1) AS semana_epi
    FROM semanas s
)
INSERT INTO dw.dim_tiempo (id_tiempo, fecha, tipo_miembro, anio, semestre, trimestre, mes, nombre_mes,
                           anio_mes, dia, dia_semana, nombre_dia, es_fin_de_semana, anio_epi, semana_epi,
                           inicio_semana_epi, temporada_influenza, es_festivo, nombre_festivo, tipo_dia)
SELECT to_char(c.fecha, 'YYYYMMDD')::int,
       c.fecha,
       'FECHA',
       extract(year FROM c.fecha),
       CASE WHEN extract(month FROM c.fecha) <= 6 THEN 1 ELSE 2 END,
       extract(quarter FROM c.fecha),
       extract(month FROM c.fecha),
       (ARRAY['ENERO','FEBRERO','MARZO','ABRIL','MAYO','JUNIO','JULIO','AGOSTO',
              'SEPTIEMBRE','OCTUBRE','NOVIEMBRE','DICIEMBRE'])[extract(month FROM c.fecha)::int],
       to_char(c.fecha, 'YYYY-MM'),
       extract(day FROM c.fecha),
       extract(isodow FROM c.fecha),
       (ARRAY['LUNES','MARTES','MIÉRCOLES','JUEVES','VIERNES','SÁBADO','DOMINGO'])[extract(isodow FROM c.fecha)::int],
       extract(isodow FROM c.fecha) >= 6,
       c.anio_epi,
       c.semana_epi,
       c.inicio_semana_epi,
       -- Temporada estacional de influenza de la DGE: semana 40 a semana 20 del año siguiente.
       CASE WHEN c.semana_epi >= 40 THEN 'ESTACIONAL ' || c.anio_epi || '-' || (c.anio_epi + 1)
            WHEN c.semana_epi <= 20 THEN 'ESTACIONAL ' || (c.anio_epi - 1) || '-' || c.anio_epi
            ELSE 'INTERESTACIONAL ' || c.anio_epi END,
       f.fecha IS NOT NULL,
       f.nombre,
       CASE WHEN f.fecha IS NOT NULL THEN 'FESTIVO OFICIAL'
            WHEN extract(isodow FROM c.fecha) >= 6 THEN 'FIN DE SEMANA'
            ELSE 'LABORAL' END
FROM calendario c
LEFT JOIN festivos f ON f.fecha = c.fecha
ORDER BY c.fecha;

CALL etl.registrar(9, 'Carga de dimensiones', 'dw.dim_tiempo', NULL, 'Generada: 730 días y 2 miembros especiales');

-- ---------------------------------------------------------------------------------------
-- 2. dim_ubicacion: el catálogo de municipios completo y los miembros inferidos
-- ---------------------------------------------------------------------------------------
INSERT INTO dw.dim_ubicacion (cve_entidad, nombre_entidad, abrev_entidad, cve_municipio, nombre_municipio,
                              cvegeo, tipo_miembro, es_entidad_federativa)
SELECT m.clave_entidad,
       e.entidad_federativa,
       e.abreviatura,
       m.clave_municipio,
       m.municipio,
       CASE WHEN m.municipio NOT IN ('NO ESPECIFICADO', 'NO APLICA', 'SE IGNORA')
            THEN lpad(m.clave_entidad::text, 2, '0') || lpad(m.clave_municipio::text, 3, '0') END,
       CASE WHEN m.municipio IN ('NO ESPECIFICADO', 'NO APLICA', 'SE IGNORA') THEN m.municipio
            ELSE 'MUNICIPIO' END,
       m.clave_entidad BETWEEN 1 AND 32
FROM public.cat_municipios m
JOIN public.cat_entidades e ON e.clave_entidad = m.clave_entidad
ORDER BY m.clave_entidad, m.clave_municipio;

-- Miembros inferidos: pares entidad-municipio que aparecen en los casos y no existen en
-- el catálogo. Se conservan el código y la entidad, para no borrar el dato ni inventar
-- un municipio. En estos datos es uno solo: Chihuahua (8) con municipio 113.
INSERT INTO dw.dim_ubicacion (cve_entidad, nombre_entidad, abrev_entidad, cve_municipio, nombre_municipio,
                              cvegeo, tipo_miembro, es_entidad_federativa)
SELECT DISTINCT h.entidad_res,
       coalesce(e.entidad_federativa, 'NO EXISTE EN EL CATÁLOGO'),
       e.abreviatura,
       h.municipio_res,
       'NO EXISTE EN EL CATÁLOGO (CLAVE ' || h.municipio_res || ')',
       NULL::char(5),
       'FUERA DE CATÁLOGO',
       h.entidad_res BETWEEN 1 AND 32
FROM public.covid_historica h
LEFT JOIN public.cat_entidades e ON e.clave_entidad = h.entidad_res
WHERE NOT EXISTS (SELECT 1 FROM dw.dim_ubicacion u
                  WHERE u.cve_entidad = h.entidad_res AND u.cve_municipio = h.municipio_res);

CALL etl.registrar(9, 'Carga de dimensiones', 'dw.dim_ubicacion', 'SELECT count(*) FROM public.cat_municipios', 'Catálogo completo más miembros inferidos');

-- ---------------------------------------------------------------------------------------
-- 3. dim_entidad: el catálogo de entidades (la versión resumida de dim_ubicacion)
-- ---------------------------------------------------------------------------------------
INSERT INTO dw.dim_entidad (cve_entidad, nombre_entidad, abrev_entidad, tipo_miembro, es_entidad_federativa)
SELECT e.clave_entidad,
       e.entidad_federativa,
       e.abreviatura,
       CASE WHEN e.clave_entidad BETWEEN 1 AND 32 THEN 'ENTIDAD FEDERATIVA'
            WHEN e.clave_entidad = 36 THEN 'PAÍS'
            ELSE e.entidad_federativa END,
       e.clave_entidad BETWEEN 1 AND 32
FROM public.cat_entidades e
ORDER BY e.clave_entidad;

INSERT INTO dw.dim_entidad (cve_entidad, nombre_entidad, abrev_entidad, tipo_miembro, es_entidad_federativa)
SELECT DISTINCT h.entidad_nac, 'NO EXISTE EN EL CATÁLOGO (CLAVE ' || h.entidad_nac || ')', NULL::varchar(3),
       'FUERA DE CATÁLOGO', false
FROM public.covid_historica h
WHERE NOT EXISTS (SELECT 1 FROM dw.dim_entidad d WHERE d.cve_entidad = h.entidad_nac);

CALL etl.registrar(9, 'Carga de dimensiones', 'dw.dim_entidad', 'SELECT count(*) FROM public.cat_entidades', 'Catálogo completo');

-- ---------------------------------------------------------------------------------------
-- 4. dim_unidad_medica: una fila por CLUES (2023) o por sector-entidad (2022)
-- ---------------------------------------------------------------------------------------
INSERT INTO dw.dim_unidad_medica (clues, es_unidad_identificada, es_clues_ficticia, cve_sector, nombre_sector,
                                  tipo_institucion, cve_entidad_um, nombre_entidad_um, abrev_entidad_um,
                                  cve_municipio_um, nombre_municipio_um, cvegeo_um, tipo_miembro)
SELECT u.clues,
       u.clues IS NOT NULL,
       coalesce(substr(u.clues, 3, 3) = 'XXX', false),
       u.sector,
       coalesce(s.sector, 'NO EXISTE EN EL CATÁLOGO'),
       -- Gómez-Dantés et al. (2011): instituciones de seguridad social (IMSS, ISSSTE,
       -- PEMEX, SEDENA, SEMAR), instituciones para la población sin seguridad social
       -- (SSa, servicios estatales, IMSS-Oportunidades, hoy IMSS-Bienestar) y sector
       -- privado. Lo que el artículo no enumera queda aparte.
       CASE WHEN u.sector IN (4, 6, 8, 10, 11) THEN 'SEGURIDAD SOCIAL'
            WHEN u.sector IN (3, 5, 12)       THEN 'SIN SEGURIDAD SOCIAL'
            WHEN u.sector = 9                 THEN 'PRIVADO'
            WHEN u.sector IN (1, 2, 7, 13)    THEN 'OTRAS INSTITUCIONES'
            ELSE 'NO ESPECIFICADO' END,
       u.entidad_um,
       coalesce(e.entidad_federativa, 'NO EXISTE EN EL CATÁLOGO'),
       e.abreviatura,
       u.municipio_um,
       CASE WHEN u.municipio_um IS NULL THEN 'NO DISPONIBLE EN EL EXTRACTO'
            ELSE coalesce(m.municipio, 'NO EXISTE EN EL CATÁLOGO (CLAVE ' || u.municipio_um || ')') END,
       CASE WHEN m.municipio IS NOT NULL AND m.municipio NOT IN ('NO ESPECIFICADO', 'NO APLICA', 'SE IGNORA')
            THEN lpad(u.entidad_um::text, 2, '0') || lpad(u.municipio_um::text, 3, '0') END,
       CASE WHEN u.clues IS NULL THEN 'UNIDAD NO IDENTIFICADA (EXTRACTO 2022)'
            ELSE 'UNIDAD IDENTIFICADA POR CLUES' END
FROM (SELECT DISTINCT clues, sector, entidad_um, municipio_um FROM public.covid_historica) u
LEFT JOIN public.cat_sector s     ON s.clave_sector = u.sector
LEFT JOIN public.cat_entidades e  ON e.clave_entidad = u.entidad_um
LEFT JOIN public.cat_municipios m ON m.clave_entidad = u.entidad_um AND m.clave_municipio = u.municipio_um
ORDER BY u.clues NULLS FIRST, u.sector, u.entidad_um;

CALL etl.registrar(9, 'Carga de dimensiones', 'dw.dim_unidad_medica', 'SELECT count(*) FROM (SELECT DISTINCT clues, sector, entidad_um, municipio_um FROM public.covid_historica) x');

-- ---------------------------------------------------------------------------------------
-- 5. dim_paciente: combinaciones observadas de los seis atributos demográficos
-- ---------------------------------------------------------------------------------------
INSERT INTO dw.dim_paciente (sexo, sexo_desc, embarazo, embarazo_desc, habla_lengua_indig, habla_lengua_indig_desc,
                             indigena, indigena_desc, nacionalidad, nacionalidad_desc, migrante, migrante_desc)
SELECT c.sexo,               coalesce(sx.sexo, 'VALOR NO VÁLIDO'),
       c.embarazo,           coalesce(s1.si_no, 'VALOR NO VÁLIDO'),
       c.habla_lengua_indig, coalesce(s2.si_no, 'VALOR NO VÁLIDO'),
       c.indigena,           coalesce(s3.si_no, 'VALOR NO VÁLIDO'),
       c.nacionalidad,       coalesce(n.nacionalidad, 'VALOR NO VÁLIDO'),
       c.migrante,           coalesce(s4.si_no, 'VALOR NO VÁLIDO')
FROM (SELECT DISTINCT sexo, embarazo, habla_lengua_indig, indigena, nacionalidad, migrante
      FROM public.covid_historica) c
LEFT JOIN public.cat_sexo sx         ON sx.clave_sexo = c.sexo
LEFT JOIN public.cat_si_no s1        ON s1.clave_si_no = c.embarazo
LEFT JOIN public.cat_si_no s2        ON s2.clave_si_no = c.habla_lengua_indig
LEFT JOIN public.cat_si_no s3        ON s3.clave_si_no = c.indigena
LEFT JOIN public.cat_nacionalidad n  ON n.clave_nacionalidad = c.nacionalidad
LEFT JOIN public.cat_si_no s4        ON s4.clave_si_no = c.migrante
ORDER BY c.sexo, c.embarazo, c.habla_lengua_indig, c.indigena, c.nacionalidad, c.migrante;

CALL etl.registrar(9, 'Carga de dimensiones', 'dw.dim_paciente', 'SELECT count(*) FROM (SELECT DISTINCT sexo, embarazo, habla_lengua_indig, indigena, nacionalidad, migrante FROM public.covid_historica) x');

-- ---------------------------------------------------------------------------------------
-- 6. dim_pais: cada texto distinto de los dos campos de país, normalizado
-- ---------------------------------------------------------------------------------------
INSERT INTO dw.dim_pais (pais_original, pais, tipo_valor, es_mexico, nota)
SELECT v.pais_original,
       coalesce(n.pais, v.pais_original),
       coalesce(n.tipo_valor, 'PAÍS O TERRITORIO'),
       v.pais_original = 'México',
       n.nota
FROM (SELECT pais_nacionalidad AS pais_original FROM public.covid_historica
      UNION
      SELECT pais_origen FROM public.covid_historica) v
LEFT JOIN public.cat_pais_normalizacion n ON n.pais_original = v.pais_original
ORDER BY v.pais_original;

CALL etl.registrar(9, 'Carga de dimensiones', 'dw.dim_pais', 'SELECT count(*) FROM (SELECT pais_nacionalidad FROM public.covid_historica UNION SELECT pais_origen FROM public.covid_historica) x');

-- ---------------------------------------------------------------------------------------
-- 7. dim_edad: una fila por edad observada
-- ---------------------------------------------------------------------------------------
INSERT INTO dw.dim_edad (id_edad, edad, quinquenio, grupo_decenal, grupo_etario, es_edad_valida, nota)
SELECT x.edad,
       x.edad,
       CASE WHEN x.edad >= 100 THEN '100+'
            ELSE lpad((x.edad / 5 * 5)::text, 2, '0') || '-' || lpad((x.edad / 5 * 5 + 4)::text, 2, '0') END,
       CASE WHEN x.edad >= 100 THEN '100+'
            ELSE lpad((x.edad / 10 * 10)::text, 2, '0') || '-' || lpad((x.edad / 10 * 10 + 9)::text, 2, '0') END,
       CASE WHEN x.edad < 18 THEN '0-17 (MENORES DE EDAD)'
            WHEN x.edad < 40 THEN '18-39'
            WHEN x.edad < 60 THEN '40-59'
            ELSE '60 Y MÁS (PERSONAS ADULTAS MAYORES)' END,
       x.edad < 122,
       CASE WHEN x.edad >= 122 THEN 'NACIMIENTO IMPLÍCITO EN 1900 O ANTES: FECHA POR OMISIÓN (PRÁCTICA 2)' END
FROM (SELECT DISTINCT edad FROM public.covid_historica) x
ORDER BY x.edad;

CALL etl.registrar(9, 'Carga de dimensiones', 'dw.dim_edad', 'SELECT count(*) FROM (SELECT DISTINCT edad FROM public.covid_historica) x');

-- ---------------------------------------------------------------------------------------
-- 8. dim_comorbilidad: combinaciones observadas de las 10 banderas
-- ---------------------------------------------------------------------------------------
INSERT INTO dw.dim_comorbilidad (diabetes, epoc, asma, inmusupr, hipertension, otra_com, cardiovascular, obesidad,
                                 renal_cronica, tabaquismo, num_comorbilidades, grupo_comorbilidades,
                                 tiene_comorbilidad, num_sin_dato, descripcion)
SELECT c.diabetes, c.epoc, c.asma, c.inmusupr, c.hipertension, c.otra_com, c.cardiovascular, c.obesidad,
       c.renal_cronica, c.tabaquismo,
       n.num,
       CASE n.num WHEN 0 THEN 'NINGUNA' WHEN 1 THEN 'UNA' WHEN 2 THEN 'DOS' ELSE 'TRES O MÁS' END,
       n.num > 0,
       (c.diabetes IN (97, 98, 99))::int + (c.epoc IN (97, 98, 99))::int + (c.asma IN (97, 98, 99))::int
         + (c.inmusupr IN (97, 98, 99))::int + (c.hipertension IN (97, 98, 99))::int
         + (c.otra_com IN (97, 98, 99))::int + (c.cardiovascular IN (97, 98, 99))::int
         + (c.obesidad IN (97, 98, 99))::int + (c.renal_cronica IN (97, 98, 99))::int
         + (c.tabaquismo IN (97, 98, 99))::int,
       coalesce(nullif(concat_ws(' + ',
           CASE WHEN c.diabetes = 1 THEN 'DIABETES' END,
           CASE WHEN c.epoc = 1 THEN 'EPOC' END,
           CASE WHEN c.asma = 1 THEN 'ASMA' END,
           CASE WHEN c.inmusupr = 1 THEN 'INMUNOSUPRESIÓN' END,
           CASE WHEN c.hipertension = 1 THEN 'HIPERTENSIÓN' END,
           CASE WHEN c.otra_com = 1 THEN 'OTRA' END,
           CASE WHEN c.cardiovascular = 1 THEN 'CARDIOVASCULAR' END,
           CASE WHEN c.obesidad = 1 THEN 'OBESIDAD' END,
           CASE WHEN c.renal_cronica = 1 THEN 'RENAL CRÓNICA' END,
           CASE WHEN c.tabaquismo = 1 THEN 'TABAQUISMO' END), ''), 'NINGUNA')
FROM (SELECT DISTINCT diabetes, epoc, asma, inmusupr, hipertension, otra_com, cardiovascular, obesidad,
                      renal_cronica, tabaquismo
      FROM public.covid_historica) c
CROSS JOIN LATERAL (
    SELECT (c.diabetes = 1)::int + (c.epoc = 1)::int + (c.asma = 1)::int + (c.inmusupr = 1)::int
         + (c.hipertension = 1)::int + (c.otra_com = 1)::int + (c.cardiovascular = 1)::int
         + (c.obesidad = 1)::int + (c.renal_cronica = 1)::int AS num
) n
ORDER BY n.num, c.diabetes, c.epoc, c.asma, c.inmusupr, c.hipertension, c.otra_com, c.cardiovascular,
         c.obesidad, c.renal_cronica, c.tabaquismo;

CALL etl.registrar(9, 'Carga de dimensiones', 'dw.dim_comorbilidad', 'SELECT count(*) FROM (SELECT DISTINCT diabetes, epoc, asma, inmusupr, hipertension, otra_com, cardiovascular, obesidad, renal_cronica, tabaquismo FROM public.covid_historica) x');

-- ---------------------------------------------------------------------------------------
-- 9. dim_atencion: origen, tipo de paciente, neumonía, intubación y UCI
-- ---------------------------------------------------------------------------------------
INSERT INTO dw.dim_atencion (origen, origen_desc, tipo_paciente, tipo_paciente_desc, neumonia, neumonia_desc,
                             intubado, intubado_desc, uci, uci_desc, nivel_gravedad, gravedad_desc)
SELECT c.origen,        coalesce(o.origen, 'VALOR NO VÁLIDO'),
       c.tipo_paciente, coalesce(t.tipo_paciente, 'VALOR NO VÁLIDO'),
       c.neumonia,      coalesce(s1.si_no, 'VALOR NO VÁLIDO'),
       c.intubado,      coalesce(s2.si_no, 'VALOR NO VÁLIDO'),
       c.uci,           coalesce(s3.si_no, 'VALOR NO VÁLIDO'),
       g.nivel,
       CASE g.nivel WHEN 1 THEN 'AMBULATORIO'
                    WHEN 2 THEN 'HOSPITALIZADO (SIN UCI NI INTUBACIÓN REGISTRADAS)'
                    WHEN 3 THEN 'HOSPITALIZADO CON UCI O INTUBACIÓN'
                    ELSE 'NO ESPECIFICADO' END
FROM (SELECT DISTINCT origen, tipo_paciente, neumonia, intubado, uci FROM public.covid_historica) c
CROSS JOIN LATERAL (
    SELECT CASE WHEN c.tipo_paciente = 1 THEN 1
                WHEN c.tipo_paciente = 2 AND (c.uci = 1 OR c.intubado = 1) THEN 3
                WHEN c.tipo_paciente = 2 THEN 2
                ELSE 9 END AS nivel
) g
LEFT JOIN public.cat_origen o         ON o.clave_origen = c.origen
LEFT JOIN public.cat_tipo_paciente t  ON t.clave_tipo_paciente = c.tipo_paciente
LEFT JOIN public.cat_si_no s1         ON s1.clave_si_no = c.neumonia
LEFT JOIN public.cat_si_no s2         ON s2.clave_si_no = c.intubado
LEFT JOIN public.cat_si_no s3         ON s3.clave_si_no = c.uci
ORDER BY g.nivel, c.origen, c.tipo_paciente, c.neumonia, c.intubado, c.uci;

CALL etl.registrar(9, 'Carga de dimensiones', 'dw.dim_atencion', 'SELECT count(*) FROM (SELECT DISTINCT origen, tipo_paciente, neumonia, intubado, uci FROM public.covid_historica) x');

-- ---------------------------------------------------------------------------------------
-- 10. dim_diagnostico: contacto, muestras, resultados y clasificación final
-- ---------------------------------------------------------------------------------------
INSERT INTO dw.dim_diagnostico (otro_caso, otro_caso_desc, toma_muestra_lab, toma_muestra_lab_desc, resultado_lab,
                                resultado_lab_desc, toma_muestra_antigeno, toma_muestra_antigeno_desc,
                                resultado_antigeno, resultado_antigeno_desc, clasificacion_final,
                                clasificacion_final_desc, grupo_clasificacion, es_confirmado)
SELECT c.otro_caso,             coalesce(s1.si_no, 'VALOR NO VÁLIDO'),
       c.toma_muestra_lab,      coalesce(s2.si_no, 'VALOR NO VÁLIDO'),
       c.resultado_lab,         coalesce(rl.resultado_lab, 'VALOR NO VÁLIDO'),
       c.toma_muestra_antigeno, coalesce(s3.si_no, 'VALOR NO VÁLIDO'),
       c.resultado_antigeno,    coalesce(ra.resultado_antigeno, 'VALOR NO VÁLIDO'),
       c.clasificacion_final,   coalesce(cf.clasificacion, 'VALOR NO VÁLIDO'),
       CASE WHEN c.clasificacion_final IN (1, 2, 3) THEN 'CONFIRMADO'
            WHEN c.clasificacion_final = 6 THEN 'SOSPECHOSO'
            WHEN c.clasificacion_final = 7 THEN 'NEGATIVO'
            WHEN c.clasificacion_final IN (4, 5) THEN 'NO CONCLUYENTE'
            ELSE 'VALOR NO VÁLIDO' END,
       c.clasificacion_final IN (1, 2, 3)
FROM (SELECT DISTINCT otro_caso, toma_muestra_lab, resultado_lab, toma_muestra_antigeno, resultado_antigeno,
                      clasificacion_final
      FROM public.covid_historica) c
LEFT JOIN public.cat_si_no s1                ON s1.clave_si_no = c.otro_caso
LEFT JOIN public.cat_si_no s2                ON s2.clave_si_no = c.toma_muestra_lab
LEFT JOIN public.cat_resultado_lab rl        ON rl.clave_resultado_lab = c.resultado_lab
LEFT JOIN public.cat_si_no s3                ON s3.clave_si_no = c.toma_muestra_antigeno
LEFT JOIN public.cat_resultado_antigeno ra   ON ra.clave_resultado_antigeno = c.resultado_antigeno
LEFT JOIN public.cat_clasificacion_final cf  ON cf.clave_clasificacion = c.clasificacion_final
ORDER BY c.clasificacion_final, c.otro_caso, c.toma_muestra_lab, c.resultado_lab, c.toma_muestra_antigeno,
         c.resultado_antigeno;

CALL etl.registrar(9, 'Carga de dimensiones', 'dw.dim_diagnostico', 'SELECT count(*) FROM (SELECT DISTINCT otro_caso, toma_muestra_lab, resultado_lab, toma_muestra_antigeno, resultado_antigeno, clasificacion_final FROM public.covid_historica) x');

-- ---------------------------------------------------------------------------------------
-- 11. dim_extracto: un renglón por archivo. FECHA_ACTUALIZACION tiene que ser única por
--     archivo; si no lo fuera, el min() escondería un problema, así que se comprueba.
-- ---------------------------------------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM public.covid_historica GROUP BY archivo_origen
               HAVING count(DISTINCT fecha_actualizacion) > 1) THEN
        RAISE EXCEPTION 'FECHA_ACTUALIZACION no depende solo del archivo: revisar antes de usar dim_extracto';
    END IF;
END $$;

-- Lo que no está en covid_historica (filas del CSV, columnas, periodo) viene de la
-- inspección de la Práctica 2 (Tablas 2 y 13 del reporte).
-- Según cómo se haya cargado la P2, el archivo de 2022 aparece con o sin la etiqueta
-- " (reparado)". Se compara sin ella, pero se guarda el nombre tal como está en el origen:
-- corregirlo aquí rompería la reconstrucción de v06 (ver la bitácora, error 1).
INSERT INTO dw.dim_extracto (archivo_origen, fecha_actualizacion, anio_nominal, columnas_csv, trae_unidad_y_resultado,
                             filas_csv, casos_unicos, fecha_sintomas_min, fecha_sintomas_max, periodo_efectivo)
SELECT h.archivo_origen,
       min(h.fecha_actualizacion),
       substring(h.archivo_origen FROM '(20[0-9]{2})\.csv')::smallint,   -- el año pegado a ".csv"
       p.columnas_csv,
       p.columnas_csv = 44,
       p.filas_csv,
       count(*),
       min(h.fecha_sintomas),
       max(h.fecha_sintomas),
       p.periodo_efectivo
FROM public.covid_historica h
JOIN (VALUES ('muestra200k_COVID19MEXICOLOC2022.csv', 41::smallint, 3999996, 'ENERO A JUNIO DE 2022 (99.99% DE LOS CASOS)'),
             ('muestra100k_COVID19MEXICOLOC2023.csv', 44::smallint,   99999, 'ENERO DE 2023 (99.91% DE LOS CASOS)'))
     AS p (archivo_origen, columnas_csv, filas_csv, periodo_efectivo)
     ON p.archivo_origen = replace(h.archivo_origen, ' (reparado)', '')
GROUP BY h.archivo_origen, p.columnas_csv, p.filas_csv, p.periodo_efectivo
ORDER BY 3;

CALL etl.registrar(9, 'Carga de dimensiones', 'dw.dim_extracto', 'SELECT count(*) FROM (SELECT DISTINCT archivo_origen FROM public.covid_historica) x');

-- ---------------------------------------------------------------------------------------
-- 12. dim_calidad: las reglas de la Práctica 2 como banderas. La vista calcula las
--     banderas de cada caso; la dimensión guarda las combinaciones observadas, y la
--     carga de hechos vuelve a usar la misma vista para no repetir la lógica.
-- ---------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW etl.v_banderas_calidad AS
SELECT h.id_registro,
       h.edad >= 122                                                        AS edad_no_valida,
       coalesce(h.fecha_def < h.fecha_ingreso, false)
         OR coalesce(h.fecha_def < h.fecha_sintomas, false)
         OR coalesce(h.fecha_resultado < h.fecha_ingreso, false)
         OR h.fecha_sintomas > h.fecha_ingreso                              AS fechas_en_desorden,
       h.fecha_ingreso - h.fecha_sintomas > 10                              AS sintomas_mas_de_10_dias,
       h.fecha_ingreso - h.fecha_sintomas > 31                              AS demora_extrema,
       h.embarazo = 1 AND (h.edad < 10 OR h.edad > 55)                      AS embarazo_edad_atipica,
       h.tabaquismo = 1 AND h.edad < 10                                     AS tabaquismo_menor_10,
       NOT EXISTS (SELECT 1 FROM public.cat_municipios m
                   WHERE m.clave_entidad = h.entidad_res AND m.clave_municipio = h.municipio_res)
                                                                            AS municipio_fuera_catalogo,
       (h.nacionalidad = 2 AND h.entidad_nac <> 97)
         OR (h.nacionalidad = 1 AND h.entidad_nac NOT BETWEEN 1 AND 32)    AS entidad_nac_inconsistente,
       coalesce(substr(h.clues, 3, 3) = 'XXX', false)                       AS clues_ficticia,
       h.fecha_def IS NOT NULL AND h.tipo_paciente = 1                      AS defuncion_ambulatoria,
       h.intubado = 1 AND h.uci = 2                                         AS intubado_sin_uci
FROM public.covid_historica h;

COMMENT ON VIEW etl.v_banderas_calidad IS 'Banderas de calidad de cada caso (reglas de la Práctica 2). Fuente de dw.dim_calidad.';

INSERT INTO dw.dim_calidad (edad_no_valida, fechas_en_desorden, sintomas_mas_de_10_dias, demora_extrema,
                            embarazo_edad_atipica, tabaquismo_menor_10, municipio_fuera_catalogo,
                            entidad_nac_inconsistente, clues_ficticia, defuncion_ambulatoria, intubado_sin_uci,
                            num_banderas, nivel_maximo, descripcion)
SELECT b.*,
       b.edad_no_valida::int + b.fechas_en_desorden::int + b.sintomas_mas_de_10_dias::int + b.demora_extrema::int
         + b.embarazo_edad_atipica::int + b.tabaquismo_menor_10::int + b.municipio_fuera_catalogo::int
         + b.entidad_nac_inconsistente::int + b.clues_ficticia::int + b.defuncion_ambulatoria::int
         + b.intubado_sin_uci::int,
       CASE WHEN b.edad_no_valida OR b.fechas_en_desorden OR b.municipio_fuera_catalogo
                 OR b.entidad_nac_inconsistente OR b.clues_ficticia THEN 'ERROR'
            WHEN b.sintomas_mas_de_10_dias OR b.demora_extrema OR b.embarazo_edad_atipica
                 OR b.tabaquismo_menor_10 OR b.defuncion_ambulatoria OR b.intubado_sin_uci THEN 'POR REVISAR'
            ELSE 'SIN BANDERAS' END,
       coalesce(nullif(concat_ws(', ',
           CASE WHEN b.edad_no_valida THEN 'EDAD NO VÁLIDA' END,
           CASE WHEN b.fechas_en_desorden THEN 'FECHAS EN DESORDEN' END,
           CASE WHEN b.sintomas_mas_de_10_dias THEN 'SÍNTOMAS A MÁS DE 10 DÍAS' END,
           CASE WHEN b.demora_extrema THEN 'DEMORA EXTREMA' END,
           CASE WHEN b.embarazo_edad_atipica THEN 'EMBARAZO EN EDAD ATÍPICA' END,
           CASE WHEN b.tabaquismo_menor_10 THEN 'TABAQUISMO EN MENOR DE 10' END,
           CASE WHEN b.municipio_fuera_catalogo THEN 'MUNICIPIO FUERA DE CATÁLOGO' END,
           CASE WHEN b.entidad_nac_inconsistente THEN 'ENTIDAD DE NACIMIENTO INCONSISTENTE' END,
           CASE WHEN b.clues_ficticia THEN 'CLUES FICTICIA' END,
           CASE WHEN b.defuncion_ambulatoria THEN 'DEFUNCIÓN AMBULATORIA' END,
           CASE WHEN b.intubado_sin_uci THEN 'INTUBADO SIN UCI' END), ''), 'SIN BANDERAS')
FROM (SELECT DISTINCT edad_no_valida, fechas_en_desorden, sintomas_mas_de_10_dias, demora_extrema,
                      embarazo_edad_atipica, tabaquismo_menor_10, municipio_fuera_catalogo,
                      entidad_nac_inconsistente, clues_ficticia, defuncion_ambulatoria, intubado_sin_uci
      FROM etl.v_banderas_calidad) b
ORDER BY 12, 13;

CALL etl.registrar(9, 'Carga de dimensiones', 'dw.dim_calidad', 'SELECT count(*) FROM (SELECT DISTINCT edad_no_valida, fechas_en_desorden, sintomas_mas_de_10_dias, demora_extrema, embarazo_edad_atipica, tabaquismo_menor_10, municipio_fuera_catalogo, entidad_nac_inconsistente, clues_ficticia, defuncion_ambulatoria, intubado_sin_uci FROM etl.v_banderas_calidad) x');

COMMIT;

-- VACUUM (ANALYZE) y no solo ANALYZE: así el mapa de visibilidad y el de espacio libre se
-- crean ahora y no cuando le toque a autovacuum (ver la nota en 02_llaves_foraneas.sql).
VACUUM (ANALYZE) dw.dim_tiempo, dw.dim_ubicacion, dw.dim_entidad, dw.dim_unidad_medica, dw.dim_paciente,
       dw.dim_pais, dw.dim_edad, dw.dim_comorbilidad, dw.dim_atencion, dw.dim_diagnostico, dw.dim_extracto,
       dw.dim_calidad;

-- Filas por dimensión
SELECT 'dim_tiempo' AS dimension, count(*) AS filas FROM dw.dim_tiempo
UNION ALL SELECT 'dim_ubicacion', count(*) FROM dw.dim_ubicacion
UNION ALL SELECT 'dim_entidad', count(*) FROM dw.dim_entidad
UNION ALL SELECT 'dim_unidad_medica', count(*) FROM dw.dim_unidad_medica
UNION ALL SELECT 'dim_paciente', count(*) FROM dw.dim_paciente
UNION ALL SELECT 'dim_pais', count(*) FROM dw.dim_pais
UNION ALL SELECT 'dim_edad', count(*) FROM dw.dim_edad
UNION ALL SELECT 'dim_comorbilidad', count(*) FROM dw.dim_comorbilidad
UNION ALL SELECT 'dim_atencion', count(*) FROM dw.dim_atencion
UNION ALL SELECT 'dim_diagnostico', count(*) FROM dw.dim_diagnostico
UNION ALL SELECT 'dim_extracto', count(*) FROM dw.dim_extracto
UNION ALL SELECT 'dim_calidad', count(*) FROM dw.dim_calidad;
