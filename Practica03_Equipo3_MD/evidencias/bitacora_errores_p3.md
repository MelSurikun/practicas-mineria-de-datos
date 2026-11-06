# Bitácora de errores del ETL (Práctica 3)

Corresponde al punto 5 del reporte. Solo se registra lo que pasó de verdad al ejecutar la carga en la base `covid20a23sedi` (PostgreSQL 17.11, Windows).

## Errores encontrados

| # | Evidencia | Causa probable | Solución aplicada | Verificación |
|---|---|---|---|---|
| 1 | La primera carga, con `cargar_modelo.sql`, se detuvo en los hechos: `ERROR: el valor nulo en la columna «id_extracto» de la relación «fact_casos_covid» viola la restricción de no nulo`. `dim_extracto` quedó con 1 fila en lugar de 2. Salida completa en `etl/01_fallo_carga_inicial.txt` | En esta base, `covid_historica.archivo_origen` vale `muestra200k_COVID19MEXICOLOC2022.csv (reparado)`, y la carga de prueba buscaba el nombre sin la terminación ` (reparado)`. El archivo de 2022 no encontraba su fila de metadatos y `dim_extracto` no lo incluía. La versión actual de `03_ingesta.sql` de la P2 escribe el nombre sin esa terminación, así que la base probablemente se cargó con una versión o un paso manual distinto: no se pudo confirmar cuál | En `sql/06_dimensiones.sql`, la comparación quita la terminación con `replace()` y la expresión que obtiene el año ya no exige que `.csv` sea el final del texto. El nombre se guarda tal como está en el origen, sin modificar `covid_historica`. El mismo cambio se aplicó después a `sql/prueba_carga/10_dimensiones.sql`, para que `cargar_modelo.sql` también funcione en bases con o sin la terminación | `correr_etl.sql` termina sin errores y sus 19 comprobaciones dan OK (`etl/02_correr_etl_corrida1.txt`). `v02` da 1,999,998 y 99,999 casos, y `v06` da 0 y 0 diferencias, incluida la columna `archivo_origen`. Una segunda corrida da los mismos conteos (`etl/03_correr_etl_corrida2.txt`). Con el parche, `cargar_modelo.sql` de Santiago también termina con las 19 comprobaciones en OK (5 de noviembre) |
| 2 | En los archivos de salida, la palabra «Duración» de `\timing` aparece como `Duraci�n` | Con `PGCLIENTENCODING=UTF8`, esos mensajes de psql se muestran con la codificación regional de Windows (`lc_messages` = `Spanish_Mexico.1252`). Afecta solo al texto de la consola | Ninguna: es cosmético y los datos no cambian. Se decidió no alterar la configuración del servidor | En `dw.dim_tiempo` y `dw.dim_ubicacion`, y en los CSV de `etl/` y `exploracion/`, los acentos se conservan |

**Lo que mostró el error 1.** La carga usa `LEFT JOIN` contra columnas `NOT NULL`, una decisión de diseño de Santiago. Por eso falló de inmediato. Con un `JOIN` normal habría terminado sin avisar, con 99,999 casos en lugar de 2,099,997: se habrían perdido 1,999,998 casos (95.24%).

## Diferencias contra los resultados de referencia

Se compararon las 15 consultas de validación con `evidencias/validacion/` de Santiago. 13 son idénticas y 2 difieren, sin que eso indique un problema:

| Consulta | Diferencia | Explicación |
|---|---|---|
| `v02_conteos_por_extracto` | El nombre del archivo lleva ` (reparado)` | Es el error 1. Los conteos son idénticos |
| `v14_tamanos` | `covid_historica` mide 433,061,888 bytes aquí contra 384,368,640 | El README de Santiago anticipa esta diferencia por el `DROP COLUMN` de la P2. Aquí el tamaño tampoco coincide con los 402,128,896 que él da para una base del equipo, y no se investigó más. Las filas de `v14` de los hechos y las dimensiones sí coinciden con las de Santiago |

## Problemas reportados por Santiago que aquí no ocurrieron

No son errores de esta ejecución; se citan para dar el contexto de cómo está hecha la carga.

| Tema | Lo que reportó | Situación aquí |
|---|---|---|
| Codificación | En Windows, los acentos detenían la carga (`character with byte sequence 0x81 in encoding "WIN1252"`) | No ocurrió: cada script fija `SET client_encoding = 'UTF8'` |
| Llaves foráneas durante la carga | 102 s con llaves e índices puestos, 23 s sin ellos (su máquina) | Se conservó su orden: llaves al final. Aquí la carga sin ellas tardó 94.58 s; no se midió la versión con ellas |
| Unión por CLUES | `coalesce` 0.30 s contra `IS NOT DISTINCT FROM` 1.85 s (su máquina) | Se conservó `coalesce`; no se volvió a medir |
