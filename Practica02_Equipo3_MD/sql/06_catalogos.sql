-- Práctica 02, Equipo 3
-- Paso 6: catálogos de referencia (entidad, municipio y sector).
-- El diccionario oficial (Diccionario_Datos/201128 Catalogos.xlsx) trae 11
-- catálogos; este script carga los tres que usan las visualizaciones y el
-- análisis de dependencias entre atributos: entidad y municipio, para poner
-- nombres en la Gráfica 3 y para que el SELECT de la sección de dependencias
-- entre atributos (cat_municipios LEFT JOIN) tenga contra qué comparar, y
-- sector, para nombrar el eje de la Gráfica 6 (demora por sector).
--
-- Antes de correr este script, genera los dos CSV desde el diccionario:
--   python scripts/exportar_catalogos.py
-- Eso escribe Diccionario_Datos/cat_entidades.csv y cat_municipios.csv, que
-- no se versionan (se regeneran del xlsx cada vez, igual que el diccionario).
--
-- Ejecutar conectado a covid20a23sedi: \c covid20a23sedi

-- cat_municipios se elimina primero porque su llave foránea depende de
-- cat_entidades; en el orden inverso, DROP TABLE cat_entidades falla.
DROP TABLE IF EXISTS cat_municipios;
DROP TABLE IF EXISTS cat_entidades;
CREATE TABLE cat_entidades (
    clave_entidad        smallint PRIMARY KEY,
    entidad_federativa   text NOT NULL,
    abreviatura          text
);

CREATE TABLE cat_municipios (
    clave_entidad   smallint NOT NULL REFERENCES cat_entidades (clave_entidad),
    clave_municipio smallint NOT NULL,
    municipio       text NOT NULL,
    PRIMARY KEY (clave_entidad, clave_municipio)
);

\copy cat_entidades (clave_entidad, entidad_federativa, abreviatura) FROM 'Diccionario_Datos/cat_entidades.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- El CSV trae (clave_municipio, municipio, clave_entidad); se reordena en el
-- INSERT para que coincida con la llave primaria (entidad, municipio).
DROP TABLE IF EXISTS cat_municipios_stage;
CREATE TABLE cat_municipios_stage (
    clave_municipio text,
    municipio       text,
    clave_entidad   text
);

\copy cat_municipios_stage FROM 'Diccionario_Datos/cat_municipios.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

INSERT INTO cat_municipios (clave_entidad, clave_municipio, municipio)
SELECT clave_entidad::smallint, clave_municipio::smallint, municipio
FROM cat_municipios_stage;

DROP TABLE cat_municipios_stage;

DROP TABLE IF EXISTS cat_sector;
CREATE TABLE cat_sector (
    clave_sector smallint PRIMARY KEY,
    sector       text NOT NULL
);

\copy cat_sector (clave_sector, sector) FROM 'Diccionario_Datos/cat_sector.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- Verificación:
--   SELECT count(*) FROM cat_entidades;   -- esperado: 36
--   SELECT count(*) FROM cat_municipios;  -- esperado: 2501
--   SELECT count(*) FROM cat_sector;      -- esperado: 14
--   -- ahora sí corre el SELECT de la sección de dependencias entre atributos:
--   SELECT count(*) FILTER (WHERE m.municipio IS NULL) AS municipio_fuera_de_su_entidad
--   FROM covid_historica h
--   LEFT JOIN cat_municipios m
--          ON m.clave_entidad = h.entidad_res AND m.clave_municipio = h.municipio_res;
