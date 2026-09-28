# scripts

Scripts de Python auxiliares. Ninguno reemplaza a los scripts SQL de `sql/`, son apoyo para
inspeccionar, reparar y visualizar.

| Script | Qué hace | Cuándo correrlo |
|---|---|---|
| `inspeccion.py` | Recorre los dos CSV de `Covid_Muestras/` y reporta tamaño, filas, columnas, encabezados, codificación y formato de fechas | Antes de cargar nada, para producir `evidencias/inspeccion_archivos.md` |
| `reparar_csv_2022.py` | Genera una copia reparada de `muestra200k_COVID19MEXICOLOC2022.csv`, sin modificar el original. El archivo trae el encabezado del CSV duplicado a la mitad, ver `evidencias/bitacora_errores.md`, hallazgo 6 | Antes de correr `sql/03_ingesta.sql`, que carga 2022 desde el archivo reparado |
| `graficar.py` | Genera las 4 gráficas del reporte, leyendo `covid_historica` con `psql --csv` (no usa `psycopg2`, no está instalado) | Después de correr `sql/05_consolidacion.sql`, cuando `covid_historica` ya existe |

Requieren `pandas` y `matplotlib` (`graficar.py`), y Python 3 con la librería estándar
(`inspeccion.py`, `reparar_csv_2022.py`).
