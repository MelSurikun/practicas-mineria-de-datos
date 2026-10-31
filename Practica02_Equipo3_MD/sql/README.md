# sql

Los 11 scripts que crean la base de datos, cargan los CSV, tipan, consolidan y validan la
información. Se ejecutan en este orden, cada uno depende del anterior (06 y 07 son
independientes entre sí, pero ambos requieren que 05 ya se haya corrido; 08 requiere 06,
09 requiere 08, y 10 y 11 solo requieren 06). El paso a paso
completo con los comandos exactos de `psql` está en `GUIA_POSTGRESQL.md`, en la raíz del
repositorio, y la versión con interfaz gráfica (pgAdmin y SSMS) en `GUIA_INTERFAZ_GRAFICA.md`.

| Script | Qué hace |
|---|---|
| `01_crear_bd.sql` | Crea la base de datos de trabajo `covid20a23sedi`, con codificación UTF8 |
| `02_stages.sql` | Crea las dos tablas de paso, todo en texto: `covid_stage_2022` (41 columnas) y `covid_stage_2023` (44 columnas). Son dos tablas porque los dos archivos de origen no comparten el mismo esquema |
| `03_ingesta.sql` | Carga los dos CSV con `\copy`. Carga primero 2023 y después 2022, este último desde una copia reparada del archivo (ver `scripts/reparar_csv_2022.py`), no desde el original |
| `04_tipado.sql` | Construye `covid_tipada`, con tipos de datos correctos (fechas, enteros) y las 44 columnas de ambos periodos. Usa `CASE` para las conversiones seguras, sin sobrescribir el valor original del stage |
| `05_consolidacion.sql` | Verifica que los conteos cuadren, detecta duplicados por `ID_REGISTRO` y construye la tabla final `covid_historica` (una fila por caso único, con `pk_covid_historica` sobre `id_registro`) y `covid_historica_auditoria` (las filas descartadas, conservadas como evidencia) |
| `06_catalogos.sql` | Carga `cat_entidades`, `cat_municipios` y `cat_sector` desde `Diccionario_Datos/201128 Catalogos.xlsx` (requiere antes `python scripts/exportar_catalogos.py`). Habilita el SELECT de dependencias entre atributos de la sección 6 y las Gráficas 3 y 6 |
| `07_anomalias.sql` | Crea la vista `v_anomalias`, con 9 reglas de consistencia lógica entre atributos (embarazo vs. sexo, orden de fechas, UCI vs. intubación, etc.), usada en la sección "Preparación para el modelo multidimensional" del reporte |
| `08_catalogos_complementarios.sql` | Carga los otros ocho catálogos del diccionario (origen, sexo, tipo de paciente, SI_NO, nacionalidad, resultado de laboratorio, resultado de antígeno y clasificación final) y `diccionario_variables`, con las 40 variables del descriptor (requiere antes `python scripts/exportar_catalogos_complementarios.py`). Mismas convenciones que el 06 (`clave_<catálogo>`, claves smallint); no borra nada y se puede correr dos veces |
| `09_validacion_esquema.sql` | Solo lectura. Compara `covid_historica` contra el diccionario y los once catálogos: nombres y tipos (incluido `OTRAS_COM` contra `otra_com`), tamaños contra el ejemplo de tabla temporal del enunciado, dominios, municipios contra su entidad, fechas del stage, conversiones, NULL introducidos por el tipado y la llave `ID_REGISTRO` |
| `10_atipicos.sql` | Crea `covid_atipicos`, con una fila por registro y criterio que cumple: reglas de dominio, estadística robusta (z-MAD y Tukey) y reglas contextuales sobre EDAD y los intervalos entre fechas. No borra ni modifica `covid_historica`. Respalda las Tablas 14 y 15 del reporte (las Gráficas 5 y 6 las dibuja `scripts/graficar_atipicos.py`) |
| `11_apoyo_anomalias.sql` | Solo lectura. Anomalías contra el diccionario y los catálogos, ordenadas con la clasificación de Rahm y Do: centinelas por columna y en texto, códigos no documentados, valores de país con problema, 20 reglas entre atributos, ruido embebido, cobertura temporal y conflictos de esquema (Tablas 10 a 13 del reporte) |

Cada consulta de 09, 10 y 11 empieza con un comentario `-- @consulta <nombre>`:
`python scripts/ejecutar_consultas.py <script> <carpeta>` guarda cada una como CSV en
`evidencias/<carpeta>/`. Con `psql -f` corren igual y los resultados salen en pantalla.

## propuestas/ y pruebas/ (opcionales)

No forman parte de la carga. El resultado de cada una está en `evidencias/pruebas.md`.

| Script | Qué hace |
|---|---|
| `propuestas/04_tipado_conversion_segura.sql` | Alternativa a `04_tipado.sql`: misma `covid_tipada`, con conversiones que no se detienen ante un valor sucio (`pg_input_is_valid()`, PostgreSQL 16 o posterior) y una tabla `covid_tipado_rechazos` con cada valor que no se pudo convertir. Se corre en lugar del 04 |
| `propuestas/05b_restricciones_dominio.sql` | Llaves foráneas de `covid_historica` hacia los catálogos y un CHECK de edad no negativa; la del par entidad-municipio de residencia va NOT VALID por el registro 4d0ea9. Después de 06 y 08. Con las llaves puestas, el 06 ya no se puede volver a correr |
| `pruebas/diagnostico_error_enunciado.sql` | Reproduce el error de la captura del enunciado (columna 40, PAIS_ORIGEN) con el CSV original de 2022, en tablas temporales |
| `pruebas/prueba_conversion_segura.sql` | Muestra que el cast directo del 04 se detiene ante un valor sucio y `pg_input_is_valid()` no |

## Verificación rápida después de correr los 11

```sql
SELECT count(*) FROM covid_stage_2022;              -- 3999996
SELECT count(*) FROM covid_stage_2023;               -- 99999
SELECT count(*) FROM covid_tipada;                   -- 4099995
SELECT count(*) FROM covid_historica;                -- 2099997
SELECT count(*) FROM covid_historica_auditoria;      -- 1999998
SELECT count(*) FROM cat_entidades;                  -- 36
SELECT count(*) FROM cat_municipios;                 -- 2501
SELECT count(*) FROM cat_sector;                     -- 14
SELECT count(*) FROM diccionario_variables;          -- 40
SELECT count(*) FROM cat_clasificacion_final;        -- 7
SELECT count(*) FROM covid_atipicos;                 -- 20265 (19,799 registros distintos)
```

El detalle de cada cifra, con la evidencia de por qué salió así, está en
`evidencias/conteos.md`.
