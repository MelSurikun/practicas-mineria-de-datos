"""
Práctica 02, Equipo 3.
Genera las 4 visualizaciones del reporte a partir de covid_historica.

No usa psycopg2 (no está instalado en esta máquina): en su lugar, cada gráfica
extrae sus datos con `psql --csv` a un archivo temporal y lo lee con pandas.

Requiere psql en el PATH, o edita PSQL abajo con la ruta completa
(por ejemplo "C:/Program Files/PostgreSQL/17/bin/psql.exe").

Uso:
    python scripts/graficar.py
"""
import os
import subprocess
import sys
import tempfile

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

PSQL = r"C:\Program Files\PostgreSQL\17\bin\psql.exe"
DB = "covid20a23sedi"
USER = "postgres"
HOST = "localhost"
CARPETA_SALIDA = os.path.join(os.path.dirname(__file__), "..", "graficas")

# Paleta neutral, consistente entre las 4 gráficas
COLOR_PRINCIPAL = "#2F5496"
COLOR_ATIPICO = "#C0392B"


def consultar(sql):
    """Corre una consulta con psql --csv y regresa un DataFrame de pandas."""
    with tempfile.NamedTemporaryFile(suffix=".csv", delete=False) as tmp:
        ruta = tmp.name
    try:
        subprocess.run(
            [PSQL, "-U", USER, "-h", HOST, "-d", DB, "--csv", "-c", sql, "-o", ruta],
            check=True,
            env={**os.environ},
        )
        return pd.read_csv(ruta)
    finally:
        os.unlink(ruta)


def grafica_nulos():
    # information_schema no da el conteo de NULL directamente; se arma
    # dinámicamente una consulta con un FILTER por columna.
    columnas = consultar(
        "SELECT column_name FROM information_schema.columns "
        "WHERE table_name = 'covid_historica' ORDER BY ordinal_position;"
    )["column_name"].tolist()

    partes = [f"count(*) FILTER (WHERE {c} IS NULL) AS {c}" for c in columnas]
    sql_nulos = f"SELECT {', '.join(partes)}, count(*) AS total FROM covid_historica;"
    df = consultar(sql_nulos)

    total = df["total"].iloc[0]
    porcentajes = (df.drop(columns="total").iloc[0] / total * 100).sort_values()

    fig, ax = plt.subplots(figsize=(8, 10))
    ax.barh(porcentajes.index, porcentajes.values, color=COLOR_PRINCIPAL)
    ax.set_xlabel("% de valores NULL")
    ax.set_title("Porcentaje de valores NULL por columna, covid_historica")
    fig.tight_layout()
    fig.savefig(os.path.join(CARPETA_SALIDA, "01_nulos_por_columna.png"), dpi=150)
    plt.close(fig)
    print("Generada 01_nulos_por_columna.png")


def grafica_top_paises():
    df = consultar(
        "SELECT pais_nacionalidad, count(*) AS n FROM covid_historica "
        "GROUP BY pais_nacionalidad ORDER BY n DESC LIMIT 10;"
    )
    fig, ax = plt.subplots(figsize=(8, 5))
    ax.barh(df["pais_nacionalidad"][::-1], df["n"][::-1], color=COLOR_PRINCIPAL)
    ax.set_xscale("log")
    ax.set_xlabel("Número de registros (escala logarítmica)")
    ax.set_title("Top 10 de PAIS_NACIONALIDAD")
    fig.tight_layout()
    fig.savefig(os.path.join(CARPETA_SALIDA, "02_top_paises.png"), dpi=150)
    plt.close(fig)
    print("Generada 02_top_paises.png")


def grafica_top_municipios():
    df = consultar(
        "SELECT municipio_res, entidad_res, count(*) AS n FROM covid_historica "
        "GROUP BY municipio_res, entidad_res ORDER BY n DESC LIMIT 15;"
    )
    etiquetas = df["entidad_res"].astype(str) + "/" + df["municipio_res"].astype(str)
    fig, ax = plt.subplots(figsize=(8, 6))
    ax.barh(etiquetas[::-1], df["n"][::-1], color=COLOR_PRINCIPAL)
    ax.set_xlabel("Número de registros")
    ax.set_ylabel("ENTIDAD_RES / MUNICIPIO_RES (códigos)")
    ax.set_title("Top 15 de MUNICIPIO_RES")
    fig.tight_layout()
    fig.savefig(os.path.join(CARPETA_SALIDA, "03_top_municipios.png"), dpi=150)
    plt.close(fig)
    print("Generada 03_top_municipios.png")


def grafica_edad():
    df = consultar("SELECT edad FROM covid_historica WHERE edad IS NOT NULL;")
    fig, ax = plt.subplots(figsize=(8, 5))
    ax.hist(df["edad"], bins=30, color=COLOR_PRINCIPAL, edgecolor="white")
    maximo = df["edad"].max()
    ax.axvline(maximo, color=COLOR_ATIPICO, linestyle="--",
               label=f"Máximo observado: {maximo} años")
    ax.set_xlabel("Edad")
    ax.set_ylabel("Número de registros")
    ax.set_title("Distribución de EDAD")
    ax.legend()
    fig.tight_layout()
    fig.savefig(os.path.join(CARPETA_SALIDA, "04_distribucion_edad.png"), dpi=150)
    plt.close(fig)
    print("Generada 04_distribucion_edad.png")


if __name__ == "__main__":
    os.makedirs(CARPETA_SALIDA, exist_ok=True)
    grafica_nulos()
    grafica_top_paises()
    grafica_top_municipios()
    grafica_edad()
    print("Listo. Revisa la carpeta graficas/.")
