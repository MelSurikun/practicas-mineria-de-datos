"""
Practica 02, Equipo 3.
Exporta las hojas "Catalogo de ENTIDADES" y "Catalogo MUNICIPIOS" del
diccionario oficial (Diccionario_Datos/201128 Catalogos.xlsx) a CSV, para
que sql/06_catalogos.sql las cargue con \\copy. No se versiona el CSV
resultante (se regenera con este script), solo el .sql que lo consume.

Uso:
    python scripts/exportar_catalogos.py
"""

import csv
import sys
from pathlib import Path

import openpyxl

ORIGEN = Path("Diccionario_Datos/201128 Catalogos.xlsx")
DESTINO = Path("Diccionario_Datos")

HOJAS = {
    "Catálogo de ENTIDADES": ("cat_entidades.csv", ["clave_entidad", "entidad_federativa", "abreviatura"]),
    "Catálogo MUNICIPIOS": ("cat_municipios.csv", ["clave_municipio", "municipio", "clave_entidad"]),
    "Catálogo SECTOR": ("cat_sector.csv", ["clave_sector", "sector"]),
}


def exportar():
    if not ORIGEN.exists():
        sys.exit(f"No se encontro {ORIGEN}. Corre este script parado en Practica02_Equipo3_MD/.")

    wb = openpyxl.load_workbook(ORIGEN, data_only=True)
    for hoja, (nombre_csv, encabezado) in HOJAS.items():
        if hoja not in wb.sheetnames:
            sys.exit(f"La hoja '{hoja}' no existe en el catalogo. Hojas disponibles: {wb.sheetnames}")
        ws = wb[hoja]
        ruta_salida = DESTINO / nombre_csv
        filas = 0
        with open(ruta_salida, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(encabezado)
            for i, row in enumerate(ws.iter_rows(values_only=True)):
                if i == 0:
                    continue  # encabezado original de la hoja
                if row[0] is None:
                    continue
                writer.writerow(row[: len(encabezado)])
                filas += 1
        print(f"{hoja} -> {ruta_salida} ({filas} filas)")


if __name__ == "__main__":
    exportar()
