# Inspección preliminar de los archivos de origen

Generado con `scripts/inspeccion.py`. Corresponde a la sección 1 del reporte.

| Elemento | muestra100k_COVID19MEXICOLOC2023.csv | muestra200k_COVID19MEXICOLOC2022.csv |
|---|---|---|
| Tamaño en disco | 20,258,324 bytes (~19.3 MB) | 686,356,922 bytes (~654.6 MB) |
| Filas (sin encabezado) | 99,999 | 3,999,996 |
| Columnas | 44 | 41 |
| Encabezados | Consistentes, en mayúsculas, sin espacios | Consistentes, mismo estilo |
| Codificación | UTF-8, sin BOM | UTF-8, sin BOM |
| Terminador de fila | CRLF | CRLF |
| Delimitador de campo | Coma | Coma |
| Comillas | Solo en algunos campos, no en todos | Igual, inconsistente |
| Formato de fechas | AAAA-MM-DD | AAAA-MM-DD |
| Faltantes visibles | Sin celdas vacías; se usan códigos centinela (97, 98, 99, 9999-99-99) | Igual, más una anomalía puntual: un tabulador dentro del campo MIGRANTE en algunas filas |

## Hallazgo: el nombre de archivo no corresponde al contenido

Ninguno de los dos nombres coincide con su número real de filas. El archivo llamado
"200k" trae casi 4 millones de registros y pesa 654.6 MB, no 200,000 filas como
sugiere su nombre. Se confirmó revisando el tamaño en bytes y contando los saltos de
línea del archivo, así que no es un error de descarga sino una discrepancia de
nomenclatura del archivo entregado.

## Diferencia de esquema entre los dos archivos

El CSV de 2023 incluye tres columnas que el de 2022 no tiene: MUNICIPIO_UM, CLUES y
FECHA_RESULTADO. Las 41 columnas restantes coinciden en nombre y orden entre ambos
archivos. Esto obliga a usar dos tablas de paso distintas (ver `sql/02_stages.sql`) y
a resolver la diferencia como un superconjunto de 44 columnas al consolidar la
información histórica.
