"""
Práctica 02, Equipo 3. Aportación de Santiago (Arquitecto).

Ejecuta un archivo .sql dividido en bloques "-- @consulta <nombre>" y guarda el
resultado de cada bloque como CSV en evidencias/<carpeta>/<nombre>.csv. Sirve para
que cada cifra del reporte tenga detrás un archivo que se puede abrir y revisar.

La conexión se toma de las variables estándar de PostgreSQL (PGHOST, PGPORT, PGUSER,
PGPASSWORD o el archivo pgpass); si no están definidas, usa localhost, el usuario postgres
y la base covid20a23sedi, igual que graficar.py. Ninguna credencial va escrita en el código.

Requiere psycopg (pip install "psycopg[binary]"). Es opcional: los mismos SQL corren con
psql -f y muestran los resultados en pantalla; este script solo los guarda en CSV.

Uso, parado en Practica02_Equipo3_MD/:
    python scripts/ejecutar_consultas.py sql/09_validacion_esquema.sql validacion_esquema
    python scripts/ejecutar_consultas.py sql/10_atipicos.sql atipicos
    python scripts/ejecutar_consultas.py sql/11_apoyo_anomalias.sql apoyo_anomalias
"""
import csv
import os
import re
import sys
import time

import psycopg

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def partes(ruta_sql):
    """Regresa (preámbulo, [(nombre, sql), ...]). El preámbulo es todo lo que va antes de
    la primera consulta marcada (por ejemplo, la creación de tablas) y se ejecuta primero."""
    texto = open(ruta_sql, encoding="utf-8").read()
    trozos = re.split(r"^-- @consulta (\S+)\s*$", texto, flags=re.M)
    # trozos = [preámbulo, nombre1, sql1, nombre2, sql2, ...]
    return trozos[0], list(zip(trozos[1::2], (s.strip() for s in trozos[2::2])))


def tiene_sql(texto):
    sin_comentarios = re.sub(r"--[^\n]*", "", texto)
    return bool(sin_comentarios.strip())


def main(ruta_sql, carpeta):
    salida = os.path.join(RAIZ, "evidencias", carpeta)
    os.makedirs(salida, exist_ok=True)
    dbname = os.environ.get("PGDATABASE", "covid20a23sedi")
    host = os.environ.get("PGHOST", "localhost")
    user = os.environ.get("PGUSER", "postgres")
    preambulo, consultas = partes(ruta_sql)
    with psycopg.connect(dbname=dbname, host=host, user=user, autocommit=True) as con:
        if tiene_sql(preambulo):
            t0 = time.time()
            con.execute(preambulo)
            print(f"preámbulo ejecutado ({time.time() - t0:.1f} s)")
        for nombre, sql in consultas:
            t0 = time.time()
            with con.cursor() as cur:
                cur.execute(sql)
                if cur.description is None:
                    print(f"{nombre}: sin resultado ({time.time() - t0:.1f} s)")
                    continue
                columnas = [d.name for d in cur.description]
                filas = cur.fetchall()
            with open(os.path.join(salida, f"{nombre}.csv"), "w", encoding="utf-8", newline="") as f:
                w = csv.writer(f)
                w.writerow(columnas)
                w.writerows(filas)
            print(f"{nombre}: {len(filas)} filas ({time.time() - t0:.1f} s)")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
