# graficas

Las 6 visualizaciones del reporte, generadas a partir de `covid_historica` (la tabla final,
ya sin duplicados) con `scripts/graficar.py`. También están embebidas directamente dentro de
`reporte/Reporte_Practica02_Equipo3.docx`, en la sección "Visualizaciones" y en la sección
"Detección de valores atípicos" del desarrollo; esta carpeta guarda los archivos fuente en
PNG, útiles para regenerarlas o para revisarlas sin abrir el Word.

| Archivo | Contenido | Consulta base |
|---|---|---|
| `01_nulos_por_columna.png` | Porcentaje de valores NULL por columna, barras horizontales ordenadas de mayor a menor | Un `count(*) FILTER (WHERE columna IS NULL)` por cada columna de `covid_historica` |
| `02_top_paises.png` | Top 10 de PAIS_NACIONALIDAD por número de registros, escala logarítmica porque México domina el total | `SELECT pais_nacionalidad, count(*) FROM covid_historica GROUP BY 1 ORDER BY 2 DESC LIMIT 10;` |
| `03_top_municipios.png` | Top 15 de MUNICIPIO_RES por número de registros, identificado por el nombre del municipio y la abreviatura de su entidad (catálogo), no por el código crudo | `SELECT ... FROM covid_historica h LEFT JOIN cat_municipios m ON ... LEFT JOIN cat_entidades e ON ...` |
| `04_distribucion_edad.png` | Histograma de EDAD, con el valor máximo observado marcado con una línea punteada como posible atípico | `SELECT edad FROM covid_historica WHERE edad IS NOT NULL;` |
| `05_edad_atipicos.png` | Distribución de EDAD en escala logarítmica con los tres umbrales de atípicos (Tukey 1.5 IQR, z-MAD, Tukey 3 IQR), calculados en el propio script a partir de los datos | Cuartiles, mediana y MAD de `edad`, ver Tabla 9 del reporte |
| `06_demora_por_sector.png` | Demora máxima entre FECHA_SINTOMAS y FECHA_INGRESO por sector que atendió, con el catálogo de sectores | `... JOIN cat_sector s ON s.clave_sector = h.sector ...`, ver Tabla 10 del reporte |

## Cómo regenerarlas

```powershell
$env:PSQL_PATH = "C:\Program Files\PostgreSQL\17\bin\psql.exe"  # opcional, si psql no está en el PATH
python scripts\graficar.py
```

El script corre las 6 consultas y sobreescribe las 6 imágenes de esta carpeta. Requiere:

- `sql/05_consolidacion.sql` ya ejecutado (lee de `covid_historica`).
- `sql/06_catalogos.sql` ya ejecutado, para las Gráficas 3 y 6, que usan `cat_municipios`,
  `cat_entidades` y `cat_sector`.
