-- Práctica 03, Equipo 3 (aportación de Santiago): prueba de carga del modelo.
-- Paso 11: la tabla de hechos, una fila por caso de covid_historica.
--
-- Cada columna de covid_historica se traduce a la llave de su dimensión buscando la
-- combinación de códigos (la "llave natural") en la dimensión ya cargada.
--
-- Por qué LEFT JOIN y no JOIN: si una combinación no encontrara su fila en una dimensión,
-- un JOIN normal descartaría el caso EN SILENCIO y la tabla de hechos tendría menos filas
-- sin ningún error. Con LEFT JOIN la llave queda NULL, la columna es NOT NULL y la carga
-- entera falla con un mensaje que dice cuál llave faltó. Preferimos que truene a que
-- pierda casos.
--
-- Ejecutar:  psql -d covid_p3 -v ON_ERROR_STOP=1 -f sql/prueba_carga/11_hechos.sql

-- Los scripts están en UTF-8. En Windows, psql suele leerlos como WIN1252 y los acentos
-- detienen la carga (character with byte sequence 0x81 in encoding "WIN1252"...).
-- Esta línea lo evita: el resto del archivo se interpreta como UTF-8.
SET client_encoding = 'UTF8';

\timing on
BEGIN;

-- Carga masiva sin llaves foráneas ni índices secundarios. Si quedaron de una corrida
-- anterior, se quitan aquí; 02_llaves_foraneas.sql los vuelve a declarar al final.
-- Medido en covid_p3 (codigo/probar_reproducibilidad.sh): con las 16 llaves y los
-- 3 índices puestos, esta carga tardó 102 s; sin ellos, 23 s.
ALTER TABLE dw.fact_casos_covid
    DROP CONSTRAINT IF EXISTS fk_fact_fecha_sintomas,
    DROP CONSTRAINT IF EXISTS fk_fact_fecha_ingreso,
    DROP CONSTRAINT IF EXISTS fk_fact_fecha_resultado,
    DROP CONSTRAINT IF EXISTS fk_fact_fecha_defuncion,
    DROP CONSTRAINT IF EXISTS fk_fact_ubicacion_residencia,
    DROP CONSTRAINT IF EXISTS fk_fact_entidad_nacimiento,
    DROP CONSTRAINT IF EXISTS fk_fact_unidad_medica,
    DROP CONSTRAINT IF EXISTS fk_fact_paciente,
    DROP CONSTRAINT IF EXISTS fk_fact_pais_nacionalidad,
    DROP CONSTRAINT IF EXISTS fk_fact_pais_origen,
    DROP CONSTRAINT IF EXISTS fk_fact_edad,
    DROP CONSTRAINT IF EXISTS fk_fact_comorbilidad,
    DROP CONSTRAINT IF EXISTS fk_fact_atencion,
    DROP CONSTRAINT IF EXISTS fk_fact_diagnostico,
    DROP CONSTRAINT IF EXISTS fk_fact_extracto,
    DROP CONSTRAINT IF EXISTS fk_fact_calidad;
DROP INDEX IF EXISTS dw.ix_fact_fecha_sintomas;
DROP INDEX IF EXISTS dw.ix_fact_fecha_ingreso;
DROP INDEX IF EXISTS dw.ix_fact_ubicacion;

TRUNCATE dw.fact_casos_covid RESTART IDENTITY;

INSERT INTO dw.fact_casos_covid (
    id_registro,
    id_fecha_sintomas, id_fecha_ingreso, id_fecha_resultado, id_fecha_defuncion,
    id_ubicacion_residencia, id_entidad_nacimiento, id_unidad_medica,
    id_paciente, id_pais_nacionalidad, id_pais_origen, id_edad,
    id_comorbilidad, id_atencion, id_diagnostico, id_extracto, id_calidad,
    casos, confirmados, hospitalizados, ingresos_uci, intubados, con_neumonia, defunciones,
    edad_anios, dias_sintomas_a_ingreso, dias_ingreso_a_resultado, dias_ingreso_a_defuncion
)
SELECT
    h.id_registro,
    -- Fechas: la llave de dim_tiempo es la fecha escrita como AAAAMMDD, así que no hace
    -- falta buscarla. Los huecos van a los miembros especiales, nunca a NULL.
    to_char(h.fecha_sintomas, 'YYYYMMDD')::int,
    to_char(h.fecha_ingreso, 'YYYYMMDD')::int,
    CASE WHEN h.fecha_resultado IS NOT NULL THEN to_char(h.fecha_resultado, 'YYYYMMDD')::int
         WHEN NOT x.trae_unidad_y_resultado THEN -1          -- el CSV de 2022 no trae la columna
         ELSE -2 END,                                         -- 2023 con 9999-99-99: no hubo resultado
    coalesce(to_char(h.fecha_def, 'YYYYMMDD')::int, -2),     -- sin defunción
    u.id_ubicacion,
    en.id_entidad,
    um.id_unidad_medica,
    p.id_paciente,
    pn.id_pais,
    po.id_pais,
    h.edad,                                                   -- la llave de dim_edad es la edad
    c.id_comorbilidad,
    a.id_atencion,
    d.id_diagnostico,
    x.id_extracto,
    q.id_calidad,
    -- Medidas aditivas (0/1)
    1,
    d.es_confirmado::int,
    (h.tipo_paciente = 2)::int,
    (h.uci = 1)::int,
    (h.intubado = 1)::int,
    (h.neumonia = 1)::int,
    (h.fecha_def IS NOT NULL)::int,
    -- Medidas no aditivas: lo imposible queda NULL (la fila conserva el valor original en
    -- sus llaves: id_edad = 122, las fechas en dim_tiempo)
    CASE WHEN de.es_edad_valida THEN h.edad END,
    CASE WHEN h.fecha_ingreso >= h.fecha_sintomas THEN h.fecha_ingreso - h.fecha_sintomas END,
    CASE WHEN h.fecha_resultado >= h.fecha_ingreso THEN h.fecha_resultado - h.fecha_ingreso END,
    CASE WHEN h.fecha_def >= h.fecha_ingreso THEN h.fecha_def - h.fecha_ingreso END
FROM public.covid_historica h
LEFT JOIN etl.v_banderas_calidad b ON b.id_registro = h.id_registro
LEFT JOIN dw.dim_extracto x        ON x.archivo_origen = h.archivo_origen
LEFT JOIN dw.dim_ubicacion u       ON u.cve_entidad = h.entidad_res AND u.cve_municipio = h.municipio_res
LEFT JOIN dw.dim_entidad en        ON en.cve_entidad = h.entidad_nac
-- CLUES es NULL en todo 2022. NULL = NULL no es verdadero en SQL, así que se compara con
-- coalesce: ambos lados quedan en '' y la CLUES entra en la condición de unión.
-- IS NOT DISTINCT FROM da el mismo resultado, pero no sirve como condición de unión:
-- PostgreSQL une solo por sector y entidad y revisa la CLUES fila por fila como filtro
-- (medido en covid_p3: 1.85 s contra 0.30 s con coalesce, para los 2,099,997 casos).
LEFT JOIN dw.dim_unidad_medica um  ON coalesce(um.clues, '') = coalesce(h.clues, '')
                                  AND um.cve_sector = h.sector
                                  AND um.cve_entidad_um = h.entidad_um
LEFT JOIN dw.dim_paciente p        ON (p.sexo, p.embarazo, p.habla_lengua_indig, p.indigena, p.nacionalidad, p.migrante)
                                    = (h.sexo, h.embarazo, h.habla_lengua_indig, h.indigena, h.nacionalidad, h.migrante)
LEFT JOIN dw.dim_pais pn           ON pn.pais_original = h.pais_nacionalidad
LEFT JOIN dw.dim_pais po           ON po.pais_original = h.pais_origen
LEFT JOIN dw.dim_edad de           ON de.id_edad = h.edad
LEFT JOIN dw.dim_comorbilidad c    ON (c.diabetes, c.epoc, c.asma, c.inmusupr, c.hipertension, c.otra_com,
                                       c.cardiovascular, c.obesidad, c.renal_cronica, c.tabaquismo)
                                    = (h.diabetes, h.epoc, h.asma, h.inmusupr, h.hipertension, h.otra_com,
                                       h.cardiovascular, h.obesidad, h.renal_cronica, h.tabaquismo)
LEFT JOIN dw.dim_atencion a        ON (a.origen, a.tipo_paciente, a.neumonia, a.intubado, a.uci)
                                    = (h.origen, h.tipo_paciente, h.neumonia, h.intubado, h.uci)
LEFT JOIN dw.dim_diagnostico d     ON (d.otro_caso, d.toma_muestra_lab, d.resultado_lab, d.toma_muestra_antigeno,
                                       d.resultado_antigeno, d.clasificacion_final)
                                    = (h.otro_caso, h.toma_muestra_lab, h.resultado_lab, h.toma_muestra_antigeno,
                                       h.resultado_antigeno, h.clasificacion_final)
LEFT JOIN dw.dim_calidad q         ON (q.edad_no_valida, q.fechas_en_desorden, q.sintomas_mas_de_10_dias,
                                       q.demora_extrema, q.embarazo_edad_atipica, q.tabaquismo_menor_10,
                                       q.municipio_fuera_catalogo, q.entidad_nac_inconsistente, q.clues_ficticia,
                                       q.defuncion_ambulatoria, q.intubado_sin_uci)
                                    = (b.edad_no_valida, b.fechas_en_desorden, b.sintomas_mas_de_10_dias,
                                       b.demora_extrema, b.embarazo_edad_atipica, b.tabaquismo_menor_10,
                                       b.municipio_fuera_catalogo, b.entidad_nac_inconsistente, b.clues_ficticia,
                                       b.defuncion_ambulatoria, b.intubado_sin_uci)
ORDER BY h.fecha_sintomas, h.id_registro;

COMMIT;

ANALYZE dw.fact_casos_covid;

SELECT count(*) AS filas_hechos,
       (SELECT count(*) FROM public.covid_historica) AS filas_covid_historica
FROM dw.fact_casos_covid;
