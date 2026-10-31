-- Práctica 03, Equipo 3 (aportación de Santiago)
-- Paso 1: el modelo multidimensional. Esquema estrella en el esquema "dw".
--
--   Grano de la tabla de hechos: un caso (ID_REGISTRO) en su último estado conocido,
--   con sus hitos de síntomas, ingreso, resultado y defunción (en términos de Kimball,
--   una instantánea acumulativa). 2,099,997 filas, una por fila de covid_historica.
--
--   12 dimensiones. Las llaves de las dimensiones son sustitutas (identity), salvo dos
--   que ya son enteros estables: dim_tiempo usa AAAAMMDD y dim_edad la propia edad.
--
--   Miembros especiales (nunca NULL en una llave foránea):
--     dim_tiempo  -1  NO DISPONIBLE EN EL EXTRACTO  (el CSV de 2022 no trae FECHA_RESULTADO)
--     dim_tiempo  -2  NO APLICA (SIN EVENTO)         (no hubo defunción o no hubo resultado)
--   Un código que no existe en su catálogo (en estos datos, solo el municipio 113 de
--   Chihuahua del registro 4d0ea9) entra como miembro inferido con tipo_miembro =
--   'FUERA DE CATÁLOGO': conserva el código original y su entidad, en lugar de borrarlo.
--
--   Las llaves foráneas se declaran en 02_llaves_foraneas.sql, después de la carga
--   masiva (validarlas una vez al final es mucho más rápido que revisar fila por fila).
--
-- Requiere PostgreSQL 15 o posterior (UNIQUE NULLS NOT DISTINCT en dim_unidad_medica).
--
-- Ejecutar:  psql -d covid_p3 -v ON_ERROR_STOP=1 -f sql/modelo/01_esquema_dw.sql
--
-- OJO: borra y vuelve a crear el esquema dw completo, con todo lo que tenga. Si en tu
-- base ya hay un esquema dw con trabajo propio, cámbiale el nombre antes de correr esto.

DROP SCHEMA IF EXISTS dw CASCADE;
CREATE SCHEMA dw;
COMMENT ON SCHEMA dw IS 'Modelo multidimensional (estrella) de los casos COVID-19 de covid_historica. Práctica 3, Equipo 3.';

-- =====================================================================================
-- Dimensión de tiempo (una tabla, cuatro roles en la tabla de hechos)
-- =====================================================================================
CREATE TABLE dw.dim_tiempo (
    id_tiempo            integer      PRIMARY KEY,
    fecha                date         UNIQUE,
    tipo_miembro         varchar(30)  NOT NULL,
    anio                 smallint,
    semestre             smallint,
    trimestre            smallint,
    mes                  smallint,
    nombre_mes           varchar(10),
    anio_mes             char(7),
    dia                  smallint,
    dia_semana           smallint,
    nombre_dia           varchar(10),
    es_fin_de_semana     boolean,
    anio_epi             smallint,
    semana_epi           smallint,
    inicio_semana_epi    date,
    temporada_influenza  varchar(30),
    es_festivo           boolean,
    nombre_festivo       varchar(60),
    tipo_dia             varchar(20),
    -- extract() es inmutable; to_char() no lo es (depende de la configuración regional),
    -- y una restricción debería dar siempre el mismo resultado para la misma fila.
    CONSTRAINT ck_dim_tiempo_miembro CHECK (
        (id_tiempo > 0 AND fecha IS NOT NULL
         AND id_tiempo = (extract(year FROM fecha) * 10000 + extract(month FROM fecha) * 100
                          + extract(day FROM fecha))::integer)
        OR (id_tiempo IN (-1, -2) AND fecha IS NULL))
);
COMMENT ON TABLE  dw.dim_tiempo IS 'Calendario diario 2022-2023 más dos miembros especiales. Se usa cuatro veces en la tabla de hechos: síntomas, ingreso, resultado y defunción.';
COMMENT ON COLUMN dw.dim_tiempo.id_tiempo IS 'Llave AAAAMMDD (20220102). -1 = no disponible en el extracto; -2 = no aplica (el evento no ocurrió).';
COMMENT ON COLUMN dw.dim_tiempo.fecha IS 'Fecha del día; NULL solo en los miembros especiales.';
COMMENT ON COLUMN dw.dim_tiempo.tipo_miembro IS 'FECHA, NO DISPONIBLE EN EL EXTRACTO o NO APLICA (SIN EVENTO).';
COMMENT ON COLUMN dw.dim_tiempo.anio IS 'Año calendario. Jerarquía: día → mes → trimestre → semestre → año.';
COMMENT ON COLUMN dw.dim_tiempo.semestre IS 'Semestre del año (1 o 2).';
COMMENT ON COLUMN dw.dim_tiempo.trimestre IS 'Trimestre del año (1 a 4).';
COMMENT ON COLUMN dw.dim_tiempo.mes IS 'Mes (1 a 12).';
COMMENT ON COLUMN dw.dim_tiempo.nombre_mes IS 'Nombre del mes en español, en mayúsculas.';
COMMENT ON COLUMN dw.dim_tiempo.anio_mes IS 'Año y mes como texto AAAA-MM: ordena bien en cualquier herramienta de gráficas.';
COMMENT ON COLUMN dw.dim_tiempo.dia IS 'Día del mes.';
COMMENT ON COLUMN dw.dim_tiempo.dia_semana IS 'Día de la semana ISO: 1 = lunes ... 7 = domingo.';
COMMENT ON COLUMN dw.dim_tiempo.nombre_dia IS 'Nombre del día en español, en mayúsculas.';
COMMENT ON COLUMN dw.dim_tiempo.es_fin_de_semana IS 'Verdadero en sábado y domingo.';
COMMENT ON COLUMN dw.dim_tiempo.anio_epi IS 'Año epidemiológico: el año del miércoles de la semana. Jerarquía: día → semana epidemiológica → año epidemiológico.';
COMMENT ON COLUMN dw.dim_tiempo.semana_epi IS 'Semana epidemiológica (domingo a sábado; la semana 1 es la que contiene el 4 de enero). SE01 2022 = 2 al 8 de enero; SE01 2023 = 1 al 7 de enero.';
COMMENT ON COLUMN dw.dim_tiempo.inicio_semana_epi IS 'Domingo con el que empieza la semana epidemiológica.';
COMMENT ON COLUMN dw.dim_tiempo.temporada_influenza IS 'Temporada estacional de influenza de la DGE (semana 40 a semana 20 del año siguiente) o periodo interestacional.';
COMMENT ON COLUMN dw.dim_tiempo.es_festivo IS 'Día de descanso obligatorio nacional (LFT, artículo 74, fracciones I a VI y VIII).';
COMMENT ON COLUMN dw.dim_tiempo.nombre_festivo IS 'Conmemoración del día de descanso obligatorio.';
COMMENT ON COLUMN dw.dim_tiempo.tipo_dia IS 'LABORAL, FIN DE SEMANA o FESTIVO OFICIAL.';

-- =====================================================================================
-- Dimensiones geográficas
-- =====================================================================================
CREATE TABLE dw.dim_ubicacion (
    id_ubicacion           integer      GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    cve_entidad            smallint     NOT NULL,
    nombre_entidad         varchar(40)  NOT NULL,
    abrev_entidad          varchar(3),
    cve_municipio          smallint     NOT NULL,
    nombre_municipio       varchar(80)  NOT NULL,
    cvegeo                 char(5),
    tipo_miembro           varchar(30)  NOT NULL,
    es_entidad_federativa  boolean      NOT NULL,
    CONSTRAINT uq_dim_ubicacion UNIQUE (cve_entidad, cve_municipio)
);
COMMENT ON TABLE  dw.dim_ubicacion IS 'Municipio de residencia del paciente. Una fila por municipio del catálogo oficial (2,501, con el 999 NO ESPECIFICADO de cada entidad) más los miembros inferidos fuera de catálogo.';
COMMENT ON COLUMN dw.dim_ubicacion.id_ubicacion IS 'Llave sustituta.';
COMMENT ON COLUMN dw.dim_ubicacion.cve_entidad IS 'Clave de entidad (ENTIDAD_RES). Jerarquía: municipio → entidad → país.';
COMMENT ON COLUMN dw.dim_ubicacion.nombre_entidad IS 'Nombre oficial de la entidad.';
COMMENT ON COLUMN dw.dim_ubicacion.abrev_entidad IS 'Abreviatura de la entidad del catálogo.';
COMMENT ON COLUMN dw.dim_ubicacion.cve_municipio IS 'Clave de municipio (MUNICIPIO_RES). Solo es única junto con la entidad: el 999 existe en cada entidad.';
COMMENT ON COLUMN dw.dim_ubicacion.nombre_municipio IS 'Nombre oficial del municipio.';
COMMENT ON COLUMN dw.dim_ubicacion.cvegeo IS 'Clave geoestadística del INEGI de 5 dígitos (09007 = Iztapalapa), para unir con capas o datos del INEGI. NULL en códigos fuera de catálogo.';
COMMENT ON COLUMN dw.dim_ubicacion.tipo_miembro IS 'MUNICIPIO, NO ESPECIFICADO, NO APLICA, SE IGNORA o FUERA DE CATÁLOGO.';
COMMENT ON COLUMN dw.dim_ubicacion.es_entidad_federativa IS 'Verdadero en las claves de entidad 1 a 32.';

CREATE TABLE dw.dim_entidad (
    id_entidad             smallint     GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    cve_entidad            smallint     NOT NULL UNIQUE,
    nombre_entidad         varchar(40)  NOT NULL,
    abrev_entidad          varchar(3),
    tipo_miembro           varchar(30)  NOT NULL,
    es_entidad_federativa  boolean      NOT NULL
);
COMMENT ON TABLE  dw.dim_entidad IS 'Entidad de nacimiento del paciente. Versión resumida (rollup) y conformada de dim_ubicacion: mismas claves y nombres de entidad, sin el nivel municipio, que ENTIDAD_NAC no tiene.';
COMMENT ON COLUMN dw.dim_entidad.id_entidad IS 'Llave sustituta.';
COMMENT ON COLUMN dw.dim_entidad.cve_entidad IS 'Clave de entidad del catálogo (1 a 32, 36, 97, 98, 99).';
COMMENT ON COLUMN dw.dim_entidad.nombre_entidad IS 'Nombre oficial de la entidad, idéntico al de dim_ubicacion.';
COMMENT ON COLUMN dw.dim_entidad.abrev_entidad IS 'Abreviatura de la entidad del catálogo.';
COMMENT ON COLUMN dw.dim_entidad.tipo_miembro IS 'ENTIDAD FEDERATIVA, PAÍS, NO APLICA, SE IGNORA, NO ESPECIFICADO o FUERA DE CATÁLOGO.';
COMMENT ON COLUMN dw.dim_entidad.es_entidad_federativa IS 'Verdadero en las claves 1 a 32.';

CREATE TABLE dw.dim_unidad_medica (
    id_unidad_medica        integer      GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    clues                   varchar(11),
    es_unidad_identificada  boolean      NOT NULL,
    es_clues_ficticia       boolean      NOT NULL,
    cve_sector              smallint     NOT NULL,
    nombre_sector           varchar(20)  NOT NULL,
    tipo_institucion        varchar(30)  NOT NULL,
    cve_entidad_um          smallint     NOT NULL,
    nombre_entidad_um       varchar(40)  NOT NULL,
    abrev_entidad_um        varchar(3),
    cve_municipio_um        smallint,
    nombre_municipio_um     varchar(80)  NOT NULL,
    cvegeo_um               char(5),
    tipo_miembro            varchar(40)  NOT NULL,
    CONSTRAINT uq_dim_unidad_medica UNIQUE NULLS NOT DISTINCT (clues, cve_sector, cve_entidad_um)
);
COMMENT ON TABLE  dw.dim_unidad_medica IS 'Unidad médica que atendió el caso. En 2023, una fila por CLUES (2,269), que determina sector, entidad y municipio. En 2022 no hay CLUES: una fila por par sector-entidad (212), marcada como unidad no identificada.';
COMMENT ON COLUMN dw.dim_unidad_medica.id_unidad_medica IS 'Llave sustituta.';
COMMENT ON COLUMN dw.dim_unidad_medica.clues IS 'Clave Única de Establecimientos de Salud (11 caracteres). NULL en las unidades no identificadas del extracto 2022.';
COMMENT ON COLUMN dw.dim_unidad_medica.es_unidad_identificada IS 'Verdadero si la fila corresponde a una CLUES (archivo 2023).';
COMMENT ON COLUMN dw.dim_unidad_medica.es_clues_ficticia IS 'Verdadero en CLUES con institución XXX (CHXXX005555, 36 registros de Chihuahua con sector 99).';
COMMENT ON COLUMN dw.dim_unidad_medica.cve_sector IS 'Clave de SECTOR. Jerarquía: CLUES → sector → tipo de institución.';
COMMENT ON COLUMN dw.dim_unidad_medica.nombre_sector IS 'Nombre del sector en el catálogo oficial.';
COMMENT ON COLUMN dw.dim_unidad_medica.tipo_institucion IS 'SEGURIDAD SOCIAL, SIN SEGURIDAD SOCIAL o PRIVADO, según Gómez-Dantés et al. (2011); OTRAS INSTITUCIONES (Cruz Roja, DIF, Municipal, Universitario) y NO ESPECIFICADO.';
COMMENT ON COLUMN dw.dim_unidad_medica.cve_entidad_um IS 'Entidad de la unidad (ENTIDAD_UM). Jerarquía: CLUES → municipio → entidad.';
COMMENT ON COLUMN dw.dim_unidad_medica.nombre_entidad_um IS 'Nombre de la entidad de la unidad.';
COMMENT ON COLUMN dw.dim_unidad_medica.abrev_entidad_um IS 'Abreviatura de la entidad de la unidad (coincide con las dos primeras letras de la CLUES).';
COMMENT ON COLUMN dw.dim_unidad_medica.cve_municipio_um IS 'Municipio de la unidad (MUNICIPIO_UM). NULL en 2022, donde la columna no existe.';
COMMENT ON COLUMN dw.dim_unidad_medica.nombre_municipio_um IS 'Nombre del municipio de la unidad, o NO DISPONIBLE EN EL EXTRACTO.';
COMMENT ON COLUMN dw.dim_unidad_medica.cvegeo_um IS 'Clave geoestadística del municipio de la unidad. NULL en 2022.';
COMMENT ON COLUMN dw.dim_unidad_medica.tipo_miembro IS 'UNIDAD IDENTIFICADA POR CLUES o UNIDAD NO IDENTIFICADA (EXTRACTO 2022).';

-- =====================================================================================
-- Dimensiones del paciente
-- =====================================================================================
CREATE TABLE dw.dim_paciente (
    id_paciente              smallint     GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    sexo                     smallint     NOT NULL,
    sexo_desc                varchar(20)  NOT NULL,
    embarazo                 smallint     NOT NULL,
    embarazo_desc            varchar(20)  NOT NULL,
    habla_lengua_indig       smallint     NOT NULL,
    habla_lengua_indig_desc  varchar(20)  NOT NULL,
    indigena                 smallint     NOT NULL,
    indigena_desc            varchar(20)  NOT NULL,
    nacionalidad             smallint     NOT NULL,
    nacionalidad_desc        varchar(20)  NOT NULL,
    migrante                 smallint     NOT NULL,
    migrante_desc            varchar(20)  NOT NULL,
    CONSTRAINT uq_dim_paciente UNIQUE (sexo, embarazo, habla_lengua_indig, indigena, nacionalidad, migrante)
);
COMMENT ON TABLE  dw.dim_paciente IS 'Perfil demográfico del paciente: una fila por combinación observada de seis atributos de catálogo (dimensión basura o mini-dimensión). 87 combinaciones en 2,099,997 casos.';
COMMENT ON COLUMN dw.dim_paciente.id_paciente IS 'Llave sustituta de la combinación.';
COMMENT ON COLUMN dw.dim_paciente.sexo IS 'SEXO: 1 MUJER, 2 HOMBRE, 99 NO ESPECIFICADO.';
COMMENT ON COLUMN dw.dim_paciente.sexo_desc IS 'Descripción de SEXO en el catálogo.';
COMMENT ON COLUMN dw.dim_paciente.embarazo IS 'EMBARAZO (catálogo SI_NO): 97 NO APLICA en todos los hombres.';
COMMENT ON COLUMN dw.dim_paciente.embarazo_desc IS 'Descripción de EMBARAZO.';
COMMENT ON COLUMN dw.dim_paciente.habla_lengua_indig IS 'HABLA_LENGUA_INDIG (catálogo SI_NO).';
COMMENT ON COLUMN dw.dim_paciente.habla_lengua_indig_desc IS 'Descripción de HABLA_LENGUA_INDIG.';
COMMENT ON COLUMN dw.dim_paciente.indigena IS 'INDIGENA, autoadscripción (catálogo SI_NO).';
COMMENT ON COLUMN dw.dim_paciente.indigena_desc IS 'Descripción de INDIGENA.';
COMMENT ON COLUMN dw.dim_paciente.nacionalidad IS 'NACIONALIDAD: 1 MEXICANA, 2 EXTRANJERA, 99 NO ESPECIFICADO. Coincide siempre con PAIS_NACIONALIDAD.';
COMMENT ON COLUMN dw.dim_paciente.nacionalidad_desc IS 'Descripción de NACIONALIDAD.';
COMMENT ON COLUMN dw.dim_paciente.migrante IS 'MIGRANTE (catálogo SI_NO): 99 NO ESPECIFICADO en el 98.77% de los casos.';
COMMENT ON COLUMN dw.dim_paciente.migrante_desc IS 'Descripción de MIGRANTE.';

CREATE TABLE dw.dim_pais (
    id_pais        smallint      GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    pais_original  varchar(60)   NOT NULL UNIQUE,
    pais           varchar(60)   NOT NULL,
    tipo_valor     varchar(20)   NOT NULL,
    es_mexico      boolean       NOT NULL,
    nota           varchar(160)
);
COMMENT ON TABLE  dw.dim_pais IS 'País, normalizado. Una fila por valor de texto distinto de PAIS_NACIONALIDAD o PAIS_ORIGEN (159). Se usa dos veces: nacionalidad y país de origen.';
COMMENT ON COLUMN dw.dim_pais.id_pais IS 'Llave sustituta.';
COMMENT ON COLUMN dw.dim_pais.pais_original IS 'El texto tal como viene en covid_historica (Thailandia, SE DESCONOCE, 97).';
COMMENT ON COLUMN dw.dim_pais.pais IS 'Nombre corregido (Tailandia) o etiqueta de la categoría (DESCONOCIDO, NO APLICA).';
COMMENT ON COLUMN dw.dim_pais.tipo_valor IS 'PAÍS O TERRITORIO, AGRUPACIÓN, NO VIGENTE, NO ES PAÍS, GENÉRICO, DESCONOCIDO o NO APLICA.';
COMMENT ON COLUMN dw.dim_pais.es_mexico IS 'Verdadero solo para México.';
COMMENT ON COLUMN dw.dim_pais.nota IS 'Qué se corrigió o por qué el valor no es un país.';

CREATE TABLE dw.dim_edad (
    id_edad          smallint     PRIMARY KEY,
    edad             smallint     NOT NULL UNIQUE,
    quinquenio       varchar(7)   NOT NULL,
    grupo_decenal    varchar(7)   NOT NULL,
    grupo_etario     varchar(40)  NOT NULL,
    es_edad_valida   boolean      NOT NULL,
    nota             varchar(120),
    CONSTRAINT ck_dim_edad_llave CHECK (id_edad = edad)
);
COMMENT ON TABLE  dw.dim_edad IS 'Edad en años con sus grupos. Una fila por edad observada (0 a 122).';
COMMENT ON COLUMN dw.dim_edad.id_edad IS 'Llave: la propia edad (entero estable, no hace falta llave sustituta).';
COMMENT ON COLUMN dw.dim_edad.edad IS 'EDAD en años. Jerarquía: edad → quinquenio → grupo decenal → grupo etario.';
COMMENT ON COLUMN dw.dim_edad.quinquenio IS 'Grupo de cinco años (00-04 ... 95-99, 100+).';
COMMENT ON COLUMN dw.dim_edad.grupo_decenal IS 'Grupo de diez años (00-09 ... 90-99, 100+).';
COMMENT ON COLUMN dw.dim_edad.grupo_etario IS 'MENORES DE EDAD (0-17), 18-39, 40-59, PERSONAS ADULTAS MAYORES (60 y más, LDPAM art. 3).';
COMMENT ON COLUMN dw.dim_edad.es_edad_valida IS 'Falso desde 122 años: nacimiento implícito en 1900 o antes, una fecha por omisión (Práctica 2). En estos datos solo hay 122.';
COMMENT ON COLUMN dw.dim_edad.nota IS 'Por qué la edad no es válida.';

-- =====================================================================================
-- Dimensiones clínicas (dimensiones basura: combinaciones observadas de banderas)
-- =====================================================================================
CREATE TABLE dw.dim_comorbilidad (
    id_comorbilidad        integer      GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    diabetes               smallint     NOT NULL,
    epoc                   smallint     NOT NULL,
    asma                   smallint     NOT NULL,
    inmusupr               smallint     NOT NULL,
    hipertension           smallint     NOT NULL,
    otra_com               smallint     NOT NULL,
    cardiovascular         smallint     NOT NULL,
    obesidad               smallint     NOT NULL,
    renal_cronica          smallint     NOT NULL,
    tabaquismo             smallint     NOT NULL,
    num_comorbilidades     smallint     NOT NULL,
    grupo_comorbilidades   varchar(12)  NOT NULL,
    tiene_comorbilidad     boolean      NOT NULL,
    num_sin_dato           smallint     NOT NULL,
    descripcion            varchar(200) NOT NULL,
    CONSTRAINT uq_dim_comorbilidad UNIQUE (diabetes, epoc, asma, inmusupr, hipertension, otra_com,
                                           cardiovascular, obesidad, renal_cronica, tabaquismo)
);
COMMENT ON TABLE  dw.dim_comorbilidad IS 'Comorbilidades y tabaquismo: una fila por combinación observada de las 10 banderas SI_NO (1,315). Es el catálogo de comorbilidades con valores únicos que sugiere el enunciado.';
COMMENT ON COLUMN dw.dim_comorbilidad.id_comorbilidad IS 'Llave sustituta de la combinación.';
COMMENT ON COLUMN dw.dim_comorbilidad.diabetes IS 'DIABETES (catálogo SI_NO: 1 SI, 2 NO, 98 SE IGNORA).';
COMMENT ON COLUMN dw.dim_comorbilidad.epoc IS 'EPOC (catálogo SI_NO).';
COMMENT ON COLUMN dw.dim_comorbilidad.asma IS 'ASMA (catálogo SI_NO).';
COMMENT ON COLUMN dw.dim_comorbilidad.inmusupr IS 'INMUSUPR, inmunosupresión (catálogo SI_NO).';
COMMENT ON COLUMN dw.dim_comorbilidad.hipertension IS 'HIPERTENSION (catálogo SI_NO).';
COMMENT ON COLUMN dw.dim_comorbilidad.otra_com IS 'OTRA_COM, otras enfermedades (catálogo SI_NO). El diccionario de 2020 la llama OTRAS_COM.';
COMMENT ON COLUMN dw.dim_comorbilidad.cardiovascular IS 'CARDIOVASCULAR (catálogo SI_NO).';
COMMENT ON COLUMN dw.dim_comorbilidad.obesidad IS 'OBESIDAD (catálogo SI_NO).';
COMMENT ON COLUMN dw.dim_comorbilidad.renal_cronica IS 'RENAL_CRONICA (catálogo SI_NO).';
COMMENT ON COLUMN dw.dim_comorbilidad.tabaquismo IS 'TABAQUISMO, hábito (catálogo SI_NO). No cuenta como comorbilidad en num_comorbilidades.';
COMMENT ON COLUMN dw.dim_comorbilidad.num_comorbilidades IS 'Cuántas de las 9 enfermedades valen 1 (SI). Jerarquía: combinación → número → grupo → tiene alguna.';
COMMENT ON COLUMN dw.dim_comorbilidad.grupo_comorbilidades IS 'NINGUNA, UNA, DOS o TRES O MÁS.';
COMMENT ON COLUMN dw.dim_comorbilidad.tiene_comorbilidad IS 'Verdadero si al menos una de las 9 enfermedades vale 1.';
COMMENT ON COLUMN dw.dim_comorbilidad.num_sin_dato IS 'Cuántas de las 10 banderas valen 97, 98 o 99 (no aplica, se ignora o no especificado).';
COMMENT ON COLUMN dw.dim_comorbilidad.descripcion IS 'Lista legible de lo que vale 1 (DIABETES + HIPERTENSIÓN) o NINGUNA.';

CREATE TABLE dw.dim_atencion (
    id_atencion          smallint     GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    origen               smallint     NOT NULL,
    origen_desc          varchar(20)  NOT NULL,
    tipo_paciente        smallint     NOT NULL,
    tipo_paciente_desc   varchar(20)  NOT NULL,
    neumonia             smallint     NOT NULL,
    neumonia_desc        varchar(20)  NOT NULL,
    intubado             smallint     NOT NULL,
    intubado_desc        varchar(20)  NOT NULL,
    uci                  smallint     NOT NULL,
    uci_desc             varchar(20)  NOT NULL,
    nivel_gravedad       smallint     NOT NULL,
    gravedad_desc        varchar(50)  NOT NULL,
    CONSTRAINT uq_dim_atencion UNIQUE (origen, tipo_paciente, neumonia, intubado, uci)
);
COMMENT ON TABLE  dw.dim_atencion IS 'Cómo se vigiló y atendió el caso: origen de la vigilancia, tipo de paciente, neumonía, intubación y UCI. Una fila por combinación observada.';
COMMENT ON COLUMN dw.dim_atencion.id_atencion IS 'Llave sustituta de la combinación.';
COMMENT ON COLUMN dw.dim_atencion.origen IS 'ORIGEN: 1 USMER, 2 FUERA DE USMER. Es del caso, no de la unidad: una misma CLUES (CMIMS000186) tiene ambos valores.';
COMMENT ON COLUMN dw.dim_atencion.origen_desc IS 'Descripción de ORIGEN.';
COMMENT ON COLUMN dw.dim_atencion.tipo_paciente IS 'TIPO_PACIENTE: 1 AMBULATORIO, 2 HOSPITALIZADO.';
COMMENT ON COLUMN dw.dim_atencion.tipo_paciente_desc IS 'Descripción de TIPO_PACIENTE.';
COMMENT ON COLUMN dw.dim_atencion.neumonia IS 'NEUMONIA (catálogo SI_NO).';
COMMENT ON COLUMN dw.dim_atencion.neumonia_desc IS 'Descripción de NEUMONIA.';
COMMENT ON COLUMN dw.dim_atencion.intubado IS 'INTUBADO (catálogo SI_NO): 97 NO APLICA en todos los ambulatorios.';
COMMENT ON COLUMN dw.dim_atencion.intubado_desc IS 'Descripción de INTUBADO.';
COMMENT ON COLUMN dw.dim_atencion.uci IS 'UCI (catálogo SI_NO): 97 NO APLICA en todos los ambulatorios.';
COMMENT ON COLUMN dw.dim_atencion.uci_desc IS 'Descripción de UCI.';
COMMENT ON COLUMN dw.dim_atencion.nivel_gravedad IS '1 ambulatorio, 2 hospitalizado, 3 hospitalizado con UCI o intubación, 9 no especificado. Jerarquía: combinación → nivel de gravedad → tipo de paciente.';
COMMENT ON COLUMN dw.dim_atencion.gravedad_desc IS 'Descripción del nivel de gravedad.';

CREATE TABLE dw.dim_diagnostico (
    id_diagnostico              smallint     GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    otro_caso                   smallint     NOT NULL,
    otro_caso_desc              varchar(20)  NOT NULL,
    toma_muestra_lab            smallint     NOT NULL,
    toma_muestra_lab_desc       varchar(20)  NOT NULL,
    resultado_lab               smallint     NOT NULL,
    resultado_lab_desc          varchar(40)  NOT NULL,
    toma_muestra_antigeno       smallint     NOT NULL,
    toma_muestra_antigeno_desc  varchar(20)  NOT NULL,
    resultado_antigeno          smallint     NOT NULL,
    resultado_antigeno_desc     varchar(40)  NOT NULL,
    clasificacion_final         smallint     NOT NULL,
    clasificacion_final_desc    varchar(80)  NOT NULL,
    grupo_clasificacion         varchar(20)  NOT NULL,
    es_confirmado               boolean      NOT NULL,
    CONSTRAINT uq_dim_diagnostico UNIQUE (otro_caso, toma_muestra_lab, resultado_lab,
                                          toma_muestra_antigeno, resultado_antigeno, clasificacion_final)
);
COMMENT ON TABLE  dw.dim_diagnostico IS 'Ruta diagnóstica del caso: contacto con otro caso, muestras, resultados y clasificación final. Una fila por combinación observada (66).';
COMMENT ON COLUMN dw.dim_diagnostico.id_diagnostico IS 'Llave sustituta de la combinación.';
COMMENT ON COLUMN dw.dim_diagnostico.otro_caso IS 'OTRO_CASO, contacto con otro caso de SARS-CoV-2 (catálogo SI_NO).';
COMMENT ON COLUMN dw.dim_diagnostico.otro_caso_desc IS 'Descripción de OTRO_CASO.';
COMMENT ON COLUMN dw.dim_diagnostico.toma_muestra_lab IS 'TOMA_MUESTRA_LAB (catálogo SI_NO).';
COMMENT ON COLUMN dw.dim_diagnostico.toma_muestra_lab_desc IS 'Descripción de TOMA_MUESTRA_LAB.';
COMMENT ON COLUMN dw.dim_diagnostico.resultado_lab IS 'RESULTADO_LAB: 1 positivo, 2 no positivo, 3 pendiente, 4 no adecuado, 97 sin muestra.';
COMMENT ON COLUMN dw.dim_diagnostico.resultado_lab_desc IS 'Descripción de RESULTADO_LAB.';
COMMENT ON COLUMN dw.dim_diagnostico.toma_muestra_antigeno IS 'TOMA_MUESTRA_ANTIGENO (catálogo SI_NO).';
COMMENT ON COLUMN dw.dim_diagnostico.toma_muestra_antigeno_desc IS 'Descripción de TOMA_MUESTRA_ANTIGENO.';
COMMENT ON COLUMN dw.dim_diagnostico.resultado_antigeno IS 'RESULTADO_ANTIGENO: 1 positivo, 2 negativo, 97 sin muestra.';
COMMENT ON COLUMN dw.dim_diagnostico.resultado_antigeno_desc IS 'Descripción de RESULTADO_ANTIGENO.';
COMMENT ON COLUMN dw.dim_diagnostico.clasificacion_final IS 'CLASIFICACION_FINAL (1 a 7). Jerarquía: clasificación → grupo → confirmado.';
COMMENT ON COLUMN dw.dim_diagnostico.clasificacion_final_desc IS 'Descripción oficial de CLASIFICACION_FINAL.';
COMMENT ON COLUMN dw.dim_diagnostico.grupo_clasificacion IS 'CONFIRMADO (1, 2, 3), SOSPECHOSO (6), NEGATIVO (7) o NO CONCLUYENTE (4, 5).';
COMMENT ON COLUMN dw.dim_diagnostico.es_confirmado IS 'Verdadero en las clasificaciones 1, 2 y 3.';

-- =====================================================================================
-- Dimensiones de linaje y de calidad (dimensiones de auditoría)
-- =====================================================================================
CREATE TABLE dw.dim_extracto (
    id_extracto               smallint     GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    archivo_origen            varchar(60)  NOT NULL UNIQUE,
    fecha_actualizacion       date         NOT NULL,
    anio_nominal              smallint     NOT NULL,
    columnas_csv              smallint     NOT NULL,
    trae_unidad_y_resultado   boolean      NOT NULL,
    filas_csv                 integer      NOT NULL,
    casos_unicos              integer      NOT NULL,
    fecha_sintomas_min        date         NOT NULL,
    fecha_sintomas_max        date         NOT NULL,
    periodo_efectivo          varchar(60)  NOT NULL
);
COMMENT ON TABLE  dw.dim_extracto IS 'Archivo del que viene cada caso (linaje). FECHA_ACTUALIZACION depende solo del archivo, así que vive aquí y no se repite en 2.1 millones de filas.';
COMMENT ON COLUMN dw.dim_extracto.id_extracto IS 'Llave sustituta.';
COMMENT ON COLUMN dw.dim_extracto.archivo_origen IS 'Nombre del CSV de origen (columna archivo_origen de covid_historica).';
COMMENT ON COLUMN dw.dim_extracto.fecha_actualizacion IS 'FECHA_ACTUALIZACION: fecha de corte del extracto (2023-06-01 para el de 2022, 2023-06-23 para el de 2023).';
COMMENT ON COLUMN dw.dim_extracto.anio_nominal IS 'Año que dice el nombre del archivo.';
COMMENT ON COLUMN dw.dim_extracto.columnas_csv IS 'Columnas del CSV: 41 en 2022 y 44 en 2023.';
COMMENT ON COLUMN dw.dim_extracto.trae_unidad_y_resultado IS 'Falso en 2022: ese CSV no trae MUNICIPIO_UM, CLUES ni FECHA_RESULTADO.';
COMMENT ON COLUMN dw.dim_extracto.filas_csv IS 'Filas de datos del CSV antes de quitar duplicados (Práctica 2).';
COMMENT ON COLUMN dw.dim_extracto.casos_unicos IS 'Casos del extracto en covid_historica, ya sin duplicados.';
COMMENT ON COLUMN dw.dim_extracto.fecha_sintomas_min IS 'Primera fecha de inicio de síntomas del extracto.';
COMMENT ON COLUMN dw.dim_extracto.fecha_sintomas_max IS 'Última fecha de inicio de síntomas del extracto.';
COMMENT ON COLUMN dw.dim_extracto.periodo_efectivo IS 'Periodo que concentra los casos (Práctica 2, Tabla 13): el nombre del archivo no lo dice.';

CREATE TABLE dw.dim_calidad (
    id_calidad                  smallint     GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    edad_no_valida              boolean      NOT NULL,
    fechas_en_desorden          boolean      NOT NULL,
    sintomas_mas_de_10_dias     boolean      NOT NULL,
    demora_extrema              boolean      NOT NULL,
    embarazo_edad_atipica       boolean      NOT NULL,
    tabaquismo_menor_10         boolean      NOT NULL,
    municipio_fuera_catalogo    boolean      NOT NULL,
    entidad_nac_inconsistente   boolean      NOT NULL,
    clues_ficticia              boolean      NOT NULL,
    defuncion_ambulatoria       boolean      NOT NULL,
    intubado_sin_uci            boolean      NOT NULL,
    num_banderas                smallint     NOT NULL,
    nivel_maximo                varchar(15)  NOT NULL,
    descripcion                 varchar(300) NOT NULL,
    CONSTRAINT uq_dim_calidad UNIQUE (edad_no_valida, fechas_en_desorden, sintomas_mas_de_10_dias, demora_extrema,
                                      embarazo_edad_atipica, tabaquismo_menor_10, municipio_fuera_catalogo,
                                      entidad_nac_inconsistente, clues_ficticia, defuncion_ambulatoria, intubado_sin_uci)
);
COMMENT ON TABLE  dw.dim_calidad IS 'Banderas de calidad del caso, de las reglas de la Práctica 2: una fila por combinación observada. Permite excluir o estudiar los registros dudosos sin borrarlos.';
COMMENT ON COLUMN dw.dim_calidad.id_calidad IS 'Llave sustituta de la combinación.';
COMMENT ON COLUMN dw.dim_calidad.edad_no_valida IS 'ERROR. EDAD = 122: nacimiento implícito en 1900 (34 casos).';
COMMENT ON COLUMN dw.dim_calidad.fechas_en_desorden IS 'ERROR. Defunción antes del ingreso o de los síntomas, resultado antes del ingreso, o síntomas después del ingreso.';
COMMENT ON COLUMN dw.dim_calidad.sintomas_mas_de_10_dias IS 'POR REVISAR. Más de 10 días entre síntomas e ingreso: fuera de la ventana de la definición operativa de caso (DGE, 2022).';
COMMENT ON COLUMN dw.dim_calidad.demora_extrema IS 'POR REVISAR. Más de 31 días entre síntomas e ingreso (cerca de Tukey sobre el logaritmo de la demora, Práctica 2).';
COMMENT ON COLUMN dw.dim_calidad.embarazo_edad_atipica IS 'POR REVISAR. EMBARAZO = 1 con edad menor de 10 o mayor de 55.';
COMMENT ON COLUMN dw.dim_calidad.tabaquismo_menor_10 IS 'POR REVISAR. TABAQUISMO = 1 con edad menor de 10.';
COMMENT ON COLUMN dw.dim_calidad.municipio_fuera_catalogo IS 'ERROR. El par ENTIDAD_RES-MUNICIPIO_RES no existe en el catálogo.';
COMMENT ON COLUMN dw.dim_calidad.entidad_nac_inconsistente IS 'ERROR. Extranjero con ENTIDAD_NAC distinta de 97, o mexicano sin entidad de nacimiento entre 1 y 32.';
COMMENT ON COLUMN dw.dim_calidad.clues_ficticia IS 'ERROR. CLUES con institución XXX.';
COMMENT ON COLUMN dw.dim_calidad.defuncion_ambulatoria IS 'POR REVISAR. Defunción registrada en un paciente ambulatorio.';
COMMENT ON COLUMN dw.dim_calidad.intubado_sin_uci IS 'POR REVISAR. Intubado sin ingreso a UCI: posible fuera de terapia intensiva, no necesariamente un error.';
COMMENT ON COLUMN dw.dim_calidad.num_banderas IS 'Cuántas banderas están activas.';
COMMENT ON COLUMN dw.dim_calidad.nivel_maximo IS 'SIN BANDERAS, POR REVISAR o ERROR: la bandera más grave que tiene el caso.';
COMMENT ON COLUMN dw.dim_calidad.descripcion IS 'Lista legible de las banderas activas.';

-- =====================================================================================
-- Tabla de hechos
-- =====================================================================================
CREATE TABLE dw.fact_casos_covid (
    id_fact_covid             bigint       GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    id_registro               varchar(10)  NOT NULL UNIQUE,
    -- llaves a dimensiones
    id_fecha_sintomas         integer      NOT NULL,
    id_fecha_ingreso          integer      NOT NULL,
    id_fecha_resultado        integer      NOT NULL,
    id_fecha_defuncion        integer      NOT NULL,
    id_ubicacion_residencia   integer      NOT NULL,
    id_entidad_nacimiento     smallint     NOT NULL,
    id_unidad_medica          integer      NOT NULL,
    id_paciente               smallint     NOT NULL,
    id_pais_nacionalidad      smallint     NOT NULL,
    id_pais_origen            smallint     NOT NULL,
    id_edad                   smallint     NOT NULL,
    id_comorbilidad           integer      NOT NULL,
    id_atencion               smallint     NOT NULL,
    id_diagnostico            smallint     NOT NULL,
    id_extracto               smallint     NOT NULL,
    id_calidad                smallint     NOT NULL,
    -- medidas aditivas: 1 si el caso cuenta, 0 si no; sumadas dan conteos
    casos                     smallint     NOT NULL DEFAULT 1,
    confirmados               smallint     NOT NULL,
    hospitalizados            smallint     NOT NULL,
    ingresos_uci              smallint     NOT NULL,
    intubados                 smallint     NOT NULL,
    con_neumonia              smallint     NOT NULL,
    defunciones               smallint     NOT NULL,
    -- medidas no aditivas: se promedian o se resumen con medianas, nunca se suman
    edad_anios                smallint,
    dias_sintomas_a_ingreso   smallint,
    dias_ingreso_a_resultado  smallint,
    dias_ingreso_a_defuncion  smallint,
    CONSTRAINT ck_fact_banderas CHECK (casos = 1
        AND confirmados IN (0, 1) AND hospitalizados IN (0, 1) AND ingresos_uci IN (0, 1)
        AND intubados IN (0, 1) AND con_neumonia IN (0, 1) AND defunciones IN (0, 1)),
    CONSTRAINT ck_fact_demoras CHECK (dias_sintomas_a_ingreso >= 0 AND dias_ingreso_a_resultado >= 0
        AND dias_ingreso_a_defuncion >= 0)
);
COMMENT ON TABLE  dw.fact_casos_covid IS 'Un caso por fila (grano: ID_REGISTRO), con llaves a 12 dimensiones y 11 medidas. Instantánea acumulativa: los hitos del caso son cuatro fechas.';
COMMENT ON COLUMN dw.fact_casos_covid.id_fact_covid IS 'Llave sustituta de la fila de hechos.';
COMMENT ON COLUMN dw.fact_casos_covid.id_registro IS 'ID_REGISTRO, dimensión degenerada: identifica el caso y permite volver a covid_historica.';
COMMENT ON COLUMN dw.fact_casos_covid.id_fecha_sintomas IS 'FECHA_SINTOMAS → dim_tiempo (rol: inicio de síntomas).';
COMMENT ON COLUMN dw.fact_casos_covid.id_fecha_ingreso IS 'FECHA_INGRESO → dim_tiempo (rol: ingreso a la unidad).';
COMMENT ON COLUMN dw.fact_casos_covid.id_fecha_resultado IS 'FECHA_RESULTADO → dim_tiempo (rol: resultado). -1 en 2022 (no existe la columna); -2 sin resultado (9999-99-99).';
COMMENT ON COLUMN dw.fact_casos_covid.id_fecha_defuncion IS 'FECHA_DEF → dim_tiempo (rol: defunción). -2 si no hubo defunción (9999-99-99).';
COMMENT ON COLUMN dw.fact_casos_covid.id_ubicacion_residencia IS 'ENTIDAD_RES + MUNICIPIO_RES → dim_ubicacion.';
COMMENT ON COLUMN dw.fact_casos_covid.id_entidad_nacimiento IS 'ENTIDAD_NAC → dim_entidad.';
COMMENT ON COLUMN dw.fact_casos_covid.id_unidad_medica IS 'CLUES, SECTOR, ENTIDAD_UM y MUNICIPIO_UM → dim_unidad_medica.';
COMMENT ON COLUMN dw.fact_casos_covid.id_paciente IS 'SEXO, EMBARAZO, HABLA_LENGUA_INDIG, INDIGENA, NACIONALIDAD y MIGRANTE → dim_paciente.';
COMMENT ON COLUMN dw.fact_casos_covid.id_pais_nacionalidad IS 'PAIS_NACIONALIDAD → dim_pais (rol: nacionalidad).';
COMMENT ON COLUMN dw.fact_casos_covid.id_pais_origen IS 'PAIS_ORIGEN → dim_pais (rol: país de origen del migrante).';
COMMENT ON COLUMN dw.fact_casos_covid.id_edad IS 'EDAD → dim_edad (la edad tal como viene, incluso 122).';
COMMENT ON COLUMN dw.fact_casos_covid.id_comorbilidad IS 'Las 10 banderas de comorbilidad y tabaquismo → dim_comorbilidad.';
COMMENT ON COLUMN dw.fact_casos_covid.id_atencion IS 'ORIGEN, TIPO_PACIENTE, NEUMONIA, INTUBADO y UCI → dim_atencion.';
COMMENT ON COLUMN dw.fact_casos_covid.id_diagnostico IS 'OTRO_CASO, TOMA_MUESTRA_LAB, RESULTADO_LAB, TOMA_MUESTRA_ANTIGENO, RESULTADO_ANTIGENO y CLASIFICACION_FINAL → dim_diagnostico.';
COMMENT ON COLUMN dw.fact_casos_covid.id_extracto IS 'archivo_origen y FECHA_ACTUALIZACION → dim_extracto.';
COMMENT ON COLUMN dw.fact_casos_covid.id_calidad IS 'Banderas de calidad calculadas en la carga → dim_calidad.';
COMMENT ON COLUMN dw.fact_casos_covid.casos IS 'Siempre 1. Sumado da el número de casos (medida aditiva).';
COMMENT ON COLUMN dw.fact_casos_covid.confirmados IS '1 si CLASIFICACION_FINAL es 1, 2 o 3 (aditiva).';
COMMENT ON COLUMN dw.fact_casos_covid.hospitalizados IS '1 si TIPO_PACIENTE = 2 (aditiva).';
COMMENT ON COLUMN dw.fact_casos_covid.ingresos_uci IS '1 si UCI = 1 (aditiva).';
COMMENT ON COLUMN dw.fact_casos_covid.intubados IS '1 si INTUBADO = 1 (aditiva).';
COMMENT ON COLUMN dw.fact_casos_covid.con_neumonia IS '1 si NEUMONIA = 1 (aditiva).';
COMMENT ON COLUMN dw.fact_casos_covid.defunciones IS '1 si hay FECHA_DEF (aditiva). Letalidad entre confirmados = sum(defunciones * confirmados) / sum(confirmados): solo cuentan las defunciones de casos confirmados.';
COMMENT ON COLUMN dw.fact_casos_covid.edad_anios IS 'EDAD como medida (no aditiva: promedio, mediana). NULL cuando la edad no es válida (122).';
COMMENT ON COLUMN dw.fact_casos_covid.dias_sintomas_a_ingreso IS 'FECHA_INGRESO - FECHA_SINTOMAS en días (no aditiva). NULL si las fechas están en desorden.';
COMMENT ON COLUMN dw.fact_casos_covid.dias_ingreso_a_resultado IS 'FECHA_RESULTADO - FECHA_INGRESO en días (no aditiva). NULL sin resultado, en 2022 o si las fechas están en desorden.';
COMMENT ON COLUMN dw.fact_casos_covid.dias_ingreso_a_defuncion IS 'FECHA_DEF - FECHA_INGRESO en días (no aditiva). NULL sin defunción o si las fechas están en desorden.';

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
