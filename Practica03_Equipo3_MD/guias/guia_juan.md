# Guía de Juan: Práctica 3

Hola, Juan. Esta guía resume cómo va la práctica, qué te falta, qué revisar del reporte y cómo subir tus cambios a GitHub. Versión del 5 de noviembre de 2026.

## 1. Cambio de repartición

**La exploración analítica (6a–c) pasó a Melanie**, así que las consultas, la interpretación, las hipótesis y las gráficas del punto 6 las hace una sola persona. A ti te quedan:

| Punto | Qué es | Peso |
|---|---|---|
| **7. Calidad de datos después de la migración** | Nulos, duplicados, llaves huérfanas, rangos, atípicos, causas y soluciones | 10% |
| **8. Documento** | Portada, introducción, conclusiones, anexos e integración | 5% |
| **Coordinación** | Fechas internas, seguimiento y revisión final | — |

`reparticion.md` ya refleja el cambio.

## 2. Qué está hecho

| Quién | Qué | Dónde |
|---|---|---|
| Santiago | Puntos 1, 2 y 3: justificación del modelo, comparación con 3 LLM, diagrama, jerarquías y Anexo A (diccionario) | Ya en el Google Doc |
| Santiago | El modelo estrella (13 tablas) y su carga | `sql/modelo/`, `cargar_modelo.sql` |
| Melanie | Punto 4: diseño del ETL con su diagrama | `diagramas/flujo_etl.png` |
| Melanie | Punto 5: carga probada, validación (0 diferencias), bitácora y capturas | `correr_etl.sql`, `sql/06` a `08`, `evidencias/` |
| Melanie | Punto 6 completo: 28 consultas, 17 gráficas, interpretación, 7 hipótesis | `sql/10_exploracion.sql`, `evidencias/exploracion/`; las gráficas van dentro de su sección |
| Melanie | Su sección del reporte, ya redactada (puntos 4, 5 y 6) | `seccion_melanie_v2.docx`, en Drive |
| Tú | Portada e introducción | Ya en el Google Doc |

**Pendiente de Santiago:** la prueba de DBeaver con un LLM (sección 3.1) y sus capturas, no es necesario pero  puede complementar.

## 3. Lo que te falta

### Punto 7. Calidad de datos después de la migración

Guarda tus consultas en `sql/09_calidad.sql`. Si separas cada consulta con una línea `-- @consulta nombre`, puedes exportar todas a CSV con el script de Melanie:

```powershell
$env:PGPASSWORD = "<tu contraseña de postgres>"     # solo vale en esa terminal; no la guardes en un archivo
python scripts/exportar_consultas.py sql/09_calidad.sql calidad
```

Los resultados quedan en `evidencias/calidad/`. Esto es lo que pide el enunciado y en qué te puedes apoyar:

| Qué revisar | Ya está medido en | Lo que te falta |
|---|---|---|
| Nulos y su porcentaje por columna | — | Contar los NULL en las medidas (`edad_anios` en 34 casos, las demoras cuando el evento no ocurrió) y en `dim_unidad_medica` (clues y municipio en las 212 unidades no identificadas de 2022). En la tabla de hechos **ninguna llave es NULL**, porque los huecos apuntan a miembros especiales: explícalo |
| Duplicados en las dimensiones | `evidencias/etl/v03_duplicados_en_dimensiones.csv`: 0 en las 12 | Citarlo |
| Llaves sin correspondencia | `evidencias/etl/v04_llaves_huerfanas.csv`: 0 en las 16 llaves | Citarlo |
| Rangos mínimos y máximos | — | Edad (0 a 122), las 4 fechas por rol y las 3 demoras |
| Atípicos | Las Figuras 29 y 30 de Melanie (distribución de edad y de demoras) y `dim_calidad` | Interpretarlos: los 34 casos de 122 años (nacimiento implícito en 1900) y las colas de las demoras (hasta 273 días de síntomas a ingreso) |
| NACIONALIDAD contra el catálogo | Sección 4 de `README.md` | NACIONALIDAD solo toma 1 y 2 y coincide con PAIS_NACIONALIDAD; el problema está en el texto del país, que `dim_pais` clasifica en `tipo_valor` |
| Los «NO ESPECIFICADO» de estado y municipio | Sección 4 de `README.md` | ENTIDAD_RES nunca vale 99; MUNICIPIO_RES vale 999 en 26 casos de 16 entidades; ENTIDAD_NAC vale 99 en 27,186 casos, de los cuales 27,181 son extranjeros que debían llevar 97 |
| Causa probable y solución de cada problema | `evidencias/bitacora_errores_p3.md` (formato) | Una tabla: problema → causa → solución propuesta |

Para excluir lo dudoso en una consulta: `JOIN dw.dim_calidad q ... WHERE q.nivel_maximo <> 'ERROR'`.

### Conclusiones (punto 8)

Tienen que responder estas cuatro preguntas. Ya hay datos para cada una:

| Pregunta | De dónde sacar la respuesta |
|---|---|
| ¿Qué ventajas ofreció el modelo frente a la tabla de ingesta? | Sección 4 de `README.md` (SQL de 61 a 34 líneas, consultas hasta 4 veces más rápidas, 31% menos espacio sin índices) y `evidencias/comparacion/resumen.csv` |
| ¿Qué dimensiones fueron más útiles para descubrir patrones? | La sección de Melanie «Cómo cambia la interpretación al agregar dimensiones» (Tabla 19): edad, tiempo y comorbilidad |
| ¿Qué consultas o indicadores podrían alimentar un tablero? | La sección de Melanie «Uso para el negocio»: curva semanal con positividad, mapa por entidad, matriz de letalidad, reglas de mayor lift; `x24` a `x26` en `evidencias/exploracion/` |
| ¿Qué mejoras harían si el proyecto creciera? | Sección 4 de `README.md`: particionar por mes, vistas materializadas, carga incremental, población del INEGI para tener tasas, otras tablas de hechos (vacunación) |

### Integración del documento

1. **Orden de las secciones:** Portada → Índice → Roles → Introducción → 1, 2 y 3 (Santiago) → 4, 5 y 6 (Melanie) → 7 (tú) → Conclusiones → Anexos → Referencias.
2. **Pegar la sección de Melanie** (`seccion_melanie_v2.docx`, en Drive) después del punto 3. Si todavía ves marcadores amarillos `[CAPTURA ...]`, pídele a Melanie sus 9 capturas: cada marcador dice qué archivo va ahí.
3. **Numeración:**
   - Santiago usa las Figuras 1 a 3 y las Tablas 1 a 10.
   - Melanie usa las **Figuras 4 a 30** y las **Tablas 11 a 20**.
   - Tus figuras empiezan en la **31** y tus tablas en la **21**.
   - Las tablas del Anexo A de Santiago se recorren después de las tuyas.
   - Si Santiago agrega figuras en la 3.1, las de Melanie y las tuyas se recorren. Ninguno cita una figura por su número en el texto, así que solo cambian los pies.
4. **Índice:** hoy dice «Encabezado 1 … 2». En Google Docs: Insertar → Índice, después de aplicar los estilos de título (Título 1, Título 2) a cada sección.
5. **Tabla de roles** por integrante, como en la Práctica 2, con el cambio de la exploración.
6. **Referencias:** juntar las de Santiago con las tuyas en una sola lista.
7. **Anexos:** el diccionario (ya está), los scripts (en el repositorio) y las evidencias adicionales.

## 4. Qué revisar del reporte

- [ ] El índice está vacío («Encabezado 1 2»).
- [ ] La sección 3.1 (DBeaver) tiene la tabla de prompts, pero todavía no las respuestas ni las capturas: Santiago.
- [ ] La 3.1 dice «DBeaver Lite»: si Santiago la hace con otra edición, hay que cambiar esa frase.
- [ ] Faltan los puntos 4, 5 y 6 (la sección de Melanie, ya lista) y el 7 (tuyo).
- [ ] Faltan las conclusiones.
- [ ] La numeración de figuras y tablas no se repite después de integrar.
- [ ] Portada: confirmar con el equipo el nombre del proyecto. El README de Santiago propone «Caracterización de fallas de infraestructura y ruteo adaptativo ante eventos críticos en la Ciudad de México», que no parece de esta práctica de COVID.
- [ ] Revisar contra la tabla de la rúbrica (sección 7 de `reparticion.md`) antes de entregar.

## 5. Guía rápida de Git y GitHub

El repositorio es **https://github.com/MelSurikun/practicas-mineria-de-datos** y la rama es `main`. Para poder subir cambios, Melanie te tiene que agregar como colaborador (en GitHub: Settings → Collaborators) y tú aceptar la invitación que te llega por correo.

### Primera vez: descargar el repositorio

1. Instala **Git para Windows** (git-scm.com) si no lo tienes. Compruébalo en PowerShell con `git --version`.
2. Configura tu nombre y correo, una sola vez:
   ```powershell
   git config --global user.name "Tu Nombre"
   git config --global user.email "tu_correo@ejemplo.com"
   ```
3. Elige una carpeta **con ruta simple** (sin acentos ni espacios, como `C:\repos`) y clona ahí:
   ```powershell
   cd C:\repos
   git clone https://github.com/MelSurikun/practicas-mineria-de-datos.git
   cd practicas-mineria-de-datos
   ```
   La primera vez que subas algo, Windows te pedirá iniciar sesión en GitHub en una ventana del navegador.

### ¿En qué carpeta tengo que estar?

Los comandos de git funcionan en **cualquier carpeta dentro de `practicas-mineria-de-datos`**, que es donde vive la carpeta oculta `.git`. Si ves `fatal: not a git repository`, estás fuera. Para comprobarlo:

```powershell
git status
```

Si responde `On branch main`, estás bien. Para trabajar en la práctica: `cd Practica03_Equipo3_MD`.

### Cada vez que trabajes

```powershell
# 1. ANTES de empezar: bajar lo que subieron los demás
git pull

# 2. Trabajas: editas o creas tus archivos

# 3. Ver qué cambió
git status

# 4. Agregar SOLO tus archivos (no uses "git add ." a ciegas)
git add Practica03_Equipo3_MD/sql/09_calidad.sql Practica03_Equipo3_MD/evidencias/calidad/

# 5. Guardar el cambio con un mensaje que diga qué hiciste
git commit -m "Práctica 03: consultas de calidad del punto 7"

# 6. Volver a bajar por si alguien subió algo mientras trabajabas, y luego subir
git pull
git push
```

### Reglas para no pisar el trabajo de los demás

- **Siempre `git pull` antes de empezar y antes de `git push`.**
- **No edites los archivos de otro sin avisar:** los `sql/06` a `10` y `scripts/` son de Melanie; `sql/modelo/`, `sql/prueba_carga/` y `llm/` son de Santiago.
- **Nunca subas contraseñas.** Usa `$env:PGPASSWORD` solo en la terminal. El `.gitignore` ya bloquea archivos con «password» o «credencial» en el nombre, pero no revisa lo que escribes dentro de un archivo.
- **No se suben (ya los ignora el `.gitignore`):** los `.docx` de la Práctica 3 (el reporte va en Drive), la carpeta `temp/` y los CSV originales de COVID.

### Si algo sale mal

| Mensaje | Qué hacer |
|---|---|
| `rejected ... fetch first` al hacer push | Alguien subió antes que tú: `git pull` y luego `git push` |
| `CONFLICT (content): Merge conflict in archivo` | Los dos cambiaron el mismo archivo. Ábrelo en VS Code, elige qué conservar entre las marcas `<<<<<<<` y `>>>>>>>`, guarda y corre `git add archivo`, `git commit` y `git push`. Si es un archivo de otro, pregúntale antes |
| `Please tell me who you are` | Falta el paso 2 de «Primera vez» |
| `Permission denied` o `403` | Aún no eres colaborador o no aceptaste la invitación |
| Hiciste `git add` de algo que no querías | `git restore --staged archivo` (lo quita del commit sin borrarlo) |

Con VS Code también puedes hacer todo esto desde el ícono de **Control de código fuente** (la rama a la izquierda): ✓ para el commit y «Sincronizar cambios» para pull y push.

## 6. Cómo correr el modelo en tu base (si lo necesitas)

```powershell
cd C:\repos\practicas-mineria-de-datos\Practica03_Equipo3_MD
$env:PGCLIENTENCODING = "UTF8"
& "C:\Program Files\PostgreSQL\17\bin\psql.exe" -h localhost -U postgres -d covid20a23sedi -f correr_etl.sql
```

Tarda unos 2 minutos y al final deben salir 19 comprobaciones en OK. Si aparece un error, la tabla «Si algo falla» del `README.md` dice qué hacer.
