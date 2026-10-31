-- Modelo multidimensional en copo de nieve (snowflake) para datos de casos COVID-19 en México,
-- conforme al diccionario oficial (201128 Descriptores.xlsx) y catálogos (201128 Catalogos.xlsx),
-- con granularidad adecuada para análisis epidemiológico, sin redundancias innecesarias,
-- y respetando que LOCALIDAD_RES se excluye del hecho (no se incluye en dim_localizacion como clave jerárquica principal; se almacena en dim_localizacion como atributo, pero no se usa como dimensión separada).
-- Todas las columnas de covid_historica se incluyen excepto LOCALIDAD_RES (que no está en el diccionario y se excluye del modelo de hechos/dimensiones como atributo independiente; se mantiene en dim_localizacion como campo opcional si se desea, pero en este script se incluye como parte de dim_localizacion para representar ubicación del paciente).
-- Nota: El script crea tablas con tipos exactos de PostgreSQL 17, usando SERIAL para claves secuenciales, VARCHAR con longitud adecuada, INT para enteros, DATE para fechas, etc.

-- 1. Tabla dim_tiempo: fecha, día, mes, año, semana, trimestre, tipo de fecha (ingreso, sintomas, resultado, defuncion)
CREATE TABLE dim_tiempo (
    id_tiempo SERIAL PRIMARY KEY,
    fecha DATE NOT NULL,
    anio INT NOT NULL,
    mes INT NOT NULL CHECK (mes >= 1 AND mes <= 12),
    dia INT NOT NULL CHECK (dia >= 1 AND dia <= 31),
    nombre_mes VARCHAR(20) NOT NULL, -- ej. "Enero", generado dinámicamente en consulta o ETL; aquí se almacena como texto estándar
    dia_semana INT NOT NULL CHECK (dia_semana >= 1 AND dia_semana <= 7), -- 1=lunes, 7=domingo
    nombre_dia VARCHAR(20) NOT NULL, -- ej. "lunes"
    trimestre INT NOT NULL CHECK (trimestre >= 1 AND trimestre <= 4),
    tipo_fecha VARCHAR(50) NOT NULL CHECK (tipo_fecha IN ('ingreso', 'sintomas', 'resultado', 'defuncion', 'actualizacion')), -- solo se usa para asociar el hecho a la fecha relevante
    CONSTRAINT chk_tipo_fecha CHECK (tipo_fecha IN ('ingreso', 'sintomas', 'resultado', 'defuncion')) -- 'actualizacion' no se usa como dimensión del hecho; solo se referencia si se quiere, pero se mantiene en fact_covid si se desea
);

-- 2. Tabla dim_localizacion: entidad_nac, entidad_res, municipio_res, localidad_res, pais_nacionalidad, pais_origen
-- Jerarquía: entidad (01-32) -> municipio (001-999) -> localidad (entero)
CREATE TABLE dim_localizacion (
    id_loc SERIAL PRIMARY KEY,
    entidad_nac INT NOT NULL CHECK (entity_nac IN (SELECT clave FROM catalogos_entidades WHERE clave IS NOT NULL)), -- se asume que catalogos_entidades contiene claves; aquí se usa nombre conceptual
    entidad_res INT NOT NULL CHECK (entity_res IN (SELECT clave FROM catalogos_entidades WHERE clave IS NOT NULL)),
    municipio_res INT NOT NULL CHECK (municipio_res IN (SELECT clave FROM catalogos_municipios WHERE clave IS NOT NULL)),
    localidad_res INT NOT NULL, -- código interno de localidad (falta catálogo explícito, se almacena tal cual)
    pais_nacionalidad TEXT NOT NULL CHECK (pais_nacionalidad IS NOT NULL AND (pais_nacionalidad = '99' OR pais_nacionalidad NOT LIKE '%99%')), -- permite '99' como "no especificado", pero se almacena como texto
    pais_origen TEXT NOT NULL CHECK (pais_origen IS NOT NULL AND (pais_origen = '97' OR pais_origen NOT LIKE '%97%')), -- '97' = NO APLICA
    CONSTRAINT chk_localizacion CHECK (localidad_res IS NOT NULL)
);

-- 3. Tabla dim_paciente: sexo, embarazo, habla_lengua_indig, indigena, nacionalidad, migrante
CREATE TABLE dim_paciente (
    id_paciente SERIAL PRIMARY KEY,
    sexo CHAR(1) NOT NULL CHECK (sexo IN ('1', '2', '99')), -- '1'=MUJER, '2'=HOMBRE, '99'=NO ESPECIFICADO
    edad INT NOT NULL CHECK (edad >= 0 AND edad <= 120 OR edad = 99), -- 99 se permite como "no especificado" (no es edad real)
    embarazo INT NOT NULL CHECK (embarazo IN ('1', '2', '99')),
    habla_lengua_indig INT NOT NULL CHECK (habla_lengua_indig IN ('1', '2', '99')),
    indigena INT NOT NULL CHECK (indigena IN ('1', '2', '99')),
    nacionalidad INT NOT NULL CHECK (nacionalidad IN ('1', '2', '99')), -- '1'=MEXICANA, '2'=EXTRANJERA
    migrante INT NOT NULL CHECK (migrante IN ('1', '2', '99')) -- '1'=SÍ, '2'=NO, '99'=NO ESPECIFICADO
);

-- 4. Tabla dim_comorbilidad: variables binarias (diabetes, epoc, asma, inmusupr, hipertension, obesidad, renal_cronica, cardiovascular, tabaquismo, otra_com)
-- NOTA: otra_com se incluye como parte de comorbilidad (catálogo dice "OTRAS_COM" = otras enfermedades)
CREATE TABLE dim_comorbilidad (
    id_comorbilidad SERIAL PRIMARY KEY,
    diabetes INT NOT NULL CHECK (diabetes IN ('1', '2', '99')),
    epoc INT NOT NULL CHECK (epoc IN ('1', '2', '99')),
    asma INT NOT NULL CHECK (asma IN ('1', '2', '99')),
    inmusupr INT NOT NULL CHECK (inmusupr IN ('1', '2', '99')),
    hipertension INT NOT NULL CHECK (hipertension IN ('1', '2', '99')),
    obesidad INT NOT NULL CHECK (obesidad IN ('1', '2', '99')),
    renal_cronica INT NOT NULL CHECK (renal_cronica IN ('1', '2', '99')),
    cardiovascular INT NOT NULL CHECK (cardiovascular IN ('1', '2', '99')),
    tabaquismo INT NOT NULL CHECK (tabaquismo IN ('1', '2', '99')),
    otra_com INT NOT NULL CHECK (otra_com IN ('1', '2', '99'))
);

-- 5. Tabla dim_resultado: origen, tipo_paciente, resultado_lab, resultado_antigeno, clasificacion_final, uci
-- Agrupa valores de resultado diagnóstico y estado clínico
CREATE TABLE dim_resultado (
    id_res INT PRIMARY KEY, -- se usa INT porque se asume que se crean claves secuenciales; si se prefiere SERIAL, se puede usar, pero id_res debe ser entero para FK en fact_covid
    origen INT NOT NULL CHECK (origen IN ('1', '2', '99')), -- '1'=USMER, '2'=FUERA DE USMER, '99'=NO ESPECIFICADO
    tipo_paciente INT NOT NULL CHECK (tipo_paciente IN ('1', '2', '99')), -- '1'=AMBULATORIO, '2'=HOSPITALIZADO, '99'=NO ESPECIFICADO
    resultado_lab INT NOT NULL CHECK (resultado_lab IN ('1', '2', '3', '4', '97')), -- '1'=POSITIVO, '2'=NO POSITIVO, '3'=PENDIENTE, '4'=NO ADECUADO, '97'=NO APLICA
    resultado_antigeno INT NOT NULL CHECK (resultado_antigeno IN ('1', '2', '97')), -- '1'=POSITIVO, '2'=NEGATIVO, '97'=NO APLICA
    clasificacion_final INT NOT NULL CHECK (clasificacion_final IN ('1', '2', '3', '4', '5', '6', '7')), -- según catálogo: 1-7
    uci INT NOT NULL CHECK (uci IN ('1', '2', '99')), -- '1'=SÍ (ingreso a UCI), '2'=NO, '99'=NO ESPECIFICADO
    CONSTRAINT chk_resultado CHECK (origen <> '99' OR tipo_paciente <> '99' OR resultado_lab <> '97' OR resultado_antigeno <> '97' OR clasificacion_final <> '4' OR uci <> '99') -- no se restringe estrictamente, solo se valida que los valores estén en catálogos; la validación se hace en ETL
);

-- 6. Tabla fact_covid: hechos del caso, con referencias a dimensiones y medidas binarias
-- NOTA: No se incluye LOCALIDAD_RES como dimensión separada; se almacena en dim_localizacion.
-- Las claves de tiempo se crean por cada fecha relevante del caso (ingreso, sintomas, resultado, defuncion). 
-- Si una fecha es NULL (ej. fecha_def), no se crea referencia a dim_tiempo para ese tipo; en el hecho se omite la FK correspondiente o se deja NULL (PostgreSQL permite NULL en FK si no se requiere integridad estricta; pero aquí se permite NULL para fechas faltantes).
CREATE TABLE fact_covid (
    id_fact_covid SERIAL PRIMARY KEY,
    id_registro TEXT NOT NULL, -- mismo tipo que en covid_historica (text)
    id_fecha_ingreso_dim INT, -- FK a dim_tiempo (tipo_fecha='ingreso')
    id_fecha_sintomas_dim INT, -- FK a dim_tiempo (tipo_fecha='sintomas')
    id_fecha_resultado_dim INT, -- FK a dim_tiempo (tipo_fecha='resultado')
    id_fecha_def_dim INT, -- FK a dim_tiempo (tipo_fecha='defuncion'); NULL si fecha_def IS NULL
    id_residencia_dim INT, -- FK a dim_localizacion
    id_comorbilidad_dim INT, -- FK a dim_comorbilidad
    id_paciente INT, -- FK a dim_paciente
    id_resultado_dim INT, -- FK a dim_resultado (una sola referencia por caso, ya que el resultado final es único)
    edad INT NOT NULL CHECK (edad >= 0 AND edad <= 120 OR edad = 99), -- se almacena tal cual; en análisis se filtra si edad=99
    tipo_paciente INT NOT NULL CHECK (tipo_paciente IN ('1', '2', '99')), -- se almacena para validación; pero id_paciente ya incluye tipo? No: tipo_paciente está en dim_resultado y dim_paciente no lo incluye; se almacena en fact_covid para evitar duplicar referencia si se quiere usar sin FK, pero mejor usar FK a dim_resultado que incluye tipo_paciente. Sin embargo, para simplicidad, se almacena edad y tipo_paciente en fact_covid (pero tipo_paciente también en dim_resultado). Para evitar redundancia, se usa FK a dim_resultado (que incluye tipo_paciente) y no se almacena tipo_paciente en fact_covid. Corrección: en el diseño, fact_covid no almacena tipo_paciente ni otras atributos de dim; solo claves FK. Por lo tanto, se elimina tipo_paciente de fact_covid y se usa FK a dim_resultado.
    -- Medidas binarias (todas 0/1, se calculan en el hecho o se almacenan como 0/1):
    caso_confirmado INT NOT NULL CHECK (caso_confirmado IN (0, 1)), -- 1 si clasificacion_final ∈ {1,2,3} (confirmado), 0 en caso contrario (4=inválido,5=no realizado,6=sospechoso,7=negativo)
    caso_hospitalizado INT NOT NULL CHECK (caso_hospitalizado IN (0, 1)), -- 1 si tipo_paciente=2 (hospitalizado)
    caso_uc_intensivo INT NOT NULL CHECK (caso_uc_intensivo IN (0, 1)), -- 1 si uci=1
    defuncion INT NOT NULL CHECK (defuncion IN (0, 1)), -- 1 si fecha_def IS NOT NULL
    resultado_lab_positivo INT NOT NULL CHECK (resultado_lab_positivo IN (0, 1)), -- 1 si resultado_lab=1 o resultado_antigeno=1, 0 en caso contrario (2,3,4,97)
    archivo_origen TEXT NOT NULL, -- nombre del archivo de origen (CSV 2022 o 2023)
    CONSTRAINT chk_fact_medidas CHECK (
        caso_confirmado IN (0,1) AND caso_hospitalizado IN (0,1) AND caso_uc_intensivo IN (0,1) AND defuncion IN (0,1) AND resultado_lab_positivo IN (0,1)
    ),
    -- Claves foráneas
    CONSTRAINT fk_id_fecha_ingreso_dim FOREIGN KEY (id_fecha_ingreso_dim) REFERENCES dim_tiempo(id_tiempo) ON DELETE SET NULL,
    CONSTRAINT fk_id_fecha_sintomas_dim FOREIGN KEY (id_fecha_sintomas_dim) REFERENCES dim_tiempo(id_tiempo) ON DELETE SET NULL,
    CONSTRAINT fk_id_fecha_resultado_dim FOREIGN KEY (id_fecha_resultado_dim) REFERENCES dim_tiempo(id_tiempo) ON DELETE SET NULL,
    CONSTRAINT fk_id_fecha_def_dim FOREIGN KEY (id_fecha_def_dim) REFERENCES dim_tiempo(id_tiempo) ON DELETE SET NULL,
    CONSTRAINT fk_id_residencia_dim FOREIGN KEY (id_residencia_dim) REFERENCES dim_localizacion(id_loc) ON DELETE SET NULL,
    CONSTRAINT fk_id_comorbilidad_dim FOREIGN KEY (id_comorbilidad_dim) REFERENCES dim_comorbilidad(id_comorbilidad) ON DELETE SET NULL,
    CONSTRAINT fk_id_paciente FOREIGN KEY (id_paciente) REFERENCES dim_paciente(id_paciente) ON DELETE SET NULL,
    CONSTRAINT fk_id_resultado_dim FOREIGN KEY (id_resultado_dim) REFERENCES dim_resultado(id_res) ON DELETE SET NULL
);

-- Nota: El script anterior tiene un error en dim_resultado: la columna se llama id_res pero se usa como PK INT; mejor usar SERIAL para id_res para consistencia.
-- Corregir: en dim_resultado, usar SERIAL para id_res.
-- También, en fact_covid, id_resultado_dim debe referenciar dim_resultado(id_res), pero id_res es SERIAL.

-- Corregir el script completo con tipos consistentes:

-- Reescribir con correcciones:

-- 1. dim_tiempo (ya correcto)
CREATE TABLE dim_tiempo (
    id_tiempo SERIAL PRIMARY KEY,
    fecha DATE NOT NULL,
    anio INT NOT NULL,
    mes INT NOT NULL CHECK (mes >= 1 AND mes <= 12),
    dia INT NOT NULL CHECK (dia >= 1 AND dia <= 31),
    nombre_mes VARCHAR(20) NOT NULL,
    dia_semana INT NOT NULL CHECK (dia_semana >= 1 AND dia_semana <= 7),
    nombre_dia VARCHAR(20) NOT NULL,
    trimestre INT NOT NULL CHECK (trimestre >= 1 AND trimestre <= 4),
    tipo_fecha VARCHAR(50) NOT NULL CHECK (tipo_fecha IN ('ingreso', 'sintomas', 'resultado', 'defuncion'))
);

-- 2. dim_localizacion (ya correcto)
CREATE TABLE dim_localizacion (
    id_loc SERIAL PRIMARY KEY,
    entidad_nac INT NOT NULL,
    entidad_res INT NOT NULL,
    municipio_res INT NOT NULL,
    localidad_res INT NOT NULL,
    pais_nacionalidad TEXT NOT NULL,
    pais_origen TEXT NOT NULL
);

-- 3. dim_paciente (ya correcto)
CREATE TABLE dim_paciente (
    id_paciente SERIAL PRIMARY KEY,
    sexo CHAR(1) NOT NULL CHECK (sexo IN ('1', '2', '99')),
    edad INT NOT NULL CHECK (edad >= 0 AND edad <= 120 OR edad = 99),
    embarazo INT NOT NULL CHECK (embarazo IN ('1', '2', '99')),
    habla_l