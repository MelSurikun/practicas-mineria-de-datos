# Práctica 03, Minería de Datos, Equipo 3
## Modelo multidimensional, proceso ETL y exploración analítica

Por ahora esta carpeta tiene mi parte (Santiago, Arquitecto y Machine Learning), que va primero porque el ETL y la exploración dependen del modelo. Aquí está el modelo cerrado y todo lo que hace falta para cargarlo en su base de la Práctica 2, comprobar que quedó bien y empezar sus partes, más la evidencia de la comparación con LLM (punto 2). El texto del reporte no va aquí: cada quien pega su parte en el Google Doc, y el reporte solo se pone en Drive.

> **Actualización del 5 de noviembre de 2026 (Melanie):** la carpeta ya trae también la parte de Melanie: el ETL (puntos 4 y 5), la exploración analítica (6a-c) y las gráficas (6d). Qué hay y cómo correrlo está en la [sección 8](#8-parte-de-melanie-etl-exploración-y-gráficas). Lo que le toca a Juan está en `guias/guia_juan.md`.

Versión del 31 de octubre de 2026.

## 1. Cargar el modelo (de 1 a 3 minutos)

Necesitan:

- PostgreSQL 15 o posterior (ustedes tienen el 17) con su base **covid20a23sedi** y su tabla `covid_historica` de la Práctica 2 (`Practica02_Equipo3_MD/`, pasos 1 a 5).
- **psql**, que viene con PostgreSQL. Los scripts usan `\copy`, `\gset` e `\if`, que solo entiende psql: el Query Tool de pgAdmin y DBeaver no los pueden correr.

### En Windows, con PowerShell

1. Actualicen el repositorio (`git pull` en la rama main) y abran la carpeta `Practica03_Equipo3_MD`. Clic derecho en un espacio vacío de la carpeta → **Abrir en Terminal** (en Windows 10: Shift + clic derecho → **Abrir la ventana de PowerShell aquí**).
2. Copien estas dos líneas y den Enter. Les pide la contraseña de `postgres`:

```powershell
$env:PGCLIENTENCODING = "UTF8"
& "C:\Program Files\PostgreSQL\17\bin\psql.exe" -h localhost -U postgres -d covid20a23sedi -f cargar_modelo.sql
```

Es la misma ruta de psql que usó `graficar.py` en la Práctica 2. Si su PostgreSQL está en otra carpeta, cámbienla.

### En Windows, con SQL Shell (psql)

Ábranlo desde el menú Inicio. Den Enter en todo, salvo en `Database`, donde escriben `covid20a23sedi`, y en la contraseña. Luego escriban la ruta real de la carpeta, con diagonales `/`:

```
\cd 'C:/Users/SU_USUARIO/Documents/practicas-mineria-de-datos/Practica03_Equipo3_MD'
\i cargar_modelo.sql
```

### En Mac o Linux

```bash
cd practicas-mineria-de-datos/Practica03_Equipo3_MD
psql -h localhost -U postgres -d covid20a23sedi -f cargar_modelo.sql
```

### Qué hace y cómo saber que funcionó

`cargar_modelo.sql` revisa primero que la base tenga `covid_historica` y que PostgreSQL sea 15 o posterior; si algo falta, sale sin tocar nada. Después corre estos cinco scripts en orden y se detiene en el primer error:

| Script | Qué hace |
|---|---|
| `sql/modelo/00_catalogos.sql` | Los 11 catálogos. No toca los que ya tienen de la Práctica 2 (`cat_entidades`, `cat_municipios`, `cat_sector` del `06` y, si corrieron el `08`, los otros ocho): solo crea y llena los que faltan |
| `sql/modelo/01_esquema_dw.sql` | Borra y vuelve a crear el esquema `dw` con sus 13 tablas. Si ya tienen un esquema `dw` con trabajo propio, cámbienle el nombre antes |
| `sql/prueba_carga/10_dimensiones.sql` | Llena las 12 dimensiones |
| `sql/prueba_carga/11_hechos.sql` | Llena la tabla de hechos: 2,099,997 casos |
| `sql/modelo/02_llaves_foraneas.sql` | Declara las 16 llaves foráneas y los índices |

Al final imprime 19 comprobaciones (conteos, filas de cada dimensión, llaves foráneas y que no haya columnas de localidad). **Si todas dicen OK, el modelo quedó bien.** Se puede volver a correr cuantas veces quieran sin duplicar nada.

Después corran la validación completa: son 15 consultas y en mi máquina tarda menos de un minuto. Se corre igual que la carga, cambiando el archivo por `sql/prueba_carga/12_validacion.sql` (en SQL Shell, `\i sql/prueba_carga/12_validacion.sql`). Cada consulta trae en un comentario el resultado esperado, y los míos están en `evidencias/validacion/`. La más importante es `v06_ida_y_vuelta`: reconstruye las 44 columnas de `covid_historica` usando solo el modelo, las compara en los dos sentidos y debe dar 0 y 0.

Si su base salió de los scripts del equipo, `v14_tamanos` les va a dar otro tamaño para `covid_historica` (402,128,896 bytes contra mis 384,368,640): el `05_consolidacion.sql` de la Práctica 2 le borra una columna con DROP COLUMN y PostgreSQL no libera ese espacio. Las tablas del modelo miden lo mismo, y las otras 14 consultas deben dar exactamente lo que está en `evidencias/validacion/`.

Lo probé como lo van a correr ustedes: en una carpeta limpia, sobre una copia de la base del equipo (con los catálogos del `06` y la vista `v_anomalias` del `07` de la Práctica 2) y con la codificación de Windows. Las 13 tablas quedaron idénticas a las mías, byte por byte, y `v_anomalias` sigue funcionando. También corre desde esta carpeta del repositorio sobre una base armada desde cero con los scripts de `Practica02_Equipo3_MD/`.

### Si algo falla

| Lo que aparece | Qué pasa y qué hacer |
|---|---|
| `El término 'psql' no se reconoce...` | PowerShell no encuentra psql: usen la línea con la ruta completa, como arriba |
| `role "..." does not exist` o `password authentication failed` | Falta `-U postgres` o la contraseña no es la de postgres |
| `catalogos/cat_entidades.csv: No such file or directory` | psql no está parado en `Practica03_Equipo3_MD`: abran la terminal ahí o usen `\cd` en SQL Shell |
| `Esta base no tiene public.covid_historica` | Están conectados a otra base: debe ser covid20a23sedi |
| `Hace falta PostgreSQL 15 o posterior` | Su servidor es más viejo; el modelo usa `UNIQUE NULLS NOT DISTINCT` |
| `character with byte sequence 0x81 in encoding "WIN1252"...` | No debería pasar, porque cada script fija UTF-8. Si pasa, corran antes `$env:PGCLIENTENCODING = "UTF8"` |
| Acentos raros en la consola, como `CatÃ¡logo` | Es solo la pantalla de Windows; en la base quedan bien. Se comprueba abriendo `dw.dim_tiempo` en pgAdmin o DBeaver |
| `el valor nulo en la columna «id_extracto»...` al cargar los hechos | Su `covid_historica` guarda el archivo de 2022 como `...2022.csv (reparado)`. Ya está corregido en `10_dimensiones.sql` y `06_dimensiones.sql`: actualicen el repositorio y vuelvan a correr la carga (bitácora de Melanie, error 1) |
| Alguna comprobación dice REVISAR | Su `covid_historica` no es igual a la de la Práctica 2. Mándenme la tabla de comprobaciones |
| Una ruta con acentos o eñes falla en `\cd` | Clonen el repositorio en una ruta simple, como `C:/repos/practicas-mineria-de-datos` |

## 2. El modelo en una línea

**Esquema estrella:** una tabla de hechos, `dw.fact_casos_covid`, con **una fila por caso** (ID_REGISTRO), y 12 dimensiones. La vista de una página, con las filas, jerarquías y roles de cada dimensión, está en `diagramas/modelo_estrella_vista_general.png`. El diagrama con llaves y atributos está en `diagramas/modelo_estrella.png` y el completo, con las 174 columnas, en `diagramas/modelo_estrella_completo.pdf`.

| Dimensión | Qué guarda | Filas |
|---|---|---|
| dim_tiempo | Calendario diario 2022-2023 con semana epidemiológica, temporada de influenza y festivos. Se usa 4 veces: síntomas, ingreso, resultado y defunción | 732 |
| dim_ubicacion | Municipio de residencia (llave: entidad + municipio) | 2,502 |
| dim_entidad | Entidad de nacimiento (mismas claves y nombres que dim_ubicacion) | 36 |
| dim_unidad_medica | CLUES con su sector, tipo de institución, entidad y municipio (en 2022 no hay CLUES: sector × entidad) | 2,481 |
| dim_paciente | Sexo, embarazo, lengua indígena, indígena, nacionalidad y migrante | 87 |
| dim_pais | País normalizado, usado 2 veces: nacionalidad y origen | 159 |
| dim_edad | Edad, quinquenio, grupo decenal y grupo etario | 123 |
| dim_comorbilidad | Las 10 banderas y el número de comorbilidades | 1,315 |
| dim_atencion | Origen (USMER), tipo de paciente, neumonía, intubado, UCI y nivel de gravedad | 25 |
| dim_diagnostico | Contacto, muestras, resultados, clasificación final y su grupo | 66 |
| dim_extracto | Archivo de origen y fecha de actualización (linaje) | 2 |
| dim_calidad | 11 banderas de calidad de la Práctica 2, para excluir o estudiar registros sin borrarlos | 23 |

Medidas de la tabla de hechos:

- **Aditivas (0 o 1, se suman):** `casos`, `confirmados`, `hospitalizados`, `ingresos_uci`, `intubados`, `con_neumonia` y `defunciones`.
- **No aditivas (promedio o mediana, nunca suma):** `edad_anios`, `dias_sintomas_a_ingreso`, `dias_ingreso_a_resultado` y `dias_ingreso_a_defuncion`.

Tres convenciones que conviene tener presentes:

- Ninguna llave foránea es NULL. Una fecha que no existe va a `-1` (no disponible en el extracto: FECHA_RESULTADO en 2022) o a `-2` (no aplica: sin defunción o sin resultado).
- Los 97, 98 y 99 de los catálogos son miembros normales, con su descripción: no son NULL. Para un porcentaje de diabetes, por ejemplo, el denominador son los casos con 1 o 2.
- Un código fuera de catálogo (solo pasa con el municipio 113 de Chihuahua, registro 4d0ea9) entra como miembro «FUERA DE CATÁLOGO» con su código y su entidad, en lugar de borrarse.

## 3. Para Melanie: ETL (puntos 4 y 5) y gráficas (6d)

> **Hecho.** Melanie adoptó y extendió esta carga en `correr_etl.sql` y `sql/06` a `08` (sección 8). Lo que sigue queda como referencia del diseño.

- **`mapeo_origen_destino.xlsx` es la especificación del ETL:** columna por columna, a qué tabla va, por qué llave se llega y qué regla se aplica a cada código y a cada hueco. También trae el diccionario del modelo, los miembros especiales y el orden de ejecución.
- `10_dimensiones.sql` y `11_hechos.sql` son una carga probada que puedes adoptar o cambiar. El diagrama del flujo con los pasos numerados, las capturas y la bitácora de errores son tuyos. Así encaja la carga de prueba en los pasos del ejemplo del enunciado:

| Paso del enunciado | En la carga de prueba |
|---|---|
| Extracción (1-3) | Origen: `covid_historica`, 2,099,997 filas y 45 columnas; se usan 44, todas menos LOCALIDAD_RES. Sin filtros: los casos dudosos se marcan en `dim_calidad`, no se descartan |
| Transformación (4-5): tipos y fechas | Los tipos ya vienen de la Práctica 2 (fechas `date`, códigos `smallint`). Cada fecha se vuelve la llave AAAAMMDD de `dim_tiempo`; las que faltan van a -1 o -2 |
| Transformación (6): textos y catálogos de valores únicos | Los países se normalizan con `catalogos/paises_normalizacion.csv` sin perder el texto original. Las combinaciones de comorbilidades (1,315), del paciente (87), de atención (25), de diagnóstico (66) y de calidad (23) salen con `SELECT DISTINCT` |
| Transformación (7): valores no válidos | En lugar de -99, el código fuera de catálogo entra como miembro inferido. Las cantidades imposibles (edad de 122 años, fechas en desorden) quedan en NULL solo en la medida |
| Carga (8-9) | Primero las dimensiones (`10`), después los hechos (`11`), buscando la llave de cada dimensión por su llave natural; las llaves foráneas al final (`02`) |
| Validación | `12_validacion.sql`: conteos origen-destino (`v01`, `v02`), duplicados (`v03`), llaves huérfanas (`v04`), ida y vuelta (`v06`) y medidas contra el origen (`v08`) |

- Tres puntos que vale la pena contar en la bitácora:
  - Las llaves foráneas se declaran después de la carga: con ellas puestas, la carga de hechos tardó 102 s; sin ellas, 23 s.
  - La carga de hechos usa LEFT JOIN contra columnas NOT NULL. Si una combinación no encuentra su dimensión, la carga truena en lugar de perder casos sin avisar; por eso no hay registros rechazados.
  - CLUES es NULL en todo 2022. Para unir se usa `coalesce(clues, '')`: con `IS NOT DISTINCT FROM`, la unión tardó 1.85 s contra 0.30 s.
- **Para las gráficas (6d):** las medidas de 0 o 1 se suman directo, y la letalidad entre confirmados es `sum(defunciones * confirmados) / sum(confirmados)`, no `sum(defunciones) / sum(confirmados)`: con la segunda fórmula sale 1.991% a nivel nacional en lugar de 1.126%.

## 4. Para la exploración (6a-c, Melanie), la calidad (7, Juan) y el documento (Juan)

> **Cambio de repartición:** la exploración (6a-c) pasó a Melanie. Sus consultas están en `sql/10_exploracion.sql` y sus resultados, en `evidencias/exploracion/`. Las de roll-up (`x24`, `x25`) y concentración municipal (`x26`) sirven para las conclusiones de Juan.

**Qué atributo responde cada ejemplo del enunciado:**

| Pregunta del enunciado | En el modelo |
|---|---|
| por año, mes o semana | `dim_tiempo.anio`, `anio_mes`, `anio_epi` + `semana_epi` (eligiendo el rol: síntomas, ingreso o defunción) |
| por entidad o municipio | `dim_ubicacion.nombre_entidad`, `nombre_municipio` |
| por sexo | `dim_paciente.sexo_desc` |
| por grupo de edad | `dim_edad.grupo_etario`, `quinquenio`, `grupo_decenal` |
| por clasificación final o resultado | `dim_diagnostico.clasificacion_final_desc`, `grupo_clasificacion` |
| por comorbilidad | `dim_comorbilidad.diabetes`..., `grupo_comorbilidades`, `descripcion` |
| tiempo + ubicación + resultado | ejemplo listo en `sql/consultas/q4_estrella.sql` |
| sexo + grupo de edad + comorbilidad | ejemplo listo en `sql/consultas/q3_estrella.sql` |

Las consultas de `sql/consultas/` se abren y corren en DBeaver o pgAdmin. Cada pregunta está escrita dos veces, contra `covid_historica` y contra el modelo, y las dos dan el mismo resultado.

**Ojo con «por año».** El archivo «2022» es en realidad enero a junio de 2022 y el «2023» es casi solo enero de 2023 (Práctica 2, Tabla 13). Comparar años compara periodos distintos; conviene usar el mes o la semana epidemiológica.

**Para el punto 7 (calidad después de migrar):**

- `12_validacion.sql` ya cubre conteos origen-destino, duplicados en las 12 dimensiones (0), llaves huérfanas (0) y miembros especiales.
- `dim_calidad` tiene las banderas de la Práctica 2 (edad de 122, fechas en desorden, entidad de nacimiento inconsistente...). Para excluir lo dudoso: `WHERE q.nivel_maximo <> 'ERROR'`.
- Sobre la nota del enunciado: NACIONALIDAD solo toma 1 y 2, que existen en su catálogo, y coincide siempre con PAIS_NACIONALIDAD; el problema está en el texto del país, que `dim_pais` clasifica en `tipo_valor`. ENTIDAD_RES nunca vale 99. MUNICIPIO_RES vale 999 en 26 casos de 16 entidades, y ENTIDAD_NAC vale 99 en 27,186, de los cuales 27,181 son extranjeros que debían llevar 97.
- En la tabla de hechos ninguna llave es NULL. Los nulos que conviene reportar son los de las medidas (`edad_anios` en 34 casos y las demoras cuando el evento no ocurrió) y los de `dim_unidad_medica` (clues y municipio en las 212 unidades no identificadas de 2022).

**Para las conclusiones, datos medidos:**

- *¿Qué ventajas ofreció el modelo frente a la tabla de ingesta?* Las cuatro consultas de `sql/consultas/` dan exactamente lo mismo en las dos versiones. Contra el modelo, el SQL bajó de 61 a 34 líneas y de 4 expresiones CASE a ninguna, porque los grupos ya viven en las dimensiones. Tres de las cuatro corrieron más rápido (Q1 3.7 veces, Q3 3.0 y Q4 4.0) y Q2 quedó empatada. La tabla de hechos ocupa 31% menos que `covid_historica` sin contar índices (252 contra 367 MB) y las 12 dimensiones juntas, menos de 1 MB; con índices quedan casi iguales (398 contra 412 MB), porque el modelo lleva cinco índices en lugar de uno. Los tiempos están en `evidencias/comparacion/resumen.csv`.
- *¿Qué dimensiones fueron más útiles?* Lo dirá tu exploración. Desde el diseño, las que más trabajo ahorran son el tiempo (la semana epidemiológica ya calculada), la edad (sus grupos), las comorbilidades (el número de comorbilidades en lugar de diez columnas) y el diagnóstico (el grupo de clasificación).
- *¿Qué consultas o indicadores podrían alimentar un tablero?* Casos, confirmados y defunciones por semana epidemiológica; letalidad y hospitalización por grupo etario y número de comorbilidades; un mapa por entidad o municipio con la CVEGEO; la gravedad por tipo de institución, y el porcentaje de casos con banderas de calidad.
- *¿Qué mejoras harían si el proyecto creciera?* En volumen, particionar la tabla de hechos por mes con índices BRIN en las fechas y crear vistas materializadas para los tableros. En temporalidad, carga incremental por FECHA_ACTUALIZACION e historial de versiones en las dimensiones que cambian. En complejidad, nuevas tablas de hechos que compartan tiempo y lugar (vacunación, ocupación hospitalaria, clima) y la población del INEGI para pasar de conteos a tasas. En medidas, una de positividad, que salió de la comparación con los LLM.

**Para el documento:** mi parte va justo después de la introducción (te dejé una propuesta de introducción en mi texto, por si te sirve). Mis tablas y figuras van numeradas en orden y ningún párrafo las cita por número, así que puedes renumerarlas al integrar. Mis referencias van al final de mi texto, para juntarlas con las de ustedes.

## 5. Qué hay en cada carpeta

| Ruta | Qué es |
|---|---|
| `README.md` | Este archivo |
| `cargar_modelo.sql` | **Empieza aquí.** Crea y carga el modelo en un solo paso |
| `mapeo_origen_destino.xlsx` | A dónde va cada una de las 45 columnas de `covid_historica`, por qué llave se llega y qué regla se aplica. LOCALIDAD_RES es la única excluida |
| `sql/modelo/` | El modelo: `00_catalogos.sql`, `01_esquema_dw.sql` (con un comentario en cada tabla y columna) y `02_llaves_foraneas.sql` |
| `sql/prueba_carga/` | La carga probada: `10_dimensiones.sql` y `11_hechos.sql`, y la validación, `12_validacion.sql` |
| `sql/consultas/` | Cuatro preguntas de 1, 2 y 3 dimensiones, contra la tabla de ingesta y contra el modelo |
| `catalogos/` | Los 11 catálogos del Excel del profesor en CSV, limpios, y `paises_normalizacion.csv` |
| `diagramas/` | Vista general, diagrama principal y completo (PNG y PDF), jerarquías, `modelo_estrella.dbml` (se abre en dbdiagram.io) y `diccionario_modelo.csv`. Son de consulta: en el reporte ya van en mi parte |
| `evidencias/` | Mis resultados de la validación y de la comparación de consultas, para que comparen los suyos |
| `llm/` | Punto 2: los tres prompts en el orden en que se usaron, las respuestas completas de Qwen3, Granite y Mistral Nemo, la repetición de Qwen3, la evaluación del SQL de cada modelo, las notas de lectura y el intento con OLMo |
| `guias/guia_dbeaver_llm.md` | Los pasos del 3.1 (DBeaver con un LLM local); la prueba la hago yo |
| `correr_etl.sql`, `sql/06` a `08`, `sql/10_exploracion.sql`, `scripts/`, `evidencias/etl/`, `evidencias/exploracion/` | Parte de Melanie (sección 8) |
| `guias/guia_juan.md` | Guía de Juan: estado, pendientes, revisión del reporte y uso de Git |

## 6. Qué no trae y por qué

- **El texto del reporte** (mi documento, sus figuras y tablas): cada quien pega su parte en el Google Doc, y el reporte solo se pone en Drive.
- **La prueba de DBeaver (3.1):** está pendiente. Cuando la haga, sus capturas y respuestas se suman aquí.
- **Mis scripts de Python** (diagramas, mapeo, comparación de consultas y la corrida de los LLM): solo sirven para regenerar mis archivos y no hacen falta para cargar ni para usar el modelo. Si alguien cambia el modelo, yo regenero diagramas, mapeo y diccionario.
- **Los CSV originales:** no se suben, igual que en la Práctica 2, y `covid_historica` vive en su base. Los Excel del profesor ya están en `Practica02_Equipo3_MD/Diccionario_Datos/`.

## Si cambian algo del modelo

Avísenme antes de mover una tabla o una columna: el diagrama, el mapeo y el diccionario salen del catálogo de la base, y los regenero en un minuto.

*Cambios desde la versión del 30 de octubre:* se agregó `cargar_modelo.sql`, que corre todo en un paso y comprueba el resultado; cada script fija ahora la codificación UTF-8, porque en Windows los acentos detenían la carga; y el paquete ya no lleva archivos que solo sirven para regenerar los míos. El modelo, la carga y el mapeo no cambiaron.

## 7. Repartición de trabajo del equipo

Basado en la repartición acordada por el equipo. Lo mío va primero porque los otros dos dependen del modelo.

### Santiago, Arquitectura y Machine Learning

- Punto 1, justificación del modelo (estrella, copo de nieve o constelación, a partir de la Tabla 16 de la Práctica 2), con los incisos i a vii.
- Punto 2, comparación con tres LLM de software libre: prompts y su orden, si la respuesta fue mejor, peor o complementaria, mejoras y alucinaciones.
- Punto 3, diagrama del modelo (tablas, PK/FK, relaciones y atributos), con la prueba de DBeaver y un LLM (3.1).
- Revisar que el modelo traiga todos los campos menos LOCALIDAD_RES.

### Melanie, Ingeniería de Datos y Visualización

- Punto 4, diseño del ETL: el flujo de extracción, transformación, carga y validación, como diagrama y con los pasos numerados.
- Punto 5, implementación: el SQL que carga las dimensiones y la tabla de hechos, las consultas de conteo origen contra destino, las capturas y la bitácora de errores.
- Punto 6, exploración completa (pasó de Juan a Melanie): consultas de 1, 2 y 3 dimensiones, interpretación, hipótesis y gráficas.

### Juan, Coordinación

- Punto 7, calidad después de la migración: nulos y su porcentaje, duplicados en las dimensiones, llaves huérfanas, rangos y atípicos, con causas y soluciones; NACIONALIDAD contra su catálogo y los «NO ESPECIFICADO» de estado y municipio.
- Documento: portada, introducción, conclusiones, anexos e integración de las tres partes.

## 8. Parte de Melanie: ETL, exploración y gráficas

### Cómo correrlo (Windows, PowerShell)

```powershell
$env:PGCLIENTENCODING = "UTF8"
$psql = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
& $psql -h localhost -U postgres -d covid20a23sedi -f correr_etl.sql      # carga, unos 2 minutos
$env:PGPASSWORD = "<su contraseña>"                                      # solo en esa terminal
python scripts/exportar_consultas.py sql/08_validacion.sql etl             # validación
python scripts/exportar_consultas.py sql/10_exploracion.sql exploracion    # exploración
python scripts/graficar_p3.py                                              # 17 gráficas
```

`correr_etl.sql` y `cargar_modelo.sql` dan el mismo modelo: las dos cargas reconocen el archivo de 2022 con o sin la etiqueta « (reparado)». `correr_etl.sql` además registra filas y segundos de cada paso en `etl.control_carga`.

### Qué hay

| Ruta | Qué es |
|---|---|
| `correr_etl.sql` | Corre la carga completa y la comprueba (19 comprobaciones) |
| `sql/06_dimensiones.sql`, `07_hechos.sql`, `08_validacion.sql` | Punto 5: dimensiones, hechos y 18 consultas de validación |
| `sql/10_exploracion.sql` | Punto 6: 28 consultas de 1, 2 y 3 dimensiones, riesgo relativo crudo y ajustado por edad, reglas de asociación, roll-up y distribuciones |
| `scripts/exportar_consultas.py`, `scripts/graficar_p3.py`, `scripts/diagrama_flujo_etl.py` | Exportan cada consulta a CSV, dibujan las gráficas y el diagrama del flujo ETL |
| `diagramas/flujo_etl.png` | Punto 4: el flujo del ETL |
| `graficas/` (no se sube) | Las 17 gráficas del punto 6. Se generan con `graficar_p3.py` y ya van dentro del reporte |
| `evidencias/etl/`, `evidencias/exploracion/` | Salida de la carga y resultado de cada consulta, en CSV |
| Capturas de los puntos 5 y 6 (no se suben) | Van dentro del reporte, en Drive |
| `evidencias/bitacora_errores_p3.md` | Bitácora de errores del ETL |

### Resultado

- 2,099,997 casos en origen y destino, 0 rechazados, 0 duplicados, 0 llaves huérfanas y 0 diferencias al reconstruir las 44 columnas.
- La sección del reporte (`seccion_melanie_v2.docx`, solo en Drive) usa las **Figuras 4 a 30** y las **Tablas 11 a 20**, así que el Anexo A empieza en la Tabla 21.
