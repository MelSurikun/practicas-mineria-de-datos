"""
Práctica 03, Equipo 3 (Melanie, Ingeniería de Datos).

Corre un .sql dividido en bloques "-- @consulta <nombre>" y guarda cada bloque como CSV en
evidencias/<carpeta>/<nombre>.csv. Separa los bloques igual que ejecutar_consultas.py de la
Práctica 2, pero extrae con `psql --csv`, como graficar.py, para no necesitar psycopg.

La contraseña se toma de PGPASSWORD o de pgpass; ninguna credencial va en el código.
Si psql está en otra ruta, define PSQL_PATH con la ruta completa.

Uso, parado en Practica03_Equipo3_MD/:
    python scripts/exportar_consultas.py sql/08_validacion.sql etl
"""
import os
import re
import subprocess
import sys
import time

PSQL = os.environ.get("PSQL_PATH", "C:/Program Files/PostgreSQL/17/bin/psql.exe")
DB = "covid20a23sedi"
USER = "postgres"
HOST = "localhost"
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def bloques(ruta_sql):
    """Regresa [(nombre, sql), ...]; lo que va antes de la primera consulta se ignora."""
    texto = open(ruta_sql, encoding="utf-8").read()
    trozos = re.split(r"^-- @consulta (\S+)\s*$", texto, flags=re.M)
    return list(zip(trozos[1::2], (s.strip() for s in trozos[2::2])))


def main(ruta_sql, carpeta):
    salida = os.path.join(RAIZ, "evidencias", carpeta)
    os.makedirs(salida, exist_ok=True)
    for nombre, sql in bloques(ruta_sql):
        t0 = time.time()
        subprocess.run(
            [PSQL, "-w", "-U", USER, "-h", HOST, "-d", DB, "-v", "ON_ERROR_STOP=1", "--csv",
             "-f", "-", "-o", os.path.join(salida, f"{nombre}.csv")],
            input=sql.encode("utf-8"),
            check=True,
            env={**os.environ, "PGCLIENTENCODING": "UTF8"},
        )
        print(f"{nombre}: {time.time() - t0:.1f} s")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
