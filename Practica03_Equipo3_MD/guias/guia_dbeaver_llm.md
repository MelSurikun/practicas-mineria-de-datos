# Guía: DBeaver con un LLM local (punto 3.1)

> **Esta guía la ejecutas tú**, porque DBeaver es una aplicación gráfica. Cada paso dice qué hacer, qué deberías ver y qué capturar. Al final me pasas las capturas y el SQL que generó el modelo; yo lo compruebo contra la base y redacto el 3.1.
>
> Tiempo estimado: 30 a 40 minutos, la mayor parte esperando respuestas del modelo.

## Por qué así

El enunciado pide probar DBeaver con algún LLM y documentar los prompts. Usamos un **modelo local de software libre por Ollama**, el mismo motor del punto 2. Así la prueba no cuesta nada, no necesita llaves de API y ningún dato sale de tu Mac. Además, el mismo modelo aparece en los dos puntos, lo que da hilo al reporte.

Según la documentación de DBeaver, la integración con Ollama solo existe en las ediciones **Lite, Enterprise y Ultimate**, no en Community. Usamos **DBeaver Lite**, que tiene una prueba gratuita de 14 días sin tarjeta.

> Alternativa si no quieres activar la prueba: DBeaver Community con GitHub Copilot, que tiene plan gratuito. Los prompts de la sección 5 son los mismos. Copilot no es software libre, y eso habría que decirlo en el reporte.

## 1. Encender lo necesario

En una terminal:

```bash
# Base de datos (clúster de la práctica, puerto 5434)
/Library/PostgreSQL/18/bin/pg_ctl -D ~/PostgreSQL-datos/mineria_p2 -l ~/PostgreSQL-datos/mineria_p2/server.log start

# Ollama (déjalo corriendo en su propia terminal)
OLLAMA_FLASH_ATTENTION=1 OLLAMA_KV_CACHE_TYPE=q8_0 ollama serve
```

Para comprobar que Ollama responde, abre http://localhost:11434 en el navegador: debe decir «Ollama is running».

> Cierra lo que no uses (Chrome con muchas pestañas, por ejemplo). El modelo ocupa unos 7 GB de los 16 de tu Mac y, con poca memoria libre, responde mucho más lento.

## 2. Instalar DBeaver Lite y activar la prueba

```bash
brew install --cask dbeaverlite
```

Ábrelo y, cuando pida licencia, elige la prueba gratuita (Trial) y regístrate con tu correo.

## 3. Conectar a la base del modelo

1. **Database → New Database Connection → PostgreSQL**.
2. Llena los datos:
   - Host: `localhost`
   - Port: `5434`
   - Database: `covid_p3`
   - Username: `postgres`
   - Password: vacío (el clúster usa autenticación local `trust`)
3. Si pide descargar el driver, acepta.
4. Clic en **Test Connection**: debe decir «Connected».
5. En la pestaña **PostgreSQL** de la misma ventana, marca **Show all databases** si quieres ver también las demás bases.

📸 **Captura 1:** la ventana de conexión con «Connected».

## 4. El diagrama del modelo en DBeaver

1. En el **Database Navigator**: `covid_p3 → Schemas → dw`.
2. Clic derecho sobre `dw` → **View Diagram**.
3. DBeaver dibuja las 13 tablas con sus llaves foráneas. Acomódalas con clic derecho en el lienzo → **Layout → Arrange** (o arrastrando), con `fact_casos_covid` al centro.
4. Para exportarlo: clic derecho en el lienzo → **Export diagram** (o **Save as image**), en PNG.

📸 **Captura 2:** el diagrama de `dw` en DBeaver. Este es el segundo diagrama del punto 3: lo genera la herramienta a partir de la base y confirma que el modelo existe tal como lo dibujamos.

## 5. Conectar DBeaver con Ollama

1. **Window → Preferences → AI**. En macOS el menú puede llamarse **DBeaver → Settings…**.
2. Comprueba que esté marcado **Enable AI integration**.
3. Ve a **AI → Model configurations**, clic en **+** y elige **Ollama**.
4. Llena el perfil:
   - **Instance host:** `http://localhost:11434`
   - **Model:** clic en el botón de recargar junto al selector y elige **`mistral-nemo:12b`**. Uso Mistral Nemo porque admite herramientas (tool calling, que DBeaver aprovecha) y no tiene modo de razonamiento, que con Qwen3 puede alargar y ensuciar las respuestas.
   - **Temperature:** `0.0` (viene así por omisión).
   - **Advanced settings → Request timeout (sec):** cámbialo de 30 a **`300`**. Un modelo local tarda más de 30 segundos en contestar algunas preguntas, y con 30 la prueba fallaría por tiempo aunque todo esté bien.
5. Clic en **Test connection** y luego en **Apply**.
6. En **AI → Configuration → Send database structure**, activa también:
   - **Send object description:** manda los comentarios de las tablas y columnas (escribimos un comentario en cada una, así que el modelo recibe la documentación del esquema).
   - **Send foreign keys information**.
   - **Send unique and primary keys information**.

   Por omisión DBeaver solo manda nombres de tablas y columnas con su tipo. Con esto el modelo conoce también las relaciones y el significado de cada columna.

📸 **Captura 3:** el perfil de Ollama con la prueba de conexión correcta.

> Privacidad: con Ollama todo se procesa en tu Mac. DBeaver manda la estructura (nombres, tipos, comentarios y llaves), no las filas de los casos.

## 6. Los prompts

1. Abre el chat con el ícono **AI Chat** de la barra de herramientas, o con el ícono **AI Assistant** de la barra izquierda del editor SQL.
2. Arriba del chat, elige la conexión `covid_p3`.
3. En **Change scope → Metadata sent to AI**, elige **Current schema** (el esquema `dw`). Si no aparece `dw` como esquema actual, abre antes un editor SQL sobre `dw`.

Escribe estos cuatro prompts **en este orden**, cada uno tal cual, y envíalos con el botón **Send** (o ⌘↩). Cuando la respuesta traiga SQL, usa **Execute** para correrlo, o **Editor** si prefieres revisarlo antes.

**Prompt 1 · Comprensión del modelo**

```
Describe en pocas líneas el modelo del esquema dw: cuál es la tabla de hechos, cuál es su grano y qué dimensiones tiene.
```

**Prompt 2 · Consulta con un rol de tiempo**

```
Muestra el número de casos confirmados y de defunciones por semana epidemiológica de inicio de síntomas, ordenado por año y semana epidemiológica.
```

**Prompt 3 · Una medida que exige cuidado**

```
Calcula la letalidad entre casos confirmados por grupo etario, sin contar las edades no válidas.
```

**Prompt 4 · Dimensiones con roles**

```
¿Qué columnas de dw.fact_casos_covid apuntan a dw.dim_tiempo y qué representa cada una?
```

📸 **Capturas 4 a 7:** una por prompt, donde se vean el prompt, la respuesta y, si hubo SQL, el resultado.

Además de las capturas, **copia el texto completo de cada respuesta**, sobre todo el SQL, y pégalo en `evidencias/dbeaver/respuestas.md`, uno debajo del otro. Así lo puedo correr y revisar exactamente lo que el modelo escribió.

## 7. Qué me tienes que pasar

Guarda todo en `aportacion_santiago/evidencias/dbeaver/`:

| Archivo | Qué es |
|---|---|
| `captura_1_conexion.png` | Conexión a covid_p3 correcta |
| `captura_2_diagrama.png` | Diagrama del esquema dw en DBeaver (o el PNG que exportaste) |
| `captura_3_ollama.png` | Perfil de Ollama con la prueba de conexión correcta |
| `captura_4_prompt_1.png` … `captura_7_prompt_4.png` | Cada prompt con su respuesta |
| `respuestas.md` | El texto de las cuatro respuestas |

Con eso compruebo:
- si el SQL del prompt 2 da lo mismo que nuestra consulta validada (`evidencias/comparacion/q1_estrella.csv`);
- si el del prompt 3 cuenta solo las defunciones de casos confirmados, que es el error típico;
- si el modelo identificó los cuatro roles de tiempo.

Después redacto el 3.1 con esos resultados.

## Si algo falla

| Síntoma | Qué hacer |
|---|---|
| «Connection refused» en el paso 3 | El clúster está apagado: corre la primera línea del paso 1 |
| La lista de modelos sale vacía en el paso 5 | Ollama no está corriendo: revisa http://localhost:11434 |
| El chat da «timeout» | Sube el Request timeout del paso 5 a 600 y vuelve a intentar; la primera respuesta tarda más porque carga el modelo |
| El modelo responde sobre tablas que no existen | Revisa que el alcance sea el esquema `dw` (sección 6) y que estén activados los comentarios y las llaves (paso 5.6) |
| No aparece la opción de Ollama | Estás en DBeaver Community: instala la Lite (paso 2) o usa la alternativa con Copilot |
