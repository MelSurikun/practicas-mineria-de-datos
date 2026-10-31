# Notas de lectura de las respuestas de los LLM

Lectura completa de cada turno, con el número de línea del archivo `llm/respuestas/<corrida>/turno_N.md`. Es el insumo de la parte cualitativa del Bloque 2; lo medible (SQL que corre, tablas, llaves, cobertura) está en `resumen.csv` y `cobertura.csv`.

Cómo leer las etiquetas:

- **[ALUCINACIÓN]**: afirma algo que no está en el contexto o que es falso sobre los datos, sobre SQL o sobre el dominio.
- **[CONTRADICCIÓN]**: choca con lo que el mismo modelo dijo antes, o con una regla explícita del prompt.
- **[DISEÑO]**: decisión de modelado defendible en abstracto pero equivocada para estos datos.
- **[COPIA]**: reproduce la estructura de referencia del anexo del enunciado (incluida en el prompt 1) sin adaptarla.

Conteos verificados en `covid_historica` que se citan abajo: las comorbilidades usan 1, 2 y 98 (nunca 99; DIABETES = 98 en 12,517 casos); EMBARAZO = 97 en los 935,592 hombres; UCI = 97 en los 1,998,367 ambulatorios; EDAD = 99 en 141 casos y 122 en 34; SEXO solo 1 y 2.

La estructura de referencia del prompt 1 trae `dim_tiempo` con `dia_festivo_tipo` y `tipo_fecha`, `dim_localizacion` con `localidad`, `nombre_loc`, `pob_mun` y `pob_loc`, y `dim_comorbilidad` sin `OTRA_COM`. Varias decisiones de los modelos salen de ahí.

## Qwen3 8B (`qwen3_8b`)

### Turno 1 (2,311 tokens, terminó solo)

- Elige estrella, con una justificación genérica (l. 3: «es un caso típico de un modelo de datos estrella»). No compara contra copo de nieve ni constelación: no los menciona.
- Medidas: siete conteos (l. 10-16). Ninguna medida no aditiva (edad, demoras) ni la letalidad. «Número de pacientes con comorbilidades» queda ambiguo.
- Lista seis dimensiones, entre ellas «Dimensión Atención» (l. 24), que después no aparece en las tablas (l. 116-171): **[CONTRADICCIÓN]**.
- Jerarquías, casi todas falsas **[DISEÑO]**:
  - l. 31: «Año → Mes → Semana epidemiológica → Día». La semana no se anida en el mes (20 de las 106 semanas de 2022-2023 tienen días de dos meses).
  - l. 35: «Pais → Entidad → Municipio → Localidad». Como jerarquía geográfica es válida (nuestro modelo también sube de la entidad a México), pero incluye la localidad, que está excluida, y el país de residencia es siempre México: el «análisis a nivel internacional» que le asigna (l. 78) solo se puede hacer con la nacionalidad o el país de origen, que son otros atributos.
  - l. 39: «Nacionalidad → Entidad de nacimiento → Entidad de residencia → Municipio de residencia». Son atributos distintos, no niveles.
  - l. 40: «Sexo → Edad → Grupos de edad». El sexo no contiene a la edad, y el grupo de edad va arriba de la edad, no abajo.
  - l. 43: las comorbilidades en cadena («Diabetes → Hipertensión → …»): es una lista, no una jerarquía.
  - l. 46: «Clasificación final → Resultado de laboratorio → … → Defunción»: tampoco.
- Granularidad y límite: incluye la localidad (l. 81, l. 112: «Se puede enriquecer hasta el nivel de **localidad**»), contra la regla explícita del prompt **[CONTRADICCIÓN]**.
- Tablas: `dim_localizacion` con `pob_mun` y `pob_loc` (l. 141-142), población que no viene en ninguna fuente **[COPIA]**; `dim_comorbilidad` sin `otra_com` (l. 153-163) **[COPIA]**; `dim_tiempo` con `tipo_fecha` (l. 130), que no cabe en una dimensión con roles.
- Hecho: repite en `fact_casos_covid` columnas que ya puso en dimensiones: `resultado_lab`, `resultado_antigeno`, `clasificacion_final`, `uci` (también en `dim_resultado`) y `migrante` (también en `dim_paciente`) (l. 186-199) **[DISEÑO]**. `fecha_resultado` queda como fecha cruda, sin llave a `dim_tiempo` (l. 195). `dim_resultado` trae `fecha_def` (l. 171), una fecha dentro de una dimensión de resultado.
- Campos que no aparecen en ninguna tabla: fecha_actualizacion, origen, sector, entidad_um, municipio_um, clues, entidad_nac, otra_com, otro_caso.

### Turno 2 (684 tokens): el SQL

- Es la lista del turno 1 en SQL, con la misma localidad (`localidad`, `nombre_loc`, `pob_loc`). El prompt pedía todos los campos menos LOCALIDAD_RES **[CONTRADICCIÓN]**.
- `sexo VARCHAR(10)` en `dim_paciente` cuando el campo es un código numérico.
- `dim_resultado` existe pero la tabla de hechos no tiene llave hacia ella: queda suelta.
- Todas las llaves foráneas aceptan NULL.

### Turno 3 (2,166 tokens): la evidencia

- Lee mal la evidencia y desarma el modelo **[DISEÑO]**:
  - l. 18: las 1,315 combinaciones de comorbilidades «sugieren que no son independientes y que su agrupación en una dimensión es redundante». Es al revés: que haya pocas combinaciones es lo que hace útil una dimensión basura (1,315 filas en lugar de 10 columnas por caso).
  - l. 28: lo mismo con las 87 combinaciones del paciente.
  - l. 38: elimina toda la geografía por un solo municipio fuera de catálogo («la dimensión no es completamente confiable»). Un caso de 2.1 millones se resuelve con un miembro inferido.
- Resultado final: una tabla plana con `dim_tiempo` como única dimensión (l. 93-152). Es justo la tabla de ingesta que el modelo multidimensional debía reemplazar.
- Ese SQL incluye `localidad_res INTEGER` (l. 136) aunque en el mismo turno dice «excepto LOCALIDAD_RES» (l. 58, 166) **[CONTRADICCIÓN]**, y declara `tipo_paciente` dos veces (l. 116 y 138): no compila (se confirma en el sandbox).
- Las secciones 7 y 8 repiten palabra por palabra las 5 y 6 (l. 65-81).
- Reconoce un error real del turno 1: faltaba `OTRA_COM` (l. 18).
- No usa los hallazgos 1 (CLUES y ORIGEN), 2 (FECHA_ACTUALIZACION), 4 (95% sin CLUES ni fecha de resultado), 6 (edad 122 y entidad 99) ni 7 (periodo de cada archivo).

## Granite 4.2 8B, corrida con 12,000 tokens (`granite4.2_8b`): la que se evalúa

### Turno 1 (cortado otra vez, ahora a 12,000 tokens; 36,196 caracteres)

- Sus primeros 12,930 caracteres son idénticos, byte por byte, a la respuesta cortada a 4,000 tokens: con temperatura 0 el límite solo decidió dónde se cortó. Todo lo anotado abajo para el turno 1 de 4,000 vale aquí; lo nuevo empieza en la l. 58.
- Esta vez cubre los siete incisos y se corta al final, en la «Lista final de tablas» (l. 212-216), después de un «Resumen de tablas» completo (l. 181-188).
- Piensa en voz alta dentro de la respuesta y se corrige sobre la marcha: pone `tipo_fecha` en `dim_tiempo` (l. 101) y en la «Revisión final» la quita (l. 112); confunde `otra_caso` con `otra_com` (l. 149) y se corrige en la l. 150.
- Mantiene LOCALIDAD_RES de forma explícita: «No se omite; se respeta el dato» (l. 65) **[CONTRADICCIÓN]** con la regla del prompt.
- Repite que `entidad_um` sirve para analizar USMER contra no USMER (l. 70, 81, 199) **[ALUCINACIÓN]**.
- El catálogo de clasificación: en las l. 59 y 77 dice «6-7 = sospecha»; en la l. 158, bien, «6=sospechoso, 7=negativo» **[CONTRADICCIÓN]**. El 7 es negativo.
- El día de la semana: escribe tres fórmulas seguidas (l. 97) y en medio pregunta «`EXTRACT(DOW FROM fecha)` da 0=lunes?» (en PostgreSQL 0 es domingo). La primera fórmula da 6 al domingo y al sábado; la última, `(EXTRACT(DOW FROM fecha)::INT + 6) % 7 + 1`, sí es correcta. Propone `TO_CHAR(fecha, 'DOW', 'L')` (l. 98): `to_char` recibe dos argumentos y `DOW` no es un patrón de `to_char` **[ALUCINACIÓN sobre SQL]**.
- «Semana epidemiológica» como `FLOOR((fecha - '2022-01-01')/7) + 1` (l. 99): cuenta semanas desde una fecha fija, no es el calendario epidemiológico.
- Elige copo de nieve, pero escribe «No se crea sub-tablas» en su «Jerarquía interna (snowflake ligera)» (l. 59): el modelo final es una estrella **[CONTRADICCIÓN]**.
- «Jerarquías naturales (... tipo paciente → hospitalizado/ambulatorio)» (l. 200): llama jerarquía a una variable y sus valores.
- `edad` «0-120; '99' no es edad» (l. 130), dentro de `dim_paciente`: la edad sigue en la dimensión del paciente, que con la edad deja de ser chica.
- Códigos 1/2/99 en comorbilidades y en los atributos del paciente (l. 131-148): los datos usan 98, y embarazo usa 97 en todos los hombres.
- Tablas finales (l. 183-188): `dim_tiempo`, `dim_localizacion`, `dim_paciente`, `dim_comorbilidad` (ya con `otra_com`), `dim_resultado` y `fact_covid` con cuatro llaves de fecha, cuatro de dimensión y cinco medidas 0/1. Faltan en todas: fecha_actualizacion, sector, entidad_um, municipio_um, clues, intubado, neumonia, toma_muestra_lab y toma_muestra_antigeno. Deja fuera `archivo_origen` a propósito (l. 179).
- Llaves de fecha en NULL cuando falte la fecha (l. 166-169, 195).

### Turno 2 (6,778 tokens, terminó solo)

- El prompt pedía «todo el SQL en un solo bloque». Escribe un script completo (l. 1-117), y sin cerrar el bloque mete texto (l. 118-122: «Pero el usuario pidió "todo el SQL en un solo bloque y no omitas columnas ni tablas". Como en la respuesta anterior no se incluyó `intubado` y `neumonia`…») y abre un segundo bloque con «el script SQL correcto y completo» (l. 124-205). El evaluador toma ese último.
- El comentario de arriba dice «sin incluir LOCALIDAD_RES en dimensiones (se usa en dim_localizacion)» (l. 4) **[CONTRADICCIÓN]**, y en la explicación final: «`LOCALIDAD_RES` se incluye en `dim_localizacion` como `localidad_res`, cumpliendo "todas las columnas de covid_historica excepto LOCALIDAD_RES"» (l. 210).
- Omite SECTOR a propósito: «no forma parte de la jerarquía espacial ni temporal ni temática» (l. 209), y `archivo_origen` (l. 214). Faltan siete campos exigidos: fecha_actualizacion, sector, entidad_um, municipio_um, clues, toma_muestra_lab y toma_muestra_antigeno. Agrega intubado y neumonia, que se le habían olvidado en el turno 1.
- El script final compila, pero sus CHECK no aceptan los 97 ni los 98 que hay en los datos, y la edad tope es 120: **rechazarían 2,051,620 de los 2,099,997 casos (97.7%)**. UCI e INTUBADO = 97 en los 1,998,367 ambulatorios, EMBARAZO = 97 o 98 y las 34 edades de 122 (951,953 casos), y los 98 de las comorbilidades (16,781). Solo cabrían 48,377 casos (`casos_que_no_caben.sql`).
- `sexo CHAR(1)` con `CHECK (sexo IN ('1', '2', '99'))`, la edad dentro de `dim_paciente` y las ocho llaves foráneas sin `NOT NULL`.

### Turno 3 (10,422 tokens, terminó solo)

- Aunque el razonamiento estaba apagado (`think: false`), la respuesta trae su razonamiento: las l. 1-165 son el modelo pensando, en la l. 166 aparece una etiqueta `</think>` y de la l. 167 en adelante repite la respuesta en limpio.
- Lee bien el hallazgo 1: como la CLUES no determina el ORIGEN, el ORIGEN se queda como campo propio (l. 13, 171).
- Lee bien el hallazgo 3: 1,315 combinaciones justifican su `dim_comorbilidad` con una fila por combinación (l. 53-61), al revés que Qwen3. Para llegar ahí calcula que el máximo es 2¹⁰ = 1,024, nota que 1,315 es mayor («imposible») y lo atribuye a los 99 (l. 50): en los datos son 98, y el máximo del catálogo es 5¹⁰.
- Con el municipio 999 y el 113 de Chihuahua decide guardar todas las combinaciones reportadas sin validar contra el catálogo (l. 40-43): no pierde el caso, pero tampoco lo marca. En el encabezado del inciso b) confunde el municipio 999 con la localidad (l. 28).
- El único cambio que propone es agregar SECTOR (l. 131), reconociendo que omitirlo en el turno 2 fue un error (l. 77). Lo pone en `dim_resultado`, junto a los atributos del caso, cuando el hallazgo 1 decía justo que SECTOR depende de la CLUES; ENTIDAD_UM, MUNICIPIO_UM y CLUES siguen fuera **[DISEÑO]**.
- Edad 122: «se almacena como entero… el modelo no debe imponer el filtro en la tabla» (l. 108, 160), pero su `dim_paciente` del turno 2 tiene `CHECK (edad >= 0 AND edad <= 120)`, que la rechaza **[CONTRADICCIÓN]**.
- FECHA_ACTUALIZACION sigue fuera: «no afecta el modelo» (l. 146, 208). Los hallazgos 6 (entidad 99 en extranjeros) y 7 (periodo de cada archivo) no cambian nada.
- Sostiene que «copo de nieve sigue siendo adecuado» (l. 3, 163).
- Su SQL del turno 3 es solo `dim_resultado` con SECTOR (l. 183-197): compila, y sus CHECK siguen sin aceptar el 97 de UCI e INTUBADO.

## Granite 4.2 8B, corrida con 4,000 tokens (`granite4.2_8b_limite_4000`)

Se cortó en los tres turnos. Se repitió con 12,000 tokens (`granite4.2_8b`); esta corrida queda como evidencia de por qué.

### Turno 1 (cortado a 4,000 tokens, a la mitad del inciso i)

- Elige copo de nieve (l. 1-10), con «una ligera normalización (snowflake)». Pero ninguna dimensión queda normalizada en tablas separadas: `dim_comorbilidad` es «una sola tabla» (l. 51) y `dim_localizacion` también **[CONTRADICCIÓN]**: el diseño que describe es una estrella.
- Medidas solo binarias (l. 15-22); lo dice como virtud: «No se usan medidas continuas».
- `dim_tiempo` con `tipo_fecha` (l. 28) y al mismo tiempo cuatro llaves de fecha en el hecho (l. 31); dice «tres claves» y enumera cuatro. Semana calculada como `FLOOR((fecha - '2022-01-01')/7) + 1` (l. 28), que no es la semana epidemiológica.
- Propone llaves de fecha en NULL cuando falte la fecha (l. 32).
- `dim_localizacion` mezcla nacimiento, residencia, localidad y los dos países (l. 38): **mantiene `localidad_res` explícitamente** («aunque no está en diccionario, está en CSV y se mantiene») **[CONTRADICCIÓN]** y le atribuye un «catálogo LOCALIDAD_RES» que no existe **[ALUCINACIÓN]**.
- l. 42: dice que `entidad_um` sirve «para posible análisis de fuente (USMER vs. no USMER)». La entidad de la unidad médica no tiene relación con USMER, que es el campo ORIGEN **[ALUCINACIÓN]**.
- l. 46: «si edad es 99 en CSV, se trata como faltante». En EDAD el 99 es una edad (99 años); el diccionario no le da un significado especial **[ALUCINACIÓN]**.
- l. 46 y 52: valores 1/2/99 para embarazo y comorbilidades. El catálogo SI_NO del prompt tiene 1, 2, 97, 98 y 99, y en los datos las comorbilidades usan 98 (SE IGNORA), no 99; embarazo usa 97 en todos los hombres.
- `dim_paciente` con una fila por caso (l. 47): 2.1 millones de filas, tantas como hechos.
- Códigos de ORIGEN, TIPO_PACIENTE, RESULTADO_LAB, RESULTADO_ANTIGENO y CLASIFICACION_FINAL bien leídos del catálogo (l. 15, 58).

### Turno 2 (cortado a 4,000 tokens)

- El comentario inicial dice que LOCALIDAD_RES se excluye y en la misma línea que se incluye en `dim_localizacion` (l. 5-6) **[CONTRADICCIÓN]**.
- `CHECK` con subconsultas (`entity_nac IN (SELECT clave FROM catalogos_entidades ...)`, l. 29-31): PostgreSQL no permite subconsultas en un CHECK, y además `entity_nac` no es el nombre de la columna (`entidad_nac`) **[ALUCINACIÓN sobre SQL]**.
- `sexo CHAR(1) ... CHECK (sexo IN ('1', '2', '99'))` (l. 40): el 99 no cabe en un `CHAR(1)`. En estos datos no hay ningún sexo 99 (1,164,405 mujeres y 935,592 hombres), pero el catálogo lo admite y el diseño no lo aguantaría.
- Los CHECK de UCI, comorbilidades y embarazo no aceptan 97 ni 98, que están en los datos: la carga fallaría para casi todos los casos ambulatorios (UCI = 97).
- Dos CHECK contradictorios sobre `tipo_fecha` en la misma tabla (l. 19-20).
- A media tabla de hechos escribe en un comentario que `tipo_paciente` se elimina del hecho, y la columna se queda (l. 92).
- Al terminar el script dice que tiene un error y empieza a reescribirlo completo (l. 117-125); ahí se corta.

### Turno 3 (cortado a 4,000 tokens)

- l. 10-11: afirma que «~95% de casos no tienen resultado_lab ni resultado_antigeno». El hallazgo 4 dice que les falta CLUES, MUNICIPIO_UM y FECHA_RESULTADO, no los resultados **[ALUCINACIÓN]**. Con esa premisa elimina la llave a `dim_resultado`.
- l. 15: `caso_confirmado` en NULL para sospechosos y, en la misma línea, el 6 (sospechoso) dentro de los ceros; menciona una clasificación 99 que el catálogo no tiene.
- l. 27: sigue guardando `localidad_res` «lo cual es correcto».
- l. 44: `WHERE cardiovascular=1 OR coronary=1`: no existe una columna `coronary` **[ALUCINACIÓN]**.

## Mistral Nemo 12B (`mistral-nemo_12b`)

### Turno 1 (755 tokens, se detuvo solo a media frase)

- Termina en «En resumen, el modelo de estrella propuesto para el conjunto de datos de contagios de COVID» (l. 37) con `done_reason = stop`: el modelo dejó de generar, no fue el límite de tokens. No lista las tablas, que el prompt pedía al final.
- Estrella, sin comparar alternativas (l. 1).
- Medidas: «Número de recuperados» (l. 8). Los datos no tienen ningún campo de recuperación **[ALUCINACIÓN]**.
- Tiempo: «fecha de diagnóstico» (l. 10), campo que no existe **[ALUCINACIÓN]**.
- Ubicación con localidad (l. 11, 18) y límite de enriquecimiento «hasta el nivel de localidad» (l. 35) **[CONTRADICCIÓN]** con la regla y con su propia granularidad municipal (l. 26).
- Las listas de los incisos v y vi son las mismas de los incisos ii y iv, copiadas (l. 17-20 y 30-33).
- Límite del tiempo «hasta el nivel de año» (l. 35): confunde el nivel más alto de la jerarquía con un límite de enriquecimiento.
- No menciona los códigos 97/98/99, el grano ni las llaves.

### Turno 2 (624 tokens): el SQL

- Es la estructura de referencia recortada **[COPIA]**: `dim_tiempo` con `dia_festivo_tipo` y `tipo_fecha`, `dim_localizacion` con `pob_mun`, `dim_comorbilidad` sin `otra_com`. Quita la localidad.
- `sexo CHAR(1)` (l. 41): no cabe el 99 que admite el catálogo (en estos datos no aparece). Viene de la estructura de referencia, que ya traía `sexo CHAR(1)`.
- `migrante` sale de `dim_paciente` y queda en el hecho. Sin llave a ninguna dimensión de resultado o diagnóstico: los códigos van crudos al hecho.
- Todas las llaves foráneas aceptan NULL.

### Turno 3 (491 tokens)

- l. 3: propone agregar ORIGEN «en la tabla dim_ubicacion». Su modelo no tiene esa tabla (tiene `dim_localizacion`) y ORIGEN describe al caso, no a la residencia.
- l. 4: «eliminar esta columna [FECHA_ACTUALIZACION] de la tabla dim_tiempo»: nunca estuvo ahí, y el enunciado exige conservar todos los campos menos LOCALIDAD_RES.
- l. 5: agrupa «DIABETES, EPOC y ASMA en una categoría llamada "Enfermedades respiratorias crónicas"». La diabetes no es una enfermedad respiratoria **[ALUCINACIÓN de dominio]**.
- l. 6: eliminar CLUES, MUNICIPIO_UM y FECHA_RESULTADO porque faltan en el 95%: son campos exigidos y el 5% de 2023 sí los trae **[CONTRADICCIÓN]** con la regla.
- l. 7: confunde el municipio 999 de residencia con MUNICIPIO_UM.
- l. 8: restricciones para rechazar EDAD = 122 y ENTIDAD_NAC = 99. Rechazarían 27,220 casos reales (34 con edad 122 y 27,186 con entidad 99: 27,181 extranjeros y 5 mexicanos) en lugar de marcarlos.
- No reescribe el modelo ni usa los hallazgos 3 (las 87 combinaciones) y 7.
