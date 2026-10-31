"""
Práctica 02, Equipo 3. Aportación de Santiago (Arquitecto).

Exporta a CSV lo que sql/08_catalogos_complementarios.sql carga con \\copy:

- las ocho hojas de Diccionario_Datos/201128 Catalogos.xlsx que no exporta
  scripts/exportar_catalogos.py (ese se encarga de entidades, municipios y sector);
- las 40 variables de Diccionario_Datos/201128 Descriptores.xlsx.

Los CSV quedan en Diccionario_Datos/ junto a los del 06 y tampoco se versionan
(se regeneran con este script).

Qué corrige del Excel y deja registrado en evidencias/catalogos_normalizacion.csv:
  - espacios al inicio o al final ("SI " -> "SI");
  - espacios dobles dentro del texto;
  - saltos de línea dentro de una celda (las descripciones de CLASIFICACION_FINAL);
  - hojas sin fila de encabezado (RESULTADO_LAB, RESULTADO_ANTIGENO y
    CLASIFICACION_FINAL empiezan con una fila vacía y luego datos): una fila
    cuenta como dato solo si su primera celda es una clave numérica.

Las claves se escriben como enteros, porque así están tipadas en covid_historica
(smallint). Las columnas se llaman clave_<catálogo> y <catálogo>, igual que en el
06 del equipo y en el modelo de la Práctica 3.

Requiere openpyxl. Uso, parado en Practica02_Equipo3_MD/:
    python scripts/exportar_catalogos_complementarios.py
"""

import csv
import re
import sys
from pathlib import Path

import openpyxl

CATALOGOS = Path("Diccionario_Datos/201128 Catalogos.xlsx")
DESCRIPTORES = Path("Diccionario_Datos/201128 Descriptores.xlsx")
DESTINO = Path("Diccionario_Datos")
EVIDENCIA = Path("evidencias/catalogos_normalizacion.csv")

# hoja -> (csv de salida, columnas)
HOJAS = {
    "Catálogo ORIGEN": ("cat_origen.csv", ["clave_origen", "origen"]),
    "Catálogo SEXO": ("cat_sexo.csv", ["clave_sexo", "sexo"]),
    "Catálogo TIPO_PACIENTE": ("cat_tipo_paciente.csv", ["clave_tipo_paciente", "tipo_paciente"]),
    "Catálogo SI_NO": ("cat_si_no.csv", ["clave_si_no", "si_no"]),
    "Catálogo NACIONALIDAD": ("cat_nacionalidad.csv", ["clave_nacionalidad", "nacionalidad"]),
    "Catálogo RESULTADO_LAB": ("cat_resultado_lab.csv", ["clave_resultado_lab", "resultado_lab"]),
    "Catálogo RESULTADO_ANTIGENO": ("cat_resultado_antigeno.csv", ["clave_resultado_antigeno", "resultado_antigeno"]),
    "Catálogo CLASIFICACION_FINAL": ("cat_clasificacion_final.csv", ["clave_clasificacion", "clasificacion", "descripcion"]),
}
COLUMNAS_DICCIONARIO = ["num", "nombre_variable", "descripcion", "formato_o_fuente"]


def es_clave(valor):
    """Una fila es dato si su primera celda es un número o un texto de solo dígitos."""
    if isinstance(valor, (int, float)):
        return True
    return isinstance(valor, str) and valor.strip().isdigit()


def limpiar(valor):
    """Quita espacios en los extremos y colapsa saltos de línea y espacios repetidos en uno solo."""
    if valor is None:
        return None
    if isinstance(valor, float) and valor.is_integer():
        valor = int(valor)
    return re.sub(r"\s+", " ", str(valor)).strip()


def leer(ws, columnas, cambios, hoja):
    """Filas de datos de una hoja, limpias; anota en cambios cada texto que se corrigió."""
    filas = []
    for n_fila, fila in enumerate(ws.iter_rows(values_only=True), start=1):
        if not es_clave(fila[0]):
            continue  # encabezado o fila vacía
        salida = []
        for col, original in zip(columnas, fila[: len(columnas)]):
            nuevo = limpiar(original)
            if col.startswith("clave_") or col == "num":
                nuevo = int(nuevo)
            elif nuevo != original and original is not None:
                cambios.append({"hoja": hoja, "fila_excel": n_fila, "columna": col,
                                "original": repr(original), "normalizado": repr(nuevo)})
            salida.append(nuevo)
        filas.append(salida)
    return filas


def escribir(nombre_csv, columnas, filas):
    with open(DESTINO / nombre_csv, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(columnas)
        w.writerows(filas)


def exportar():
    for ruta in (CATALOGOS, DESCRIPTORES):
        if not ruta.exists():
            sys.exit(f"No se encontró {ruta}. Corre el script parado en Practica02_Equipo3_MD/.")
    cambios = []

    wb = openpyxl.load_workbook(DESCRIPTORES, data_only=True)
    ws = wb.worksheets[0]
    filas = leer(ws, COLUMNAS_DICCIONARIO, cambios, ws.title)
    escribir("diccionario_variables.csv", COLUMNAS_DICCIONARIO, filas)
    print(f"{ws.title:32s} -> Diccionario_Datos/{'diccionario_variables.csv':28s} {len(filas):5d} filas")

    wb = openpyxl.load_workbook(CATALOGOS, data_only=True)
    for hoja, (nombre_csv, columnas) in HOJAS.items():
        if hoja not in wb.sheetnames:
            sys.exit(f"La hoja '{hoja}' no existe en el catálogo. Hojas disponibles: {wb.sheetnames}")
        filas = leer(wb[hoja], columnas, cambios, hoja)
        escribir(nombre_csv, columnas, filas)
        print(f"{hoja:32s} -> Diccionario_Datos/{nombre_csv:28s} {len(filas):5d} filas")

    EVIDENCIA.parent.mkdir(parents=True, exist_ok=True)
    with open(EVIDENCIA, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["hoja", "fila_excel", "columna", "original", "normalizado"])
        w.writeheader()
        w.writerows(cambios)
    print(f"\n{len(cambios)} textos normalizados -> {EVIDENCIA}")


if __name__ == "__main__":
    exportar()
