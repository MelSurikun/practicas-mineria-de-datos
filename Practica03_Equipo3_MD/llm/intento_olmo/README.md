# El intento con OLMo 3 7B (`olmo-3:7b`)

OLMo 3, del Allen Institute for AI (Apache 2.0), era el cuarto modelo y el más abierto: publica también sus datos de entrenamiento y su código. Quedó fuera de la comparación porque no llegó a responder el turno 1. Esta carpeta guarda lo que produjo.

## Qué pasó

- Corrió en las mismas condiciones que los demás (temperatura 0, semilla 42, contexto de 20,480 tokens, caché KV en q8_0 con flash attention), salvo el razonamiento. OLMo 3 no permite apagarlo, así que tuvo 12,000 tokens de salida en lugar de 4,000.
- Turno 1: los 12,000 tokens se fueron en razonamiento (`turno_1_razonamiento.md`, 49,969 caracteres, en inglés) y la respuesta quedó vacía (`turno_1.md`, 0 caracteres; `done_reason = length` en `turno_1.json`).
- Tardó 11,727 s, del 31 de octubre a las 08:24 a las 11:39. Casi todo ese tiempo la Mac estuvo dormida en batería; despierta generaba entre 5 y 7 tokens por segundo, más lento que los otros tres. Dos causas probables, no medidas por separado: el razonamiento se acumula en el contexto y cada token nuevo atiende a todos los anteriores, y su atención no comparte cabezas (32 cabezas de llave y valor contra 8 de los otros), así que lee cuatro veces más caché por token.
- La corrida se detuvo durante el turno 2: con el turno 1 vacío, la conversación ya no era comparable con las de los demás.

## ¿Se podía acortar el razonamiento?

Ollama acepta niveles de razonamiento (`"think": "low"`) en algunos modelos. Con OLMo no surtió efecto. A la pregunta «¿Cuánto es 17 por 3? Responde solo el número», con temperatura 0:

| `think` | tokens generados | caracteres de razonamiento | respuesta |
|---|---|---|---|
| `"low"` | 432 | 1,427 | 51 |
| `true` | 232 | 763 | 51 |

Con el nivel bajo razonó más, no menos. No hay forma de pedirle una respuesta directa, y con 12,000 tokens no le alcanzó para empezarla.

## Lo que alcanza a verse en el razonamiento

No es una respuesta y no se evalúa como tal, pero muestra hacia dónde iba:

- Entiende las opciones como «snowflake, star schema, or conformed dimension» (línea 1): confunde la constelación de hechos con las dimensiones conformadas.
- Mete la localidad en la dimensión de ubicación (líneas 9, 72 y 101) aunque en la línea 53 reconoce que el enunciado excluye LOCALIDAD_RES.
- Redacta varias veces la lista completa de tablas dentro del razonamiento (el encabezado «Dimension Tables:» aparece 4 veces) en lugar de pasar a la respuesta.
