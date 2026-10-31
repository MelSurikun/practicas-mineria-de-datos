  CREATE TABLE dim_resultado (
      id_res SERIAL PRIMARY KEY,
      origen INTEGER NOT NULL CHECK (origen IN ('1', '2', '99')), -- 1=USMER; 2=FUERA DE USMER; 99=NO ESPECIFICADO
      sector INTEGER NOT NULL CHECK (sector IN ('1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '99')), -- 1-13 del catálogo, 99=NO ESPECIFICADO
      tipo_paciente INTEGER NOT NULL CHECK (tipo_paciente IN ('1', '2', '99')), -- 1=AMBULATORIO; 2=HOSPITALIZADO; 99=NO ESPECIFICADO
      intubado INTEGER NOT NULL CHECK (intubado IN ('1', '2', '99')), -- 1=SI, 2=NO, 99=NO ESPECIFICADO
      neumonia INTEGER NOT NULL CHECK (neumonia IN ('1', '2', '99')), -- 1=SI, 2=NO, 99=NO ESPECIFICADO
      resultado_lab INTEGER NOT NULL CHECK (resultado_lab IN ('1', '2', '3', '4', '97')), -- 1=POSITIVO; 2=NO POSITIVO; 3=PENDIENTE; 4=NO ADECUADO; 97=NO APLICA
      resultado_antigeno INTEGER NOT NULL CHECK (resultado_antigeno IN ('1', '2', '97')), -- 1=POSITIVO; 2=NEGATIVO; 97=NO APLICA
      clasificacion_final INTEGER NOT NULL CHECK (clasificacion_final IN ('1', '2', '3', '4', '5', '6', '7')), -- 1-7
      uci INTEGER NOT NULL CHECK (uci IN ('1', '2', '99')), -- 1=SI UCI; 2=NO UCI; 99=NO ESPECIFICADO
      otro_caso INTEGER NOT NULL CHECK (otro_caso IN ('1', '2', '99')) -- 1=SI contacto; 2=NO; 99=NO ESPECIFICADO
  );