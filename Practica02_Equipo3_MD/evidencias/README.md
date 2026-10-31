# evidencias

Documentos de respaldo para las secciones 1, 3, 4, 5, 6 y 7 del reporte.

| Archivo | Corresponde a | Contenido |
|---|---|---|
| `inspeccion_archivos.md` | Sección 1 | Nombre, tamaño, filas, columnas, codificación, delimitadores y faltantes visibles de los dos CSV, generado con `scripts/inspeccion.py` |
| `bitacora_errores.md` | Sección 3.3 | Los 7 hallazgos de calidad encontrados, cada uno con evidencia, causa probable, solución aplicada y verificación |
| `conteos.md` | Secciones 3, 5.2 y 5.3 | Los conteos reales de cada carga y de cada tabla, incluida la consulta que demuestra que los duplicados son copias exactas y no casos con distinta fecha de actualización |
| `validacion_esquema/` | Secciones 4.1 y 4.2 | Un CSV por consulta de `sql/09_validacion_esquema.sql` (v1 a v9): nombres y tipos contra el diccionario, tamaños contra el ejemplo del enunciado, dominios contra los catálogos, municipios contra su entidad, fechas del stage, conversiones, NULL introducidos por el tipado, forma de `ID_REGISTRO` y restricciones |
| `atipicos/` | Sección 6, «Detección de valores atípicos» (Tablas 14 y 15, Gráficas 5 y 6) | Un CSV por consulta de `sql/10_atipicos.sql` (a1 a a7): parámetros robustos, resumen por criterio, por qué no se usa 1.5 IQR, cola de EDAD, registros con más de un criterio, demora por sector y el atípico colectivo |
| `apoyo_anomalias/` | Sección 6 (Tablas 10 a 13) | Un CSV por consulta de `sql/11_apoyo_anomalias.sql` (n1 a n9): centinelas por columna y en texto, fechas centinela, códigos no documentados, valores de país con problema, reglas entre atributos, ruido embebido, cobertura temporal y conflictos de esquema |
| `catalogos_normalizacion.csv` | Sección 4.2 (paso 8) | Los 42 textos del Excel que `scripts/exportar_catalogos_complementarios.py` limpió (espacios sobrantes, espacios dobles y saltos de línea), con su valor original |
| `perfil_csv_columnas.csv` y `perfil_csv_resumen.json` | Sección 1 | Campos por fila, comillas, longitudes y caracteres de control de cada columna, y la prueba de que las dos mitades del CSV de 2022 son idénticas byte por byte (`scripts/perfil_csv.py`) |
| `manifiesto_datos.csv` | Sección 1 | Tamaño y huella SHA-256 del RAR y de los dos CSV, para comprobar que cada quien tiene los mismos archivos |
| `pruebas.md` | Secciones 3.3, 4.2 y 8.2 | Resultado de `sql/pruebas/` y `sql/propuestas/` (error de la captura del enunciado, conversiones seguras, restricciones de dominio) y de la prueba de reproducibilidad de esta carpeta |
| `seccion7/` | Sección 7 | Pruebas de mi texto de la sección 7 con datos del proyecto semestral: el z-MAD sobre los reportes diarios de SACMEX marca exactamente los 30 días de abril de 2023, la edad 0 de *0311 que la estadística no detecta y las claves de alcaldía contra el INEGI. Se generaron con la base de la Práctica 1, que no está en este repositorio |

`carga2022.log` (si aparece en esta carpeta) es la salida cruda de `psql` de una de las
corridas, queda ignorado por `.gitignore`. La información que importa de ese log ya está
resumida en `conteos.md`.
