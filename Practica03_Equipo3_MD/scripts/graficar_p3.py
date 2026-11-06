"""
Práctica 03, Equipo 3 (Melanie, Análisis y Visualización). Punto 6.

Dibuja las gráficas de 1, 2 y 3 dimensiones y las de distribución a partir de los CSV de
evidencias/exploracion/, así cada cifra de una gráfica tiene detrás un archivo que se puede abrir.
Los CSV salen de sql/10_exploracion.sql:

Uso, parado en Practica03_Equipo3_MD/:
    python scripts/exportar_consultas.py sql/10_exploracion.sql exploracion
    python scripts/graficar_p3.py
"""
import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from matplotlib.colors import LinearSegmentedColormap
from matplotlib.dates import DateFormatter
from matplotlib.ticker import FuncFormatter

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATOS = os.path.join(RAIZ, "evidencias", "exploracion")
SALIDA = os.path.join(RAIZ, "graficas")

SUPERFICIE = "#fcfcfb"
TEXTO = "#0b0b0b"
TEXTO_2 = "#52514e"
REJILLA = "#e4e3df"
AZUL = "#2a78d6"
NARANJA = "#eb6834"
AQUA = "#1baf7a"
AMARILLO = "#eda100"
NEUTRO = "#9c9b95"
# Una sola tinta, de claro a oscuro, para las magnitudes de los mapas de calor.
SECUENCIAL = LinearSegmentedColormap.from_list("azules", ["#eef4fc", "#8db8ec", AZUL, "#0f3f7a"])
# El color sigue a cada categoría en todas las gráficas donde aparece.
COLOR_CLASIFICACION = {"CONFIRMADO": AZUL, "NEGATIVO": NARANJA, "SOSPECHOSO": AQUA, "NO CONCLUYENTE": AMARILLO}
ORDEN_CLASIFICACION = list(COLOR_CLASIFICACION)
COLOR_SEXO = {"MUJER": AZUL, "HOMBRE": NARANJA}
ORDEN_ETARIO = ["0-17 (MENORES DE EDAD)", "18-39", "40-59", "60 Y MÁS (PERSONAS ADULTAS MAYORES)"]
ETIQUETA_ETARIO = {"0-17 (MENORES DE EDAD)": "0-17", "18-39": "18-39", "40-59": "40-59",
                   "60 Y MÁS (PERSONAS ADULTAS MAYORES)": "60 y más"}
ORDEN_COMORBILIDADES = ["NINGUNA", "UNA", "DOS", "TRES O MÁS"]
MESES = ["2022-01", "2022-02", "2022-03", "2022-04", "2022-05", "2022-06", "2023-01"]
ETIQUETA_MES = dict(zip(MESES, ["Ene 22", "Feb 22", "Mar 22", "Abr 22", "May 22", "Jun 22", "Ene 23"]))

plt.rcParams.update({
    "figure.facecolor": SUPERFICIE, "axes.facecolor": SUPERFICIE, "savefig.facecolor": SUPERFICIE,
    "font.size": 10, "text.color": TEXTO, "axes.labelcolor": TEXTO_2,
    "xtick.color": TEXTO_2, "ytick.color": TEXTO_2, "axes.edgecolor": REJILLA,
    "axes.titlesize": 12, "axes.titleweight": "bold", "axes.titlelocation": "left",
    "axes.spines.top": False, "axes.spines.right": False,
    "axes.grid": True, "grid.color": REJILLA, "grid.linewidth": 0.8, "axes.axisbelow": True,
    "legend.frameon": False,
})
MILES = FuncFormatter(lambda x, _: f"{x:,.0f}")


def leer(nombre):
    return pd.read_csv(os.path.join(DATOS, f"{nombre}.csv"))


def guardar(fig, nombre):
    fig.savefig(os.path.join(SALIDA, f"{nombre}.png"), dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"Generada {nombre}.png")


def nota(fig, texto):
    fig.text(0.01, -0.02, texto, fontsize=8.5, color=TEXTO_2, va="top", wrap=True)


def rotular_barras_h(ax, valores, formato="{:,.0f}"):
    tope = max(valores)
    for i, v in enumerate(valores):
        ax.text(v + tope * 0.01, i, formato.format(v), va="center", fontsize=9, color=TEXTO_2)
    ax.set_xlim(0, tope * 1.14)


def casos_por_mes():
    df = leer("x02_por_mes")
    fig, ax = plt.subplots(figsize=(9, 4.5))
    colores = [AZUL if m in MESES else NEUTRO for m in df["anio_mes"]]
    ax.bar(df["anio_mes"], df["casos"], color=colores, width=0.8)
    ax.yaxis.set_major_formatter(MILES)
    ax.grid(axis="x", visible=False)
    ax.tick_params(axis="x", rotation=60)
    ax.set_xlabel("Mes de inicio de síntomas")
    ax.set_ylabel("Casos")
    ax.set_title("Los casos se concentran en enero a junio de 2022 y en enero de 2023")
    guardar(fig, "01_casos_por_mes")


def casos_por_semana():
    df = leer("x01_curva_semanal")
    df["inicio_semana"] = pd.to_datetime(df["inicio_semana"])
    # Con menos de 1,000 casos la positividad salta de 0% a 70% por azar: no se dibuja.
    df["positividad"] = df["positividad"].where(df["casos"] >= 1000)
    periodos = [("Ene-jun de 2022", df[(df["inicio_semana"] >= "2021-12-26") & (df["inicio_semana"] <= "2022-06-30")]),
                ("Ene de 2023", df[(df["inicio_semana"] >= "2022-12-25") & (df["inicio_semana"] <= "2023-01-31")])]
    # Dos medidas de escala distinta: dos paneles con su propio eje, nunca un eje doble.
    fig, ejes = plt.subplots(2, 2, figsize=(10, 6.5), sharex="col", sharey="row", width_ratios=[4, 1],
                             height_ratios=[3, 2])
    for col, (titulo, d) in enumerate(periodos):
        arriba, abajo = ejes[0, col], ejes[1, col]
        arriba.plot(d["inicio_semana"], d["casos"], color=AZUL, linewidth=2, marker="o", markersize=4, label="Casos")
        arriba.plot(d["inicio_semana"], d["confirmados"], color=NARANJA, linewidth=2, marker="o", markersize=4, label="Confirmados")
        arriba.set_title(titulo, fontsize=10)
        arriba.yaxis.set_major_formatter(MILES)
        abajo.plot(d["inicio_semana"], d["positividad"], color=TEXTO_2, linewidth=2, marker="o", markersize=4)
        abajo.set_ylim(0, 100)
        abajo.set_xticks(d["inicio_semana"][::3 if len(d) > 10 else 2])
        abajo.xaxis.set_major_formatter(DateFormatter("%d/%m"))
        abajo.tick_params(axis="x", rotation=45)
    pico = df.loc[df["positividad"].idxmax()]
    ejes[1, 0].annotate(f"Máximo: {pico['positividad']:.1f}%", xy=(pico["inicio_semana"], pico["positividad"]),
                        xytext=(pico["inicio_semana"] + pd.Timedelta(days=21), pico["positividad"] + 8),
                        fontsize=9, color=TEXTO_2, arrowprops=dict(arrowstyle="-", color=NEUTRO))
    ejes[0, 0].set_ylabel("Por semana")
    ejes[1, 0].set_ylabel("Positividad (%)")
    ejes[1, 0].set_xlabel("Inicio de la semana epidemiológica (día/mes)")
    nota(fig, "La positividad (confirmados entre confirmados y negativos) se omite en las semanas con menos de 1,000 casos.")
    ejes[1, 1].set_xlabel("(día/mes)")
    ejes[0, 0].legend(loc="upper right")
    fig.suptitle("Casos, confirmados y positividad por semana epidemiológica de inicio de síntomas",
                 x=0.01, ha="left", fontsize=12, fontweight="bold")
    fig.tight_layout()
    guardar(fig, "02_curva_semanal")


def casos_por_entidad():
    df = leer("x03_por_entidad").sort_values("casos")
    fig, ax = plt.subplots(figsize=(8.5, 8))
    ax.barh(df["nombre_entidad"], df["casos"], color=AZUL, height=0.75)
    rotular_barras_h(ax, df["casos"].tolist())
    ax.margins(y=0.01)
    ax.xaxis.set_major_formatter(MILES)
    ax.grid(axis="y", visible=False)
    ax.set_xlabel("Casos")
    ax.set_title("Casos por entidad de residencia")
    guardar(fig, "03_casos_por_entidad")


def casos_por_sexo_y_edad():
    sexo = leer("x04_por_sexo")
    # "100+" se ordena antes que "20-29" como texto: se lleva al final.
    edad = leer("x06_por_grupo_decenal").sort_values("grupo_decenal", key=lambda s: s.str[:-1].str.split("-").str[0].astype(int))
    fig, ejes = plt.subplots(1, 2, figsize=(10, 4.2), width_ratios=[1, 3])
    ejes[0].bar(sexo["sexo_desc"].str.capitalize(), sexo["casos"], color=AZUL, width=0.6)
    for i, v in enumerate(sexo["casos"]):
        ejes[0].text(i, v, f"{v:,}\n({v / sexo['casos'].sum():.1%})", ha="center", va="bottom", fontsize=9, color=TEXTO_2)
    ejes[0].set_ylim(0, sexo["casos"].max() * 1.2)
    ejes[0].set_title("Por sexo", fontsize=10)
    ejes[1].bar(edad["grupo_decenal"], edad["casos"], color=AZUL, width=0.8)
    ejes[1].set_title("Por grupo de edad (años)", fontsize=10)
    ejes[1].set_xlabel("Grupo de edad")
    for ax in ejes:
        ax.yaxis.set_major_formatter(MILES)
        ax.grid(axis="x", visible=False)
    ejes[0].set_ylabel("Casos")
    fig.suptitle("Casos por sexo y por grupo de edad", x=0.01, ha="left", fontsize=12, fontweight="bold")
    fig.tight_layout()
    guardar(fig, "04_casos_por_sexo_y_edad")


def casos_por_clasificacion():
    df = leer("x07_por_clasificacion").sort_values("casos")
    etiquetas = df["clasificacion_final"].astype(str) + ". " + df["clasificacion_final_desc"].str.capitalize().str.replace("sars-cov-2", "SARS-CoV-2", regex=False).str.replace("covid-19", "COVID-19", regex=False)
    fig, ax = plt.subplots(figsize=(10, 3.8))
    ax.barh(etiquetas, df["casos"], color=AZUL, height=0.7)
    rotular_barras_h(ax, df["casos"].tolist())
    ax.xaxis.set_major_formatter(MILES)
    ax.grid(axis="y", visible=False)
    ax.set_xlabel("Casos")
    ax.set_title("Casos por clasificación final")
    guardar(fig, "05_casos_por_clasificacion")


def prevalencia_comorbilidad():
    df = leer("x08_prevalencia_comorbilidad").sort_values("prevalencia")
    fig, ax = plt.subplots(figsize=(8.5, 4.2))
    ax.barh(df["comorbilidad"], df["prevalencia"], color=AZUL, height=0.7)
    rotular_barras_h(ax, df["prevalencia"].tolist(), "{:.2f}%")
    ax.grid(axis="y", visible=False)
    ax.set_xlabel("% de los casos con dato (1 = sí o 2 = no)")
    ax.set_title("Prevalencia de cada comorbilidad y del tabaquismo")
    guardar(fig, "06_prevalencia_comorbilidad")


def mapa_mes_entidad():
    df = leer("x11_mes_por_entidad")
    tabla = df.pivot(index="nombre_entidad", columns="anio_mes", values="casos").fillna(0)[MESES]
    tabla = tabla.loc[tabla.sum(axis=1).sort_values(ascending=False).index]
    porcentaje = tabla.div(tabla.sum(axis=1), axis=0) * 100
    fig, ax = plt.subplots(figsize=(8.5, 9.5))
    img = ax.imshow(porcentaje.values, cmap=SECUENCIAL, aspect="auto", vmin=0)
    ax.set_xticks(range(len(MESES)), [ETIQUETA_MES[m] for m in MESES])
    ax.set_yticks(range(len(tabla)), tabla.index, fontsize=8.5)
    ax.grid(False)
    ax.tick_params(length=0)
    for s in ax.spines.values():
        s.set_visible(False)
    ax.set_xticks(np.arange(-0.5, len(MESES)), minor=True)
    ax.set_yticks(np.arange(-0.5, len(tabla)), minor=True)
    ax.grid(which="minor", color=SUPERFICIE, linewidth=1.5)
    ax.tick_params(which="minor", length=0)
    limite = np.nanmax(porcentaje.values) * 0.55
    for i in range(porcentaje.shape[0]):
        for j in range(porcentaje.shape[1]):
            v = porcentaje.iat[i, j]
            ax.text(j, i, f"{v:.0f}", ha="center", va="center", fontsize=7.5, color="white" if v > limite else TEXTO)
    fig.colorbar(img, ax=ax, label="% de los casos de la entidad", shrink=0.5, pad=0.02)
    ax.set_xlabel("Mes de inicio de síntomas")
    ax.set_title("Cuándo se concentraron los casos de cada entidad")
    guardar(fig, "07_mapa_mes_entidad")


def edad_por_clasificacion():
    df = leer("x13_edad_por_clasificacion")
    tabla = df.pivot(index="grupo_etario", columns="grupo_clasificacion", values="casos").fillna(0).loc[ORDEN_ETARIO, ORDEN_CLASIFICACION]
    porcentaje = tabla.div(tabla.sum(axis=1), axis=0) * 100
    fig, ax = plt.subplots(figsize=(9.5, 4.8))
    ancho = 0.2
    for k, grupo in enumerate(ORDEN_CLASIFICACION):
        x = np.arange(len(ORDEN_ETARIO)) + (k - 1.5) * ancho
        ax.bar(x, porcentaje[grupo], width=ancho * 0.92, color=COLOR_CLASIFICACION[grupo], label=grupo.capitalize())
        for xi, v in zip(x, porcentaje[grupo]):
            ax.text(xi, v + 0.6, f"{v:.1f}", ha="center", fontsize=8, color=TEXTO_2)
    ax.set_xticks(range(len(ORDEN_ETARIO)), [ETIQUETA_ETARIO[g] for g in ORDEN_ETARIO])
    ax.grid(axis="x", visible=False)
    ax.set_xlabel("Grupo de edad (años)")
    ax.set_ylabel("% de los casos del grupo de edad")
    ax.legend(ncols=4, loc="upper center", bbox_to_anchor=(0.5, -0.14))
    ax.set_title("Clasificación final según el grupo de edad")
    guardar(fig, "08_edad_por_clasificacion")


def sexo_por_comorbilidad():
    df = leer("x14_sexo_por_comorbilidad")
    tabla = df.pivot(index="comorbilidad", columns="sexo_desc", values="prevalencia")
    tabla = tabla.loc[tabla.max(axis=1).sort_values().index]
    fig, ax = plt.subplots(figsize=(8.5, 5.5))
    y = np.arange(len(tabla))
    for desplazamiento, sexo in [(0.2, "MUJER"), (-0.2, "HOMBRE")]:
        ax.barh(y + desplazamiento, tabla[sexo], height=0.36, color=COLOR_SEXO[sexo], label=sexo.capitalize())
        for yi, v in zip(y + desplazamiento, tabla[sexo]):
            ax.text(v + 0.1, yi, f"{v:.1f}", va="center", fontsize=8, color=TEXTO_2)
    ax.set_yticks(y, tabla.index)
    ax.grid(axis="y", visible=False)
    ax.set_xlabel("% de los casos con dato (1 = sí o 2 = no)")
    ax.legend(loc="lower right")
    ax.set_title("Prevalencia de cada comorbilidad según el sexo")
    guardar(fig, "09_sexo_por_comorbilidad")


def facetas_mes_entidad_clasificacion():
    df = leer("x19_mes_entidad_clasificacion")
    orden = df.groupby("nombre_entidad")["casos"].sum().sort_values(ascending=False).index
    fig, ejes = plt.subplots(2, 3, figsize=(11, 6.5), sharex=True, sharey=True)
    for ax, entidad in zip(ejes.flat, orden):
        tabla = (df[df["nombre_entidad"] == entidad]
                 .pivot(index="anio_mes", columns="grupo_clasificacion", values="casos")
                 .reindex(index=MESES, columns=ORDEN_CLASIFICACION).fillna(0))
        porcentaje = tabla.div(tabla.sum(axis=1), axis=0) * 100
        base = np.zeros(len(MESES))
        for grupo in ORDEN_CLASIFICACION:
            ax.bar(range(len(MESES)), porcentaje[grupo], bottom=base, width=0.82, color=COLOR_CLASIFICACION[grupo],
                   edgecolor=SUPERFICIE, linewidth=1, label=grupo.capitalize())
            base += porcentaje[grupo].values
        ax.set_title(f"{entidad.title().replace(' De ', ' de ')} ({tabla.values.sum():,.0f} casos)", fontsize=10)
        ax.set_xticks(range(len(MESES)), [ETIQUETA_MES[m] for m in MESES], rotation=60)
        ax.grid(axis="x", visible=False)
        ax.set_ylim(0, 100)
    for ax in ejes[:, 0]:
        ax.set_ylabel("% de los casos del mes")
    manejadores, etiquetas = ejes[0, 0].get_legend_handles_labels()
    fig.legend(manejadores, etiquetas, ncols=4, loc="lower center", bbox_to_anchor=(0.5, -0.04))
    fig.suptitle("Composición de la clasificación final por mes en las 6 entidades con más casos",
                 x=0.01, ha="left", fontsize=12, fontweight="bold")
    fig.tight_layout()
    guardar(fig, "12_facetas_mes_entidad_clasificacion")


def matriz_letalidad():
    df = leer("x20_matriz_letalidad")
    fig, ejes = plt.subplots(1, 2, figsize=(11, 4.2), sharey=True)
    tablas = {s: d for s, d in df.groupby("sexo_desc")}
    tope = df["letalidad"].max()
    for ax, sexo in zip(ejes, ["MUJER", "HOMBRE"]):
        d = tablas[sexo]
        letal = d.pivot(index="grupo_etario", columns="grupo_comorbilidades", values="letalidad").loc[ORDEN_ETARIO, ORDEN_COMORBILIDADES]
        conf = d.pivot(index="grupo_etario", columns="grupo_comorbilidades", values="confirmados").loc[ORDEN_ETARIO, ORDEN_COMORBILIDADES]
        img = ax.imshow(letal.values, cmap=SECUENCIAL, aspect="auto", vmin=0, vmax=tope)
        for i in range(letal.shape[0]):
            for j in range(letal.shape[1]):
                v = letal.iat[i, j]
                ax.text(j, i, f"{v:.1f}%\nn={conf.iat[i, j]:,.0f}", ha="center", va="center", fontsize=8.5,
                        color="white" if v > tope * 0.55 else TEXTO)
        ax.set_xticks(range(4), [c.capitalize() for c in ORDEN_COMORBILIDADES])
        ax.set_yticks(range(4), [ETIQUETA_ETARIO[g] for g in ORDEN_ETARIO])
        ax.grid(False)
        ax.tick_params(length=0)
        for s in ax.spines.values():
            s.set_visible(False)
        ax.set_title(sexo.capitalize(), fontsize=10)
        ax.set_xlabel("Número de comorbilidades")
    ejes[0].set_ylabel("Grupo de edad (años)")
    fig.colorbar(img, ax=ejes, label="Letalidad entre confirmados (%)", shrink=0.85, pad=0.02)
    fig.suptitle("Letalidad entre confirmados por sexo, edad y número de comorbilidades",
                 x=0.01, ha="left", fontsize=12, fontweight="bold")
    guardar(fig, "13_matriz_letalidad")


def riesgo_por_comorbilidad():
    crudo = leer("x15_riesgo_por_comorbilidad").set_index("comorbilidad")
    ajustado = leer("x21_riesgo_ajustado_por_edad").set_index("comorbilidad")
    orden = ajustado["rr_ajustado_edad"].sort_values().index
    fig, ax = plt.subplots(figsize=(9, 5))
    y = np.arange(len(orden))
    for yi, c in zip(y, orden):
        ax.plot([crudo.at[c, "rr_letalidad_ic_inf"], crudo.at[c, "rr_letalidad_ic_sup"]], [yi + 0.15] * 2,
                color=NEUTRO, linewidth=2)
        ax.plot([ajustado.at[c, "rr_ajustado_edad"], crudo.at[c, "rr_letalidad"]], [yi, yi + 0.15],
                color=REJILLA, linewidth=1, zorder=1)
    ax.scatter(crudo.loc[orden, "rr_letalidad"], y + 0.15, s=50, color=NEUTRO, zorder=3,
               edgecolor=SUPERFICIE, linewidth=1.5, label="Crudo, con IC del 95%")
    ax.scatter(ajustado.loc[orden, "rr_ajustado_edad"], y, s=60, color=AZUL, marker="D", zorder=3,
               edgecolor=SUPERFICIE, linewidth=1.5, label="Ajustado por edad (Mantel-Haenszel)")
    for yi, c in zip(y, orden):
        ax.text(crudo.at[c, "rr_letalidad_ic_sup"] * 1.08, yi + 0.15, f"{crudo.at[c, 'rr_letalidad']:.1f}",
                va="center", fontsize=8.5, color=TEXTO_2)
        ax.text(ajustado.at[c, "rr_ajustado_edad"] * 0.92, yi - 0.02, f"{ajustado.at[c, 'rr_ajustado_edad']:.1f}",
                va="center", ha="right", fontsize=8.5, color=TEXTO)
    ax.axvline(1, color=TEXTO_2, linewidth=1, linestyle="--")
    ax.set_xscale("log")
    ax.set_xticks([0.5, 1, 2, 5, 10, 20], ["0.5", "1", "2", "5", "10", "20"])
    ax.set_xlim(0.4, 30)
    ax.set_yticks(y, orden)
    ax.grid(axis="y", visible=False)
    ax.set_xlabel("Riesgo relativo de defunción entre confirmados (escala logarítmica; 1 = sin diferencia)")
    ax.legend(loc="lower right")
    ax.set_title("Riesgo de defunción con cada comorbilidad, antes y después de ajustar por edad")
    guardar(fig, "10_riesgo_por_comorbilidad")


def demora_por_desenlace():
    df = leer("x18_demora_por_desenlace")
    fig, ejes = plt.subplots(1, 2, figsize=(10, 4))
    for ax, columna, titulo in [(ejes[0], "pct_hospitalizados", "Hospitalizados (% de los casos)"),
                                (ejes[1], "letalidad", "Letalidad entre confirmados (%)")]:
        ax.bar(df["dias_sintomas_a_ingreso"].str.capitalize(), df[columna], color=AZUL, width=0.7)
        for i, v in enumerate(df[columna]):
            ax.text(i, v, f"{v:.1f}", ha="center", va="bottom", fontsize=9, color=TEXTO_2)
        ax.set_ylim(0, df[columna].max() * 1.15)
        ax.grid(axis="x", visible=False)
        ax.set_title(titulo, fontsize=10)
        ax.set_xlabel("Días de inicio de síntomas a ingreso")
    fig.suptitle("Desenlace según los días que pasaron entre los síntomas y la llegada a la unidad",
                 x=0.01, ha="left", fontsize=12, fontweight="bold")
    fig.tight_layout()
    guardar(fig, "11_demora_por_desenlace")


def periodo_por_edad():
    df = leer("x22_periodo_edad_desenlace")
    periodos = sorted(df["periodo"].unique())
    etiquetas = ["Ene-feb 22 (ola)", "Mar-may 22", "Jun 22", "Ene 23"]
    # La letalidad de 60 y más es 50 veces la de 18-39: cada grupo con su propio eje.
    fig, ejes = plt.subplots(1, 4, figsize=(11, 3.8))
    for ax, grupo in zip(ejes, ORDEN_ETARIO):
        d = df[df["grupo_etario"] == grupo].set_index("periodo").loc[periodos]
        ax.bar(range(len(periodos)), d["letalidad"], color=AZUL, width=0.7)
        for i, (v, n) in enumerate(zip(d["letalidad"], d["confirmados"])):
            ax.text(i, v, f"{v:.2f}", ha="center", va="bottom", fontsize=8.5, color=TEXTO_2)
        ax.set_ylim(0, d["letalidad"].max() * 1.2)
        ax.set_xticks(range(len(periodos)), etiquetas, fontsize=8, rotation=45)
        ax.grid(axis="x", visible=False)
        ax.set_title(f"{ETIQUETA_ETARIO[grupo]} años", fontsize=10)
    ejes[0].set_ylabel("Letalidad entre confirmados (%)")
    fig.suptitle("Letalidad por periodo de inicio de síntomas, dentro de cada grupo de edad",
                 x=0.01, ha="left", fontsize=12, fontweight="bold")
    fig.tight_layout()
    guardar(fig, "14_periodo_por_edad")


def reglas_de_asociacion():
    df = leer("x23_reglas_comorbilidad").head(15).iloc[::-1]
    etiquetas = df["descripcion"].str.capitalize().str.replace("epoc", "EPOC").str.replace("Epoc", "EPOC")
    fig, ax = plt.subplots(figsize=(10, 6))
    ax.barh(etiquetas, df["lift"], color=AZUL, height=0.7)
    tope = df["lift"].max()
    for i, (lift, conf, n, edad) in enumerate(zip(df["lift"], df["confianza_pct"], df["confirmados"], df["edad_media"])):
        ax.text(lift + tope * 0.01, i, f"{lift:.1f}  ({conf:.1f}% de {n:,}; edad media {edad:.0f})",
                va="center", fontsize=8.5, color=TEXTO_2)
    ax.set_xlim(0, tope * 1.55)
    ax.axvline(1, color=TEXTO_2, linewidth=1, linestyle="--")
    ax.grid(axis="y", visible=False)
    ax.set_xlabel("Lift: letalidad de la combinación / letalidad nacional entre confirmados (1.126%)")
    ax.set_title("Las 15 combinaciones de comorbilidades con más riesgo de defunción (reglas de asociación)")
    guardar(fig, "15_reglas_de_asociacion")


def distribucion_edad():
    df = leer("x27_distribucion_edad")
    maximo = int(df["edad"].max())
    n_maximo = int(df.loc[df["edad"] == maximo, "casos"].iloc[0])
    fig, ax = plt.subplots(figsize=(9.5, 4.8))
    ax.bar(df["edad"], df["casos"], width=1.0, color=[NARANJA if e == maximo else AZUL for e in df["edad"]])
    ax.set_yscale("log")
    ax.yaxis.set_major_formatter(MILES)
    ax.grid(axis="x", visible=False)
    ax.annotate(f"{n_maximo} casos con {maximo} años", xy=(maximo, n_maximo), xytext=(maximo, n_maximo * 120),
                fontsize=9, ha="right", color=TEXTO_2, arrowprops=dict(arrowstyle="-", color=NEUTRO))
    ax.set_xlabel("Edad (años)")
    ax.set_ylabel("Casos (escala logarítmica)")
    ax.set_title("Distribución de la edad")
    guardar(fig, "16_distribucion_edad")


def distribucion_demoras():
    df = leer("x28_distribucion_demoras")
    orden = ["Síntomas a ingreso", "Ingreso a resultado", "Ingreso a defunción"]
    fig, ejes = plt.subplots(3, 1, figsize=(9.5, 8), sharex=True)
    for ax, demora in zip(ejes, orden):
        d = df[df["demora"] == demora]
        total = d["casos"].sum()
        ax.bar(d["dias"], d["casos"], width=1.0, color=AZUL)
        ax.set_yscale("log")
        ax.yaxis.set_major_formatter(MILES)
        ax.grid(axis="x", visible=False)
        ax.set_title(f"{demora}: {total:,} casos, máximo de {int(d['dias'].max())} días", fontsize=10)
        ax.set_ylabel("Casos (log)")
    ejes[0].axvline(10, color=NEUTRO, linestyle="--", linewidth=1)
    ejes[0].axvline(31, color=NEUTRO, linestyle="--", linewidth=1)
    ejes[0].text(10.8, ejes[0].get_ylim()[1] * 0.3, "10", fontsize=8.5, color=TEXTO_2)
    ejes[0].text(31.8, ejes[0].get_ylim()[1] * 0.3, "31 días", fontsize=8.5, color=TEXTO_2)
    ejes[-1].set_xlabel("Días")
    fig.suptitle("Distribución de las demoras entre fechas", x=0.01, ha="left", fontsize=12, fontweight="bold")
    fig.tight_layout()
    guardar(fig, "17_distribucion_demoras")


if __name__ == "__main__":
    os.makedirs(SALIDA, exist_ok=True)
    casos_por_mes()
    casos_por_semana()
    casos_por_entidad()
    casos_por_sexo_y_edad()
    casos_por_clasificacion()
    prevalencia_comorbilidad()
    mapa_mes_entidad()
    edad_por_clasificacion()
    sexo_por_comorbilidad()
    riesgo_por_comorbilidad()
    demora_por_desenlace()
    facetas_mes_entidad_clasificacion()
    matriz_letalidad()
    periodo_por_edad()
    reglas_de_asociacion()
    distribucion_edad()
    distribucion_demoras()
    print("Listo. Revisa la carpeta graficas/.")
