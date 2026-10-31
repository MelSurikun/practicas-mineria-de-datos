"""
Práctica 02, Equipo 3. Aportación de Santiago (Machine Learning).
Gráficas 5 y 6 del reporte, las de la detección de atípicos (sql/10_atipicos.sql), con la
misma paleta que scripts/graficar.py para que el reporte se vea como un solo documento.

graficar.py también dibuja una versión de estas dos gráficas; las que van en el reporte son
estas. Por eso este script se corre después y sobrescribe graficas/05_edad_atipicos.png y
graficas/06_demora_por_sector.png.

Igual que graficar.py, lee los datos con `psql --csv` y no necesita psycopg. La ruta de
psql se toma de la variable PSQL_PATH (la misma de graficar.py) o del PATH. La conexión
usa PGHOST, PGUSER y PGDATABASE si están definidas; si no, localhost, postgres y
covid20a23sedi, como graficar.py. Si hace falta, psql pide la contraseña. Ninguna
credencial va escrita aquí. Requiere cat_sector (sql/06_catalogos.sql).

Uso, parado en Practica02_Equipo3_MD/:
    python scripts/graficar_atipicos.py
"""
import io
import os
import shutil
import subprocess

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd
from matplotlib.ticker import FixedLocator, FuncFormatter

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SALIDA = os.path.join(RAIZ, "graficas")

# Paleta de scripts/graficar.py (azul principal y rojo para lo atípico) más un gris de
# contexto. Validada contra daltonismo: Delta E >= 17 entre cualquier par (OKLab x100).
AZUL = "#2F5496"
ROJO = "#C0392B"
GRIS = "#A6ACB5"
TINTA = "#333333"
TINTA_SUAVE = "#666666"
REJILLA = "#E6E6E6"


def psql_csv(sql):
    """Ejecuta una consulta con psql --csv y regresa un DataFrame."""
    psql = os.environ.get("PSQL_PATH") or shutil.which("psql")
    if not psql:
        raise SystemExit("No encontré psql: agrégalo al PATH o define la variable PSQL_PATH.")
    entorno = {**os.environ}
    entorno.setdefault("PGHOST", "localhost")
    entorno.setdefault("PGUSER", "postgres")
    entorno.setdefault("PGDATABASE", "covid20a23sedi")
    salida = subprocess.run([psql, "-X", "--csv", "-c", sql], check=True,
                            capture_output=True, text=True, env=entorno).stdout
    return pd.read_csv(io.StringIO(salida))


def estilo(ax):
    for lado in ("top", "right"):
        ax.spines[lado].set_visible(False)
    for lado in ("left", "bottom"):
        ax.spines[lado].set_color("#BBBBBB")
        ax.spines[lado].set_linewidth(0.8)
    ax.tick_params(colors=TINTA_SUAVE, labelsize=9)
    ax.set_axisbelow(True)


def grafica_edad():
    edades = psql_csv("SELECT edad, count(*) AS n FROM covid_historica GROUP BY edad ORDER BY edad;")
    p = psql_csv("""
        WITH q AS (SELECT percentile_cont(0.25) WITHIN GROUP (ORDER BY edad) q1,
                          percentile_cont(0.50) WITHIN GROUP (ORDER BY edad) med,
                          percentile_cont(0.75) WITHIN GROUP (ORDER BY edad) q3 FROM covid_historica)
        SELECT q1, med, q3,
               (SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY abs(edad - q.med))
                FROM covid_historica) AS mad FROM q;""").iloc[0]
    iqr = p.q3 - p.q1
    cortes = [
        (p.q3 + 1.5 * iqr, f"Tukey 1.5 IQR\n(> {p.q3 + 1.5 * iqr:.0f})"),
        (p.med + 3.5 * p.mad / 0.6745, f"z-MAD > 3.5\n(≥ {int(p.med + 3.5 * p.mad / 0.6745) + 1})"),
        (p.q3 + 3 * iqr, f"Tukey 3 IQR\n(> {p.q3 + 3 * iqr:.0f})"),
    ]

    fig, ax = plt.subplots(figsize=(9, 5))
    estilo(ax)
    colores = [ROJO if e == 122 else AZUL for e in edades.edad]
    ax.bar(edades.edad, edades.n, width=0.8, color=colores, linewidth=0)
    ax.set_yscale("log")
    ax.set_ylim(0.8, 3e5)
    ax.yaxis.set_major_locator(FixedLocator([1, 10, 100, 1000, 10000, 100000]))
    ax.yaxis.set_major_formatter(FuncFormatter(lambda v, _: f"{v:,.0f}"))
    ax.yaxis.set_minor_formatter(FuncFormatter(lambda v, _: ""))
    ax.set_xlim(-1.5, 124)
    ax.grid(axis="y", color=REJILLA, linewidth=0.8)
    for x, texto in cortes:
        ax.axvline(x, color=TINTA_SUAVE, linewidth=1, linestyle=(0, (4, 3)))
        ax.text(x - 0.8, 1.6e5, texto, ha="right", va="top", fontsize=8, color=TINTA_SUAVE)
    n122 = int(edades.loc[edades.edad == 122, "n"].iloc[0])
    n121 = int(edades.loc[edades.edad == 121, "n"].iloc[0])
    ax.annotate(f"{n122} registros\ncon 122 años\n(121 años: {n121})\nnacimiento\nimplícito: 1900",
                xy=(122, n122 * 1.05), xytext=(105, 250), fontsize=8.5, color=TINTA,
                ha="left", va="bottom",
                arrowprops=dict(arrowstyle="-", color=TINTA_SUAVE, linewidth=0.8,
                                shrinkA=2, shrinkB=1))
    ax.set_xlabel("Edad (años)", color=TINTA, fontsize=10)
    ax.set_ylabel("Número de registros (escala logarítmica)", color=TINTA, fontsize=10)
    ax.set_title("EDAD en covid_historica y dónde corta cada criterio de atípicos",
                 color=TINTA, fontsize=12)
    fig.tight_layout()
    ruta = os.path.join(SALIDA, "05_edad_atipicos.png")
    fig.savefig(ruta, dpi=200)
    plt.close(fig)
    print("Generada", os.path.relpath(ruta, RAIZ))


def grafica_demora_por_sector():
    d = psql_csv("""
        SELECT s.sector, count(*) AS registros,
               max(h.fecha_ingreso - h.fecha_sintomas) AS max_dias,
               count(*) FILTER (WHERE h.fecha_ingreso - h.fecha_sintomas > 31) AS extremos
        FROM covid_historica h JOIN cat_sector s ON s.clave_sector = h.sector
        GROUP BY s.sector ORDER BY max_dias, registros;""")
    fig, ax = plt.subplots(figsize=(9, 5.2))
    estilo(ax)
    colores = [ROJO if m > 31 else GRIS for m in d.max_dias]
    ax.barh(d.sector.str.title().str.replace("Imss", "IMSS").str.replace("Issste", "ISSSTE")
            .str.replace("Dif", "DIF").str.replace("Ssa", "SSA").str.replace("Pemex", "PEMEX")
            .str.replace("Sedena", "SEDENA").str.replace("Semar", "SEMAR")
            .str.replace("No Especificado", "No especificado"),
            d.max_dias, height=0.62, color=colores, linewidth=0)
    ax.set_xscale("log")
    ax.set_xlim(5, 600)
    ax.grid(axis="x", color=REJILLA, linewidth=0.8)
    ax.set_ylim(-0.6, len(d) + 0.9)
    ax.axvline(10, color=TINTA_SUAVE, linewidth=1, linestyle=(0, (4, 3)))
    ax.text(9.6, len(d) + 0.1, "10 días:\ndefinición\nde caso", fontsize=8,
            color=TINTA_SUAVE, va="center", ha="right")
    ax.axvline(31, color=TINTA_SUAVE, linewidth=1, linestyle=(0, (4, 3)))
    ax.text(32.5, len(d) + 0.1, "31 días: cerca de Tukey\nsobre ln(1 + días)", fontsize=8,
            color=TINTA_SUAVE, va="center")
    for i, fila in enumerate(d.itertuples()):
        if fila.max_dias > 31:
            registros = "registro" if fila.extremos == 1 else "registros"
            ax.text(fila.max_dias * 1.08, i, f"{fila.max_dias} días · {fila.extremos} {registros} > 31 días",
                    va="center", fontsize=8.5, color=TINTA)
    ax.set_xticks([5, 10, 15, 31, 50, 100, 273])
    ax.set_xticklabels(["5", "10", "15", "31", "50", "100", "273"])
    ax.set_xlabel("Demora máxima entre FECHA_SINTOMAS y FECHA_INGRESO (días, escala logarítmica)",
                  color=TINTA, fontsize=10)
    ax.set_title("Demora máxima entre síntomas e ingreso, por sector que atendió",
                 color=TINTA, fontsize=12)
    fig.tight_layout()
    ruta = os.path.join(SALIDA, "06_demora_por_sector.png")
    fig.savefig(ruta, dpi=200)
    plt.close(fig)
    print("Generada", os.path.relpath(ruta, RAIZ))


if __name__ == "__main__":
    os.makedirs(SALIDA, exist_ok=True)
    grafica_edad()
    grafica_demora_por_sector()
