```sql
-- Creación de tablas para el modelo multidimensional de datos de casos de COVID-19

CREATE TABLE dim_tiempo (
    id_tiempo SERIAL PRIMARY KEY,
    fecha DATE,
    anio INT,
    mes INT,
    dia INT,
    nombre_mes VARCHAR(20),
    dia_semana INT,
    nombre_dia VARCHAR(20),
    trimestre INT,
    dia_festivo_tipo VARCHAR(50),
    tipo_fecha VARCHAR(50)
);

CREATE TABLE dim_localizacion (
    id_loc SERIAL PRIMARY KEY,
    pais VARCHAR(100),
    estado VARCHAR(100),
    municipio VARCHAR(100),
    localidad VARCHAR(100),
    nombre_est VARCHAR(100),
    nombre_mun VARCHAR(100),
    nombre_loc VARCHAR(100),
    pob_mun INT,
    pob_loc INT
);

CREATE TABLE dim_paciente (
    id_paciente SERIAL PRIMARY KEY,
    sexo VARCHAR(10),
    embarazo SMALLINT,
    habla_lengua_indig SMALLINT,
    indigena SMALLINT,
    nacionalidad SMALLINT,
    migrante SMALLINT
);

CREATE TABLE dim_comorbilidad (
    id_comorbilidad SERIAL PRIMARY KEY,
    diabetes SMALLINT,
    epoc SMALLINT,
    asma SMALLINT,
    inmusupr SMALLINT,
    hipertension SMALLINT,
    obesidad SMALLINT,
    renal_cronica SMALLINT,
    cardiovascular SMALLINT,
    tabaquismo SMALLINT
);

CREATE TABLE dim_resultado (
    id_resultado SERIAL PRIMARY KEY,
    clasificacion_final SMALLINT,
    resultado_lab SMALLINT,
    resultado_antigeno SMALLINT,
    uci SMALLINT,
    fecha_def DATE
);

CREATE TABLE fact_casos_covid (
    id_fact_covid SERIAL PRIMARY KEY,
    id_registro TEXT,
    id_fecha_ingreso_dim INT,
    id_fecha_def_dim INT,
    id_fecha_sintomas_dim INT,
    id_residencia_dim INT,
    id_comorbilidad_dim INT,
    id_paciente INT,
    edad SMALLINT,
    tipo_paciente SMALLINT,
    intubado SMALLINT,
    neumonia SMALLINT,
    toma_muestra_lab SMALLINT,
    resultado_lab SMALLINT,
    toma_muestra_antigeno SMALLINT,
    resultado_antigeno SMALLINT,
    clasificacion_final SMALLINT,
    fecha_resultado DATE,
    migrante SMALLINT,
    pais_nacionalidad TEXT,
    pais_origen TEXT,
    uci SMALLINT,
    CONSTRAINT fk_fecha_ingreso FOREIGN KEY (id_fecha_ingreso_dim) REFERENCES dim_tiempo(id_tiempo),
    CONSTRAINT fk_fecha_def FOREIGN KEY (id_fecha_def_dim) REFERENCES dim_tiempo(id_tiempo),
    CONSTRAINT fk_fecha_sintomas FOREIGN KEY (id_fecha_sintomas_dim) REFERENCES dim_tiempo(id_tiempo),
    CONSTRAINT fk_residencia FOREIGN KEY (id_residencia_dim) REFERENCES dim_localizacion(id_loc),
    CONSTRAINT fk_comorbilidad FOREIGN KEY (id_comorbilidad_dim) REFERENCES dim_comorbilidad(id_comorbilidad),
    CONSTRAINT fk_paciente FOREIGN KEY (id_paciente) REFERENCES dim_paciente(id_paciente)
);
```