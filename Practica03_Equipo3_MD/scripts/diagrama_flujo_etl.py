"""
Práctica 03, Equipo 3 (Melanie, Ingeniería de Datos). Punto 4.

Dibuja el flujo del ETL en diagramas/flujo_etl.png, con la numeración de pasos 1 a 11.
Las cifras son las de evidencias/etl/ (e01, c01 y las consultas v).

Uso, parado en Practica03_Equipo3_MD/:
    python scripts/diagrama_flujo_etl.py
"""
import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SUPERFICIE = "#fcfcfb"
TEXTO = "#0b0b0b"
TEXTO_2 = "#52514e"
LINEA = "#6f6e69"
AZUL = "#2a78d6"

# Etapa, y sus cajas: (título, detalle, archivo)
ETAPAS = [
    ("EXTRACCIÓN", [
        ("1. Tabla de origen", "public.covid_historica\n(Práctica 2)", ""),
        ("2. Conteo", "2,099,997 filas\n45 columnas, 44 usadas", "e01_perfil_extraccion"),
        ("3. Filtros", "Se excluye LOCALIDAD_RES\nSin filtros de filas", "e01_perfil_extraccion"),
        ("Catálogos", "11 catálogos en CSV\n(201128 Catalogos)", "00_catalogos.sql"),
    ]),
    ("TRANSFORMACIÓN", [
        ("4. Tipos", "Se conservan smallint y date\nLlaves int o smallint", "01_esquema_dw.sql"),
        ("5. Fechas", "Llave AAAAMMDD\nHuecos: -1 y -2", "07_hechos.sql"),
        ("6. Textos", "Catálogo en mayúsculas\nPaíses normalizados", "06_dimensiones.sql"),
        ("7. Valores únicos", "Combinaciones con\nSELECT DISTINCT", "06_dimensiones.sql"),
        ("8. No válidos", "Miembro inferido\nMedida en NULL", "06 y 07"),
    ]),
    ("CARGA", [
        ("Esquema dw", "13 tablas vacías\ncon comentarios", "01_esquema_dw.sql"),
        ("9. Dimensiones", "12 dimensiones\ncon llaves únicas", "06_dimensiones.sql"),
        ("10. Hechos", "2,099,997 filas\nsin llaves ni índices", "07_hechos.sql"),
        ("10. Llaves foráneas", "16 llaves validadas\n3 índices", "02_llaves_foraneas.sql"),
    ]),
    ("VALIDACIÓN", [
        ("11. Conteos", "Origen = destino\nRechazados: 0 y 0", "v01, v02, r01"),
        ("11. Duplicados y FK", "Duplicados: 0\nHuérfanas: 0", "v03, v04"),
        ("11. Ida y vuelta", "44 columnas\nDiferencias: 0 y 0", "v06"),
        ("11. Medidas", "Modelo = origen", "v08"),
        ("11. Nulos y atípicos", "Miembros especiales\n11 banderas", "v05, v10"),
    ]),
]

ANCHO_TOTAL = 15.0
INICIO_X = 1.5
ALTO_CAJA = 1.28
ALTO_FILA = 2.1


def caja(ax, x, y, ancho, titulo, detalle, archivo):
    ax.add_patch(FancyBboxPatch((x, y), ancho, ALTO_CAJA, boxstyle="round,pad=0,rounding_size=0.06",
                                facecolor="white", edgecolor=AZUL, linewidth=1.3))
    ax.text(x + ancho / 2, y + ALTO_CAJA - 0.2, titulo, ha="center", va="center", fontsize=10,
            fontweight="bold", color=TEXTO)
    ax.text(x + ancho / 2, y + ALTO_CAJA / 2 - 0.02, detalle, ha="center", va="center", fontsize=8.5, color=TEXTO)
    ax.text(x + ancho / 2, y + 0.14, archivo, ha="center", va="center", fontsize=7.5, color=TEXTO_2, style="italic")


def flecha(ax, a, b, **kw):
    ax.add_patch(FancyArrowPatch(a, b, arrowstyle="-|>", mutation_scale=13, color=LINEA, linewidth=1.3, **kw))


def main():
    filas = len(ETAPAS)
    alto = filas * ALTO_FILA + 0.5
    fig, ax = plt.subplots(figsize=(14, alto * 0.82), facecolor=SUPERFICIE)
    ax.set_xlim(0, INICIO_X + ANCHO_TOTAL + 0.2)
    ax.set_ylim(-0.6, alto)
    ax.axis("off")

    separacion = 0.35
    for f, (etapa, cajas) in enumerate(ETAPAS):
        y = alto - (f + 1) * ALTO_FILA
        ax.text(0.65, y + ALTO_CAJA / 2, etapa, rotation=90, ha="center", va="center", fontsize=9.5,
                fontweight="bold", color=AZUL)
        ancho = (ANCHO_TOTAL - separacion * (len(cajas) - 1)) / len(cajas)
        for i, (titulo, detalle, archivo) in enumerate(cajas):
            x = INICIO_X + i * (ancho + separacion)
            caja(ax, x, y, ancho, titulo, detalle, archivo)
            if i < len(cajas) - 1:
                flecha(ax, (x + ancho, y + ALTO_CAJA / 2), (x + ancho + separacion, y + ALTO_CAJA / 2))
        if f < filas - 1:
            centro = INICIO_X + ANCHO_TOTAL / 2
            flecha(ax, (centro, y), (centro, y - (ALTO_FILA - ALTO_CAJA)))

    # Si algo falla, la transacción se deshace y se vuelve a correr desde correr_etl.sql.
    y_final = alto - filas * ALTO_FILA
    ax.text(INICIO_X + ANCHO_TOTAL / 2, y_final - 0.32,
            "Si un paso falla, su transacción se deshace, se corrige la causa y se vuelve a correr correr_etl.sql "
            "(registro en evidencias/bitacora_errores_p3.md)",
            ha="center", va="center", fontsize=9, color=TEXTO_2)

    ax.set_title("Flujo del ETL: de covid_historica al modelo estrella", loc="left", fontsize=13,
                 fontweight="bold", color=TEXTO)
    salida = os.path.join(RAIZ, "diagramas", "flujo_etl.png")
    fig.savefig(salida, dpi=170, bbox_inches="tight", facecolor=SUPERFICIE)
    print(f"Generado {salida}")


if __name__ == "__main__":
    main()
