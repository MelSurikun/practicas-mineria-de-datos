"""
Práctica 02, Equipo 3.
Repara la corrupción encontrada en muestra200k_COVID19MEXICOLOC2022.csv.

Hallazgo (documentado también en evidencias/bitacora_errores.md, #6):
exactamente a la mitad del archivo, el encabezado aparece duplicado, pegado
sin salto de línea al final de la fila anterior. Todo apunta a que el archivo
se armó concatenando dos extractos sin quitar el segundo encabezado ni
insertar el salto de línea que le correspondía. Esto rompe la fila que quedó
justo en ese punto (el último campo se lee unido al encabezado, generando 81
"columnas" en lugar de 41) y hace que \\copy aborte toda la carga.

Este script NO modifica el archivo original: genera una copia reparada al
lado, insertando el salto de línea que faltaba y eliminando el renglón de
encabezado duplicado. No se inventa ni se descarta ningún valor de las
columnas; solo se restablece el separador de fila que el archivo de origen
tenía roto.

Uso:
    python scripts/reparar_csv_2022.py
"""
import os

CARPETA = os.path.join(os.path.dirname(__file__), "..", "Covid_Muestras")
ORIGINAL = os.path.join(CARPETA, "muestra200k_COVID19MEXICOLOC2022.csv")
REPARADO = os.path.join(CARPETA, "muestra200k_COVID19MEXICOLOC2022_reparado.csv")
MARCA_ENCABEZADO = b'"FECHA_ACTUALIZACION","ID_REGISTRO"'


def reparar():
    with open(ORIGINAL, "rb") as f:
        data = f.read()

    primera = data.find(MARCA_ENCABEZADO)
    if primera != 0:
        raise RuntimeError("El archivo no empieza con el encabezado esperado.")

    segunda = data.find(MARCA_ENCABEZADO, primera + 1)
    if segunda == -1:
        print("No se encontró un encabezado duplicado: el archivo ya parece sano, "
              "se copia tal cual.")
        with open(REPARADO, "wb") as f:
            f.write(data)
        return

    tercera = data.find(MARCA_ENCABEZADO, segunda + 1)
    if tercera != -1:
        raise RuntimeError("Se encontró más de una duplicación de encabezado; "
                            "revisar el archivo manualmente antes de continuar.")

    fin_encabezado_duplicado = data.find(b"\r\n", segunda)
    if fin_encabezado_duplicado == -1:
        raise RuntimeError("No se encontró el fin de línea del encabezado duplicado.")

    reparado = data[:segunda] + b"\r\n" + data[fin_encabezado_duplicado + 2:]

    print(f"Encabezado duplicado localizado en el byte {segunda:,} de {len(data):,} "
          f"(~{segunda / len(data):.0%} del archivo).")
    print(f"Tamaño original: {len(data):,} bytes. Tamaño reparado: {len(reparado):,} bytes. "
          f"Diferencia: {len(data) - len(reparado):,} bytes "
          f"(el largo del renglón de encabezado eliminado).")

    with open(REPARADO, "wb") as f:
        f.write(reparado)
    print(f"Copia reparada escrita en: {REPARADO}")


if __name__ == "__main__":
    reparar()
