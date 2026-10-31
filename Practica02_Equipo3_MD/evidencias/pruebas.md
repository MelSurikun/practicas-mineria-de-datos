# Pruebas y propuestas (Santiago)

Resultado de los scripts de `sql/pruebas/` y `sql/propuestas/`, y de la prueba de
reproducibilidad de esta carpeta. Las salidas de psql van copiadas tal como salen; los `.log`
no se suben (ver `.gitignore`), así que aquí queda lo que importa de cada uno.

Todo se corrió dos veces el 31 de octubre de 2026, la segunda desde un clon limpio del
repositorio, en una base `covid20a23sedi` nueva (PostgreSQL 18.1 en macOS, Python 3.13) y
siguiendo los pasos 1 a 12 de la sección 5 del `README.md`. Las dos corridas dieron lo mismo;
solo cambian los tiempos.

## 1. El error de la captura del enunciado (sección 3.3)

`sql/pruebas/diagnostico_error_enunciado.sql` carga el CSV original de 2022 en tablas
temporales con los tamaños del ejemplo del enunciado. Las filas de la captura (6968, 10139,
10675, 15328 y 17218) son las cinco primeras donde PAIS_ORIGEN trae un nombre de país en
lugar de 97: el error es de tipo, no de longitud ni de página de códigos.

```
--- Prueba A: stage del ejemplo del enunciado (pais_origen varchar(50))
ERROR:  value too long for type character varying(50)
CONTEXT:  COPY stage_ejemplo_enunciado, line 433268, column pais_origen: "Países de la Ex-U.R.S.S., excepto Ucrania y Bielorusia"
--- Prueba B: pais_origen smallint
ERROR:  invalid input syntax for type smallint: "China"
CONTEXT:  COPY stage_pais_origen_numerico, line 6968, column pais_origen: "China"
--- Prueba C: filas que fallarían en todo el archivo
 fallan_como_smallint | fallan_como_varchar50 | fallan_como_varchar100 | filas_stage_2022
----------------------+-----------------------+------------------------+------------------
                11044 |                     2 |                      0 |          3999996
```

## 2. Conversiones seguras (sección 4.2)

`sql/pruebas/prueba_conversion_segura.sql`: con un solo valor sucio, las conversiones de
`sql/04_tipado.sql` detienen toda la inserción; con `pg_input_is_valid()` el valor queda en
NULL y la carga sigue.

```
--- 1. Cast numérico de sql/04 (NULLIF + btrim + ::smallint) sobre un valor no numérico
ERROR:  invalid input syntax for type smallint: "N/A"
--- 2. Conversión de fechas de sql/04 (regex + ::date) sobre una fecha imposible
ERROR:  date/time field value out of range: "2023-02-30"
--- 3. Las mismas conversiones con pg_input_is_valid (PostgreSQL 16 o posterior)
   valor    | como_smallint | como_fecha
------------+---------------+------------
 12         |            12 |
         99 |            99 |
 N/A        |               |
 2023-02-30 |               |
 9999-99-99 |               |
 2023-02-28 |               | 2023-02-28
```

`sql/propuestas/04_tipado_conversion_segura.sql`, corrida en lugar del 04 y comparada fila
por fila con la `covid_tipada` del 04 del equipo:

| Comprobación | Resultado |
|---|---:|
| Filas de `covid_tipada` con la propuesta | 4,099,995 |
| Filas que solo están en la de la propuesta | 0 |
| Filas que solo están en la del 04 | 0 |
| Valores en `covid_tipado_rechazos` | 0 |
| Tiempo en las dos corridas, contra 27 y 16 s del 04 | 83 y 82 s |

Con estos CSV el resultado es el mismo; la diferencia es que la propuesta no se detiene si
algún día llega un valor sucio y deja ese valor en la tabla de rechazos.

## 3. Restricciones de dominio (sección 4.2)

`sql/propuestas/05b_restricciones_dominio.sql`, después de 06 y 08 (5 a 6 s sobre las 2,099,997
filas):

```
 llaves_foraneas | checks | sin_validar_sobre_historico
-----------------+--------+-----------------------------
              33 |      1 | fk_municipio_res
```

La llave del par de residencia queda NOT VALID por un solo registro, y las demás ya rechazan
valores fuera de catálogo:

```
-- validar el par de residencia sobre lo existente:
ERROR:  insert or update on table "covid_historica" violates foreign key constraint "fk_municipio_res"
DETAIL:  Key (entidad_res, municipio_res)=(8, 113) is not present in table "cat_municipios".
-- fila con SEXO = 5 (dentro de una transacción que se deshace):
ERROR:  insert or update on table "covid_historica" violates foreign key constraint "fk_sexo"
DETAIL:  Key (sexo)=(5) is not present in table "cat_sexo".
```

## 4. Reproducibilidad de la carpeta (sección 8.2)

| Paso | Resultado |
|---|---|
| 1 a 5 (`sql/01` a `05` y `reparar_csv_2022.py`) | Sin errores: 99,999 y 3,999,996 filas en las tablas de paso, 4,099,995 en `covid_tipada`, 2,099,997 en `covid_historica` y 1,999,998 en la auditoría |
| 6 y 7 (`exportar_catalogos.py`, `sql/06`, `sql/07`) | Sin errores |
| 8 (`exportar_catalogos_complementarios.py`, `sql/08`) | Sin errores; los ocho CSV son idénticos a los que usa el modelo de la Práctica 3. Corrido por segunda vez, no duplica filas |
| 9 a 11 (`ejecutar_consultas.py`) | Los 25 CSV de `validacion_esquema/`, `atipicos/` y `apoyo_anomalias/` salen idénticos, byte por byte, a los de mi aportación del 28 de septiembre. Solo cambia el texto «ver sql/10_atipicos.sql» en `n4`, que antes decía 08 |
| 12 (`graficar.py` y `graficar_atipicos.py`) | Las Gráficas 5 y 6 salen idénticas, píxel por píxel, a las del reporte final |
| `perfil_csv.py` | Los dos archivos de `evidencias/perfil_csv_*` salen idénticos |
| 09 a 11 con `psql -f`, en UTF-8 y en WIN1252 | Salida idéntica en las dos codificaciones. Sin la línea `SET client_encoding = 'UTF8'`, en WIN1252 `pais_nacionalidad = 'México'` cuenta 0 registros en lugar de 2,072,816 |

Ningún archivo de la carpeta trae contraseñas, llaves ni cadenas de conexión: los scripts
toman la conexión de las variables de PostgreSQL y, si no están, usan `localhost` y el
usuario `postgres`, igual que `graficar.py`.
