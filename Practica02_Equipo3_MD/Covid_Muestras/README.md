# Covid_Muestras

Esta carpeta recibe los dos archivos CSV originales de la práctica. Los CSV en sí **no se
suben a git** (ver `.gitignore` en la raíz del repositorio), así que después de clonar el
repositorio, cada integrante debe descomprimir `Covid-2022a2023-BigMuestras.rar` (entregado
por el profesor vía Classroom) y copiar aquí los dos archivos, antes de seguir
`GUIA_POSTGRESQL.md`.

## De dónde vienen los datos

Los datos provienen de la base histórica de casos de COVID-19 de la Secretaría de Salud de
México, en el formato oficial "COVID19MEXICO". Cada fila representa un caso o registro
individual, con variables demográficas (edad, sexo, entidad y municipio de residencia),
clínicas (síntomas, neumonía, intubación, comorbilidades) y de resultado (clasificación
final, ingreso a UCI, defunción).

## Los dos archivos

| Archivo | Periodo (según encabezado) | Filas reales | Columnas | Tamaño en disco |
|---|---|---|---|---|
| `muestra100k_COVID19MEXICOLOC2023.csv` | 2023 | 99,999 | 44 | ~20.2 MB |
| `muestra200k_COVID19MEXICOLOC2022.csv` | 2022 | 3,999,996 | 41 | ~686 MB |

Dos cosas importantes antes de trabajar con ellos:

**El nombre del archivo no corresponde a su contenido real.** El archivo llamado "200k"
trae casi 4 millones de filas, no doscientas mil, y "100k" tampoco tiene 100,000. Esto se
verificó contando bytes y saltos de línea, no es un error de descarga, así que no hay que
confundirse por el nombre al planear cuánto tiempo tomará cargar cada uno.

**Los dos archivos no comparten el mismo esquema.** El de 2023 incluye tres columnas que el
de 2022 no tiene: `MUNICIPIO_UM`, `CLUES` y `FECHA_RESULTADO`. El resto de las 41 columnas
coincide en nombre y orden entre ambos. Por eso la ingesta usa dos tablas de paso distintas
(`sql/02_stages.sql`), no una sola.

## Formato de los archivos

- Codificación **UTF-8, sin BOM**.
- Terminador de fila **CRLF** (salto de línea de Windows).
- Separador de campo: coma.
- Comillas dobles solo en algunos campos, no en todos.
- Fechas en formato `AAAA-MM-DD`.

Los valores faltantes **no aparecen como celdas vacías**. Se usan códigos centinela del
diccionario de datos oficial (ver `Diccionario_Datos/`): por ejemplo `97` significa "no
aplica", `98` o `99` significan "se desconoce" o "se ignora", y `9999-99-99` aparece en
columnas de fecha cuando el evento no ocurrió, como una defunción que no se dio. Ninguno de
estos códigos debe tratarse como un NULL real sin antes contrastarlo con el diccionario.

## Un defecto conocido en el archivo de 2022

El archivo original de 2022 trae el encabezado del CSV duplicado exactamente a la mitad del
archivo, pegado sin salto de línea al final de una fila. Esto tumba la carga si se usa el
archivo tal cual. Antes de cargarlo, corre `python scripts/reparar_csv_2022.py`, que genera
una copia reparada al lado (`muestra200k_COVID19MEXICOLOC2022_reparado.csv`, tampoco se sube
a git) sin modificar el original. El detalle completo está en
`evidencias/bitacora_errores.md`, hallazgo 6.
