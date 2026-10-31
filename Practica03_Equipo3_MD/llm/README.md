# llm

Evidencia del punto 2: la comparación del modelo del equipo con tres LLM de software libre,
corridos en local con Ollama 0.40.13. El análisis (mejor, peor o complementaria, mejoras y
alucinaciones) va en mi parte del reporte; aquí están los prompts, las respuestas completas y
lo que se midió sobre ellas.

## Cómo se corrió

- La misma conversación de tres turnos con cada modelo, en este orden: `prompts/01_justificacion.md`
  (contexto de los datos y la pregunta del punto 1), `prompts/02_ddl.md` (el SQL del modelo) y
  `prompts/03_evidencia.md` (hallazgos de los datos para que revise su diseño). Cada modelo ve
  en el historial sus propias respuestas anteriores.
- Temperatura 0 y semilla 42, contexto de 20,480 tokens y hasta 4,000 tokens de respuesta, sin
  razonamiento (Mistral Nemo no razona).
- Granite se cortó en 4,000 tokens en los tres turnos, así que se repitió con 12,000 tokens y
  contexto de 40,960. La corrida cortada queda como evidencia en `respuestas/granite4.2_8b_limite_4000/`.
- OLMo 3 no permite apagar el razonamiento y no llegó a responder el turno 1; quedó fuera de la
  comparación (`intento_olmo/README.md`).

| Corrida | Modelo | Licencia | Tokens de respuesta (turnos 1, 2 y 3) |
|---|---|---|---|
| `respuestas/qwen3_8b/` | qwen3:8b (Alibaba Cloud), 8.2B, Q4_K_M | Apache 2.0 | 2,311 · 684 · 2,166 |
| `respuestas/granite4.2_8b/` | granite4.2:8b (IBM), 8.8B, Q4_K_M | Apache 2.0 | 12,000 (cortado) · 6,778 · 10,422 |
| `respuestas/granite4.2_8b_limite_4000/` | la misma, con el límite de 4,000 | Apache 2.0 | 4,000 · 4,000 · 4,000 (los tres cortados) |
| `respuestas/mistral-nemo_12b/` | mistral-nemo:12b (Mistral AI y NVIDIA), 12.2B, Q4_0 | Apache 2.0 | 755 · 624 · 491 |
| `repeticion/qwen3_8b/` | qwen3:8b, otra vez | Apache 2.0 | Los tres turnos idénticos, byte por byte, a la primera corrida |

## Qué hay en cada carpeta

| Ruta | Qué es |
|---|---|
| `prompts/` | Los tres prompts, tal como se mandaron |
| `respuestas/<corrida>/` | `turno_N.md` (la respuesta), `turno_N.json` (lo que devolvió Ollama) y `metadatos.json` (modelo, licencia, cuantización, opciones, tokens y segundos de cada turno) |
| `repeticion/qwen3_8b/` | La repetición de Qwen3, para comprobar que con temperatura 0 la corrida se reproduce |
| `evaluacion/ddl/` | El SQL de cada modelo, extraído de su respuesta (turno 2, y turno 3 cuando reescribió su esquema), más `modelo_propuesto.sql`, el DDL del equipo, como control |
| `evaluacion/resumen.csv` | Una fila por corrida y turno: si el SQL corre en una base aparte, tablas, llaves, llaves foráneas que aceptan NULL, campos cubiertos de los 43 y si incluye LOCALIDAD_RES |
| `evaluacion/cobertura.csv` y `cobertura_revisada.csv` | Qué campos de `covid_historica` cubre cada modelo, por nombre y revisado a mano |
| `evaluacion/columnas_*.csv` | Cada columna de cada DDL con su campo de origen |
| `evaluacion/casos_que_no_caben.sql` y `.csv` | Cuántos casos reales rechazarían las restricciones de cada modelo (Granite: 2,051,620, el 97.7%) |
| `evaluacion/notas_de_lectura.md` | Lectura completa de cada turno, con número de línea y etiquetas (alucinación, contradicción, diseño, copia de la referencia) |
| `intento_olmo/` | Lo que produjo OLMo 3 y la prueba de sus niveles de razonamiento |
