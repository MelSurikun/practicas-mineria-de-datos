"""
Práctica 02, Equipo 3.
Inspección preliminar de los CSV de origen (sección 1 del reporte).

Recorre cada archivo de Covid_Muestras/ y reporta tamaño, número de filas y
columnas, encabezados, codificación, delimitadores, formato de fechas y los
faltantes visibles (códigos centinela del diccionario, no celdas vacías).

Uso:
    python scripts/inspeccion.py
"""
import csv
import os

CARPETA = os.path.join(os.path.dirname(__file__), "..", "Covid_Muestras")
ARCHIVOS = [
    "muestra100k_COVID19MEXICOLOC2023.csv",
    "muestra200k_COVID19MEXICOLOC2022.csv",
]
CENTINELAS = {"97", "98", "99", "9999-99-99"}


def inspeccionar(nombre):
    ruta = os.path.join(CARPETA, nombre)
    tam = os.path.getsize(ruta)

    with open(ruta, "rb") as f:
        crudo = f.read()
    tiene_bom = crudo[:3] == b"\xef\xbb\xbf"
    tiene_crlf = b"\r\n" in crudo[:5000]
    try:
        crudo.decode("utf-8")
        codificacion = "UTF-8 (sin errores de decodificación)"
    except UnicodeDecodeError:
        codificacion = "No es UTF-8 válido"

    with open(ruta, encoding="utf-8-sig", newline="") as f:
        lector = csv.reader(f)
        encabezado = next(lector)
        n_filas = sum(1 for _ in lector)

    # formato de fechas: se toma la primera fila para inspeccionar una muestra
    with open(ruta, encoding="utf-8-sig", newline="") as f:
        lector = csv.reader(f)
        next(lector)
        primera = next(lector)

    print(f"Archivo: {nombre}")
    print(f"  Tamaño en disco: {tam:,} bytes (~{tam / 1024 / 1024:.1f} MB)")
    print(f"  Filas (sin encabezado): {n_filas:,}")
    print(f"  Columnas: {len(encabezado)}")
    print(f"  Encabezados: {encabezado}")
    print(f"  Codificación: {codificacion}, BOM: {tiene_bom}")
    print(f"  Terminador de fila CRLF detectado: {tiene_crlf}")
    print(f"  Delimitador de campo: ','")
    print(f"  Ejemplo de fila (para revisar formato de fechas y comillas): {primera}")
    print(f"  Valores centinela usados como faltantes: {sorted(CENTINELAS)}")
    print()
    return {"archivo": nombre, "tamano_bytes": tam, "filas": n_filas, "columnas": len(encabezado)}


if __name__ == "__main__":
    resultados = [inspeccionar(a) for a in ARCHIVOS]
    print("Resumen:")
    for r in resultados:
        print(f"  {r['archivo']}: {r['filas']:,} filas x {r['columnas']} columnas, "
              f"{r['tamano_bytes']:,} bytes")
