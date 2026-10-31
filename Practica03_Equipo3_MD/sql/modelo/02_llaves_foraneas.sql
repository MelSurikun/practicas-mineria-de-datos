-- Práctica 03, Equipo 3 (aportación de Santiago)
-- Paso 2: las 16 llaves foráneas de la tabla de hechos.
--
-- Se declaran DESPUÉS de cargar dimensiones y hechos. Con las llaves ya puestas, cada
-- INSERT revisaría sus 16 referencias fila por fila (33.6 millones de búsquedas para
-- 2,099,997 casos); declaradas al final, PostgreSQL valida cada una con una sola
-- consulta sobre toda la tabla. Si alguna fila apunta a un miembro inexistente, el
-- ALTER TABLE falla y dice cuál: es la prueba de que no hay llaves huérfanas.
--
-- Ejecutar:  psql -d covid_p3 -v ON_ERROR_STOP=1 -f sql/modelo/02_llaves_foraneas.sql
-- Se puede correr dos veces: primero quita lo que ya exista y lo vuelve a declarar.

-- Los scripts están en UTF-8. En Windows, psql suele leerlos como WIN1252 y los acentos
-- detienen la carga (character with byte sequence 0x81 in encoding "WIN1252"...).
-- Esta línea lo evita: el resto del archivo se interpreta como UTF-8.
SET client_encoding = 'UTF8';

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

ALTER TABLE dw.fact_casos_covid
    ADD CONSTRAINT fk_fact_fecha_sintomas      FOREIGN KEY (id_fecha_sintomas)       REFERENCES dw.dim_tiempo (id_tiempo),
    ADD CONSTRAINT fk_fact_fecha_ingreso       FOREIGN KEY (id_fecha_ingreso)        REFERENCES dw.dim_tiempo (id_tiempo),
    ADD CONSTRAINT fk_fact_fecha_resultado     FOREIGN KEY (id_fecha_resultado)      REFERENCES dw.dim_tiempo (id_tiempo),
    ADD CONSTRAINT fk_fact_fecha_defuncion     FOREIGN KEY (id_fecha_defuncion)      REFERENCES dw.dim_tiempo (id_tiempo),
    ADD CONSTRAINT fk_fact_ubicacion_residencia FOREIGN KEY (id_ubicacion_residencia) REFERENCES dw.dim_ubicacion (id_ubicacion),
    ADD CONSTRAINT fk_fact_entidad_nacimiento  FOREIGN KEY (id_entidad_nacimiento)   REFERENCES dw.dim_entidad (id_entidad),
    ADD CONSTRAINT fk_fact_unidad_medica       FOREIGN KEY (id_unidad_medica)        REFERENCES dw.dim_unidad_medica (id_unidad_medica),
    ADD CONSTRAINT fk_fact_paciente            FOREIGN KEY (id_paciente)             REFERENCES dw.dim_paciente (id_paciente),
    ADD CONSTRAINT fk_fact_pais_nacionalidad   FOREIGN KEY (id_pais_nacionalidad)    REFERENCES dw.dim_pais (id_pais),
    ADD CONSTRAINT fk_fact_pais_origen         FOREIGN KEY (id_pais_origen)          REFERENCES dw.dim_pais (id_pais),
    ADD CONSTRAINT fk_fact_edad                FOREIGN KEY (id_edad)                 REFERENCES dw.dim_edad (id_edad),
    ADD CONSTRAINT fk_fact_comorbilidad        FOREIGN KEY (id_comorbilidad)         REFERENCES dw.dim_comorbilidad (id_comorbilidad),
    ADD CONSTRAINT fk_fact_atencion            FOREIGN KEY (id_atencion)             REFERENCES dw.dim_atencion (id_atencion),
    ADD CONSTRAINT fk_fact_diagnostico         FOREIGN KEY (id_diagnostico)          REFERENCES dw.dim_diagnostico (id_diagnostico),
    ADD CONSTRAINT fk_fact_extracto            FOREIGN KEY (id_extracto)             REFERENCES dw.dim_extracto (id_extracto),
    ADD CONSTRAINT fk_fact_calidad             FOREIGN KEY (id_calidad)              REFERENCES dw.dim_calidad (id_calidad);

-- Índices para filtrar por fecha y lugar sin recorrer toda la tabla. Las demás llaves
-- apuntan a dimensiones de pocas filas, donde un hash join sobre la tabla completa
-- ya es la estrategia más rápida.
CREATE INDEX ix_fact_fecha_sintomas ON dw.fact_casos_covid (id_fecha_sintomas);
CREATE INDEX ix_fact_fecha_ingreso  ON dw.fact_casos_covid (id_fecha_ingreso);
CREATE INDEX ix_fact_ubicacion      ON dw.fact_casos_covid (id_ubicacion_residencia);

-- VACUUM y no solo ANALYZE: después de una carga masiva, VACUUM crea el mapa de
-- visibilidad (que permite lecturas solo de índice) y el de espacio libre. Si se deja
-- a autovacuum, lo hace cuando le toca, y el tamaño total de la tabla cambia 8 KB según
-- el momento en que se mida (lo vimos en codigo/probar_reproducibilidad.sh).
VACUUM (ANALYZE) dw.fact_casos_covid;

-- Verificación: las 16 llaves, validadas (convalidated = true).
SELECT conname, convalidated
FROM pg_constraint
WHERE conrelid = 'dw.fact_casos_covid'::regclass AND contype = 'f'
ORDER BY conname;
