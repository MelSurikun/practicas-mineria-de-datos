# sql

Los 7 scripts que crean la base de datos, cargan los CSV, tipan, consolidan y validan la
información. Se ejecutan en este orden, cada uno depende del anterior (06 y 07 son
independientes entre sí, pero ambos requieren que 05 ya se haya corrido). El paso a paso
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

## Verificación rápida después de correr los 7

```sql
SELECT count(*) FROM covid_stage_2022;              -- 3999996
SELECT count(*) FROM covid_stage_2023;               -- 99999
SELECT count(*) FROM covid_tipada;                   -- 4099995
SELECT count(*) FROM covid_historica;                -- 2099997
SELECT count(*) FROM covid_historica_auditoria;      -- 1999998
SELECT count(*) FROM cat_entidades;                  -- 36
SELECT count(*) FROM cat_municipios;                 -- 2501
SELECT count(*) FROM cat_sector;                     -- 14
```

El detalle de cada cifra, con la evidencia de por qué salió así, está en
`evidencias/conteos.md`.
