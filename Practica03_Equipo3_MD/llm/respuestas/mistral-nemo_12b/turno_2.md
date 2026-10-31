```sql
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
  pais INT,
  estado INT,
  municipio INT,
  nombre_est VARCHAR(100),
  nombre_mun VARCHAR(100),
  pob_mun INT
);

CREATE TABLE dim_comorbilidad (
  id_comorbilidad SERIAL PRIMARY KEY,
  diabetes INT,
  epoc INT,
  asma INT,
  inmusupr INT,
  hipertension INT,
  obesidad INT,
  renal_cronica INT,
  cardiovascular INT,
  tabaquismo INT
);

CREATE TABLE dim_paciente (
  id_paciente SERIAL PRIMARY KEY,
  sexo CHAR(1),
  embarazo INT,
  habla_lengua_indig INT,
  indigena INT,
  nacionalidad INT
);

CREATE TABLE fact_covid (
  id_fact_covid SERIAL PRIMARY KEY,
  id_registro VARCHAR(25),
  id_fecha_ingreso_dim INT,
  id_fecha_def_dim INT,
  id_fecha_sintomas_dim INT,
  id_residencia_dim INT,
  id_comorbilidad_dim INT,
  id_paciente INT,
  edad INT,
  tipo_paciente INT,
  intubado INT,
  neumonia INT,
  resultado_lab INT,
  resultado_antigeno INT,
  clasificacion_final INT,
  uci INT,
  fecha_resultado DATE,
  migrante INT,
  pais_nacionalidad VARCHAR(50),
  pais_origen VARCHAR(50),
  CONSTRAINT fk_fact_fecha_ingreso FOREIGN KEY (id_fecha_ingreso_dim) REFERENCES dim_tiempo(id_tiempo),
  CONSTRAINT fk_fact_fecha_def FOREIGN KEY (id_fecha_def_dim) REFERENCES dim_tiempo(id_tiempo),
  CONSTRAINT fk_fact_fecha_sintomas FOREIGN KEY (id_fecha_sintomas_dim) REFERENCES dim_tiempo(id_tiempo),
  CONSTRAINT fk_fact_residencia FOREIGN KEY (id_residencia_dim) REFERENCES dim_localizacion(id_loc),
  CONSTRAINT fk_fact_comorbilidad FOREIGN KEY (id_comorbilidad_dim) REFERENCES dim_comorbilidad(id_comorbilidad),
  CONSTRAINT fk_fact_paciente FOREIGN KEY (id_paciente) REFERENCES dim_paciente(id_paciente)
);
```