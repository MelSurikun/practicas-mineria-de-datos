Para elegir un modelo multidimensional para el conjunto de datos de contagios de COVID, se ha optado por el modelo de estrella. La razón principal es que este modelo es adecuado para análisis de datos que tienen una tabla central de hechos y varias tablas de dimensiones que se relacionan con ella. En este caso, la tabla central de hechos sería la tabla de casos de COVID-19, que contiene información sobre cada caso individual, mientras que las tablas de dimensiones incluirían información sobre el tiempo, la ubicación, el paciente y la condición clínica.

En cuanto a la identificación de medidas y dimensiones, se han identificado las siguientes:

* Medidas:
	+ Número de casos confirmados
	+ Número de defunciones
	+ Número de recuperados
* Dimensiones:
	+ Tiempo: fecha de diagnóstico, fecha de inicio de síntomas, fecha de defunción
	+ Ubicación: entidad federativa, municipio, localidad
	+ Paciente: sexo, edad, nacionalidad, condición migratoria, grupo de edad
	+ Condición clínica: diabetes, hipertensión, obesidad, neumonía, tabaquismo, comorbilidades

En cuanto a la identificación de jerarquías de datos, se han identificado las siguientes:

* Tiempo: día, semana, mes, año
* Ubicación: país, entidad federativa, municipio, localidad
* Paciente: sexo, grupo de edad, nacionalidad, condición migratoria
* Condición clínica: tipo de comorbilidad

En cuanto a la identificación de tablas de hechos, se ha identificado una sola tabla de hechos, que es la tabla de casos de COVID-19, que contiene información sobre cada caso individual.

En cuanto a la situación de redundancias de datos en las diferentes tablas, se han identificado algunas redundancias en la información de ubicación, ya que la entidad federativa, municipio y localidad se repiten en varias tablas. Para evitar esta redundancia, se puede crear una tabla de ubicación que contenga toda la información de ubicación y relacionarla con las demás tablas a través de una clave única.

En cuanto a la granularidad de la dimensión del tiempo y espacio, se ha propuesto una granularidad diaria para la dimensión del tiempo, ya que esto permitiría un análisis detallado de la evolución de la pandemia día a día. En cuanto a la dimensión del espacio, se ha propuesto una granularidad a nivel municipio, ya que esto permitiría un análisis detallado de la distribución geográfica de la pandemia.

En cuanto a la granularidad, tipos, grupos o formas que toman la o las dimensiones temáticas, se han identificado los siguientes grupos:

* Tiempo: día, semana, mes, año
* Ubicación: país, entidad federativa, municipio, localidad
* Paciente: sexo, grupo de edad, nacionalidad, condición migratoria
* Condición clínica: tipo de comorbilidad

Finalmente, en cuanto al límite razonable de enriquecimiento del tiempo y el espacio, se ha propuesto un límite de hasta el nivel de localidad para la dimensión del espacio, ya que esto permitiría un análisis detallado de la distribución geográfica de la pandemia sin sobrecargar la base de datos con información redundante. En cuanto a la dimensión del tiempo, se ha propuesto un límite de hasta el nivel de año, ya que esto permitiría un análisis a largo plazo de la evolución de la pandemia sin sobrecargar la base de datos con información redundante.

En resumen, el modelo de estrella propuesto para el conjunto de datos de contagios de COVID