-- Práctica 02, Equipo 3. Aportación de Santiago (Arquitecto).
-- Prueba: ¿qué pasa con las conversiones de sql/04_tipado.sql si llega un valor sucio?
-- Se usan valores de una tabla (no literales), porque PostgreSQL evalúa un literal como
-- 'N/A'::smallint al analizar la consulta, antes de que el CASE decida nada.
\set ON_ERROR_STOP 0
-- Los scripts están en UTF-8. En Windows, psql suele leerlos como WIN1252 y los acentos se
-- guardan mal o detienen la carga; con esta línea el resto del archivo se lee como UTF-8.
SET client_encoding = 'UTF8';
CREATE TEMP TABLE valores_sucios (valor text);
INSERT INTO valores_sucios VALUES ('12'), (E'\t99'), ('N/A'), ('2023-02-30'), ('9999-99-99'), ('2023-02-28');

\echo '--- 1. Cast numérico de sql/04 (NULLIF + btrim + ::smallint) sobre un valor no numérico'
SELECT valor, NULLIF(btrim(valor), '')::smallint AS convertido
FROM valores_sucios WHERE valor IN ('12', E'\t99', 'N/A');

\echo '--- 2. Conversión de fechas de sql/04 (regex + ::date) sobre una fecha imposible'
SELECT valor, CASE WHEN valor ~ '^\d{4}-\d{2}-\d{2}$' AND valor <> '9999-99-99'
                   THEN valor::date END AS convertido
FROM valores_sucios WHERE valor IN ('2023-02-28', '2023-02-30', '9999-99-99');

\echo '--- 3. Las mismas conversiones con pg_input_is_valid (PostgreSQL 16 o posterior)'
SELECT valor,
       CASE WHEN pg_input_is_valid(btrim(valor), 'smallint') THEN btrim(valor)::smallint END AS como_smallint,
       CASE WHEN pg_input_is_valid(valor, 'date') THEN valor::date END                      AS como_fecha
FROM valores_sucios;
