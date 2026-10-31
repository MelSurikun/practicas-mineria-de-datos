"""
Práctica 02, Equipo 3. Aportación de Santiago (Arquitecto).

Perfil estructural de los dos CSV, fila por fila, sin cargarlos a la base:

- cuántos campos trae cada fila (una fila con un número distinto al del
  encabezado es justo lo que rompió la primera carga de 2022);
- qué columnas vienen entre comillas y cuáles no (el archivo de origen entrecomilla
  lo que su sistema trata como texto, por ejemplo los códigos con ceros a la
  izquierda);
- longitud máxima observada por columna y si hay espacios o caracteres de control
  dentro de los valores;
- si las dos mitades del archivo de 2022 son idénticas byte por byte.

Escribe evidencias/perfil_csv_columnas.csv y evidencias/perfil_csv_resumen.json.
Solo usa la biblioteca estándar de Python.

Uso:
    python scripts/perfil_csv.py
"""
import collections
import json
import os
import re

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CARPETA = os.path.join(RAIZ, "Covid_Muestras")
EVIDENCIA = os.path.join(RAIZ, "evidencias")
ARCHIVOS = [
    "muestra200k_COVID19MEXICOLOC2022.csv",
    "muestra100k_COVID19MEXICOLOC2023.csv",
]

# Un campo CSV es "..." (con "" como comilla escapada) o un texto sin comas.
CAMPO = re.compile(r'"((?:[^"]|"")*)"|([^,]*)')
CONTROL = re.compile(r"[\x00-\x1f\x7f]")


def tokenizar(linea):
    """Regresa [(valor, venia_entre_comillas), ...] para una línea sin su CRLF."""
    campos, pos, n = [], 0, len(linea)
    while True:
        m = CAMPO.match(linea, pos)
        if m.group(1) is not None:
            campos.append((m.group(1).replace('""', '"'), True))
        else:
            campos.append((m.group(2), False))
        pos = m.end()
        if pos >= n:
            break
        if linea[pos] != ",":
            # texto pegado después de un campo (por ejemplo 97"FECHA_ACTUALIZACION"):
            # se consume hasta la siguiente coma como parte del mismo campo
            siguiente = linea.find(",", pos)
            valor, comillas = campos[-1]
            campos[-1] = (valor + linea[pos: siguiente if siguiente != -1 else n], comillas)
            if siguiente == -1:
                break
            pos = siguiente
        pos += 1
        if pos == n:  # coma final: campo vacío
            campos.append(("", False))
            break
    return campos


def mitades(ruta, tam):
    """Posición del segundo encabezado y si las dos mitades son idénticas (por bloques)."""
    import hashlib
    import mmap
    with open(ruta, "rb") as f, mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ) as mm:
        marca = mm[:40]
        segunda = mm.find(marca, 1)
        if segunda == -1:
            return None, None
        if 2 * segunda != tam:
            return segunda, False
        h1, h2, bloque = hashlib.sha256(), hashlib.sha256(), 1 << 24
        for ini in range(0, segunda, bloque):
            fin = min(ini + bloque, segunda)
            h1.update(mm[ini:fin])
            h2.update(mm[segunda + ini: segunda + fin])
        return segunda, h1.digest() == h2.digest()


def perfilar(nombre):
    ruta = os.path.join(CARPETA, nombre)
    tam = os.path.getsize(ruta)
    campos_por_fila = collections.Counter()
    filas_irregulares = []
    lf_sin_cr = 0
    termina_con_salto = False
    with open(ruta, encoding="utf-8", newline="") as f:
        primera = f.readline()
        encabezado = [v for v, _ in tokenizar(primera.rstrip("\r\n"))]
        n_col = len(encabezado)
        col = {c: {"con_comillas": 0, "sin_comillas": 0, "vacios": 0, "long_max": 0,
                   "con_espacio_o_control": 0, "ejemplo_espacio_o_control": ""}
               for c in encabezado}
        n_lineas = 1
        for i, cruda in enumerate(f, start=2):  # i = línea física (encabezado = 1)
            n_lineas += 1
            termina_con_salto = cruda.endswith("\n")
            if cruda.endswith("\n") and not cruda.endswith("\r\n"):
                lf_sin_cr += 1
            linea = cruda[:-2] if cruda.endswith("\r\n") else cruda.rstrip("\n")
            campos = tokenizar(linea)
            campos_por_fila[len(campos)] += 1
            if len(campos) != n_col:
                filas_irregulares.append({"linea": i, "campos": len(campos),
                                          "inicio": linea[:60], "fin": linea[-60:]})
                continue
            for (valor, comillas), c in zip(campos, encabezado):
                d = col[c]
                d["con_comillas" if comillas else "sin_comillas"] += 1
                if valor == "":
                    d["vacios"] += 1
                if len(valor) > d["long_max"]:
                    d["long_max"] = len(valor)
                if valor != valor.strip() or CONTROL.search(valor):
                    d["con_espacio_o_control"] += 1
                    if not d["ejemplo_espacio_o_control"]:
                        d["ejemplo_espacio_o_control"] = f"línea {i}: {valor!r}"

    resumen = {
        "archivo": nombre,
        "bytes": tam,
        "lineas_fisicas": n_lineas,
        "filas_de_datos": n_lineas - 1,
        "termina_con_salto_de_linea": termina_con_salto,
        "lf_sin_cr": lf_sin_cr,
        "columnas_encabezado": n_col,
        "campos_por_fila": dict(campos_por_fila),
        "filas_irregulares": filas_irregulares,
    }
    segunda, identicas = mitades(ruta, tam)
    if segunda is not None:
        resumen["encabezado_repetido_en_byte"] = segunda
        resumen["mitades_identicas"] = identicas
    return resumen, [{"archivo": nombre, "columna": c, **d} for c, d in col.items()]


if __name__ == "__main__":
    resumenes, filas = [], []
    for nombre in ARCHIVOS:
        r, f = perfilar(nombre)
        resumenes.append(r)
        filas.extend(f)
        print(json.dumps(r, ensure_ascii=False, indent=1))
    with open(os.path.join(EVIDENCIA, "perfil_csv_resumen.json"), "w", encoding="utf-8") as f:
        json.dump(resumenes, f, ensure_ascii=False, indent=1)
    import csv
    with open(os.path.join(EVIDENCIA, "perfil_csv_columnas.csv"), "w", encoding="utf-8",
              newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(filas[0].keys()))
        w.writeheader()
        w.writerows(filas)
    print("Escrito evidencias/perfil_csv_resumen.json y evidencias/perfil_csv_columnas.csv")
