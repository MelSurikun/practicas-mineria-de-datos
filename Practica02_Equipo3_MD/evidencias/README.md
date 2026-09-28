# evidencias

Documentos de respaldo para las secciones 1, 3, 5 y 6 del reporte.

| Archivo | Corresponde a | Contenido |
|---|---|---|
| `inspeccion_archivos.md` | Sección 1 | Nombre, tamaño, filas, columnas, codificación, delimitadores y faltantes visibles de los dos CSV, generado con `scripts/inspeccion.py` |
| `bitacora_errores.md` | Sección 3.3 | Los 7 hallazgos de calidad encontrados, cada uno con evidencia, causa probable, solución aplicada y verificación |
| `conteos.md` | Secciones 3, 5.2 y 5.3 | Los conteos reales de cada carga y de cada tabla, incluida la consulta que demuestra que los duplicados son copias exactas y no casos con distinta fecha de actualización |

`carga2022.log` (si aparece en esta carpeta) es la salida cruda de `psql` de una de las
corridas, queda ignorado por `.gitignore`. La información que importa de ese log ya está
resumida en `conteos.md`.
