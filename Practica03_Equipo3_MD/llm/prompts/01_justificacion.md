Somos un equipo de la materia Minería de Datos (Licenciatura en Ciencia de Datos). En la práctica anterior cargamos y limpiamos en PostgreSQL una muestra de casos de COVID-19 en México publicada por la Secretaría de Salud. El resultado es la tabla covid_historica, con 2,099,997 casos (una fila por ID_REGISTRO, sin duplicados) que vienen de dos archivos CSV: uno de 2022 con 41 columnas y uno de 2023 con 44 (el de 2023 agrega MUNICIPIO_UM, CLUES y FECHA_RESULTADO). Los faltantes vienen codificados con los valores de los catálogos (97, 98, 99) y no como NULL; las fechas 9999-99-99 (sin defunción o sin resultado) ya se convirtieron a NULL.

Estructura de covid_historica (columna y tipo en PostgreSQL): fecha_actualizacion date, id_registro text, origen smallint, sector smallint, entidad_um smallint, municipio_um smallint, clues text, sexo smallint, entidad_nac smallint, entidad_res smallint, municipio_res smallint, localidad_res integer, tipo_paciente smallint, fecha_ingreso date, fecha_sintomas date, fecha_def date, intubado smallint, neumonia smallint, edad smallint, nacionalidad smallint, embarazo smallint, habla_lengua_indig smallint, indigena smallint, diabetes smallint, epoc smallint, asma smallint, inmusupr smallint, hipertension smallint, otra_com smallint, cardiovascular smallint, obesidad smallint, renal_cronica smallint, tabaquismo smallint, otro_caso smallint, toma_muestra_lab smallint, resultado_lab smallint, toma_muestra_antigeno smallint, resultado_antigeno smallint, clasificacion_final smallint, fecha_resultado date, migrante smallint, pais_nacionalidad text, pais_origen text, uci smallint, archivo_origen text.
La columna archivo_origen no viene en los CSV: la agregamos al cargar, con el nombre del archivo de origen.

Diccionario oficial de datos (201128 Descriptores.xlsx), tal cual:
| Nº | Variable | Descripción | Formato o fuente |
| 1 | FECHA_ACTUALIZACION | La base de datos se alimenta diariamente, esta variable permite identificar la fecha de la ultima actualizacion. | AAAA-MM-DD |
| 2 | ID_REGISTRO | Número identificador del caso | TEXTO |
| 3 | ORIGEN | La vigilancia centinela se realiza a través del sistema de unidades de salud monitoras de enfermedades respiratorias (USMER). Las USMER incluyen unidades médicas del primer, segundo o tercer nivel de atención y también participan como USMER las unidades de tercer nivel que por sus características contribuyen a ampliar el panorama de información epidemiológica, entre ellas las que cuenten con especialidad de neumología, infectología o pediatría. (Categorías en Catalógo Anexo). | CATÁLOGO: ORIGEN |
| 4 | SECTOR | Identifica el tipo de institución del Sistema Nacional de Salud que brindó la atención. | CATÁLOGO: SECTOR |
| 5 | ENTIDAD_UM | Identifica la entidad donde se ubica la unidad medica que brindó la atención. | CATALÓGO: ENTIDADES |
| 6 | SEXO | Identifica al sexo del paciente. | CATÁLOGO: SEXO |
| 7 | ENTIDAD_NAC | Identifica la entidad de nacimiento del paciente. | CATALÓGO: ENTIDADES |
| 8 | ENTIDAD_RES | Identifica la entidad de residencia del paciente. | CATALÓGO: ENTIDADES |
| 9 | MUNICIPIO_RES | Identifica el municipio de residencia del paciente. | CATALÓGO: MUNICIPIOS |
| 10 | TIPO_PACIENTE | Identifica el tipo de atención que recibió el paciente en la unidad. Se denomina como ambulatorio si regresó a su casa o se denomina como hospitalizado si fue ingresado a hospitalización. | CATÁLOGO: TIPO_PACIENTE |
| 11 | FECHA_INGRESO | Identifica la fecha de ingreso del paciente a la unidad de atención. | AAAA-MM-DD |
| 12 | FECHA_SINTOMAS | Idenitifica la fecha en que inició la sintomatología del paciente. | AAAA-MM-DD |
| 13 | FECHA_DEF | Identifica la fecha en que el paciente falleció. | AAAA-MM-DD |
| 14 | INTUBADO | Identifica si el paciente requirió de intubación. | CATÁLOGO: SI_ NO |
| 15 | NEUMONIA | Identifica si al paciente se le diagnosticó con neumonía. | CATÁLOGO: SI_ NO |
| 16 | EDAD | Identifica la edad del paciente. | NÚMERICA EN AÑOS |
| 17 | NACIONALIDAD | Identifica si el paciente es mexicano o extranjero. | CATÁLOGO: NACIONALIDAD |
| 18 | EMBARAZO | Identifica si la paciente está embarazada. | CATÁLOGO: SI_ NO |
| 19 | HABLA_LENGUA_INDIG | Identifica si el paciente habla lengua índigena. | CATÁLOGO: SI_ NO |
| 20 | INDIGENA | Identifica si el paciente se autoidentifica como una persona indígena. | CATÁLOGO: SI_ NO |
| 21 | DIABETES | Identifica si el paciente tiene un diagnóstico de diabetes. | CATÁLOGO: SI_ NO |
| 22 | EPOC | Identifica si el paciente tiene un diagnóstico de EPOC. | CATÁLOGO: SI_ NO |
| 23 | ASMA | Identifica si el paciente tiene un diagnóstico de asma. | CATÁLOGO: SI_ NO |
| 24 | INMUSUPR | Identifica si el paciente presenta inmunosupresión. | CATÁLOGO: SI_ NO |
| 25 | HIPERTENSION | Identifica si el paciente tiene un diagnóstico de hipertensión. | CATÁLOGO: SI_ NO |
| 26 | OTRAS_COM | Identifica si el paciente tiene diagnóstico de otras enfermedades. | CATÁLOGO: SI_ NO |
| 27 | CARDIOVASCULAR | Identifica si el paciente tiene un diagnóstico de enfermedades cardiovasculares. | CATÁLOGO: SI_ NO |
| 28 | OBESIDAD | Identifica si el paciente tiene diagnóstico de obesidad. | CATÁLOGO: SI_ NO |
| 29 | RENAL_CRONICA | Identifica si el paciente tiene diagnóstico de insuficiencia renal crónica. | CATÁLOGO: SI_ NO |
| 30 | TABAQUISMO | Identifica si el paciente tiene hábito de tabaquismo. | CATÁLOGO: SI_ NO |
| 31 | OTRO_CASO | Identifica si el paciente tuvo contacto con algún otro caso diagnósticado con SARS CoV-2 | CATÁLOGO: SI_ NO |
| 32 | TOMA_MUESTRA_LAB | Identifica si al paciente se le tomó muestra de laboratorio. | CATÁLOGO: SI_ NO |
| 33 | RESULTADO_LAB | Identifica el resultado del análisis de la muestra reportado por el laboratorio de la Red Nacional de Laboratorios de Vigilancia Epidemiológica (INDRE, LESP y LAVE) y laboratorios privados avalados por el InDRE cuyos resultados son registrados en SISVER. (Catálogo de resultados diagnósticos anexo). | CATÁLOGO: RESULTADO_LAB |
| 34 | TOMA_MUESTRA_ANTIGENO | Identifica si al paciente se le tomó muestra de antígeno para SARS-CoV-2 | CATÁLOGO: SI_ NO |
| 35 | RESULTADO_ANTIGENO | Identifica el resultado del análisis de la muestra de antígeno tomada al paciente | CATÁLOGO: RESULTADO_ANTIGENO |
| 36 | CLASIFICACION_FINAL | Identifica si el paciente es un caso de COVID-19 según el catálogo "CLASIFICACION_FINAL". | CATÁLOGO: CLASIFICACION_FINAL |
| 37 | MIGRANTE | Identifica si el paciente es una persona migrante. | CATÁLOGO: SI_ NO |
| 38 | PAIS_NACIONALIDAD | Identifica la nacionalidad del paciente. | TEXTO, 99= SE IGNORA |
| 39 | PAIS_ORIGEN | Identifica el país del que partió el paciente rumbo a México. | TEXTO, 97= NO APLICA |
| 40 | UCI | Identifica si el paciente requirió ingresar a una Unidad de Cuidados Intensivos. | CATÁLOGO: SI_ NO |
Las columnas LOCALIDAD_RES, MUNICIPIO_UM, CLUES y FECHA_RESULTADO vienen en los CSV pero no están en el diccionario. En los CSV la variable 26 se llama OTRA_COM.

Catálogos oficiales (201128 Catalogos.xlsx):
- ORIGEN: 1 = USMER; 2 = FUERA DE USMER; 99 = NO ESPECIFICADO
- SECTOR: 1 = CRUZ ROJA; 2 = DIF; 3 = ESTATAL; 4 = IMSS; 5 = IMSS-BIENESTAR; 6 = ISSSTE; 7 = MUNICIPAL; 8 = PEMEX; 9 = PRIVADA; 10 = SEDENA; 11 = SEMAR; 12 = SSA; 13 = UNIVERSITARIO; 99 = NO ESPECIFICADO
- SEXO: 1 = MUJER; 2 = HOMBRE; 99 = NO ESPECIFICADO
- TIPO_PACIENTE: 1 = AMBULATORIO; 2 = HOSPITALIZADO; 99 = NO ESPECIFICADO
- SI_NO: 1 = SI; 2 = NO; 97 = NO APLICA; 98 = SE IGNORA; 99 = NO ESPECIFICADO
- NACIONALIDAD: 1 = MEXICANA; 2 = EXTRANJERA; 99 = NO ESPECIFICADO
- RESULTADO_LAB: 1 = POSITIVO A SARS-COV-2; 2 = NO POSITIVO A SARS-COV-2; 3 = RESULTADO PENDIENTE; 4 = RESULTADO NO ADECUADO; 97 = NO APLICA (CASO SIN MUESTRA)
- RESULTADO_ANTIGENO: 1 = POSITIVO A SARS-COV-2; 2 = NEGATIVO A SARS-COV-2; 97 = NO APLICA (CASO SIN MUESTRA)
- CLASIFICACION_FINAL: 1 = CASO DE COVID-19 CONFIRMADO POR ASOCIACIÓN CLÍNICA EPIDEMIOLÓGICA; 2 = CASO DE COVID-19 CONFIRMADO POR COMITÉ DE DICTAMINACIÓN; 3 = CASO DE SARS-COV-2 CONFIRMADO; 4 = INVÁLIDO POR LABORATORIO; 5 = NO REALIZADO POR LABORATORIO; 6 = CASO SOSPECHOSO; 7 = NEGATIVO A SARS-COV-2
- ENTIDADES: 36 claves: 01 a 32 son las entidades federativas (01 AGUASCALIENTES ... 32 ZACATECAS), 36 = ESTADOS UNIDOS MEXICANOS, 97 = NO APLICA, 98 = SE IGNORA, 99 = NO ESPECIFICADO; cada una con nombre y abreviatura.
- MUNICIPIOS: 2,501 filas con columnas CLAVE_MUNICIPIO, MUNICIPIO, CLAVE_ENTIDAD (ejemplos: 001 AGUASCALIENTES 01; 007 IZTAPALAPA 09; 999 NO ESPECIFICADO 32; 997 NO APLICA 97; 998 SE IGNORA 98).

Reglas del enunciado de la práctica:
- Se incluyen todos los campos excepto "LOCALIDAD_RES".
- Diccionario de datos oficiales: "201128 Descriptores.xlsx" (semántica de las columnas) y "201128 Catalogos.xls" (categorías y sus valores que puede existir en una columna). ADVERTENCIA: Esta información se debe analizar en el contexto científico de la "epidemiología". Ejemplo: "SE IGNORA" = incertidumbre explícita; "NO ESPECIFICADO" = problema de captura/modelado administrativo.

Estructura SQL de referencia (anexo del enunciado):

CREATE TABLE dim_tiempo ( id_tiempo SERIAL PRIMARY KEY, fecha DATE, anio INT, mes INT, dia INT, nombre_mes VARCHAR(20), dia_semana INT, nombre_dia VARCHAR(20), trimestre INT, dia_festivo_tipo VARCHAR(50), tipo_fecha VARCHAR(50) );
CREATE TABLE dim_localizacion ( id_loc SERIAL PRIMARY KEY, pais INT, estado INT, municipio INT, localidad INT, nombre_est VARCHAR(100), nombre_mun VARCHAR(100), nombre_loc VARCHAR(100), pob_mun INT, pob_loc INT );
CREATE TABLE dim_comorbilidad ( id_comorbilidad SERIAL PRIMARY KEY, diabetes INT, epoc INT, asma INT, inmusupr INT, hipertension INT, obesidad INT, renal_cronica INT, cardiovascular INT, tabaquismo INT );
CREATE TABLE dim_paciente ( id_paciente SERIAL PRIMARY KEY, sexo CHAR(1), embarazo INT, habla_lengua_indig INT, indigena INT, nacionalidad INT );
CREATE TABLE fact_covid ( id_fact_covid SERIAL PRIMARY KEY, id_registro VARCHAR(25), id_fecha_ingreso_dim INT, id_fecha_def_dim INT, id_fecha_sintomas_dim INT, id_residencia_dim INT, id_comorbilidad_dim INT, id_paciente INT, edad INT, tipo_paciente INT, intubado INT, neumonia INT, CONSTRAINT fk_fact_fecha_ingreso FOREIGN KEY (id_fecha_ingreso_dim) REFERENCES dim_tiempo(id_tiempo), CONSTRAINT fk_fact_fecha_def FOREIGN KEY (id_fecha_def_dim) REFERENCES dim_tiempo(id_tiempo), CONSTRAINT fk_fact_fecha_sintomas FOREIGN KEY (id_fecha_sintomas_dim) REFERENCES dim_tiempo(id_tiempo), CONSTRAINT fk_fact_residencia FOREIGN KEY (id_residencia_dim) REFERENCES dim_localizacion(id_loc), CONSTRAINT fk_fact_comorbilidad FOREIGN KEY (id_comorbilidad_dim) REFERENCES dim_comorbilidad(id_comorbilidad), CONSTRAINT fk_fact_paciente FOREIGN KEY (id_paciente) REFERENCES dim_paciente(id_paciente) );

Ejemplo de referencia del enunciado:
| Tipo de tabla | Nombre sugerido | Contenido esperado |
| Hechos | fact_casos_covid | Registro analítico por caso o evento; contiene claves a dimensiones y medidas. |
| Dimensión tiempo | dim_tiempo | Fecha, día, mes, año, semana epidemiológica, trimestre. |
| Dimensión ubicación | dim_ubicacion | Entidad, municipio, localidad, país de origen o nacionalidad. |
| Dimensión paciente | dim_paciente | Sexo, edad, grupo de edad, nacionalidad, condición migrante. |
| Dimensión condición clínica | dim_condicion_clinica | Diabetes, hipertensión, obesidad, neumonía, tabaquismo, comorbilidades. |
| Dimensión atención/resultado | dim_resultado | Tipo de paciente, resultado de laboratorio, antígeno, clasificación final, defunción, UCI. |

Ahora, la tarea. Este es el punto 1 del enunciado, tal cual:

1. Análisis, razonamiento y justificación: Cada equipo deberá redactar una justificación técnica y conceptual para elegir un modelo multidimensional: estrellla, copo de nieve, o constelación. La justificación debe explicar por qué el modelo propuesto es adecuado para el conjunto de datos de contagios de COVID. Debe incluir los siguientes aspectos:
   1) Identificación de medidas, dimensiones
   2) Identificación de jerarquías de datos (dibujarlas).
   3) Identificación de tablas de hechos
   4) Situaciones de redundacias de datos en las diferentes tablas
   5) Granularidad de la dimensión del tiempo y espacio (si aplican), y todas las formas que puedan tomar
   6) Granularidad, tipos , grupos o formas que toman la o las dimensiones temáticas
   7) Proponga un limite razonable de hasta donde se puede enriquecer el tiempo y el espacio

Responde en español. Al final de tu respuesta, enumera las tablas de tu modelo (hechos y dimensiones) con sus columnas.
