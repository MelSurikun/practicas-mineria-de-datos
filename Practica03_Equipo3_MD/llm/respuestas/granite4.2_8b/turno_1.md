**Respuesta al punto 1: Análisis, razonamiento y justificación técnica y conceptual para elegir un modelo multidimensional (modelo en copo de nieve)**

> **Elección del modelo: Copo de nieve (snowflake)**  
> *Justificación conceptual y técnica:*  
> El modelo en copo de nieve es adecuado para este conjunto de datos de casos de COVID-19 en México porque:
> - Los datos provienen de una fuente administrativa y epidemiológica con estructura jerárquica clara (entidades → municipios → localidades; categorías clínicas → subcategorías; resultados diagnósticos → clasificación final).
> - Existen jerarquías naturales y necesarias para el análisis epidemiológico (por ejemplo, entidad → municipio; tipo de paciente → hospitalizado/ambulatorio; resultado laboratorio → positivo/negativo/pendiente).
> - No se requiere una relación compleja entre dimensiones que implique sobreposición de claves o redundancias críticas que justificarían una constelación; por el contrario, las relaciones son principalmente unidireccionales y jerárquicas, típicas de datos administrativos y de salud.
> - El modelo en estrella sería suficiente si todas las dimensiones fueran tablas simples sin normalización adicional, pero dado que algunas dimensiones (por ejemplo, `dim_localizacion`) tienen jerarquías internas (entidad → municipio → localidad), y `dim_comorbilidad` incluye múltiples variables binarias que pueden agruparse en categorías clínicas, se justifica una ligera normalización (snowflake) para evitar redundancias y mejorar la claridad semántica.
> - El modelo constelación se usaría cuando varias tablas de hechos compartieran dimensiones comunes pero no hubieran jerarquías claras entre dimensiones; aquí, todas las dimensiones están claramente relacionadas con el caso (paciente, tiempo, ubicación, comorbilidad, resultado), por lo que una constelación no aporta ventaja conceptual ni estructural. Por lo tanto, **el modelo en copo de nieve es el más adecuado**: permite jerarquías claras, evita redundancias innecesarias, mantiene integridad referencial y facilita consultas epidemiológicas (por ejemplo, análisis por entidad, por mes, por grupo de edad, por presencia de comorbilidades).

---

### 1) Identificación de medidas y dimensiones

**Medidas (en `fact_covid`):**  
- `caso_confirmado`: 1 si `clasificacion_final` ∈ {1,2,3} (caso confirmado por asociación clínica o comité), 0 en caso contrario (ej. clasificación 4=inválido, 5=no realizado, 6=sospechoso, 7=negativo). *Justificación epidemiológica: la medida clave es el caso confirmado según el catálogo oficial; "sospechoso" y "negativo" no son casos confirmados para análisis epidemiológico de transmisión y mortalidad.*
- `caso_hospitalizado`: 1 si `tipo_paciente` = 2 (hospitalizado), 0 si 1 (ambulatorio). *Justificación: permite analizar tasa de hospitalización por entidad, edad, comorbilidad.*
- `caso_uc_intensivo`: 1 si `uci` = 1 (ingreso a UCI), 0 en caso contrario. *Justificación: indicador clave para gravedad clínica.*
- `defuncion`: 1 si `fecha_def` IS NOT NULL, 0 en caso contrario. *Justificación: mortalidad directa; se usa `fecha_def` como señal de defunción reportada (no se inferencia).*
- `resultado_lab_positivo`: 1 si `resultado_lab` = 1 (positivo) o `resultado_antigeno` = 1 (positivo), 0 en caso contrario (negativo o no aplica). *Justificación: permite comparar resultados de laboratorio vs. clasificación final; útil para validar consistencia entre pruebas.*

> *Nota: Todas las medidas son binarias (0/1), lo que facilita cálculos de frecuencias, tasas y comparaciones por grupos. No se usan medidas continuas (ej. número de casos brutos) como medida principal; estas se derivan de `caso_confirmado` y `defuncion` para evitar sobre-agrupación.*

**Dimensiones:**

1. `dim_tiempo`  
   - Propósito: representar el momento del evento (ingreso, sintomas, resultado, defunción) con granularidad adecuada para análisis epidemiológico (por día, semana, mes).  
   - Columnas: `id_tiempo SERIAL PK`, `fecha DATE`, `anio INT`, `mes INT`, `dia INT`, `nombre_mes VARCHAR(20)` (ej. "Enero"), `dia_semana INT` (1=lunes, 7=domingo), `nombre_dia VARCHAR(20)` (ej. "lunes"), `episodio_semanal INT` (opcional: si se quiere agrupar por semana epidemiológica, se puede calcular como `FLOOR((fecha - '2022-01-01'::date)/7) + 1`, pero se propone usar `mes` y `anio` como unidad mínima para evitar sobre-agrupación; sin embargo, para análisis de tendencias, se incluye `episodio_semanal` como campo derivado), `trimestre INT`, `tipo_fecha VARCHAR(50)` (ej. "ingreso", "resultado", "defuncion", "actualizacion").  
   - *Granularidad del tiempo:* **día** (fecha exacta). Se elige día como unidad mínima porque:
     - Los datos incluyen `fecha_ingreso`, `fecha_sintomas`, `fecha_resultado`, `fecha_def` (todas en formato AAAA-MM-DD o NULL). Analizar por día permite estudiar pico de casos, incubación, duración de sintomas, relación entre fecha de resultado y fecha de ingreso.
     - No se agrupa por semana o mes como unidad de hecho; el hecho (`fact_covid`) está en nivel de caso (un fila por `id_registro`), por lo que la dimensión `dim_tiempo` debe permitir asociar el caso con **cada fecha relevante** (ingreso, sintomas, resultado, defunción). Por lo tanto, se crean **tres claves de tiempo** en `fact_covid`: `id_fecha_ingreso_dim`, `id_fecha_sintomas_dim`, `id_fecha_resultado_dim`, `id_fecha_def_dim` (cada una referencia a `dim_tiempo`). Esto permite análisis por fecha de ingreso (para estudiar gravedad), por fecha de resultado (para precisión diagnóstica), y por fecha de defunción (para mortalidad). `fecha_actualizacion` se usa solo para seguimiento de alimentación y no se incluye como dimensión del hecho; se mantiene en `fact_covid` si se desea, pero no como clave de dimensión del hecho.
     - *Límite de enriquecimiento:* El tiempo se enriquece hasta el nivel de día (no se añaden días ficticios ni se proyectan fechas faltantes). Si `fecha_ingreso` es NULL, no se crea clave para `id_fecha_ingreso_dim` (se omite o se usa NULL con restricción; pero en la práctica, se crea fila en `dim_tiempo` solo si hay fecha válida; si falta, no se hace referencia). Se evita inferir fechas (ej. fecha de sintomas = fecha_ingreso - 2 días), porque eso introduciría incertidumbre no reportada.

2. `dim_localizacion` (snowflake ligera: jerarquía entidad → municipio → localidad)  
   - Propósito: ubicar al paciente en el ámbito geográfico (entidad de nacimiento, entidad de residencia, municipio de residencia, y opcionalmente localidad de residencia). Se incluye `pais_nacionalidad` y `pais_origen` como campos de ubicación (con valores 99=no especificado, 97=no aplica, etc.).  
   - Columnas: `id_loc SERIAL PK`, `entidad_nac INT` (clave del catálogo ENTIDADES), `entidad_res INT` (clave del catálogo ENTIDADES), `municipio_res INT` (clave del catálogo MUNICIPIOS), `localidad_res INT` (valor numérico del catálogo LOCALIDAD_RES; aunque no está en diccionario, está en CSV y se mantiene), `pais_nacionalidad TEXT` (con valores como "México", "Estados Unidos", etc., y 99=no especificado), `pais_origen TEXT` (con 97=no aplica).  
   - Jerarquía:  
     - `entidad` (ej. 01 AGUASCALIENTES) → `municipio` (ej. 001 AGUASCALIENTES) → `localidad` (ej. código interno de localidad).  
     - `pais_nacionalidad` y `pais_origen` son atributos independientes (no jerárquicos entre sí), pero se almacenan junto a la ubicación.  
   - *Granularidad espacial:* **municipio de residencia + entidad de residencia + localidad de residencia** (nivel más detallado disponible). No se crea jerarquía adicional (ej. región sanitaria), porque no está en los datos ni en los catálogos. Se respeta el catálogo oficial: `entidad` y `municipio` tienen claves numéricas (01-32 para entidades, 001-999 para municipios), `localidad_res` es entero (probablemente código interno).  
   - *Límite de enriquecimiento:* Se enriquece hasta `municipio_res` y `localidad_res`; no se proyecta `entidad_um` (unidad médica) como ubicación geográfica principal (la unidad médica está en `entidad_um`, pero la ubicación del paciente es `entidad_res`/`municipio_res`/`localidad_res`, que es la ubicación epidemiológica relevante para análisis de transmisión). `entidad_um` se usa solo para posible análisis de fuente (USMER vs. no USMER), pero no como parte de `dim_localizacion`; se maneja en `dim_resultado` o se incluye como atributo opcional si se desea, pero para evitar redundancia, se separa: `dim_localizacion` = ubicación del paciente; `dim_resultado` incluye `origen` (USMER/NO USMER) si se quiere analizar fuente.

3. `dim_paciente`  
   - Propósito: capturar atributos del paciente relevantes para análisis epidemiológico (sexo, edad, nacionalidad, embarazo, lengua indígena, indigena, migrante). Evita repetir múltiples valores binarios en cada hecho.  
   - Columnas: `id_paciente SERIAL PK`, `sexo CHAR(1)` (1='MUJER', 2='HOMBRE'; 99 no se almacena aquí porque 99=no especificado se trata como "no disponible" y no se usa como valor de paciente; si `sexo`=99, se omite o se marca como "desconocido" en análisis), `edad INT` (0-120; 99 no es edad, 99=no especificado para categorías como ORIGEN; para edad, 99 no aplica; si edad es 99 en CSV, se trata como faltante y no se incluye en dimensión; se guarda en `fact_covid` como `edad` pero solo se usa si ≠99), `embarazo INT` (1/2/99), `habla_lengua_indig INT` (1/2/99), `indigena INT` (1/2/99), `nacionalidad INT` (1=mexicana, 2=extranjera, 99=no especificado), `migrante INT` (1/2/99).  
   - *Nota:* `edad` se almacena como entero; si en CSV es 99 (faltante), se no se crea fila en `dim_paciente` para ese paciente? No: `dim_paciente` se crea por paciente (por `id_registro`), pero si `edad`=99, se almacena como 99 en `dim_paciente` (pero en análisis se excluye o se marca como "desconocido"). Mejor: `dim_paciente` incluye todos los atributos relevantes; los valores 99 se aceptan como "no especificado", pero en consultas se filtra si se necesita edad precisa.  
   - *Granularidad temática:* **paciente individual** (nivel de caso). No se agrupa por grupo de edad (ej. 0-17, 18-64, >65) en la dimensión; se almacena `edad` exacta y se permite agrupar en consultas (ej. `FLOOR(edad/10)` para decenas). Esto evita perder información y permite análisis fino.

4. `dim_comorbilidad` (snowflake ligera: agrupar variables binarias en categorías clínicas)  
   - Propósito: agrupar las 10 variables binarias (diabetes, epoc, asma, inmunosupr, hipertension, obesidad, renal_cronica, cardiovascular, tabaquismo, otra_com) en categorías clínicas para evitar redundancia y facilitar análisis (ej. "patologías cardiovasculares", "patologías respiratorias", "inmunosupresión"). Sin embargo, se mantiene la precisión binaria porque el análisis epidemiológico suele requerir presencia/ausencia de cada condición. Se propone una dimensión con todas las variables binarias como columnas (por simplicidad y evitar transformación innecesaria), pero con jerarquía mínima: no se crea sub-dimensión adicional; se usa una sola tabla `dim_comorbilidad` con todas las variables.  
   - Columnas: `id_comorbilidad SERIAL PK`, `diabetes INT` (1/2/99), `epoc INT` (1/2/99), `asma INT` (1/2/99), `inmusupr INT` (1/2/99), `hipertension INT` (1/2/99), `obesidad INT` (1/2/99), `renal_cronica INT` (1/2/99), `cardiovascular INT` (1/2/99), `tabaquismo INT` (1/2/99), `otra_com INT` (1/2/99). *No se incluye `otra_caso` en la dimensión de comorbilidad; `otra_caso` es un indicador de contacto y se trata en `dim_resultado` o como medida si se desea.*  
   - *Granularidad temática:* **nivel de condición clínica binaria** (cada variable es 1/2/99). No se agrupa automáticamente (ej. "patologías respiratorias" = epoc+asma+neumonía), porque `neumonía` y `intubado` son parte del resultado clínico y no siempre indican comorbilidad previa; `neumonía` se incluye en `dim_resultado` (ver abajo). Por lo tanto, `dim_comorbilidad` contiene solo las variables binarias de diagnóstico previo (sin `neumonía`, `intubado`, `clasificacion_final`).  
   - *Redundancia evitada:* En lugar de repetir 10 valores binarios en cada `fact_covid`, se hace referencia a `id_comorbilidad_dim`, evitando escribir los 10 valores en el hecho.

5. `dim_resultado` (incluye origen, tipo paciente, resultado laboratorio, resultado antígeno, clasificación final, UCI)  
   - Propósito: capturar el resultado diagnóstico y el estado clínico del caso (ingreso hospitalizado/ambulatorio, resultado de pruebas, clasificación final, UCI). Agrupa valores catálogos relevantes para análisis de gravedad y diagnóstico.  
   - Columnas: `id_res INT PK` (usar SERIAL), `origen INT` (1=USMER, 2=FUERA DE USMER, 99=NO ESPECIFICADO), `tipo_paciente INT` (1=AMBULATORIO, 2=HOSPITALIZADO, 99=NO ESPECIFICADO), `resultado_lab INT` (1=POSITIVO, 2=NO POSITIVO, 3=PENDIENTE, 4=NO ADECUADO, 97=NO APLICA), `resultado_antigeno INT` (1=POSITIVO, 2=NEGATIVO, 97=NO APLICA), `clasificacion_final INT` (1-7 según catálogo), `uci INT` (1=SI UCI, 2=NO UCI, 99=NO ESPECIFICADO), `otra_caso INT` (1=SI contacto, 2=NO, 99=NO ESPECIFICADO) — se incluye `otra_caso` aquí porque es parte del resultado clínico y no es comorbilidad previa.  
   - *Jerarquía interna (snowflake ligera):* No se crea sub-tablas para `resultado_lab` o `clasificacion_final`, porque son valores simples (enteros con catálogo claro). Si se quisiera jerarquía (ej. clasificación 1 y 2 = confirmado, 3 = confirmado, 4-5 = no confirmado, 6-7 = sospecha), se podría crear una tabla `dim_clasificacion` con `id_clasificacion` y `nivel_confirmacion` (ej. 1=confirmado, 2=no confirmado), pero para evitar sobre-modelado, se mantiene `clasificacion_final` como valor directo en `dim_resultado`. La jerarquía se expresa en la lógica de medida (`caso_confirmado` se define a partir de `clasificacion_final`).  
   - *Granularidad temática:* **resultado clínico del caso** (origen, tipo paciente, resultados de pruebas, clasificación, UCI, contacto). No se agrupa; se almacena el valor reportado.
   - *Redundancia evitada:* `fact_covid` no almacena `origen`, `tipo_paciente`, `resultado_lab`, etc.; se hace referencia a `dim_resultado`, evitando repetir valores.

> *Situaciones de redundancias evitadas:*  
> - En la tabla original `covid_historica`, cada caso tiene valores para `entidad_res`, `municipio_res`, `localidad_res`, `sexo`, `edad`, `resultado_lab`, `clasificacion_final`, etc. Si se guardara todo directamente en `fact_covid`, se repetiría `entidad_res` y `municipio_res` en cada fila, y se perdería la posibilidad de análisis por ubicación. Al usar dimensiones, cada ubicación/paciente/resultado se almacena una sola vez (por clave), y `fact_covid` solo contiene claves (`id_residencia_dim`, `id_comorbilidad_dim`, `id_paciente`, `id_res`, `id_fecha_ingreso_dim`, etc.), evitando redundancia.  
> - `LOCALIDAD_RES` no está en el diccionario, pero está en CSV; se incluye en `dim_localizacion` como `localidad_res` (entero), porque es relevante para ubicación del paciente. No se omite; se respeta el dato.  
> - Los valores 97, 98, 99 en catálogos se manejan como valores válidos (97=NO APLICA, 98=SE IGNORA, 99=NO ESPECIFICADO). En dimensiones, se almacenan tal cual (ej. `sexo`=99 significa "no especificado"), pero en consultas se puede filtrar o agrupar según necesidad (ej. analizar solo casos con `sexo`≠99 si se necesita análisis por género). Esto respeta la incertidumbre explícita ("SE IGNORA" = incertidumbre explícita; "NO ESPECIFICADO" = problema de captura). No se convierten a NULL, porque los valores 99 tienen significado epidemiológico.

> *Granularidad del tiempo y espacio:*  
> - **Tiempo:** granularidad mínima = **día** (`fecha` en `dim_tiempo`). Se crea una fila en `dim_tiempo` por cada fecha válida (AAAA-MM-DD) que aparezca en cualquiera de `fecha_ingreso`, `fecha_sintomas`, `fecha_resultado`, `fecha_def`. Si un caso tiene `fecha_ingreso` = '2023-03-15', se busca o crea la fila en `dim_tiempo` con `fecha='2023-03-15'`. El hecho `fact_covid` tendrá tres claves de tiempo: `id_fecha_ingreso_dim` (referencia a `dim_tiempo` donde `fecha=fecha_ingreso`), `id_fecha_sintomas_dim` (si `fecha_sintomas` ≠ NULL), `id_fecha_resultado_dim` (si `fecha_resultado` ≠ NULL), `id_fecha_def_dim` (si `fecha_def` ≠ NULL). Esto permite análisis por fecha de ingreso (ej. tiempo desde notificación hasta ingreso), por fecha de resultado (precisión diagnóstica), y por fecha de defunción (mortalidad). No se agrupa el hecho por semana; la semana se deriva en consulta si se desea (ej. `EXTRACT(WEEK FROM fecha)`). El límite de enriquecimiento: no se añaden días faltantes ni se proyectan fechas (ej. si `fecha_ingreso` es NULL, no se crea clave; si `fecha_sintomas` es NULL, no se hace referencia). Solo se enriquece con la fecha exacta reportada.  
> - **Espacio:** granularidad mínima = **municipio de residencia + entidad de residencia + localidad de residencia**. `dim_localizacion` almacena `entidad_res`, `municipio_res`, `localidad_res` como claves jerárquicas (ej. entidad=01, municipio=001, localidad=10). No se baja a nivel de colonia ni se sube a nivel de entidad; se respeta el nivel del catálogo. El límite de enriquecimiento: no se busca municipios faltantes ni se proyecta `entidad_um` como ubicación; `entidad_um` se usa en `dim_resultado` si se quiere analizar por fuente (USMER vs. no USMER), pero no se mezcla con `dim_localizacion`. Por ejemplo, un caso con `entidad_um`=01 y `entidad_res`=01 puede estar en el mismo municipio, pero la ubicación epidemiológica del paciente es `entidad_res`/`municipio_res`, por lo que `dim_localizacion` usa `res` (residencia), no `um` (unidad médica). Esto evita redundancia y respeta la semántica epidemiológica (ubicación del paciente, no ubicación de la unidad).

> *Granularidad, tipos, grupos o formas de dimensiones temáticas:*  
> - `dim_tiempo`: unidades = día (fecha exacta); permite derivar semana, mes, trimestre en consulta (`episodio_semanal`, `mes`, `trimestre`). No se almacena semana como clave; se calcula.  
> - `dim_localizacion`: jerarquía clara (entidad → municipio → localidad); se almacenan claves numéricas (`entidad_res`, `municipio_res`, `localidad_res`) y nombres (`nombre_est`, `nombre_mun`, `nombre_loc`) para presentación. `pais_nacionalidad` y `pais_origen` se almacenan como texto con valores 99=no especificado; se usan en consultas para filtrar extranjeros.  
> - `dim_paciente`: atributos binarios (sexo, embarazo, etc.) con valores 1/2/99; `edad` como entero (0-120, 99 no es edad). No se agrupa en grupos de edad en la dimensión; se permite agrupar en consulta (ej. `edad_grupo = FLOOR(edad/10)`).  
> - `dim_comorbilidad`: 10 variables binarias (1/2/99); se almacenan tal cual. No se crea sub-dimensión como "patologías respiratorias"; se usa la medida `caso_hospitalizado` y `caso_uc_intensivo` para análisis de gravedad, y `dim_comorbilidad` para identificar presencia de condiciones.  
> - `dim_resultado`: valores catálogos (origen, tipo paciente, resultado_lab, resultado_antigeno, clasificacion_final, uci, otra_caso); se almacenan tal cual (1-2-3-4-97, etc.). La jerarquía implícita (ej. clasificación 1-2 = confirmado, 3 = confirmado, 4-5 = no confirmado, 6-7 = sospecha) se maneja en la definición de medida `caso_confirmado`, no en la dimensión. Esto evita sobre-modelado.

> *Límite razonable de enriquecimiento:*  
> - **Tiempo:** se enriquece hasta el nivel de día (fecha exacta reportada). No se añaden días faltantes ni se inferen fechas (ej. si `fecha_ingreso` es NULL, no se asume `fecha_sintomas` = `fecha_ingreso` - 2 días; se respeta la ausencia). Si `fecha_ingreso` es conocida y `fecha_sintomas` es NULL, no se crea `id_fecha_sintomas_dim`; se omite la referencia.  
> - **Espacio:** se enriquece hasta `municipio_res` + `localidad_res`. No se busca municipios faltantes ni se proyecta `entidad_um` como ubicación; `entidad_um` se usa solo en `dim_resultado` (como `origen` = USMER/NO USMER), porque la ubicación del paciente es `entidad_res`/`municipio_res`. No se baja a nivel de colonia ni se sube a nivel de entidad nacional; se respeta el nivel del catálogo.  
> - **Dimensiones temáticas:** no se crea sub-dimensiones adicionales (ej. `dim_clasificacion` separada de `dim_resultado`). Todas las dimensiones son necesarias y jerárquicas mínimas. El enriquecimiento se limita a usar los valores reportados en los catálogos oficiales (1-2-3-4-97-98-99) y no a inferir categorías no reportadas. Por ejemplo, no se crea "patologías cardiovasculares" como clave en `dim_localizacion`; se usa `cardiovascular` como variable binaria en `dim_comorbilidad` y `clasificacion_final` como valor en `dim_resultado`.

---

### Tablas del modelo (hechos y dimensiones) con sus columnas

> *Nota: Todas las claves primarias son SERIAL (autoincremental). Las claves foráneas (`id_*`) en `fact_covid` referencian las PK de las dimensiones. Los valores 99, 97, 98 se almacenan tal cual en las dimensiones (respetando los catálogos); en consultas se puede filtrar según necesidad epidemiológica (ej. excluir 99 si se necesita dato preciso).*

1. `dim_tiempo`  
   - `id_tiempo SERIAL PRIMARY KEY`  
   - `fecha DATE` (fecha exacta, ej. '2023-03-15')  
   - `anio INT` (ej. 2023)  
   - `mes INT` (1-12)  
   - `dia INT` (1-31)  
   - `nombre_mes VARCHAR(20)` (ej. 'Marzo')  
   - `dia_semana INT` (1=lunes, 7=domingo) — calculado como `EXTRACT(DOW FROM fecha)::INT + (CASE WHEN EXTRACT(DOW FROM fecha)=0 THEN 6 ELSE 0 END)` para que 1=lunes, 7=domingo (PostgreSQL: `EXTRACT(DOW FROM fecha)` da 0=lunes? Mejor: usar `TO_CHAR(fecha, 'DOW')` o calcular; para simplicidad, se almacena como `dia_semana` calculado en carga: `CASE WHEN EXTRACT(DOW FROM fecha)=0 THEN 7 ELSE EXTRACT(DOW FROM fecha) END` donde 1=lunes, 7=domingo. Se define en carga como `dia_semana = (EXTRACT(DOW FROM fecha)::INT + 6) % 7 + 1` para que 1=lunes, 7=domingo. (En práctica, se calcula en la tabla o en consulta; aquí se incluye como columna para facilitar análisis).  
   - `nombre_dia VARCHAR(20)` (ej. 'lunes') — se calcula como `TO_CHAR(fecha, 'DOW', 'L')` o similar; para simplicidad, se almacena como texto ('lunes', 'martes', etc.).  
   - `episodio_semanal INT` — número de semana epidemiológica (ej. si `fecha` = '2023-03-15', semana = FLOOR((fecha - '2022-01-01'::date)/7) + 1; se calcula en carga). *Se incluye para permitir agrupación por semana si se desea, pero el hecho no se agrupa por semana; la dimensión permite referenciar por día.*  
   - `trimestre INT` (1-4) — calculado como `FLOOR((mes-1)/3) + 1`  
   - `tipo_fecha VARCHAR(50)` — 'INGRESO', 'SINTOMAS', 'RESULTADO', 'DEFUNCION', 'ACTUALIZACION' — se usa para identificar qué fecha del caso se está referenciando en el hecho (ej. `id_fecha_ingreso_dim` referencia a `dim_tiempo` con `tipo_fecha='INGRESO'`, etc.). *Nota: `tipo_fecha` se almacena en `dim_tiempo` para permitir diferenciar entre fecha de ingreso, sintomas, resultado, defunción; pero en realidad, `dim_tiempo` es genérica (fecha), y `fact_covid` lleva la clave de la dimensión correspondiente. Para evitar duplicar `fecha`, se hace referencia a `dim_tiempo` con la fecha exacta; `tipo_fecha` se almacena en `fact_covid` si se necesita distinguir qué fecha del caso se está usando (ej. `id_fecha_ingreso_dim` = clave de `dim_tiempo` donde `fecha=fecha_ingreso` y `tipo_fecha='INGRESO'`). Sin embargo, para simplificar, se omite `tipo_fecha` en `dim_tiempo` y se usa solo `fecha`; la distinción se hace en `fact_covid` mediante claves separadas (`id_fecha_ingreso_dim`, etc.). *Corrección: en la referencia del enunciado, `dim_tiempo` no incluye `tipo_fecha`; incluye `fecha`, `anio`, etc. Por lo tanto, `dim_tiempo` es genérica (fecha), y `fact_covid` tiene tres claves a `dim_tiempo` (ingreso, sintomas, resultado, defuncion). Así que `dim_tiempo` no necesita `tipo_fecha`; solo `fecha`. Para evitar ambigüedad, se elimina `tipo_fecha` de `dim_tiempo` y se mantiene solo `fecha`, `anio`, `mes`, `dia`, `episodio_semanal`, `trimestre`. `tipo_fecha` se identifica en `fact_covid` mediante las claves (`id_fecha_ingreso_dim`, etc.). Por lo tanto, la tabla `dim_tiempo` es: `id_tiempo`, `fecha`, `anio`, `mes`, `dia`, `episodio_semanal`, `trimestre`. (Verificación: el ejemplo de referencia incluye `dia_semana` y `nombre_dia`, así que se incluye para presentación. Se mantiene `dia_semana` y `nombre_dia` como derivados.)  
   > *Revisión final para `dim_tiempo`:*  
   > - `id_tiempo SERIAL PK`  
   > - `fecha DATE`  
   > - `anio INT`  
   > - `mes INT` (1-12)  
   > - `dia INT` (1-31)  
   > - `dia_semana INT` (1=lunes, 7=domingo) — calculado en carga  
   > - `nombre_dia VARCHAR(20)` ('lunes', etc.) — calculado en carga  
   > - `episodio_semanal INT` — número de semana (ej. 1 para primera semana de 2022), calculado en carga  
   > - `trimestre INT` (1-4), calculado en carga  
   > *(No se incluye `tipo_fecha` en `dim_tiempo`; `tipo_fecha` se identifica en `fact_covid` mediante las claves `id_fecha_ingreso_dim`, etc.)*

2. `dim_localizacion`  
   - `id_loc SERIAL PK`  
   - `entidad_nac INT` (clave del catálogo ENTIDADES, ej. 01-32, 36=EE.UU., 97=NO APLICA, 98=SE IGNORA, 99=NO ESPECIFICADO)  
   - `entidad_res INT` (clave del catálogo ENTIDADES)  
   - `municipio_res INT` (clave del catálogo MUNICIPIOS, ej. 001-999)  
   - `localidad_res INT` (código de localidad, del CSV)  
   - `nombre_est VARCHAR(100)` — nombre de la entidad (ej. "Aguascalientes")  
   - `nombre_mun VARCHAR(100)` — nombre del municipio (ej. "Aguascalientes")  
   - `nombre_loc VARCHAR(100)` — nombre de la localidad (si está en catálogo; si no, se puede llenar con nombre reportado, pero no se requiere en modelo; se incluye para presentación)  
   - `pais_nacionalidad TEXT` (ej. "México", "Estados Unidos", "Canadá", "99=NO ESPECIFICADO")  
   - `pais_origen TEXT` (ej. "Estados Unidos", "99=NO APLICA")  
   > *Nota: `nombre_est`, `nombre_mun`, `nombre_loc` se llenan desde los catálogos (201128 Catalogos.xlsx) durante la carga; si falta nombre, se deja NULL o se usa clave. Para el modelo, se almacenan como texto para presentación.*

3. `dim_paciente`  
   - `id_paciente SERIAL PK`  
   - `sexo CHAR(1)` — '1'='MUJER', '2'='HOMBRE'; '99'='NO ESPECIFICADO' (almacenado tal cual)  
   - `edad INT` — 0-120; '99' no es edad (99=NO ESPECIFICADO para categorías), pero si `edad`=99 en CSV, se almacena como 99 (pero en análisis se excluye si se necesita edad precisa)  
   - `embarazo INT` — 1/2/99  
   - `habla_lengua_indig INT` — 1/2/99  
   - `indigena INT` — 1/2/99  
   - `nacionalidad INT` — 1=MEXICANA, 2=EXTRANJERA, 99=NO ESPECIFICADO  
   - `migrante INT` — 1/2/99 (de catálogo)  
   > *Nota: `migrante` está en el diccionario oficial (37), así que se incluye en `dim_paciente`.*

4. `dim_comorbilidad`  
   - `id_comorbilidad SERIAL PK`  
   - `diabetes INT` — 1/2/99  
   - `epoc INT` — 1/2/99  
   - `asma INT` — 1/2/99  
   - `inmusupr INT` — 1/2/99  
   - `hipertension INT` — 1/2/99  
   - `obesidad INT` — 1/2/99  
   - `renal_cronica INT` — 1/2/99  
   - `cardiovascular INT` — 1/2/99  
   - `tabaquismo INT` — 1/2/99  
   - `otra_com INT` — 1/2/99 *(nota: `otra_caso` se incluye aquí; `otra_com` es "otras comorbilidades", pero `otra_caso` es contacto, se incluye en `dim_resultado` o `dim_comorbilidad`; por claridad, se incluye `otra_caso` en `dim_resultado` y `otra_com` en `dim_comorbilidad`; ver abajo)*  
   > *Corrección: en el diccionario, columna 26 es `OTRA_COM` (otras comorbilidades), y columna 31 es `OTRO_CASO` (contacto). `OTRA_COM` pertenece a comorbilidades, `OTRO_CASO` a resultado clínico. Por lo tanto: `dim_comorbilidad` incluye `diabetes`, `epoc`, `asma`, `inmusupr`, `hipertension`, `obesidad`, `renal_cronica`, `cardiovascular`, `tabaquismo`, `otra_com` (10 variables). `dim_resultado` incluye `clasificacion_final`, `resultado_lab`, `resultado_antigeno`, `tipo_paciente`, `origen`, `uci`, `otro_caso`. Así se evita duplicar `otra_com` en dos dimensiones.*

5. `dim_resultado`  
   - `id_res SERIAL PK`  
   - `origen INT` — 1=USMER, 2=FUERA DE USMER, 99=NO ESPECIFICADO  
   - `tipo_paciente INT` — 1=AMBULATORIO, 2=HOSPITALIZADO, 99=NO ESPECIFICADO  
   - `resultado_lab INT` — 1=POSITIVO, 2=NO POSITIVO, 3=PENDIENTE, 4=NO ADECUADO, 97=NO APLICA  
   - `resultado_antigeno INT` — 1=POSITIVO, 2=NEGATIVO, 97=NO APLICA  
   - `clasificacion_final INT` — 1-7 (1=confirmado asociación, 2=confirmado comité, 3=confirmado, 4=inválido, 5=no realizado, 6=sospechoso, 7=negativo)  
   - `uci INT` — 1=SI UCI, 2=NO UCI, 99=NO ESPECIFICADO  
   - `otro_caso INT` — 1=SI contacto, 2=NO, 99=NO ESPECIFICADO  
   > *Nota: `otra_com` (otras comorbilidades) no va aquí; va en `dim_comorbilidad`. `otro_caso` va aquí porque es parte del resultado clínico (contacto con otro caso).*

6. `fact_covid`  
   - `id_fact_covid SERIAL PRIMARY KEY`  
   - `id_registro VARCHAR(25)` — mismo `id_registro` de `covid_historica` (texto, sin duplicados)  
   - `id_fecha_ingreso_dim INT REFERENCES dim_tiempo(id_tiempo)` — clave a `dim_tiempo` donde `fecha = fecha_ingreso` (si `fecha_ingreso` ≠ NULL)  
   - `id_fecha_sintomas_dim INT REFERENCES dim_tiempo(id_tiempo)` — clave a `dim_tiempo` donde `fecha = fecha_sintomas` (si `fecha_sintomas` ≠ NULL)  
   - `id_fecha_resultado_dim INT REFERENCES dim_tiempo(id_tiempo)` — clave a `dim_tiempo` donde `fecha = fecha_resultado` (si `fecha_resultado` ≠ NULL)  
   - `id_fecha_def_dim INT REFERENCES dim_tiempo(id_tiempo)` — clave a `dim_tiempo` donde `fecha = fecha_def` (si `fecha_def` ≠ NULL)  
   - `id_residencia_dim INT REFERENCES dim_localizacion(id_loc)` — clave a `dim_localizacion` donde `entidad_res`, `municipio_res`, `localidad_res` coinciden (se crea fila en `dim_localizacion` por `entidad_res`/`municipio_res`/`localidad_res`; si hay duplicado, se reutiliza)  
   - `id_paciente INT REFERENCES dim_paciente(id_paciente)` — clave a `dim_paciente` (se crea fila en `dim_paciente` por paciente; si `sexo`=99, se almacena como 99)  
   - `id_comorbilidad_dim INT REFERENCES dim_comorbilidad(id_comorbilidad)` — clave a `dim_comorbilidad` (se crea fila por combinación de las 10 variables binarias)  
   - `id_resultado_dim INT REFERENCES dim_resultado(id_res)` — clave a `dim_resultado` (se crea fila por combinación de `origen`, `tipo_paciente`, `resultado_lab`, `resultado_antigeno`, `clasificacion_final`, `uci`, `otro_caso`)  
   - `caso_confirmado INT` — 1 si `clasificacion_final` ∈ {1,2,3} (confirmado por asociación o comité o confirmado), 0 en caso contrario (4=inválido, 5=no realizado, 6=sospechoso, 7=negativo). *Se calcula en carga o como medida en consulta; pero como medida en tabla de hechos, se almacena como 0/1 para facilitar agregación.*  
   - `caso_hospitalizado INT` — 1 si `tipo_paciente` = 2 (HOSPITALIZADO), 0 si 1 (AMBULATORIO), 0 si 99 (NO ESPECIFICADO; se considera no hospitalizado si no se especifica).  
   - `caso_uc_intensivo INT` — 1 si `uci` = 1 (SI UCI), 0 en caso contrario (2=NO UCI, 99=NO ESPECIFICADO; se considera no UCI si 99).  
   - `defuncion INT` — 1 si `fecha_def` IS NOT NULL, 0 en caso contrario.  
   - `resultado_lab_positivo INT` — 1 si `resultado_lab` = 1 (POSITIVO) o `resultado_antigeno` = 1 (POSITIVO), 0 en caso contrario (2=NEGATIVO, 3=PENDIENTE, 4=NO ADECUADO, 97=NO APLICA). *Se calcula en carga; si `resultado_lab`=3 (pendiente) o `resultado_antigeno`=97 (no aplica), se considera 0 para "resultado positivo reportado" (es decir, solo se cuenta como positivo si el resultado ya está reportado como positivo).*  
   > *Nota: `archivo_origen` no se incluye en `fact_covid`; se puede guardar en una tabla separada si se necesita trazabilidad, pero no es parte del modelo multidimensional de hechos/dimensiones. El modelo se enfoca en análisis epidemiológico; `archivo_origen` es metadato de carga y no es dimensión ni medida clave.*

> **Resumen de tablas (nombre exacto y columnas):**

- `dim_tiempo`: `id_tiempo`, `fecha`, `anio`, `mes`, `dia`, `dia_semana`, `nombre_dia`, `episodio_semanal`, `trimestre`
- `dim_localizacion`: `id_loc`, `entidad_nac`, `entidad_res`, `municipio_res`, `localidad_res`, `nombre_est`, `nombre_mun`, `nombre_loc`, `pais_nacionalidad`, `pais_origen`
- `dim_paciente`: `id_paciente`, `sexo`, `edad`, `embarazo`, `habla_lengua_indig`, `indigena`, `nacionalidad`, `migrante`
- `dim_comorbilidad`: `id_comorbilidad`, `diabetes`, `epoc`, `asma`, `inmusupr`, `hipertension`, `obesidad`, `renal_cronica`, `cardiovascular`, `tabaquismo`, `otra_com`
- `dim_resultado`: `id_res`, `origen`, `tipo_paciente`, `resultado_lab`, `resultado_antigeno`, `clasificacion_final`, `uci`, `otro_caso`
- `fact_covid`: `id_fact_covid`, `id_registro`, `id_fecha_ingreso_dim`, `id_fecha_sintomas_dim`, `id_fecha_resultado_dim`, `id_fecha_def_dim`, `id_residencia_dim`, `id_paciente`, `id_comorbilidad_dim`, `id_resultado_dim`, `caso_confirmado`, `caso_hospitalizado`, `caso_uc_intensivo`, `defuncion`, `resultado_lab_positivo`

> **Explicación breve de las claves en `fact_covid`:**
> - `id_residencia_dim`: referencia a `dim_localizacion` usando `entidad_res`, `municipio_res`, `localidad_res` del caso (si hay duplicado en `dim_localizacion`, se reutiliza la misma fila; se crea `dim_localizacion` con todas las combinaciones únicas de `entidad_res`/`municipio_res`/`localidad_res`).
> - `id_paciente`: referencia a `dim_paciente` usando `sexo`, `edad`, `embarazo`, etc. (si `edad`=99, se almacena como 99; en consulta se puede filtrar si se necesita edad precisa).
> - `id_comorbilidad_dim`: referencia a `dim_comorbilidad` usando las 10 variables binarias (si alguna es 99, se almacena como 99; la dimensión incluye todas las combinaciones).
> - `id_resultado_dim`: referencia a `dim_resultado` usando `origen`, `tipo_paciente`, `resultado_lab`, `resultado_antigeno`, `clasificacion_final`, `uci`, `otro_caso` (si alguna es 99, se almacena como 99).
> - Las tres claves de tiempo (`id_fecha_ingreso_dim`, etc.) referencian `dim_tiempo` con la fecha exacta del evento (si la fecha es NULL, no se hace referencia; en la carga se omite la clave o se deja NULL, pero en la práctica se crea fila en `dim_tiempo` solo para fechas válidas y se hace referencia solo si la fecha no es NULL).

> **Límite razonable de enriquecimiento respetado:**
> - Tiempo: solo se usa la fecha reportada (día); no se infiere ni se añade día faltante.
> - Espacio: solo se usa `entidad_res`/`municipio_res`/`localidad_res`; no se busca municipios faltantes ni se sube a nivel nacional. `entidad_um` se usa solo en `dim_resultado` como `origen` (USMER/NO USMER), no como parte de `dim_localizacion`.
> - Dimensiones: no se crea sub-dimensiones innecesarias; se usan jerarquías naturales (entidad → municipio → localidad; tipo paciente → hospitalizado/ambulatorio).

> **Justificación final resumida:** El modelo en copo de nieve es adecuado porque:
> - Responde a la jerarquía clínica y geográfica natural de los datos epidemiológicos.
> - Evita redundancia al almacenar valores catálogos en dimensiones y referencias en hechos.
> - Permite granularidad adecuada: día para tiempo (precisión necesaria para análisis de incubación y mortalidad), municipio+localidad para espacio (precisión epidemiológica sin sobre-modelado).
> - Respeta los catálogos oficiales (97=NO APLICA, 98=SE IGNORA, 99=NO ESPECIFICADO como valores válidos), evitando convertirlos a NULL.
> - No sobre-modela (no se crea `dim_clasificacion` separada; se define `caso_confirmado` a partir de `clasificacion_final` en la medida).
> - El límite de enriquecimiento es claro: usar solo datos reportados en fechas y ubicaciones; no inferir ni proyectar.

---

**Lista final de tablas del modelo (en orden sugerido):**

1. `dim_tiempo` — `id_tiempo`, `fecha`, `anio`, `mes`, `dia`, `dia_semana`, `nombre_dia`, `episodio_semanal`, `trimestre`
2. `dim_localizacion` — `id_loc`, `entidad_nac`, `entidad_res`, `municipio_res`, `localidad_res`, `nombre_est`, `nombre_mun`, `nombre_loc`, `pais_nacionalidad`, `pais_origen`
3. `dim_paciente` — `id_paciente`, `sexo`, `edad`, `embarazo`, `habla_lengua_indig`, `indigena`, `nacionalidad`, `migrante`
4. `dim_comorbilidad` — `id_comorbilidad`, `diabetes`, `epoc`, `asma`, `inmusupr`, `hipertension`, `obesidad`, `renal_cronica`, `cardiovascular`, `tabaquismo`, `