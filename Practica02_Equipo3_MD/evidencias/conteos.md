# Evidencia de conteos de la carga

Corresponde a las secciones 3 y 5.2 del reporte. Base `covid20a23sedi`, PostgreSQL 17.

## Carga de 2023

| Verificación | Resultado |
|---|---|
| Filas del CSV de origen | 99,999 |
| `SELECT count(*) FROM covid_stage_2023;` | 99,999 |
| Duración de la carga | Menos de un segundo |
| `archivo_origen` distintos poblados | 1 |

Carga sin incidentes al primer intento.

## Carga de 2022

| Verificación | Resultado |
|---|---|
| Filas del CSV original | 3,999,996 |
| Primer intento de carga (archivo original) | Falló: "datos extra después de la última columna esperada" en la línea 1,999,999. Ver `evidencias/bitacora_errores.md`, hallazgo 6 |
| Filas de la copia reparada (`scripts/reparar_csv_2022.py`) | 3,999,996, todas con 41 columnas |
| Segundo intento de carga (archivo reparado) | Exitoso |
| `SELECT count(*) FROM covid_stage_2022;` | 3,999,996 |
| Duración de la carga (`\copy`) | 63.3 segundos |
| Duración de poblar `archivo_origen` (`UPDATE`) | 127.7 segundos |
| `archivo_origen` distintos poblados | 1 |

## Verificación cruzada

- `SELECT max(length(pais_origen)) FROM covid_stage_2022;` devuelve 54, confirmando que el
  `varchar(50)` del ejemplo del enunciado hubiera truncado ese valor.
- `SELECT pais_nacionalidad FROM covid_stage_2022 WHERE pais_nacionalidad ILIKE '%xico%' LIMIT 1;`
  devuelve `México`, con el acento correctamente interpretado gracias a `ENCODING 'UTF8'`.
- `SELECT DISTINCT migrante FROM covid_stage_2022 WHERE migrante ~ '\s';` devuelve el valor con
  el carácter de tabulación suelto, confirmando el hallazgo 4 de la bitácora.

## Suma esperada de la histórica

| Origen | Filas |
|---|---|
| `covid_stage_2022` | 3,999,996 |
| `covid_stage_2023` | 99,999 |
| **Total** | **4,099,995** |

## Tabla tipada (`sql/04_tipado.sql`)

| Verificación | Resultado |
|---|---|
| `SELECT count(*) FROM covid_tipada;` | 4,099,995, coincide exactamente con la suma de los dos stages |
| Filas con `fecha_def` no nula | 34,342 (confirma que la conversión de 9999 99 99 a NULL no anuló toda la columna) |
| Filas con `municipio_um` no nula | 99,999, exactamente las filas que vienen de 2023 |

## Duplicados y tabla histórica final (`sql/05_consolidacion.sql`)

| Verificación | Resultado |
|---|---|
| `ID_REGISTRO` con más de una fila | 1,999,998 |
| `SELECT count(*) FROM covid_historica;` (una fila por `ID_REGISTRO`) | 2,099,997 |
| `SELECT count(*) FROM covid_historica_auditoria;` (filas descartadas) | 1,999,998 |
| Suma de las dos anteriores | 4,099,995, coincide con `covid_tipada` |

Casi la mitad de los `ID_REGISTRO` de la tabla tipada están duplicados, y todos esos
duplicados vienen del mismo archivo, el de 2022, ninguno del de 2023. Al comparar las filas
de cada duplicado columna por columna (las 44 columnas, no solo `ID_REGISTRO` y
`FECHA_ACTUALIZACION`), resultaron ser copias exactas: no son casos con un estatus
actualizado en una fecha distinta, como se esperaría de este tipo de dato, sino la misma fila
repetida dos veces. Esto refuerza la hipótesis del hallazgo 6 de la bitácora: el archivo de
2022 se armó concatenando dos extractos idénticos de la misma base (por eso el encabezado
duplicado aparece justo a la mitad), y cada caso quedó copiado dos veces, no actualizado dos
veces. La tabla `covid_historica` conserva una sola fila por caso (el desempate por
`FECHA_ACTUALIZACION` no cambia el resultado, porque las filas que compiten son idénticas);
`covid_historica_auditoria` conserva las descartadas, sin eliminarlas, como evidencia.

Verificación de que son copias exactas:

```sql
SELECT count(*) FROM (
    SELECT fecha_actualizacion, id_registro, origen, sector, entidad_um, sexo, entidad_nac,
           entidad_res, municipio_res, localidad_res, tipo_paciente, fecha_ingreso,
           fecha_sintomas, fecha_def, intubado, neumonia, edad, nacionalidad, embarazo,
           habla_lengua_indig, indigena, diabetes, epoc, asma, inmusupr, hipertension,
           otra_com, cardiovascular, obesidad, renal_cronica, tabaquismo, otro_caso,
           toma_muestra_lab, resultado_lab, toma_muestra_antigeno, resultado_antigeno,
           clasificacion_final, migrante, pais_nacionalidad, pais_origen, uci, count(*)
    FROM covid_tipada
    WHERE id_registro IN (SELECT id_registro FROM covid_tipada GROUP BY id_registro HAVING count(*) > 1)
    GROUP BY fecha_actualizacion, id_registro, origen, sector, entidad_um, sexo, entidad_nac,
             entidad_res, municipio_res, localidad_res, tipo_paciente, fecha_ingreso,
             fecha_sintomas, fecha_def, intubado, neumonia, edad, nacionalidad, embarazo,
             habla_lengua_indig, indigena, diabetes, epoc, asma, inmusupr, hipertension,
             otra_com, cardiovascular, obesidad, renal_cronica, tabaquismo, otro_caso,
             toma_muestra_lab, resultado_lab, toma_muestra_antigeno, resultado_antigeno,
             clasificacion_final, migrante, pais_nacionalidad, pais_origen, uci
    HAVING count(*) = 2
) x;
```

Devuelve 1,999,998, exactamente el total de filas duplicadas, confirmando que el 100% de
ellas son copias idénticas fila por fila.
