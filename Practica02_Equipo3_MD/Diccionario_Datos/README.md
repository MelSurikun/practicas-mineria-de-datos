# Diccionario_Datos

Catálogos y descriptor de columnas oficiales de la Secretaría de Salud, necesarios para
interpretar los códigos del dataset y para validar el esquema tipado. A diferencia del resto
del material del curso (en la carpeta local `Ejemplo/`), estos tres archivos sí se
versionan, porque el equipo los necesita para reproducir el proceso.

| Archivo | Para qué sirve |
|---|---|
| `201128 Descriptores.xlsx` | Describe cada columna del dataset: qué significa y qué tipo de dato le corresponde. Es la referencia para `sql/04_tipado.sql` |
| `201128 Catalogos.xlsx` | Diccionario de códigos por columna: entidades, municipios, países, y los catálogos binarios de sí, no, no aplica o se ignora (97, 98, 99) |
| `201128 Catalogos.pdf` | La misma información que el Excel, en formato de lectura |

## Para qué se usan en esta práctica

- Interpretar los códigos centinela (97, 98, 99, 9999-99-99) como lo que son, valores del
  catálogo, no como datos faltantes reales.
- Validar que los tipos de datos de `covid_tipada` correspondan a lo que dice el
  descriptor (por ejemplo, qué columnas son numéricas, cuáles son fecha y cuáles deben
  quedarse como texto).
- Contrastar nombres de columna entre el diccionario y la práctica cuando no coinciden
  exactamente (por ejemplo, `OTRAS_COM` en el diccionario contra `otra_com` en la práctica).
