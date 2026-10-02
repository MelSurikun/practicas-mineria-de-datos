# Práctica 02, Minería de Datos, Equipo 3
## Ingesta, limpieza y análisis exploratorio de datos COVID-19

## 1. Objetivo de la práctica

Aplicar un proceso básico de **ingesta, validación, limpieza y análisis exploratorio (EDA)**
sobre datos reales de COVID-19 en México. El equipo debe identificar problemas de calidad de
datos, documentar sus soluciones y construir una tabla histórica intermedia adecuada para
procesos ETL posteriores. La práctica corresponde a las etapas de **comprensión de datos** y
**preparación de datos** del ciclo de vida de minería de datos (no se usa el formato completo
de CRISP-DM para el reporte, ver sección 5).

## 2. El dataset

Los datos provienen de la base histórica de casos de **COVID-19 de la Secretaría de Salud de
México**, en dos muestras entregadas por el profesor vía Classroom
(`Covid-2022a2023-BigMuestras.rar`). El detalle completo (tamaños reales, diferencia de
esquema entre los dos archivos, formato, códigos de valores faltantes, y un defecto conocido
en el archivo de 2022) está en `Covid_Muestras/README.md`.

## 3. Material de referencia

Los catálogos y el descriptor de columnas que el equipo necesita para validar dominios y
tipos de datos están en `Diccionario_Datos/`, y sí se versionan en el repositorio porque son
necesarios para reproducir el proceso:

- `201128 Descriptores.xlsx`: descripción y tipo esperado de cada columna.
- `201128 Catalogos.xlsx` y `201128 Catalogos.pdf`: diccionario de códigos por columna
  (entidades, municipios, países, catálogos binarios de sí, no, no aplica o se ignora).

El resto del material del curso (el enunciado de la práctica, la repartición de trabajo, la
lectura de referencia sobre limpieza de datos, y ejemplos de entregas anteriores) vive en la
carpeta local `Ejemplo/`, que cada integrante ya tiene desde Classroom. Esa carpeta no se
versiona (ver `.gitignore`), porque es material del profesor, no un entregable del equipo.

## 4. Estructura del repositorio

Cada carpeta tiene su propio `README.md` con el detalle de lo que contiene. Solo se muestran
aquí las carpetas y archivos que sí se suben a git. `Ejemplo/` existe en el disco de cada
integrante, pero está excluida por `.gitignore` y no llega al repositorio (ver ese archivo
para el detalle exacto de qué se excluye y por qué); `Covid_Muestras/` sí llega, pero solo
con su propio `README.md` adentro, cada integrante coloca ahí los CSV por su cuenta.

```
Practica02_Equipo3_MD/
├── README.md            : este archivo
├── GUIA_POSTGRESQL.md   : cómo verificar la instalación y probar la carga de datos
├── GUIA_INTERFAZ_GRAFICA.md : la misma carga documentada con pgAdmin y con SSMS
├── .gitignore           : excluye los CSV pesados, el material del curso y cualquier credencial
├── Covid_Muestras/      : dónde va cada CSV, y todo el detalle del dataset (los CSV en sí no se suben)
├── Diccionario_Datos/   : catálogos y descriptor de columnas, necesarios para reproducir el proceso
├── sql/                 : scripts de creación de BD, stages, ingesta, tipado, consolidación, catálogos y anomalías
├── evidencias/          : inspección de archivos, bitácora de errores, conteos
├── graficas/            : visualizaciones exportadas (PNG), también embebidas en el reporte
├── scripts/             : scripts de Python auxiliares (inspección, reparación de CSV, gráficas)
└── reporte/             : reporte final de la práctica (.docx)
```

Esto es lo que se comparte con el equipo a través del repositorio. Aparte de esto, cada
integrante puede armar su propia carpeta de entrega para el profesor (por ejemplo,
`Entregable_Profesor/`), que es solo una copia empaquetada de lo anterior, pensada para
subirse o enviarse como evidencia por separado, y no se sube al repositorio (ver
`.gitignore`).

## 5. Cómo reproducir el proceso

Motor usado: **PostgreSQL** (psql o pgAdmin). Antes de empezar, cada integrante debe seguir
`GUIA_POSTGRESQL.md` para confirmar que tiene el motor instalado y que puede cargar un CSV
de prueba sin errores. También necesita los dos CSV originales, entregados por el profesor
vía Classroom, colocados en una carpeta `Covid_Muestras/` en la raíz del repositorio (no se
suben a git por su tamaño).

1. Crear la base de datos: `sql/01_crear_bd.sql`.
2. Crear las tablas de paso ("stage", todo en texto), una por esquema de origen, 2022 con 41
   columnas y 2023 con 44: `sql/02_stages.sql`.
3. Cargar los CSV con `\copy`: `sql/03_ingesta.sql` (parámetros documentados en
   `evidencias/bitacora_errores.md`).
4. Construir la tabla tipada, convirtiendo fechas y numéricos con `CASE` (equivalente a
   `TRY_CONVERT` de SQL Server) sin sobrescribir el valor original del stage:
   `sql/04_tipado.sql`.
5. Consolidar ambos periodos y resolver duplicados por `ID_REGISTRO`: `sql/05_consolidacion.sql`.
6. Cargar los catálogos de referencia (entidad, municipio, sector), necesarios para las
   Gráficas 3 y 6 y para el análisis de dependencias entre atributos:
   `python scripts/exportar_catalogos.py` y luego `sql/06_catalogos.sql`.
7. Crear la vista de validación cruzada entre atributos: `sql/07_anomalias.sql`.
8. Generar las visualizaciones del reporte: `python scripts/graficar.py`.

La misma carga, documentada con interfaz gráfica en vez de línea de comandos (pgAdmin y
SSMS), está en `GUIA_INTERFAZ_GRAFICA.md`.

No se incluyen contraseñas, llaves ni credenciales en ningún script ni captura.


## 6. Repartición de trabajo del equipo

Basado en la repartición acordada por el equipo.

### Juan, Coordinación y Análisis de Datos

- Redacta introducción y conclusiones del reporte (propósito, dataset, estrategia,
  hallazgos y limitaciones de la muestra).
- Sección 6, EDA y calidad de `PAIS_NACIONALIDAD` y `MUNICIPIO_RES`: mínimo, máximo y
  valores distintos, anomalías contrastadas con el diccionario (códigos 97 y 99, municipios
  que no corresponden a su entidad, fechas centinela), conteo y porcentaje de NULL de todas
  las columnas.
- Ensambla el reporte final en un solo documento.
- **Entrega:** scripts SQL de la sección 6, tablas de resultados 6.1 a 6.3 con discusión,
  introducción y conclusiones, reporte final.

### Melanie, Ingeniería de Datos y Visualización

- Sección 1, inspección de cada CSV (nombre, tamaño, filas, columnas, encabezados,
  codificación, delimitadores, formato de fechas, faltantes visibles).
- Secciones 2 y 3, creación de la BD y de las tablas de paso, ingesta con `\copy`,
  documentación de cada parámetro, bitácora de errores de ingesta.
- Sección 4.2, tabla tipada final con conversiones seguras (`CASE`), sin sobrescribir los
  valores originales.
- Sección 5, consolidación de todos los archivos en la tabla histórica, verificación de
  conteos contra los CSV de origen, revisión de duplicados por `ID_REGISTRO`.
- Visualizaciones para todo el reporte (porcentaje de nulos por columna, top países y
  municipios con nombre, distribución de edad, distribución de edad con umbrales de
  atípicos, demora por sector).
- Catálogos de referencia (entidad, municipio, sector) y la vista de validación cruzada
  entre atributos, más la sección "Preparación para el modelo multidimensional" del reporte
  (esquema estrella y tabla de anomalías de consistencia lógica).
- Guía de carga con interfaz gráfica (`GUIA_INTERFAZ_GRAFICA.md`), pgAdmin y SSMS.
- **Entrega:** scripts SQL de creación, ingesta, tipado, consolidación, catálogos y
  anomalías, tabla de inspección de archivos, bitácora de errores, evidencia de conteos,
  criterio de duplicados, visualizaciones, guía de interfaz gráfica.

### Santiago, Machine Learning y Arquitectura

- Checklist de requisitos de la práctica (secciones 1 a 8) antes de entregar.
- Valida el esquema tipado contra el diccionario y catálogos oficiales (dominios, tamaños de
  columna, nombres, atención a `OTRAS_COM` del diccionario contra `otra_com` de la práctica).
- Revisa que el ZIP final sea reproducible y no lleve contraseñas ni credenciales.
- Apoya, si el tiempo lo permite, en la detección simple de valores atípicos en el EDA
  (por ejemplo `EDAD` fuera de rango), en la definición de tipos de columna de la sección 4.1
  y en las anomalías de la sección 6.2.
- Opcionalmente redacta la sección 7 (aplicación al proyecto semestral), previa consulta con
  el profesor.
- **Entrega:** checklist de requisitos, validación del esquema tipado, ZIP final revisado,
  texto de la sección 7 (si aplica).
