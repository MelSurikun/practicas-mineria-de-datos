# Guía de preparación del entorno, PostgreSQL

Antes de tocar los datos, cada integrante del equipo debe confirmar dos cosas en su propia
máquina: **(A)** que PostgreSQL está instalado y accesible desde la terminal, y **(B)** que
puede cargar un CSV de prueba sin errores. Esta guía cubre ambas.

## A. Verificar que tienes PostgreSQL instalado

### 1. Instalar (si aún no lo tienes)

Descarga el instalador desde https://www.postgresql.org/download/ (elige tu sistema
operativo) e instala la versión más reciente estable. Durante la instalación:
- Anota la contraseña que le pongas al usuario `postgres` (la vas a necesitar siempre).
- Deja marcada la opción de instalar **pgAdmin** y **herramientas de línea de comandos**.
- Anota el puerto (por defecto `5432`).

### 2. Confirmar que `psql` está en el PATH

Abre una terminal nueva (PowerShell, cmd o tu shell) y ejecuta:

```powershell
psql --version
```

Debe imprimir algo como `psql (PostgreSQL) 16.x`. Si da error de "comando no reconocido":
- Windows: agrega manualmente al PATH la carpeta `bin` de la instalación, típicamente
  `C:\Program Files\PostgreSQL\<versión>\bin`, y abre una terminal nueva. Mientras tanto,
  puedes usar la ruta completa del ejecutable en cada comando, por ejemplo
  `& "C:\Program Files\PostgreSQL\17\bin\psql.exe" ...` en PowerShell.
- Verifica también que el servicio esté corriendo: en Windows, busca "Servicios", y
  `postgresql-x64-<versión>` debe decir "En ejecución".

### 3. Probar la conexión

```powershell
psql -U postgres -h localhost -p 5432 -c "SELECT version();"
```

Te va a pedir la contraseña que pusiste al instalar. Si responde con una línea de versión de
PostgreSQL, la conexión funciona. Si el error es `password authentication failed`, la
contraseña es incorrecta; si es `connection refused`, el servicio no está corriendo.

### 4. Checklist rápido

- [ ] `psql --version` responde con un número de versión.
- [ ] El servicio de PostgreSQL aparece "en ejecución".
- [ ] `psql -U postgres -h localhost -c "SELECT version();"` conecta y responde.
- [ ] Tengo pgAdmin abierto y puedo ver el servidor `localhost` en el árbol de la izquierda
      (alternativa visual a los pasos anteriores).

## B. Probar que puedes cargar los datos

No hace falta cargar los 4 millones de filas para validar tu entorno, se prueba con un
extracto pequeño primero, como recomienda la repartición del equipo.

### 1. Coloca los CSV en `Covid_Muestras/`

Descomprime `Covid-2022a2023-BigMuestras.rar` (te lo compartió el profesor en Classroom) y
copia los dos CSV dentro de la carpeta `Covid_Muestras/` en la raíz de este repositorio (no
se suben a git por su tamaño, ver `.gitignore`). Los scripts SQL del equipo ya asumen esa
ubicación, así que no hace falta moverlos a otra carpeta.

### 2. Genera un archivo de prueba con las primeras 1,000 filas

Párate en la raíz del repositorio y ejecuta, en PowerShell (conserva el encabezado):

```powershell
Get-Content Covid_Muestras\muestra100k_COVID19MEXICOLOC2023.csv -TotalCount 1001 |
  Set-Content Covid_Muestras\prueba_2023.csv -Encoding utf8
```

`prueba_2023.csv` es solo para esta prueba, bórralo cuando termines o déjalo, ya está
cubierto por el mismo patrón `*.csv` del `.gitignore`.

### 3. Crea la base de datos y las tablas de paso

```powershell
psql -U postgres -h localhost -f sql\01_crear_bd.sql
psql -U postgres -h localhost -d covid20a23sedi -f sql\02_stages.sql
```

Verifica que existan:

```powershell
psql -U postgres -h localhost -d covid20a23sedi -c "\dt"
```

Debe listar `covid_stage_2022` y `covid_stage_2023`.

### 4. Carga el archivo de prueba (1,000 filas) con `\copy`

Abre `psql` interactivo para poder usar `\copy` (es un comando de cliente, no funciona con
`-c` desde fuera):

```powershell
psql -U postgres -h localhost -d covid20a23sedi
```

Y dentro de la sesión de `psql`:

```sql
\copy covid_stage_2023 (fecha_actualizacion, id_registro, origen, sector, entidad_um,
  municipio_um, clues, sexo, entidad_nac, entidad_res, municipio_res, localidad_res,
  tipo_paciente, fecha_ingreso, fecha_sintomas, fecha_def, intubado, neumonia, edad,
  nacionalidad, embarazo, habla_lengua_indig, indigena, diabetes, epoc, asma, inmusupr,
  hipertension, otra_com, cardiovascular, obesidad, renal_cronica, tabaquismo, otro_caso,
  toma_muestra_lab, resultado_lab, toma_muestra_antigeno, resultado_antigeno,
  clasificacion_final, fecha_resultado, migrante, pais_nacionalidad, pais_origen, uci)
FROM 'Covid_Muestras/prueba_2023.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '"', ENCODING 'UTF8');
```

Debe responder `COPY 1000`.

### 5. Verifica que los datos entraron bien

```sql
SELECT count(*) FROM covid_stage_2023;               -- esperado: 1000
SELECT * FROM covid_stage_2023 LIMIT 3;               -- revisa que las columnas no estén corridas
SELECT pais_nacionalidad FROM covid_stage_2023
  WHERE pais_nacionalidad ILIKE '%xico%' LIMIT 1;      -- "México" debe verse con acento, no como "M?xico"
```

Si el acento se ve mal, el problema es de `ENCODING`, revisa que tu terminal esté en UTF-8
(`chcp 65001` en `cmd`) y que el archivo no tenga BOM raro (los CSV originales no lo tienen).

### 6. Limpieza de la prueba

```sql
TRUNCATE covid_stage_2023;
```

Esto deja la tabla vacía y lista para la carga completa real, que se describe abajo.

### Checklist de esta parte

- [ ] Pude crear `covid20a23sedi` y las dos tablas de paso.
- [ ] `\copy` con el archivo de 1,000 filas terminó sin error y devolvió `COPY 1000`.
- [ ] `SELECT count(*)` coincide con lo esperado.
- [ ] Los acentos (`México`, etc.) se ven correctamente al hacer `SELECT`.

## C. Cuando vayas a hacer la carga completa real

No hace falta que los tres integrantes carguen los 4 millones de filas completos, basta con
que quien lo haga comparta los conteos de verificación con el resto del equipo (ver
`evidencias/conteos.md`). Si te toca a ti, hay un paso adicional antes de correr
`sql\03_ingesta.sql`:

El archivo original `muestra200k_COVID19MEXICOLOC2022.csv` trae un defecto real: el
encabezado del CSV aparece duplicado exactamente a la mitad del archivo, pegado sin salto de
línea al final de una fila (el detalle completo está en `evidencias/bitacora_errores.md`,
hallazgo 6). `sql\03_ingesta.sql` carga desde una copia reparada de ese archivo, no desde el
original, así que primero hay que generarla:

```powershell
python scripts\reparar_csv_2022.py
```

Debe imprimir que localizó el encabezado duplicado cerca del 50% del archivo y que escribió
`Covid_Muestras\muestra200k_COVID19MEXICOLOC2022_reparado.csv`. Ese archivo no se sube a git
(también lo cubre el patrón `*.csv` del `.gitignore`), así que cada quien lo regenera
localmente con este script.

Ya con eso, la carga completa es:

```powershell
psql -U postgres -h localhost -d covid20a23sedi -f sql\03_ingesta.sql
```

Los pasos siguientes de la práctica (tabla tipada, consolidación, visualizaciones) están
descritos en la sección 5 del `README.md`.

## Problemas comunes

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| `psql: command not found` | El PATH no incluye la carpeta `bin` de PostgreSQL | Agregarla al PATH y abrir una terminal nueva, o usar la ruta completa del ejecutable |
| `connection refused` | El servicio de PostgreSQL no está corriendo | Iniciar el servicio desde "Servicios" de Windows |
| `password authentication failed` | Contraseña incorrecta del usuario `postgres` | Usar la que se definió al instalar; si se perdió, se puede resetear en `pg_hba.conf` |
| `\copy` dice "No such file or directory" | La ruta usa `\` de Windows en vez de `/`, o el archivo no está donde se indica | Usar `/` en la ruta dentro de `\copy` (funciona igual en Windows) y confirmar la ruta con `dir` |
| `\copy` de `sql\03_ingesta.sql` dice que no encuentra el archivo `_reparado.csv` | No se corrió `scripts\reparar_csv_2022.py` antes | Correr ese script primero, como se explica en la sección C de esta guía |
| Los caracteres especiales salen como `?` o `Ã©` | Encoding de la terminal o de la conexión no es UTF-8 | `chcp 65001` antes de abrir `psql`, y confirmar `ENCODING 'UTF8'` en el `\copy` |
| `\copy` carga menos filas de las esperadas sin error visible | Puede haber una fila con salto de línea suelto dentro de un campo mal entrecomillado | Revisar con un editor de texto (VS Code o Notepad++) las filas cercanas al conteo faltante |
