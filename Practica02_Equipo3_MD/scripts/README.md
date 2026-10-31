# scripts

Scripts de Python auxiliares. Ninguno reemplaza a los scripts SQL de `sql/`, son apoyo para
inspeccionar, reparar y visualizar.

| Script | Qué hace | Cuándo correrlo |
|---|---|---|
| `inspeccion.py` | Recorre los dos CSV de `Covid_Muestras/` y reporta tamaño, filas, columnas, encabezados, codificación y formato de fechas | Antes de cargar nada, para producir `evidencias/inspeccion_archivos.md` |
| `reparar_csv_2022.py` | Genera una copia reparada de `muestra200k_COVID19MEXICOLOC2022.csv`, sin modificar el original. El archivo trae el encabezado del CSV duplicado a la mitad, ver `evidencias/bitacora_errores.md`, hallazgo 6 | Antes de correr `sql/03_ingesta.sql`, que carga 2022 desde el archivo reparado |
| `exportar_catalogos.py` | Exporta las hojas de entidades, municipios y sector de `Diccionario_Datos/201128 Catalogos.xlsx` a `Diccionario_Datos/cat_*.csv` | Antes de `sql/06_catalogos.sql` |
| `graficar.py` | Genera las 6 gráficas del reporte, leyendo `covid_historica` con `psql --csv` (no usa `psycopg2`, no está instalado) | Después de correr `sql/05_consolidacion.sql`, cuando `covid_historica` ya existe |
| `exportar_catalogos_complementarios.py` | Exporta los otros ocho catálogos y las 40 variables de `201128 Descriptores.xlsx` a `Diccionario_Datos/`, con los textos limpios (espacios sobrantes y saltos de línea); deja cada corrección en `evidencias/catalogos_normalizacion.csv` | Antes de `sql/08_catalogos_complementarios.sql` |
| `ejecutar_consultas.py` | Corre un SQL dividido en bloques `-- @consulta <nombre>` y guarda cada resultado como CSV en `evidencias/<carpeta>/` | Después de 08, con `sql/09_validacion_esquema.sql`, `sql/10_atipicos.sql` y `sql/11_apoyo_anomalias.sql` |
| `graficar_atipicos.py` | Genera las Gráficas 5 y 6 tal como van en el reporte (detección de atípicos) y sobrescribe las versiones de `graficar.py`. Igual que este, usa `psql --csv` y la variable `PSQL_PATH` | Después de `graficar.py` |
| `perfil_csv.py` | Recorre los dos CSV sin cargarlos: campos por fila, comillas y longitudes por columna, y si las dos mitades del CSV de 2022 son idénticas (uno o dos minutos). Escribe `evidencias/perfil_csv_*` | Cuando se quiera, no depende de la base |

Requieren `pandas` y `matplotlib` (`graficar.py`, `graficar_atipicos.py`), `openpyxl`
(`exportar_catalogos.py`, `exportar_catalogos_complementarios.py`), `psycopg`
(`ejecutar_consultas.py`, opcional: `pip install "psycopg[binary]"`), y Python 3 con la
librería estándar (`inspeccion.py`, `reparar_csv_2022.py`, `perfil_csv.py`).
