-- Práctica 03, Equipo 3 (aportación de Santiago)
-- Paso 0: los 11 catálogos oficiales (201128 Catalogos.xlsx) como tablas.
--
-- No borra ni vacía nada. Crea cada tabla solo si no existe y la llena solo si está
-- vacía. Así se puede correr en la base del equipo, donde cat_entidades, cat_municipios
-- y cat_sector ya existen por el 06_catalogos.sql de la Práctica 2 y la vista
-- v_anomalias depende de cat_municipios (un DROP TABLE fallaría ahí). También se puede
-- correr dos veces sin duplicar filas.
--
-- Las tres tablas del equipo llevan exactamente sus nombres y columnas (claves
-- smallint). Las otras ocho siguen el mismo patrón: clave_<catálogo> y la descripción.
-- Los CSV salen de scripts/exportar_catalogos.py, que normaliza espacios y saltos de
-- línea del Excel (evidencias/catalogos_normalizacion.csv). paises_normalizacion.csv es
-- del equipo: corrige la escritura de PAIS_NACIONALIDAD y PAIS_ORIGEN sin borrar el
-- valor original.
--
-- Usa \copy, \gset e \if, que son de psql (no del Query Tool de pgAdmin). Ejecutar
-- parado en la carpeta raíz (aportacion_santiago/ o la del paquete), porque las rutas de
-- \copy son relativas a ella. Lo normal es correrlo desde cargar_modelo.sql; para
-- correrlo solo:
--   psql -d covid_p3 -v ON_ERROR_STOP=1 -f sql/modelo/00_catalogos.sql

-- Los scripts están en UTF-8. En Windows, psql suele leerlos como WIN1252 y los acentos
-- detienen la carga (character with byte sequence 0x81 in encoding "WIN1252"...).
-- Esta línea lo evita: el resto del archivo se interpreta como UTF-8.
SET client_encoding = 'UTF8';

CREATE TABLE IF NOT EXISTS public.cat_entidades (
    clave_entidad       smallint PRIMARY KEY,
    entidad_federativa  text NOT NULL,
    abreviatura         text
);

CREATE TABLE IF NOT EXISTS public.cat_municipios (
    clave_entidad   smallint NOT NULL REFERENCES public.cat_entidades (clave_entidad),
    clave_municipio smallint NOT NULL,
    municipio       text NOT NULL,
    PRIMARY KEY (clave_entidad, clave_municipio)
);

CREATE TABLE IF NOT EXISTS public.cat_sector              (clave_sector smallint PRIMARY KEY, sector text NOT NULL);
CREATE TABLE IF NOT EXISTS public.cat_origen              (clave_origen smallint PRIMARY KEY, origen text NOT NULL);
CREATE TABLE IF NOT EXISTS public.cat_sexo                (clave_sexo smallint PRIMARY KEY, sexo text NOT NULL);
CREATE TABLE IF NOT EXISTS public.cat_tipo_paciente       (clave_tipo_paciente smallint PRIMARY KEY, tipo_paciente text NOT NULL);
CREATE TABLE IF NOT EXISTS public.cat_si_no               (clave_si_no smallint PRIMARY KEY, si_no text NOT NULL);
CREATE TABLE IF NOT EXISTS public.cat_nacionalidad        (clave_nacionalidad smallint PRIMARY KEY, nacionalidad text NOT NULL);
CREATE TABLE IF NOT EXISTS public.cat_resultado_lab       (clave_resultado_lab smallint PRIMARY KEY, resultado_lab text NOT NULL);
CREATE TABLE IF NOT EXISTS public.cat_resultado_antigeno  (clave_resultado_antigeno smallint PRIMARY KEY, resultado_antigeno text NOT NULL);
CREATE TABLE IF NOT EXISTS public.cat_clasificacion_final (clave_clasificacion smallint PRIMARY KEY, clasificacion text NOT NULL, descripcion text);

CREATE TABLE IF NOT EXISTS public.cat_pais_normalizacion (
    pais_original text PRIMARY KEY,   -- el texto tal como viene en covid_historica
    pais          text NOT NULL,      -- nombre corregido o etiqueta de la categoría
    tipo_valor    text NOT NULL,      -- PAÍS O TERRITORIO, AGRUPACIÓN, NO VIGENTE, NO ES PAÍS, GENÉRICO, DESCONOCIDO, NO APLICA
    nota          text
);

-- Cada bloque: ¿la tabla está vacía? (\gset guarda la respuesta en la variable :vacia);
-- solo entonces se carga. El CSV de municipios trae (clave_municipio, municipio,
-- clave_entidad), el orden de la hoja de Excel.
SELECT NOT EXISTS (SELECT 1 FROM public.cat_entidades) AS vacia \gset
\if :vacia
\copy public.cat_entidades (clave_entidad, entidad_federativa, abreviatura) FROM 'catalogos/cat_entidades.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\endif
SELECT NOT EXISTS (SELECT 1 FROM public.cat_municipios) AS vacia \gset
\if :vacia
\copy public.cat_municipios (clave_municipio, municipio, clave_entidad) FROM 'catalogos/cat_municipios.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\endif
SELECT NOT EXISTS (SELECT 1 FROM public.cat_sector) AS vacia \gset
\if :vacia
\copy public.cat_sector FROM 'catalogos/cat_sector.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\endif
SELECT NOT EXISTS (SELECT 1 FROM public.cat_origen) AS vacia \gset
\if :vacia
\copy public.cat_origen FROM 'catalogos/cat_origen.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\endif
SELECT NOT EXISTS (SELECT 1 FROM public.cat_sexo) AS vacia \gset
\if :vacia
\copy public.cat_sexo FROM 'catalogos/cat_sexo.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\endif
SELECT NOT EXISTS (SELECT 1 FROM public.cat_tipo_paciente) AS vacia \gset
\if :vacia
\copy public.cat_tipo_paciente FROM 'catalogos/cat_tipo_paciente.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\endif
SELECT NOT EXISTS (SELECT 1 FROM public.cat_si_no) AS vacia \gset
\if :vacia
\copy public.cat_si_no FROM 'catalogos/cat_si_no.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\endif
SELECT NOT EXISTS (SELECT 1 FROM public.cat_nacionalidad) AS vacia \gset
\if :vacia
\copy public.cat_nacionalidad FROM 'catalogos/cat_nacionalidad.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\endif
SELECT NOT EXISTS (SELECT 1 FROM public.cat_resultado_lab) AS vacia \gset
\if :vacia
\copy public.cat_resultado_lab FROM 'catalogos/cat_resultado_lab.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\endif
SELECT NOT EXISTS (SELECT 1 FROM public.cat_resultado_antigeno) AS vacia \gset
\if :vacia
\copy public.cat_resultado_antigeno FROM 'catalogos/cat_resultado_antigeno.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\endif
SELECT NOT EXISTS (SELECT 1 FROM public.cat_clasificacion_final) AS vacia \gset
\if :vacia
\copy public.cat_clasificacion_final FROM 'catalogos/cat_clasificacion_final.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\endif
SELECT NOT EXISTS (SELECT 1 FROM public.cat_pais_normalizacion) AS vacia \gset
\if :vacia
\copy public.cat_pais_normalizacion FROM 'catalogos/paises_normalizacion.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\endif

-- Verificación (esperado: 36, 2501, 14, 3, 3, 3, 5, 3, 5, 3, 7 y 18):
SELECT 'cat_entidades' AS catalogo, count(*) AS filas FROM public.cat_entidades
UNION ALL SELECT 'cat_municipios', count(*) FROM public.cat_municipios
UNION ALL SELECT 'cat_sector', count(*) FROM public.cat_sector
UNION ALL SELECT 'cat_origen', count(*) FROM public.cat_origen
UNION ALL SELECT 'cat_sexo', count(*) FROM public.cat_sexo
UNION ALL SELECT 'cat_tipo_paciente', count(*) FROM public.cat_tipo_paciente
UNION ALL SELECT 'cat_si_no', count(*) FROM public.cat_si_no
UNION ALL SELECT 'cat_nacionalidad', count(*) FROM public.cat_nacionalidad
UNION ALL SELECT 'cat_resultado_lab', count(*) FROM public.cat_resultado_lab
UNION ALL SELECT 'cat_resultado_antigeno', count(*) FROM public.cat_resultado_antigeno
UNION ALL SELECT 'cat_clasificacion_final', count(*) FROM public.cat_clasificacion_final
UNION ALL SELECT 'cat_pais_normalizacion', count(*) FROM public.cat_pais_normalizacion;
