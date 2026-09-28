-- Práctica 02 — Equipo 3
-- Paso 1: creación de la base de datos de trabajo (PostgreSQL)
-- Ejecutar conectado a la base "postgres" (o cualquier otra ya existente),
-- nunca dentro de la propia covid20a23sedi.

CREATE DATABASE covid20a23sedi
  WITH OWNER = postgres
  ENCODING = 'UTF8'
  TEMPLATE = template0;

-- Verificación:
--   \l   (lista las bases de datos; covid20a23sedi debe aparecer con encoding UTF8)
