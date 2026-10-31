CREATE TABLE dim_tiempo (
    id_tiempo SERIAL PRIMARY KEY,
    fecha DATE NOT NULL,
    anio INTEGER NOT NULL,
    mes INTEGER NOT NULL CHECK (mes >= 1 AND mes <= 12),
    dia INTEGER NOT NULL CHECK (dia >= 1 AND dia <= 31),
    dia_semana INTEGER NOT NULL CHECK (dia_semana >= 1 AND dia_semana <= 7), -- 1=lunes, 7=domingo
    nombre_dia VARCHAR(20), -- ej. 'lunes'
    episodio_semanal INTEGER NOT NULL, -- semana epidemiológica (ej. 1 para primera semana de 2022)
    trimestre INTEGER NOT NULL CHECK (trimestre >= 1 AND trimestre <= 4)
);

CREATE TABLE dim_localizacion (
    id_loc SERIAL PRIMARY KEY,
    entidad_nac INTEGER NOT NULL, -- clave del catálogo ENTIDADES
    entidad_res INTEGER NOT NULL, -- clave del catálogo ENTIDADES
    municipio_res INTEGER NOT NULL, -- clave del catálogo MUNICIPIOS
    localidad_res INTEGER NOT NULL, -- código de localidad del CSV
    nombre_est VARCHAR(100), -- nombre de la entidad
    nombre_mun VARCHAR(100), -- nombre del municipio
    nombre_loc VARCHAR(100), -- nombre de la localidad
    pais_nacionalidad TEXT, -- ej. "México", "Estados Unidos", "99=NO ESPECIFICADO"
    pais_origen TEXT -- ej. "Estados Unidos", "97=NO APLICA"
);

CREATE TABLE dim_paciente (
    id_paciente SERIAL PRIMARY KEY,
    sexo CHAR(1) NOT NULL CHECK (sexo IN ('1', '2', '99')), -- '1'=MUJER, '2'=HOMBRE, '99'=NO ESPECIFICADO
    edad INTEGER NOT NULL CHECK (edad >= 0 AND edad <= 120),
    embarazo INTEGER NOT NULL CHECK (embarazo IN ('1', '2', '99')),
    habla_lengua_indig INTEGER NOT NULL CHECK (habla_lengua_indig IN ('1', '2', '99')),
    indigena INTEGER NOT NULL CHECK (indigena IN ('1', '2', '99')),
    nacionalidad INTEGER NOT NULL CHECK (nacionalidad IN ('1', '2', '99')),
    migrante INTEGER NOT NULL CHECK (migrante IN ('1', '2', '99'))
);

CREATE TABLE dim_comorbilidad (
    id_comorbilidad SERIAL PRIMARY KEY,
    diabetes INTEGER NOT NULL CHECK (diabetes IN ('1', '2', '99')),
    epoc INTEGER NOT NULL CHECK (epoc IN ('1', '2', '99')),
    asma INTEGER NOT NULL CHECK (asma IN ('1', '2', '99')),
    inmusupr INTEGER NOT NULL CHECK (inmusupr IN ('1', '2', '99')),
    hipertension INTEGER NOT NULL CHECK (hipertension IN ('1', '2', '99')),
    obesidad INTEGER NOT NULL CHECK (obesidad IN ('1', '2', '99')),
    renal_cronica INTEGER NOT NULL CHECK (renal_cronica IN ('1', '2', '99')),
    cardiovascular INTEGER NOT NULL CHECK (cardiovascular IN ('1', '2', '99')),
    tabaquismo INTEGER NOT NULL CHECK (tabaquismo IN ('1', '2', '99')),
    otra_com INTEGER NOT NULL CHECK (otra_com IN ('1', '2', '99'))
);

CREATE TABLE dim_resultado (
    id_res SERIAL PRIMARY KEY,
    origen INTEGER NOT NULL CHECK (origen IN ('1', '2', '99')), -- 1=USMER; 2=FUERA DE USMER; 99=NO ESPECIFICADO
    tipo_paciente INTEGER NOT NULL CHECK (tipo_paciente IN ('1', '2', '99')), -- 1=AMBULATORIO; 2=HOSPITALIZADO; 99=NO ESPECIFICADO
    intubado INTEGER NOT NULL CHECK (intubado IN ('1', '2', '99')), -- 1=SI, 2=NO, 99=NO ESPECIFICADO
    neumonia INTEGER NOT NULL CHECK (neumonia IN ('1', '2', '99')), -- 1=SI, 2=NO, 99=NO ESPECIFICADO (97 no aplica para neumonia, pero 99 puede aparecer como no especificado)
    resultado_lab INTEGER NOT NULL CHECK (resultado_lab IN ('1', '2', '3', '4', '97')), -- 1=POSITIVO; 2=NO POSITIVO; 3=PENDIENTE; 4=NO ADECUADO; 97=NO APLICA
    resultado_antigeno INTEGER NOT NULL CHECK (resultado_antigeno IN ('1', '2', '97')), -- 1=POSITIVO; 2=NEGATIVO; 97=NO APLICA
    clasificacion_final INTEGER NOT NULL CHECK (clasificacion_final IN ('1', '2', '3', '4', '5', '6', '7')), -- 1-7
    uci INTEGER NOT NULL CHECK (uci IN ('1', '2', '99')), -- 1=SI UCI; 2=NO UCI; 99=NO ESPECIFICADO
    otro_caso INTEGER NOT NULL CHECK (otro_caso IN ('1', '2', '99')) -- 1=SI contacto; 2=NO; 99=NO ESPECIFICADO
);

CREATE TABLE fact_covid (
    id_fact_covid SERIAL PRIMARY KEY,
    id_registro TEXT NOT NULL,
    id_fecha_ingreso_dim INTEGER REFERENCES dim_tiempo(id_tiempo),
    id_fecha_sintomas_dim INTEGER REFERENCES dim_tiempo(id_tiempo),
    id_fecha_resultado_dim INTEGER REFERENCES dim_tiempo(id_tiempo),
    id_fecha_def_dim INTEGER REFERENCES dim_tiempo(id_tiempo),
    id_residencia_dim INTEGER REFERENCES dim_localizacion(id_loc),
    id_paciente INTEGER REFERENCES dim_paciente(id_paciente),
    id_comorbilidad_dim INTEGER REFERENCES dim_comorbilidad(id_comorbilidad),
    id_resultado_dim INTEGER REFERENCES dim_resultado(id_res),
    caso_confirmado INTEGER NOT NULL CHECK (caso_confirmado IN (0, 1)), -- 1 si clasificacion_final ∈ {1,2,3}
    caso_hospitalizado INTEGER NOT NULL CHECK (caso_hospitalizado IN (0, 1)), -- 1 si tipo_paciente = 2 (HOSPITALIZADO)
    caso_uc_intensivo INTEGER NOT NULL CHECK (caso_uc_intensivo IN (0, 1)), -- 1 si uci = 1
    defuncion INTEGER NOT NULL CHECK (defuncion IN (0, 1)), -- 1 si fecha_def IS NOT NULL
    resultado_lab_positivo INTEGER NOT NULL CHECK (resultado_lab_positivo IN (0, 1)) -- 1 si resultado_lab=1 o resultado_antigeno=1
);