# graficas

Las 4 visualizaciones del reporte, generadas a partir de `covid_historica` (la tabla final,
ya sin duplicados) con `scripts/graficar.py`. También están embebidas directamente dentro de
`reporte/Reporte_Practica02_Equipo3.docx`, en la sección "Visualizaciones" del desarrollo;
esta carpeta guarda los archivos fuente en PNG, útiles para regenerarlas o para revisarlas
sin abrir el Word.

| Archivo | Contenido | Consulta base |
|---|---|---|
| `01_nulos_por_columna.png` | Porcentaje de valores NULL por columna, barras horizontales ordenadas de mayor a menor | Un `count(*) FILTER (WHERE columna IS NULL)` por cada columna de `covid_historica` |
| `02_top_paises.png` | Top 10 de PAIS_NACIONALIDAD por número de registros, escala logarítmica porque México domina el total | `SELECT pais_nacionalidad, count(*) FROM covid_historica GROUP BY 1 ORDER BY 2 DESC LIMIT 10;` |
| `03_top_municipios.png` | Top 15 de MUNICIPIO_RES por número de registros, identificado junto con ENTIDAD_RES | `SELECT municipio_res, entidad_res, count(*) FROM covid_historica GROUP BY 1, 2 ORDER BY 3 DESC LIMIT 15;` |
| `04_distribucion_edad.png` | Histograma de EDAD, con el valor máximo observado marcado con una línea punteada como posible atípico | `SELECT edad FROM covid_historica WHERE edad IS NOT NULL;` |

## Cómo regenerarlas

```powershell
python scripts\graficar.py
```

El script se conecta a la base `covid20a23sedi` con la ruta completa de `psql` que tiene
escrita adentro (ajústala si tu instalación de PostgreSQL está en otra carpeta, o si `psql`
ya está en tu PATH), corre las 4 consultas y sobreescribe las 4 imágenes de esta carpeta.
Requiere que `sql/05_consolidacion.sql` ya se haya ejecutado, porque lee de
`covid_historica`.
