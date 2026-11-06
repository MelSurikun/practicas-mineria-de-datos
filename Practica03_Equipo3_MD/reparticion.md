# Práctica 3 · Repartición de tareas (Equipo 3)

**Práctica:** Diseño de modelo multidimensional, proceso ETL y exploración analítica
**Base de trabajo:** `covid20a23sedi` (PostgreSQL), tabla `covid_historica` de la Práctica 2 (deduplicada, con PK en `id_registro`)
**Punto de partida del modelo:** el esquema estrella propuesto en la Tabla 16 del reporte de la P2

---

## Estado al 5 de noviembre de 2026

| Integrante | Hecho | Falta |
|---|---|---|
| **Santiago** | Puntos 1, 2 y 3 redactados en el reporte; modelo, diagramas, jerarquías y anexos | Prueba de DBeaver con un LLM (3.1) y sus capturas; revisión final contra la rúbrica |
| **Melanie** | Puntos 4, 5 y 6 completos: ETL probado, validación, bitácora, 28 consultas, 17 gráficas, hipótesis, 9 capturas y su sección (`seccion_melanie_v2.docx`) | Pegar su sección en el Google Doc y avisar a Juan y a Santiago |
| **Juan** | Portada e introducción | Punto 7 (calidad), conclusiones, índice, anexos e integración del reporte. Su guía: `guias/guia_juan.md` |

## 1. Resumen

| Integrante | Roles | Puntos de la práctica | Peso en la rúbrica |
|---|---|---|---|
| **Santiago** | 5. Machine Learning · 6. Arquitecto | 1 (justificación), 2 (LLMs), 3 (diagrama) | 15% + 20% = **35%** |
| **Melanie** | 2. Ingeniera de Datos · 3. Analista de Datos · 4. Visualizadora | 4 (diseño ETL), 5 (implementación), 6 completo (exploración y gráficas) | 15% + 20% + 15% = **50%** |
| **Juan** | 1. Coordinador | 7 (calidad), 8 (documento) | 10% + 5% = **15% + coordinación e integración** |

**Cambio acordado (noviembre de 2026):** la exploración analítica (6a–c) pasó de Juan a Melanie, para que las consultas, su interpretación y las gráficas las haga una sola persona. Juan conserva la calidad de datos (7), el documento (8) y la coordinación e integración del reporte.

---

## 2. Reglas generales para los tres

- [ ] Se incluyen **todos los campos excepto `LOCALIDAD_RES`**.
- [ ] Los catálogos y el diccionario se leen en el contexto epidemiológico, tal como pide el enunciado:
  - `SE IGNORA` = incertidumbre explícita
  - `NO ESPECIFICADO` = problema de captura o de modelado administrativo
- [ ] Ningún valor original se sobreescribe sin dejar rastro (el mismo principio de la P2).
- [ ] Usamos la misma estructura de carpetas que en la P2:
  ```
  sql/          06_dimensiones.sql, 07_hechos.sql, 08_validacion.sql, 09_calidad.sql, 10_exploracion.sql
  scripts/      Python para gráficas o apoyo
  diagramas/    modelo multidimensional, jerarquías, flujo ETL
  evidencias/   capturas, bitacora_errores_p3.md, prompts_llm.md
  ```
- [ ] Cada quien entrega su sección **ya redactada** (no solo el código) para que Juan solo tenga que integrarla.
- [ ] Cada captura lleva un pie de figura que explique qué demuestra, igual que en la P2.

---

## 3. Santiago · Arquitecto + Machine Learning

### Punto 1. Justificación del modelo multidimensional (15%)
Elegir entre **estrella, copo de nieve o constelación** y argumentar por qué es el adecuado para los datos de COVID.

- [x] **i. Medidas y dimensiones.** Decidir qué columnas son medidas (por ejemplo `edad`, conteo de casos, días entre fechas) y cuáles son atributos de dimensión.
- [x] **ii. Jerarquías (dibujadas).** Como mínimo:
  - Tiempo: día → semana epidemiológica → mes → trimestre → año
  - Espacio: municipio → entidad → país
  - Paciente: edad → grupo de edad
- [x] **iii. Tabla(s) de hechos.** Definir el grano (un caso por `id_registro`, ya garantizado por la PK de la P2). Si se elige constelación, justificar la segunda tabla de hechos.
- [x] **iv. Redundancias.** Señalar dónde se repite información; por ejemplo, la dimensión de ubicación se usa para residencia, unidad médica y nacimiento (*role-playing dimension*), y lo mismo pasa con `dim_tiempo` para las 4 fechas.
- [x] **v. Granularidad de tiempo y espacio**, con todas las formas que pueden tomar (fecha de ingreso, de síntomas, de defunción, de resultado; entidad de residencia, de la unidad médica, de nacimiento).
- [x] **vi. Dimensiones temáticas:** granularidad, tipos y grupos (comorbilidades, resultado y clasificación, perfil del paciente, unidad médica).
- [x] **vii. Límite razonable de enriquecimiento** de tiempo y espacio (por ejemplo, días festivos y semana epidemiológica sí; hora no, porque no existe en los datos; población municipal sí, coordenadas de localidad no, porque `LOCALIDAD_RES` queda fuera).

### Punto 2. Comparación con 3 LLMs de software libre
- [x] Elegir 3 LLMs libres (por ejemplo Llama, Mistral, Qwen, Gemma o DeepSeek) y anotar la versión de cada uno.
- [x] **a.** Documentar el **prompt exacto** y el **orden** en que se usó con cada modelo (guardar en `evidencias/prompts_llm.md`).
- [x] **b.** Discutir si la respuesta fue **mejor, peor o complementaria** a la del equipo.
- [x] **c.** Proponer las **mejoras** que le harían a la respuesta de cada LLM.
- [x] **d.** Identificar **alucinaciones** (columnas que no existen, catálogos inventados, códigos mal interpretados). Conviene revisarlas contra `201128_Descriptores` y `201128_Catalogos`.
- [x] Sugerencia: una tabla comparativa de los 3 modelos contra la propuesta del equipo.

### Punto 3. Diagrama del modelo multidimensional (20%)
- [x] Diagrama con **tablas, PK, FK, relaciones y atributos principales**.
- [x] Dibujar por separado las jerarquías del inciso 1.ii.
- [ ] **3a.** Probar la conexión de **DBeaver con una LLM** y documentar los prompts usados (con capturas).
- [x] Exportar el diagrama en buena resolución a `diagramas/`.

### Rol de Arquitecto (revisar requisitos)
- [ ] Antes de entregar, revisar que el modelo y el reporte cumplan **todo** lo que pide el enunciado (usar la sección 7 de este archivo como checklist).
- [x] Confirmar que `LOCALIDAD_RES` no aparece en ninguna tabla.

### Entregables de Santiago
| Entregable | Para quién | Cuándo |
|---|---|---|
| Lista final de tablas, columnas, PK y FK | **Melanie** (lo necesita para el ETL) | **Fase 1, es lo primero** |
| Diagrama y jerarquías | Juan (para el reporte) | Fase 1 |
| Secciones redactadas de los puntos 1, 2 y 3 | Juan | Fase 2 |

---

## 4. Melanie · Ingeniera de Datos + Analista de Datos + Visualizadora

### Punto 4. Diseño del flujo ETL (15%)
Diagrama del flujo más los pasos numerados, siguiendo el ejemplo del enunciado:

- [x] **Extracción**
  1. Identificar la tabla de origen (`covid_historica`).
  2. Contar registros y columnas usadas.
  3. Documentar los filtros aplicados (por ejemplo, la exclusión de `LOCALIDAD_RES`).
- [x] **Transformación** (con las decisiones del punto 1: miembros especiales en lugar de `-99` y textos como en el catálogo oficial; ver la sección 4 del reporte)
  4. Estandarizar tipos a `INT` donde corresponda.
  5. Limpiar fechas (la centinela `9999-99-99` ya es `NULL` desde la P2; decidir cómo se representa en `dim_tiempo`, por ejemplo con un registro "sin fecha").
  6. Normalizar textos de mayúsculas a minúsculas.
  7. Generar catálogos con valores únicos (comorbilidades, perfiles, etc.).
  8. Reemplazar valores no válidos por `-99` y documentar el criterio.
- [x] **Carga**
  9. Insertar primero las dimensiones con claves únicas.
  10. Insertar después la tabla de hechos, con FK hacia las dimensiones.
- [x] **Validación**
  11. Comparar conteos origen vs. destino, detectar registros rechazados, revisar nulos, duplicados y atípicos.

### Punto 5. Implementación y migración (20%)
- [x] `sql/06_dimensiones.sql`: creación y carga de cada dimensión.
  - `dim_tiempo` (fecha, año, mes, día, nombre del mes, día de la semana, trimestre, semana epidemiológica, día festivo).
  - `dim_ubicacion` con **nombres** de entidad y municipio a partir de `201128_Catalogos.xlsx`.
  - El resto de dimensiones según el modelo de Santiago (paciente, comorbilidad, resultado, unidad médica…).
- [x] `sql/07_hechos.sql`: carga de la tabla de hechos con los `JOIN` hacia las dimensiones.
- [x] `sql/08_validacion.sql`: consultas de conteo entre `covid_historica` y la tabla de hechos (deben coincidir; si no, explicar la diferencia).
- [x] **Capturas** de cada ejecución en `evidencias/`.
- [x] `evidencias/bitacora_errores_p3.md`: cada error con el mismo formato de la P2 (evidencia → causa probable → solución → verificación).

### Punto 6a–c. Exploración analítica (15%)
La exploración debe mostrar **cómo cambia la interpretación** al pasar de 1 a 2 y a 3 dimensiones.

- [x] **6a. Una dimensión.** Consultas de distribución por año, entidad, sexo, grupo de edad, clasificación final y comorbilidad.
- [x] **6b. Dos dimensiones.** Por ejemplo: tiempo vs. ubicación, edad vs. resultado, sexo vs. comorbilidad, municipio vs. clasificación final.
- [x] **6c. Tres dimensiones.** Por ejemplo: tiempo + ubicación + resultado; sexo + grupo de edad + comorbilidad; municipio + mes + clasificación final.
- [x] Responder las preguntas del enunciado: *¿qué, cuándo y dónde ocurrió?*, *¿con qué características?*, *¿qué patrones aparecen al cruzar 2 o 3 dimensiones?*
- [x] **Interpretación de patrones y posibles hipótesis**, con un enfoque honesto: hablar de patrones observados, no de causas.
- [x] Guardar todas las consultas en `sql/10_exploracion.sql`; las gráficas de 6d salen de ellas.

### Punto 6d. Visualizaciones
Hacer las gráficas a partir de las consultas de `sql/10_exploracion.sql`:
- [x] 1 dimensión: barras o histogramas (por año, entidad, sexo, grupo de edad, clasificación final, comorbilidad).
- [x] 2 dimensiones: **mapa de calor** o barras agrupadas (por ejemplo tiempo vs. entidad, edad vs. resultado).
- [x] 3 dimensiones: **gráfico facetado** o matriz (por ejemplo mes + entidad + clasificación final).
- [x] Gráficas de distribución para que Juan detecte atípicos en el punto 7.
- [x] Cada gráfica con título, ejes etiquetados y pie de figura.

### Trabajo que puede adelantar mientras Santiago cierra el modelo
- [x] Construir `dim_tiempo` (sirve con cualquier modelo).
- [x] Cargar los catálogos de `201128_Catalogos.xlsx` como tablas en la base.
- [x] Construir `dim_ubicacion` con los nombres de entidades y municipios.

### Entregables de Melanie
| Entregable | Para quién | Cuándo |
|---|---|---|
| Modelo cargado y validado en la base | **Juan** (lo necesita para la calidad) | Fase 2 |
| Secciones redactadas de los puntos 4 y 5, con capturas | Juan | Fase 3 |
| Exploración (6a–c) redactada, con hipótesis, y gráficas del punto 6 | Juan | Fase 3 |

---

## 5. Juan · Coordinador

### Rol de Coordinador (planeación)
- [ ] Poner las fechas límite internas de cada fase y darles seguimiento.
- [ ] Asegurarse de que Santiago le pase el modelo a Melanie lo antes posible (es el cuello de botella).
- [ ] Llevar el control de esta checklist.

### Punto 7. Calidad de datos después de la migración (10%)
- [ ] Cantidad y **porcentaje de nulos** por columna relevante.
- [ ] **Duplicados** en las dimensiones.
- [ ] **FK sin correspondencia** (registros de hechos que apuntan a dimensiones inexistentes).
- [ ] **Rangos mínimos y máximos** en variables numéricas y fechas.
- [ ] **Atípicos** observados en las gráficas de distribución.
- [ ] Posibles **causas** de cada problema y **propuesta de solución**.
- [ ] ⚠️ **Verificar `NACIONALIDAD`** contra el catálogo (y aplicar el mismo criterio a otras columnas).
- [ ] ⚠️ **Revisar los `NO ESPECIFICADO`** en la clave de estado y de municipio.
- [ ] Guardar las consultas en `sql/09_calidad.sql`.

### Punto 8. Documento de entrega (5%)
- [x] **Portada:** nombre de la práctica, autores, grupo (5AV1), fecha, profesor y nombre del proyecto.
- [ ] Tabla de **roles por integrante**, igual que en la P2.
- [x] **Introducción:** el problema, el conjunto de datos y el propósito del modelo multidimensional.
- [ ] Integrar las secciones de desarrollo en el orden del enunciado.
- [ ] **Conclusiones**, respondiendo:
  - [ ] ¿Qué ventajas ofreció el modelo multidimensional frente a la tabla de ingesta?
  - [ ] ¿Qué dimensiones fueron más útiles para descubrir patrones?
  - [ ] ¿Qué consultas o indicadores podrían alimentar un dashboard?
  - [ ] ¿Qué mejoras le harían al modelo si el proyecto creciera en volumen, temporalidad o complejidad?
- [ ] **Anexos:** scripts completos, capturas, diccionario de datos y evidencias adicionales.

### Trabajo que puede adelantar mientras Santiago cierra el modelo
- [ ] Revisar `NACIONALIDAD` y los `NO ESPECIFICADO` directamente sobre `covid_historica`.
- [x] Redactar la portada y la introducción.

---

## 6. Orden de trabajo

```
FASE 1  ─────────────────────────────────────────────────────────
  Santiago   Modelo + diagrama  ──►  se lo pasa a Melanie
  Melanie    dim_tiempo, catálogos, dim_ubicacion (no dependen del modelo)
  Juan       NACIONALIDAD / NO ESPECIFICADO, portada e intro

FASE 2  ─────────────────────────────────────────────────────────
  Santiago   Comparación con 3 LLMs, prueba DBeaver + LLM, redacción de 1–3
  Melanie    Resto de dimensiones + tabla de hechos + validación  ──►  avisa a Juan
  Juan       Consultas de calidad sobre el modelo cargado

FASE 3  ─────────────────────────────────────────────────────────
  Santiago   Revisión de requisitos (checklist de la sección 7)
  Melanie    Exploración 6a–c + gráficas + redacción de 4, 5 y 6
  Juan       Conclusiones e integración del documento

FASE 4  ─────────────────────────────────────────────────────────
  Los tres   Revisión final del documento completo antes de entregar
```

**Dependencias críticas:**
1. Melanie no puede cargar la tabla de hechos sin el modelo de Santiago.
2. Juan no puede medir la calidad sin el modelo cargado por Melanie.
3. Las conclusiones de Juan usan los hallazgos de la exploración de Melanie.

---

## 7. Checklist final contra la rúbrica

| Criterio | Peso | Responsable | Listo |
|---|---|---|---|
| Justificación del modelo multidimensional (incisos i–vii) | 15% | Santiago | [x] |
| Comparación con 3 LLMs (prompt, orden, evaluación, mejoras, alucinaciones) | dentro del 15% | Santiago | [x] |
| Diagrama relacional/multidimensional + jerarquías + DBeaver/LLM | 20% | Santiago | [ ] falta DBeaver (3.1) |
| Diseño del proceso ETL | 15% | Melanie | [x] |
| Implementación: SQL de dimensiones y hechos, validación de conteos, capturas, errores | 20% | Melanie | [x] |
| Exploración de 1, 2 y 3 dimensiones + visualizaciones + hipótesis | 15% | Melanie | [x] |
| Calidad de datos (nulos, duplicados, FK, rangos, atípicos, NACIONALIDAD, NO ESPECIFICADO) | 10% | Juan | [ ] |
| Conclusiones (4 preguntas), redacción y anexos | 5% | Juan | [ ] |
| `LOCALIDAD_RES` excluida en todo el modelo | — | Santiago | [x] |
