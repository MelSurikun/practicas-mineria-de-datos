"""Práctica 03, Equipo 3. Prueba de los niveles de razonamiento de OLMo 3 (ver README.md).

Uso, parado en aportacion_santiago/ con Ollama encendido:
    .venv.nosync/bin/python llm/intento_olmo/prueba_niveles_razonamiento.py
"""
import json, time, requests
for nivel in ("low", True):
    t0 = time.time()
    r = requests.post("http://localhost:11434/api/chat", json={
        "model": "olmo-3:7b", "stream": False, "think": nivel, "keep_alive": "5m",
        "messages": [{"role": "user", "content": "¿Cuánto es 17 por 3? Responde solo el número."}],
        "options": {"temperature": 0, "seed": 42, "num_ctx": 4096, "num_predict": 3000}})
    d = r.json()
    if "error" in d:
        print(nivel, "ERROR:", d["error"]); continue
    m = d["message"]
    print(f"think={nivel!r}: {d['eval_count']} tokens, {len(m.get('thinking') or '')} caracteres de razonamiento, "
          f"respuesta={m.get('content','')[:60]!r}, {time.time()-t0:.0f} s, fin={d['done_reason']}")
