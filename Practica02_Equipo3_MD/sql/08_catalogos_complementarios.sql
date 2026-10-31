-- Práctica 02, Equipo 3. Aportación de Santiago (Arquitecto).
-- Paso 8: los ocho catálogos que faltan y el diccionario de variables, como tablas.
--
-- El diccionario oficial (Diccionario_Datos/201128 Catalogos.xlsx) trae 11 catálogos.
-- sql/06_catalogos.sql carga entidades, municipios y sector; este script carga los otros
-- ocho (origen, sexo, tipo de paciente, SI_NO, nacionalidad, resultado de laboratorio,
-- resultado de antígeno y clasificación final) y las 40 variables de
-- 201128 Descriptores.xlsx. Con ellos, sql/09_validacion_esquema.sql compara cada código
-- de covid_historica contra su catálogo y cada columna contra el diccionario.
--
-- Sigue las convenciones del 06: claves smallint, como en covid_historica, y columnas
-- clave_<catálogo> y <catálogo>. Son los mismos nombres que usa el modelo de la Práctica 3.
--
-- No borra ni vacía nada: crea cada tabla solo si no existe y la llena solo si está vacía.
-- Así se puede correr dos veces sin duplicar filas y no falla si otra tabla ya depende de
-- un catálogo (por ejemplo, las llaves de sql/propuestas/05b_restricciones_dominio.sql).
--
-- Antes de correrlo, genera los CSV desde los dos Excel:
--   python scripts/exportar_catalogos_complementarios.py
-- Eso escribe Diccionario_Datos/cat_*.csv y Diccionario_Datos/diccionario_variables.csv,
-- que no se versionan (se regeneran del xlsx, igual que los del 06).
--
-- Usa \copy, \gset e \if, que son de psql (no del Query Tool de pgAdmin). Ejecutar parado
-- en Practica02_Equipo3_MD/, conectado a covid20a23sedi, después de sql/06_catalogos.sql:
--   psql -U postgres -h localhost -d covid20a23sedi -f sql/08_catalogos_complementarios.sql

-- Los scripts están en UTF-8. En Windows, psql suele leerlos como WIN1252 y los acentos se
-- guardan mal o detienen la carga; con esta línea el resto del archivo se lee como UTF-8.
SET client_encoding = 'UTF8';

CREATE TABLE IF NOT EXISTS diccionario_variables (
    num              smallint PRIMARY KEY,
    nombre_variable  text NOT NULL UNIQUE,
    descripcion      text,
    formato_o_fuente text
);

CREATE TABLE IF NOT EXISTS cat_origen              (clave_origen smallint PRIMARY KEY, origen text NOT NULL);
CREATE TABLE IF NOT EXISTS cat_sexo                (clave_sexo smallint PRIMARY KEY, sexo text NOT NULL);
CREATE TABLE IF NOT EXISTS cat_tipo_paciente       (clave_tipo_paciente smallint PRIMARY KEY, tipo_paciente text NOT NULL);
CREATE TABLE IF NOT EXISTS cat_si_no               (clave_si_no smallint PRIMARY KEY, si_no text NOT NULL);
CREATE TABLE IF NOT EXISTS cat_nacionalidad        (clave_nacionalidad smallint PRIMARY KEY, nacionalidad text NOT NULL);
CREATE TABLE IF NOT EXISTS cat_resultado_lab       (clave_resultado_lab smallint PRIMARY KEY, resultado_lab text NOT NULL);
CREATE TABLE IF NOT EXISTS cat_resultado_antigeno  (clave_resultado_antigeno smallint PRIMARY KEY, resultado_antigeno text NOT NULL);
CREATE TABLE IF NOT EXISTS cat_clasificacion_final (clave_clasificacion smallint PRIMARY KEY, clasificacion text NOT NULL, descripcion text);

-- Cada bloque pregunta si la tabla está vacía (\gset guarda la respuesta en :vacia) y solo
-- entonces la carga.
SELECT NOT EXISTS (SELECT 1 FROM diccionario_variables) AS vacia \gset
\if :vacia
\copy diccionario_variables FROM 'Diccionario_Datos/diccionario_variables.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\endif
SELECT NOT EXISTS (SELECT 1 FROM cat_origen) AS vacia \gset
\if :vacia
\copy cat_origen FROM 'Diccionario_Datos/cat_origen.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\endif
SELECT NOT EXISTS (SELECT 1 FROM cat_sexo) AS vacia \gset
\if :vacia
\copy cat_sexo FROM 'Diccionario_Datos/cat_sexo.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\endif
SELECT NOT EXISTS (SELECT 1 FROM cat_tipo_paciente) AS vacia \gset
\if :vacia
\copy cat_tipo_paciente FROM 'Diccionario_Datos/cat_tipo_paciente.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\endif
SELECT NOT EXISTS (SELECT 1 FROM cat_si_no) AS vacia \gset
\if :vacia
\copy cat_si_no FROM 'Diccionario_Datos/cat_si_no.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\endif
SELECT NOT EXISTS (SELECT 1 FROM cat_nacionalidad) AS vacia \gset
\if :vacia
\copy cat_nacionalidad FROM 'Diccionario_Datos/cat_nacionalidad.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\endif
SELECT NOT EXISTS (SELECT 1 FROM cat_resultado_lab) AS vacia \gset
\if :vacia
\copy cat_resultado_lab FROM 'Diccionario_Datos/cat_resultado_lab.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\endif
SELECT NOT EXISTS (SELECT 1 FROM cat_resultado_antigeno) AS vacia \gset
\if :vacia
\copy cat_resultado_antigeno FROM 'Diccionario_Datos/cat_resultado_antigeno.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\endif
SELECT NOT EXISTS (SELECT 1 FROM cat_clasificacion_final) AS vacia \gset
\if :vacia
\copy cat_clasificacion_final FROM 'Diccionario_Datos/cat_clasificacion_final.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\endif

-- Verificación (esperado: 40, 3, 3, 3, 5, 3, 5, 3 y 7):
SELECT 'diccionario_variables' AS tabla, count(*) AS filas FROM diccionario_variables
UNION ALL SELECT 'cat_origen', count(*) FROM cat_origen
UNION ALL SELECT 'cat_sexo', count(*) FROM cat_sexo
UNION ALL SELECT 'cat_tipo_paciente', count(*) FROM cat_tipo_paciente
UNION ALL SELECT 'cat_si_no', count(*) FROM cat_si_no
UNION ALL SELECT 'cat_nacionalidad', count(*) FROM cat_nacionalidad
UNION ALL SELECT 'cat_resultado_lab', count(*) FROM cat_resultado_lab
UNION ALL SELECT 'cat_resultado_antigeno', count(*) FROM cat_resultado_antigeno
UNION ALL SELECT 'cat_clasificacion_final', count(*) FROM cat_clasificacion_final;
