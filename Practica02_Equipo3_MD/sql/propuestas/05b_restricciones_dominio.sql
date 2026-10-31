-- Práctica 02, Equipo 3. Aportación de Santiago (Arquitecto).
-- PROPUESTA OPCIONAL: declarar en covid_historica los dominios del diccionario.
--
-- Hoy covid_historica solo declara su llave primaria. Los tipos son correctos, pero nada
-- en el esquema impide que una carga futura meta un SEXO = 5 o una ENTIDAD_RES = 40. Aquí
-- cada columna codificada apunta a su catálogo con una llave foránea: el dominio queda
-- documentado en el propio esquema y la base lo verifica al crear la restricción (si una
-- sola fila lo viola, la sentencia falla y no se crea nada).
--
-- Se ejecuta después de sql/05_consolidacion.sql, sql/06_catalogos.sql y
-- sql/08_catalogos_complementarios.sql. Con estos datos,
-- todas las restricciones se validan sobre las 2,099,997 filas, salvo la del par
-- entidad-municipio de residencia: el registro 4d0ea9 trae ENTIDAD_RES = 08 (Chihuahua)
-- con MUNICIPIO_RES = 113, que no existe en esa entidad. Esa se declara NOT VALID: protege
-- las cargas nuevas sin borrar ni corregir el registro histórico, que queda documentado
-- como anomalía en la sección 6.2.
--
-- La EDAD no lleva límite superior aquí a propósito: que una edad sea imposible (negativa)
-- es un problema de esquema; que sea improbable (122 años) es un atípico, y se marca con
-- banderas en sql/10_atipicos.sql, sin rechazar la fila.
--
-- Ojo: con estas llaves puestas, sql/06_catalogos.sql ya no se puede volver a correr,
-- porque borra y recrea cat_entidades, cat_municipios y cat_sector. Para repetir el
-- proceso completo, partir de una base nueva.

-- Los scripts están en UTF-8. En Windows, psql suele leerlos como WIN1252 y los acentos se
-- guardan mal o detienen la carga; con esta línea el resto del archivo se lee como UTF-8.
SET client_encoding = 'UTF8';

ALTER TABLE covid_historica
    ADD CONSTRAINT fk_origen              FOREIGN KEY (origen)              REFERENCES cat_origen (clave_origen),
    ADD CONSTRAINT fk_sector              FOREIGN KEY (sector)              REFERENCES cat_sector (clave_sector),
    ADD CONSTRAINT fk_entidad_um          FOREIGN KEY (entidad_um)          REFERENCES cat_entidades (clave_entidad),
    ADD CONSTRAINT fk_sexo                FOREIGN KEY (sexo)                REFERENCES cat_sexo (clave_sexo),
    ADD CONSTRAINT fk_entidad_nac         FOREIGN KEY (entidad_nac)         REFERENCES cat_entidades (clave_entidad),
    ADD CONSTRAINT fk_entidad_res         FOREIGN KEY (entidad_res)         REFERENCES cat_entidades (clave_entidad),
    ADD CONSTRAINT fk_tipo_paciente       FOREIGN KEY (tipo_paciente)       REFERENCES cat_tipo_paciente (clave_tipo_paciente),
    ADD CONSTRAINT fk_intubado            FOREIGN KEY (intubado)            REFERENCES cat_si_no (clave_si_no),
    ADD CONSTRAINT fk_neumonia            FOREIGN KEY (neumonia)            REFERENCES cat_si_no (clave_si_no),
    ADD CONSTRAINT fk_nacionalidad        FOREIGN KEY (nacionalidad)        REFERENCES cat_nacionalidad (clave_nacionalidad),
    ADD CONSTRAINT fk_embarazo            FOREIGN KEY (embarazo)            REFERENCES cat_si_no (clave_si_no),
    ADD CONSTRAINT fk_habla_lengua_indig  FOREIGN KEY (habla_lengua_indig)  REFERENCES cat_si_no (clave_si_no),
    ADD CONSTRAINT fk_indigena            FOREIGN KEY (indigena)            REFERENCES cat_si_no (clave_si_no),
    ADD CONSTRAINT fk_diabetes            FOREIGN KEY (diabetes)            REFERENCES cat_si_no (clave_si_no),
    ADD CONSTRAINT fk_epoc                FOREIGN KEY (epoc)                REFERENCES cat_si_no (clave_si_no),
    ADD CONSTRAINT fk_asma                FOREIGN KEY (asma)                REFERENCES cat_si_no (clave_si_no),
    ADD CONSTRAINT fk_inmusupr            FOREIGN KEY (inmusupr)            REFERENCES cat_si_no (clave_si_no),
    ADD CONSTRAINT fk_hipertension        FOREIGN KEY (hipertension)        REFERENCES cat_si_no (clave_si_no),
    ADD CONSTRAINT fk_otra_com            FOREIGN KEY (otra_com)            REFERENCES cat_si_no (clave_si_no),
    ADD CONSTRAINT fk_cardiovascular      FOREIGN KEY (cardiovascular)      REFERENCES cat_si_no (clave_si_no),
    ADD CONSTRAINT fk_obesidad            FOREIGN KEY (obesidad)            REFERENCES cat_si_no (clave_si_no),
    ADD CONSTRAINT fk_renal_cronica       FOREIGN KEY (renal_cronica)       REFERENCES cat_si_no (clave_si_no),
    ADD CONSTRAINT fk_tabaquismo          FOREIGN KEY (tabaquismo)          REFERENCES cat_si_no (clave_si_no),
    ADD CONSTRAINT fk_otro_caso           FOREIGN KEY (otro_caso)           REFERENCES cat_si_no (clave_si_no),
    ADD CONSTRAINT fk_toma_muestra_lab    FOREIGN KEY (toma_muestra_lab)    REFERENCES cat_si_no (clave_si_no),
    ADD CONSTRAINT fk_resultado_lab       FOREIGN KEY (resultado_lab)       REFERENCES cat_resultado_lab (clave_resultado_lab),
    ADD CONSTRAINT fk_toma_muestra_antigeno FOREIGN KEY (toma_muestra_antigeno) REFERENCES cat_si_no (clave_si_no),
    ADD CONSTRAINT fk_resultado_antigeno  FOREIGN KEY (resultado_antigeno)  REFERENCES cat_resultado_antigeno (clave_resultado_antigeno),
    ADD CONSTRAINT fk_clasificacion_final FOREIGN KEY (clasificacion_final) REFERENCES cat_clasificacion_final (clave_clasificacion),
    ADD CONSTRAINT fk_migrante            FOREIGN KEY (migrante)            REFERENCES cat_si_no (clave_si_no),
    ADD CONSTRAINT fk_uci                 FOREIGN KEY (uci)                 REFERENCES cat_si_no (clave_si_no),
    ADD CONSTRAINT fk_municipio_um        FOREIGN KEY (entidad_um, municipio_um)
                                          REFERENCES cat_municipios (clave_entidad, clave_municipio),
    ADD CONSTRAINT ck_edad_no_negativa    CHECK (edad >= 0);

-- El par de residencia: vale para las filas nuevas; la existente que lo viola queda documentada.
ALTER TABLE covid_historica
    ADD CONSTRAINT fk_municipio_res FOREIGN KEY (entidad_res, municipio_res)
        REFERENCES cat_municipios (clave_entidad, clave_municipio) NOT VALID;

-- Verificación: cuántas restricciones quedaron y cuáles no están validadas sobre lo existente
SELECT count(*) FILTER (WHERE contype = 'f')                     AS llaves_foraneas,
       count(*) FILTER (WHERE contype = 'c')                     AS checks,
       string_agg(conname, ', ') FILTER (WHERE NOT convalidated) AS sin_validar_sobre_historico
FROM pg_constraint
WHERE conrelid = 'covid_historica'::regclass;
