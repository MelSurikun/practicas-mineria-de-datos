"""
Práctica 02, Equipo 3.
Genera las 6 visualizaciones del reporte a partir de covid_historica.

No usa psycopg2 (no está instalado en esta máquina): en su lugar, cada gráfica
extrae sus datos con `psql --csv` a un archivo temporal y lo lee con pandas.

Requiere psql en el PATH, o define la variable de entorno PSQL_PATH con la
ruta completa (por ejemplo "C:/Program Files/PostgreSQL/17/bin/psql.exe").
Las Gráficas 3 y 6 requieren los catálogos de sql/06_catalogos.sql ya
cargados (cat_municipios, cat_entidades, cat_sector); las Gráficas 5 y 6
requieren covid_historica (sql/05_consolidacion.sql).

Uso:
    python scripts/graficar.py
"""
import os
import subprocess
import tempfile

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

PSQL = os.environ.get("PSQL_PATH", "psql")
DB = "covid20a23sedi"
USER = "postgres"
HOST = "localhost"
CARPETA_SALIDA = os.path.join(os.path.dirname(__file__), "..", "graficas")

# Paleta neutral, consistente entre las 6 gráficas
COLOR_PRINCIPAL = "#2F5496"
COLOR_ATIPICO = "#C0392B"
COLOR_NEUTRO = "#9AA5B1"


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
    # Requiere sql/06_catalogos.sql ya cargado (cat_municipios, cat_entidades).
    # Antes esta gráfica etiquetaba cada barra con el código crudo
    # "ENTIDAD_RES/MUNICIPIO_RES" (por ejemplo "9/10"); ahora usa el nombre
    # del municipio y la abreviatura de su entidad, tomados del catálogo.
    df = consultar(
        "SELECT h.entidad_res, h.municipio_res, m.municipio, e.abreviatura, count(*) AS n "
        "FROM covid_historica h "
        "LEFT JOIN cat_municipios m ON m.clave_entidad = h.entidad_res "
        "                          AND m.clave_municipio = h.municipio_res "
        "LEFT JOIN cat_entidades e ON e.clave_entidad = h.entidad_res "
        "GROUP BY h.entidad_res, h.municipio_res, m.municipio, e.abreviatura "
        "ORDER BY n DESC LIMIT 15;"
    )
    etiquetas = df["municipio"].fillna("(sin catálogo)") + ", " + df["abreviatura"].fillna("?")
    fig, ax = plt.subplots(figsize=(9, 6))
    ax.barh(etiquetas[::-1], df["n"][::-1], color=COLOR_PRINCIPAL)
    ax.set_xlabel("Número de registros")
    ax.set_ylabel("Municipio, entidad")
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


def grafica_edad_atipicos():
    # Gráfica 5, sección "Detección de valores atípicos". Los tres umbrales
    # (Tukey 1.5 IQR, z-MAD y Tukey 3 IQR) se calculan aquí mismo a partir de
    # los datos, no se hardcodean, para que la gráfica se reproduzca igual
    # si cambia la muestra.
    df = consultar("SELECT edad FROM covid_historica WHERE edad IS NOT NULL;")
    edad = df["edad"]

    q1, q3 = edad.quantile([0.25, 0.75])
    iqr = q3 - q1
    umbral_tukey_15 = q3 + 1.5 * iqr
    umbral_tukey_3 = q3 + 3 * iqr

    mediana = edad.median()
    mad = (edad - mediana).abs().median()
    z_mad = 0.6745 * (edad - mediana) / mad
    umbral_z = edad[z_mad >= 3.5].min()

    conteos = edad.value_counts().sort_index()
    maximo = int(edad.max())
    n_maximo = int(conteos.get(maximo, 0))
    n_anterior = int(conteos.get(maximo - 1, 0))

    fig, ax = plt.subplots(figsize=(9, 6))
    colores = [COLOR_ATIPICO if e > umbral_tukey_3 else COLOR_PRINCIPAL for e in conteos.index]
    ax.bar(conteos.index, conteos.values, color=colores, width=1.0)
    ax.set_yscale("log")
    ax.axvline(umbral_tukey_15, color=COLOR_NEUTRO, linestyle="--")
    ax.axvline(umbral_z, color=COLOR_NEUTRO, linestyle="--")
    ax.axvline(umbral_tukey_3, color=COLOR_NEUTRO, linestyle="--")
    ax.text(umbral_tukey_15, conteos.max(), f"Tukey 1.5 IQR\n(> {umbral_tukey_15:.0f})",
            ha="center", va="bottom", fontsize=8, color=COLOR_NEUTRO)
    ax.text(umbral_z, conteos.max(), f"z-MAD > 3.5\n(≥ {umbral_z:.0f})",
            ha="center", va="bottom", fontsize=8, color=COLOR_NEUTRO)
    ax.text(umbral_tukey_3, conteos.max(), f"Tukey 3 IQR\n(> {umbral_tukey_3:.0f})",
            ha="center", va="bottom", fontsize=8, color=COLOR_NEUTRO)
    ax.annotate(
        f"{n_maximo} registros con {maximo} años\n({maximo - 1} años: {n_anterior})\n"
        "nacimiento implícito: 1900",
        xy=(maximo, n_maximo), xytext=(maximo - 15, n_maximo * 20),
        fontsize=9, ha="center",
        arrowprops=dict(arrowstyle="-", color="gray"),
    )
    ax.set_xlabel("Edad (años)")
    ax.set_ylabel("Número de registros (escala logarítmica)")
    ax.set_title("EDAD en covid_historica y dónde corta cada criterio de atípicos")
    fig.tight_layout()
    fig.savefig(os.path.join(CARPETA_SALIDA, "05_edad_atipicos.png"), dpi=150)
    plt.close(fig)
    print("Generada 05_edad_atipicos.png")


def grafica_demora_por_sector():
    # Gráfica 6, sección "Intervalos entre fechas". Requiere sql/06_catalogos.sql
    # (cat_sector) para nombrar el eje en vez de dejar el código crudo.
    umbral_dias = 31  # cerca de la cerca de Tukey sobre ln(1 + demora), ver Tabla 10
    df = consultar(
        "SELECT s.sector, "
        "  max(h.fecha_ingreso - h.fecha_sintomas) AS demora_maxima, "
        f"  count(*) FILTER (WHERE (h.fecha_ingreso - h.fecha_sintomas) > {umbral_dias}) AS extremos "
        "FROM covid_historica h "
        "JOIN cat_sector s ON s.clave_sector = h.sector "
        "WHERE h.fecha_ingreso IS NOT NULL AND h.fecha_sintomas IS NOT NULL "
        "  AND h.fecha_ingreso >= h.fecha_sintomas "
        "GROUP BY s.sector ORDER BY demora_maxima DESC;"
    )
    colores = [COLOR_ATIPICO if d > umbral_dias else COLOR_NEUTRO for d in df["demora_maxima"]]
    fig, ax = plt.subplots(figsize=(10, 7))
    ax.barh(df["sector"][::-1], df["demora_maxima"][::-1], color=colores[::-1])
    ax.set_xscale("log")
    ax.axvline(10, color="gray", linestyle="--", linewidth=1)
    ax.axvline(umbral_dias, color="gray", linestyle="--", linewidth=1)
    for i, row in df.iterrows():
        if row["demora_maxima"] > umbral_dias:
            etiqueta_registros = "registro" if row["extremos"] == 1 else "registros"
            ax.text(row["demora_maxima"] * 1.05, len(df) - 1 - i,
                     f"{row['demora_maxima']} días · {row['extremos']} {etiqueta_registros} > {umbral_dias} días",
                     va="center", fontsize=8)
    ax.set_xlabel(f"Demora máxima entre FECHA_SINTOMAS y FECHA_INGRESO (días, escala logarítmica)")
    ax.set_title("Demora máxima entre síntomas e ingreso, por sector que atendió")
    fig.tight_layout()
    fig.savefig(os.path.join(CARPETA_SALIDA, "06_demora_por_sector.png"), dpi=150)
    plt.close(fig)
    print("Generada 06_demora_por_sector.png")


if __name__ == "__main__":
    os.makedirs(CARPETA_SALIDA, exist_ok=True)
    grafica_nulos()
    grafica_top_paises()
    grafica_top_municipios()
    grafica_edad()
    grafica_edad_atipicos()
    grafica_demora_por_sector()
    print("Listo. Revisa la carpeta graficas/.")
