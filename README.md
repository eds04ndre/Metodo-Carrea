# Metodo de Carrea en poblacion mexicana

Validacion del metodo odontometrico de **Carrea** para estimar la estatura a
partir de medidas interdentales en poblacion mexicana del area metropolitana.

> **Pregunta de investigacion:** Es el metodo de estimacion de estatura mediante
> medidas interdentales propuesto por el Dr. Ubaldo Carrea (1920) valido para la
> poblacion mexicana?

Proyecto de Servicio Social - Cortes Silva Edson Andre, Facultad de Ciencias, UNAM.
Datos de la Escuela Nacional de Ciencias Forenses (ENCF) y la Coleccion Nacional
Odontologica de la UNAM.

Este repositorio es un proyecto de RStudio (`Repositorio.Rproj`) con dependencias
gestionadas por `renv` (ver `renv.lock`). Todos los scripts usan rutas relativas a
la raiz del repositorio; al abrir el `.Rproj`, RStudio fija ahi el directorio de
trabajo automaticamente.

---

## El metodo de Carrea

Para una hemiarcada anterior mandibular se mide:

- **Arco** = suma de los diametros mesiodistales del incisivo central, lateral y
  canino.
- **Cuerda (radio-cuerda)** = distancia lineal entre los mismos extremos.

La estatura estimada se obtiene con `T = medida x 30*pi / 1000` (m), generando un
rango `[Tmin, Tmax]` a partir de la cuerda y el arco. Se considera **acierto** si
la estatura real cae dentro de ese rango. El metodo fue definido y calibrado por
Carrea sobre la arcada **mandibular**; por eso el analisis de estimacion de
estatura (Etapa 4) usa solo las hemiarcadas mandibulares H3 (33-31) y H4 (43-41),
aunque la base de datos tambien incluye las maxilares.

---

## Etapa 4 (vigente) - 130 individuos, 3 observadores

Fuente unica: `data/Datos_estatura130.xlsx` (hoja `Datos`: demografia de 130
individuos; hojas `O1`/`O2`/`O3`: mediciones dentales de 3 observadores
independientes, arcada maxilar y mandibular completas). No se combina con las
fuentes de la Etapa 3.

### Hallazgos principales

1. **Con esta muestra mas grande y limpia (n=113 con estatura conocida), el arco
   dental SI se asocia con la estatura, controlando por sexo** (`estatura ~ arco +
   sexo`: R2 ajustada ~0.39, p_arco = 0.012 en H3 y 0.034 en H4) - una diferencia
   real respecto a la Etapa 3 (n=53), donde esa asociacion era nula. Sin embargo la
   estimacion puntual de Carrea sigue sin ser precisa: la correlacion entre el
   punto medio del rango de Carrea y la estatura real es baja (r=0.21 en H3, r=0.26
   en H4), y el **sexo domina el modelo** (dimorfismo de 12.4 cm, p<0.0001);
   el arco por si solo aporta poco poder explicativo adicional.
2. **La cuerda medida sigue siendo poco fiable geometricamente**: su cociente
   respecto al arco es ~0.97, y en ~35% de los casos (H3: 39/113, H4: 37/112) la
   cuerda medida *supera* al arco, lo cual es imposible. La cuerda geometrica
   (modelo de arco circular, ver `Funciones_Carrea.R`) elimina esos casos
   imposibles y mejora la precision del rango en H3 (23.0% -> 28.6%), aunque en H4
   la cuerda medida ya es ligeramente mas precisa que la geometrica (32.1% vs
   30.4%).
3. **El k de Carrea (30*pi) no es optimo para esta muestra**: el k ajustado por
   minimos cuadrados (`k_opt`, ver `resultados/k_optimo_130.csv`) difiere de 30*pi
   en las 4 combinaciones hemiarcada/cuerda, y no mejora la precision de forma
   consistente (mejora en H3-geometrica, empeora en H3-medida y H4-medida) -
   evidencia de que el problema no es solo de calibracion de la constante.
4. **Confiabilidad entre observadores (ICC)**: moderada a buena en las variables
   dentales individuales (ICC entre 0.64 y 0.81, promedio 0.76;
   `resultados/icc_por_variable_130.csv`). El **Evaluador 3** fue el mas
   consistente con el grupo (menor desviacion absoluta promedio respecto a los
   otros dos observadores; ver `resultados/consistencia_observadores_130.csv` y
   `reporte/figuras/icc130_*.png`).
5. **El acierto (que la estatura real caiga en el rango) sigue estando ligado al
   cociente cuerda/arco medido**, no a un rasgo biologico: en H3/H4 los aciertos
   tienen cociente cuerda/arco mas bajo que los fallos (H3: 0.944 vs 0.983; H4:
   0.925 vs 0.977), igual que en la Etapa 3. A nivel demografico, en esta muestra
   los aciertos si muestran una asociacion con la estatura real (mas altos en
   promedio) y con el origen en H4, algo que no se observaba en la Etapa 3 - ver
   `resultados/estimaciones_130.csv` y las pruebas en consola de
   `Analisis_demografico_130.R`.

### Profundizando el hallazgo central: arco vs. sexo

El hallazgo 1 dice que el arco se asocia con la estatura controlando por
sexo, pero no que ambos aporten lo mismo. Para cuantificarlo se compararon,
por hemiarcada y sobre la base promediada (H3 n=113, H4 n=112), tres modelos
anidados: `estatura ~ Sexo` (solo sexo), `estatura ~ arco` (solo arco), y el
combinado `estatura ~ arco + Sexo` ya reportado en el hallazgo 1, mas los
modelos de dientes individuales y de cuerda geometrica ya calculados en
`Etapa_4.R`.

**H3 (33-31):**

| Modelo | R2 | R2_adj | Prueba del predictor | AIC |
|---|---|---|---|---|
| Solo sexo (`~ Sexo`) | 0.364 | - | t = -6.72, p < 0.0001 (dif. 12.4 cm) | -280.9 |
| Solo arco (`~ arco`) | 0.037 | - | r = 0.192 | -233.9 |
| Dientes individuales (`~ mm_31+mm_32+mm_33`) | 0.083 | 0.057 | F, p_F = 0.024 | - |
| **arco + sexo** | **0.400** | **0.389** | p_arco = 0.0122, p_sexo < 0.0001 | **-285.4** |
| cuerda_geo + sexo | 0.403 | 0.392 | p_cuerda_geo = 0.0082, p_sexo < 0.0001 | - |

**H4 (43-41):**

| Modelo | R2 | R2_adj | Prueba del predictor | AIC |
|---|---|---|---|---|
| Solo sexo (`~ Sexo`) | 0.363 | - | t = -6.72, p < 0.0001 (dif. 12.4 cm) | -278.6 |
| Solo arco (`~ arco`) | 0.043 | - | r = 0.206 | -232.9 |
| Dientes individuales (`~ mm_41+mm_42+mm_43`) | 0.055 | 0.028 | F, p_F = 0.107 (NS) | - |
| **arco + sexo** | **0.389** | **0.378** | p_arco = 0.0343, p_sexo < 0.0001 | **-281.2** |
| cuerda_geo + sexo | 0.392 | 0.381 | p_cuerda_geo = 0.0248, p_sexo < 0.0001 | - |

**Comparacion formal de los modelos anidados (ANOVA de suma de cuadrados,
`anova(modelo_reducido, modelo_completo)`):**

- Agregar **sexo** al modelo de solo arco produce un salto grande y muy
  significativo: H3 F(1,110) = 66.5, p = 6.1e-13; H4 F(1,109) = 61.8,
  p = 3.0e-12. El R2 pasa de 0.037 a 0.400 en H3 (+0.363) y de 0.043 a 0.389
  en H4 (+0.346): sexo por si solo explica **~10 veces mas varianza que el
  arco por si solo**.
- Agregar **arco** al modelo de solo sexo tambien es estadisticamente
  significativo — es la misma prueba vista desde el coeficiente de arco en
  el modelo combinado (p_arco = 0.0122 en H3, p_arco = 0.0343 en H4) — pero
  el tamano del efecto es mucho menor: el R2 sube de 0.364 a 0.400 en H3
  (+0.035, un incremento relativo de ~10 %) y de 0.363 a 0.389 en H4
  (+0.026, ~7 %).
- El **AIC** confirma el mismo patron: pasar de "solo arco" a "arco + sexo"
  mejora el AIC en ~47-52 puntos (mejora enorme), mientras que pasar de
  "solo sexo" a "arco + sexo" solo lo mejora en 4.5 puntos (H3) y 2.6 puntos
  (H4) — una mejora marginal. Con n>100 hasta efectos pequenos son
  estadisticamente detectables (por eso p_arco sale significativo), pero el
  criterio de informacion deja claro que el arco aporta poco una vez que el
  sexo ya esta en el modelo, mientras que el sexo aporta muchisimo una vez
  que el arco ya esta en el modelo.

**Por que el sexo es mas descriptivo (interpretacion biologica):** la
estatura humana tiene un dimorfismo sexual grande y consistente (~12-13 cm
en esta muestra, impulsado por diferencias hormonales en el momento de
cierre de las placas de crecimiento de los huesos largos), por lo que una
sola etiqueta binaria (F/M) ya captura ~36 % de la varianza de estatura. El
tamano dental (arco), en cambio, es un proxy mucho mas debil e indirecto del
tamano corporal: la corona de los incisivos y el canino termina de formarse
antes de la erupcion, en gran medida independiente de los estirones de
crecimiento somatico que vienen despues, y responde mas al tamano local de
la cripta dentaria (control genetico especifico) que a la talla esqueletica
general. Por eso el arco explica solo ~4 % de la varianza de estatura de
forma aislada, y su aporte incremental una vez controlado el sexo es pequeno
(3-4 puntos porcentuales de R2), aunque detectable con este tamano de
muestra. Esto es justo lo que le falta al metodo de Carrea: al usar
exclusivamente medidas dentales ignora la variable que mas informacion
aporta (el sexo) y se apoya en la que aporta menos (el arco), lo que explica
por que su punto de estimacion correlaciona debilmente con la estatura real
(r = 0.21-0.26, hallazgo 1).

### Eficacia de Carrea por observador individual

`Analisis_por_observador_130.R` aplica Carrea (cuerda medida, k=30*pi) con las
mediciones de **cada observador por separado** (sin promediar entre ellos, a
diferencia del resto de la Etapa 4) y compara la precision resultante contra la
base promediada -> `resultados/precision_por_observador_130.csv`,
`reporte/figuras/aciertos130_bracket_O1/O2/O3_H3_H4.png` (bracket individual,
mismo formato que `aciertos130_bracket_H3_H4.png`) y
`reporte/figuras/comparacion130_precision_observadores.png`.

| | H3 precision | H3 rmse | H4 precision | H4 rmse |
|---|---|---|---|---|
| O1 | 25.3% | 0.1327 | 32.3% | 0.1273 |
| O2 | 23.2% | 0.1253 | 34.2% | 0.1203 |
| O3 | 23.0% | 0.1416 | 28.6% | 0.1282 |
| **Promedio** | 23.0% | 0.1314 | 32.1% | 0.1218 |

**O1 y O2 superan al promedio en precision en ambas hemiarcadas**, pero los
margenes son pequenos (+0.2 a +2.3 puntos porcentuales, n~99-113) y podrian no
ser estadisticamente significativos. **O2 es el candidato mas solido**: es el
unico que ademas tiene **menor RMSE que el promedio en H3 Y H4 simultaneamente**
(O1 tiene peor RMSE que el promedio en H4 pese a su precision ligeramente mayor).
Por eso se replico el pipeline completo de Carrea (cuerda geometrica, aciertos,
demografia, analisis inferencial) usando solo los datos de O2:
`Cuerda_geometrica_130_O2.R`, `Analisis_aciertos_130_O2.R`,
`Analisis_demografico_130_O2.R`, `Etapa_4_O2.R` (mismo orden y logica que sus
equivalentes sin sufijo, leyendo `resultados/datos_130_observadores.csv` filtrado
a `Evaluador == 2`):

```r
source("Cuerda_geometrica_130_O2.R")
source("Analisis_aciertos_130_O2.R")
source("Analisis_demografico_130_O2.R")
source("Etapa_4_O2.R")
```

#### Resultados de la replica con O2

1. **El hallazgo central (arco~estatura controlando sexo) se replica casi
   identico usando solo O2**, sin promediar: `estatura ~ arco + sexo` da R2
   ajustada 0.388 (H3) y 0.374 (H4), p_arco = 0.012 en H3 (identico al
   promedio) y 0.045 en H4 (vs 0.034 del promedio) - refuerza que el hallazgo
   1 de la Etapa 4 no es un artefacto de promediar entre observadores.
   `estatura ~ cuerda_geometrica + sexo` es aun mas significativo
   (p=0.0041 en H3, p=0.0140 en H4) que con arco.
2. **La precision con O2 (cuerda medida) es ligeramente mejor que el
   promedio** (H3: 23.2% vs 23.0%; H4: 34.2% vs 32.1%), pero la cuerda
   geometrica ya no ayuda de forma pareja: mejora H3 (23.2% -> 26.8%,
   0 casos imposibles) pero **empeora notablemente H4** (34.2% -> 25.2%),
   a diferencia del promedio general donde medida y geometrica quedaban
   cerca en H4 (32.1% vs 30.4%).
3. **El k optimo tampoco es consistente con datos de O2**: mejora la
   precision en H3 (ambas cuerdas) y en H4-geometrica, pero **empeora
   H4-medida** (34.2% -> 31.5%) - el mismo patron de inconsistencia que con
   el promedio (confirma el hallazgo 3 de la Etapa 4).
4. **El acierto sigue ligado al cociente cuerda/arco**, no a un rasgo
   biologico: en la regresion logistica `ratio` es el unico predictor
   significativo (p=2.0e-9); Estatura, Sexo y hemiarcada no lo son.
5. Con cuerda geometrica, a nivel persona **los aciertos tienen estatura
   real mayor que los fallos** (1.633 m vs 1.601 m, Wilcoxon p=0.027) -
   coincide con el hallazgo 5 de la Etapa 4 general.
6. El **dimorfismo sexual es identico** (12.4 cm, p<0.0001): no depende del
   observador, como se espera de un dato puramente demografico.

### Pipeline (raiz del repositorio)

| Script | Funcion -> Salida |
|---|---|
| `Union_datos130.R` | Limpia y une `data/Datos_estatura130.xlsx`: homologa nombres de columna, normaliza instrumento, marca outliers inverosimiles, elimina individuos sin estatura conocida, colapsa duplicados intra-observador y promedia entre observadores -> `resultados/datos_130_observadores.csv`, `resultados/datos_130_promedio.csv` |
| `Funciones_Carrea.R` | Funciones compartidas: cuerda geometrica (modelo de arco circular), metricas de Carrea, preparacion de hemiarcadas (H3/H4 solamente) |
| `Confiabilidad_130.R` | ICC entre observadores por variable dental y consistencia individual de cada observador -> `resultados/icc_por_variable_130.csv`, `resultados/consistencia_observadores_130.csv` |
| `Cuerda_geometrica_130.R` | Cuerda geometrica vs medida y precision del rango de Carrea (H3/H4) -> `resultados/estimaciones_130.csv` |
| `Analisis_aciertos_130.R` | Que distingue a los individuos con estimacion correcta (regresion logistica, cociente cuerda/arco) |
| `Analisis_demografico_130.R` | Demografia (sexo, edad, estatura, origen) de aciertos vs fallos |
| `Etapa_4.R` | Analisis inferencial completo: normalidad, correlacion arco-cuerda, Carrea (medida vs geometrica), k optimo, regresiones, dimorfismo sexual -> `resultados/resultados_carrea_130.csv`, `resultados/k_optimo_130.csv` |
| `Analisis_por_observador_130.R` | Eficacia de Carrea usando cada observador por separado (sin promediar) vs la base promediada -> `resultados/precision_por_observador_130.csv` |
| `Cuerda_geometrica_130_O2.R`, `Analisis_aciertos_130_O2.R`, `Analisis_demografico_130_O2.R`, `Etapa_4_O2.R` | Replica del pipeline de Carrea (no de la union ni de la confiabilidad) usando solo las mediciones del Observador 2 -> `resultados/*_O2.csv` |

Reproducir en orden:

```r
source("Union_datos130.R")
source("Confiabilidad_130.R")
source("Cuerda_geometrica_130.R")
source("Analisis_aciertos_130.R")
source("Analisis_demografico_130.R")
source("Etapa_4.R")
source("Analisis_por_observador_130.R")

# Opcional: replica del analisis solo para el Observador 2 (ver arriba)
source("Cuerda_geometrica_130_O2.R")
source("Analisis_aciertos_130_O2.R")
source("Analisis_demografico_130_O2.R")
source("Etapa_4_O2.R")
```

### Graficas (`reporte/figuras/`)

Cada prueba y cada resultado numerico de la Etapa 4 tiene su grafica
correspondiente, agrupadas por prefijo:

| Prefijo | Script | Contenido |
|---|---|---|
| `u130_*` | `Union_datos130.R` | Cobertura por observador, estatura por sexo, composicion por origen |
| `icc130_*` | `Confiabilidad_130.R` | ICC por variable dental, consistencia por observador |
| `geo130_*` | `Cuerda_geometrica_130.R` | Arco vs cuerda (medida y geometrica) por hemiarcada, boxplot comparativo, precision medida vs geometrica |
| `aciertos130_*` | `Analisis_aciertos_130.R` | Probabilidad de acierto (regresion logistica), cociente cuerda/arco en aciertos vs fallos, rango de Carrea vs estatura real |
| `demo130_*` | `Analisis_demografico_130.R` | Tasa de acierto por sexo y origen, estatura/edad en aciertos vs fallos |
| `etapa4_*` | `Etapa_4.R` | Normalidad (Q-Q + histograma), correlacion arco-cuerda, hallazgo central (Carrea vs estatura real), precision medida vs geometrica, k optimo, R2 de los modelos, dimorfismo sexual |
| `aciertos130_bracket_O1/O2/O3_*`, `comparacion130_*` | `Analisis_por_observador_130.R` | Rango de Carrea vs estatura real por observador individual, precision por observador vs promedio |
| `geo130_O2_*`, `aciertos130_O2_*`, `demo130_O2_*`, `etapa4_O2_*` | `*_O2.R` | Mismas graficas que sus equivalentes sin sufijo, replicadas solo con datos del Observador 2 |

### Decisiones de limpieza (ver comentarios en `Union_datos130.R`)

- Nombres de columna homologados entre `O1`/`O2`/`O3` (solo difiere `N Modelo`
  vs `N_Modelo`).
- Instrumento normalizado a `"Vernier"` (variantes `"Verniere"`/`"vernier"`).
- Placeholder `0` en columnas de medida -> NA (no medido).
- Un valor de cuerda inverosimil (`O2`, ID 71, `mm 43-41 = 71.44 mm`, geometricamente
  imposible) se marca como NA en vez de corregirse a un valor supuesto.
- Se eliminan primero los individuos sin estatura conocida (16 NA + 1 "no hay
  datos" en la hoja `Datos`); despues se colapsan por promedio las replicas no
  marcadas dentro de un mismo observador (O1: IDs 69-72; O2: ID 92, cuando su
  estatura es conocida); por ultimo se promedia entre observadores.
- Los rangos anatomicos de referencia (`Funciones_Carrea.R`) tienen una tolerancia
  de 0.5 mm: una medida solo se marca fuera de rango si se desvia mas de eso,
  para no confundir variabilidad interobservador normal con un valor
  inverosimil.

---

## Etapa 3 (archivada) - 53 individuos, solo hemiarcadas mandibulares

Superada por la Etapa 4. Sus scripts, documentados en `archivo/README.md`, se
conservan junto con sus salidas en `resultados/` y `reporte/` porque son la base
de `reporte/Etapa3_ProyectoII.tex` y `reporte/Interpretacion_union_y_demografias.md`.
Trabajaba con la union de `data/Mediciones_Estatura.csv` (41 individuos) y
`data/datos_limpios_validados.csv` (13 individuos), llegando a 53 individuos tras
corregir codigos de catalogo compartidos. Su conclusion (metodo de Carrea sin
poder predictivo, r ~ 0) reflejaba esa muestra mas pequena; la Etapa 4 la matiza
con una muestra mayor (ver hallazgo 1 arriba).

---

## Estructura del repositorio

```
.
├── Union_datos130.R          # Etapa 4: limpieza y union de Datos_estatura130.xlsx
├── Funciones_Carrea.R        # funciones compartidas (cuerda geometrica, metricas)
├── Confiabilidad_130.R       # ICC entre observadores
├── Cuerda_geometrica_130.R   # cuerda geometrica + precision de Carrea (H3/H4)
├── Analisis_aciertos_130.R   # que distingue a los aciertos
├── Analisis_demografico_130.R # demografia de aciertos vs fallos
├── Etapa_4.R                 # analisis inferencial completo
├── Analisis_por_observador_130.R  # eficacia de Carrea por observador individual vs promedio
├── Cuerda_geometrica_130_O2.R     # replica del pipeline de Carrea solo con datos del Observador 2
├── Analisis_aciertos_130_O2.R     # (idem)
├── Analisis_demografico_130_O2.R  # (idem)
├── Etapa_4_O2.R                   # (idem)
├── data/
│   ├── Datos_estatura130.xlsx        # fuente de la Etapa 4 (130 individuos, 3 observadores)
│   ├── Mediciones_Estatura.csv       # fuente de la Etapa 3 (41 individuos)
│   ├── datos_limpios_validados.csv   # fuente de la Etapa 3 (13 individuos)
│   ├── Datos_Estatura.csv            # demografia de la Etapa 3
│   └── *.xlsx                        # originales en Excel
├── resultados/                # salidas generadas (regenerables)
│   ├── datos_130_observadores.csv    # Etapa 4, por observador x individuo
│   ├── datos_130_promedio.csv        # Etapa 4, promedio por individuo
│   ├── icc_por_variable_130.csv      # Etapa 4, confiabilidad entre observadores
│   ├── consistencia_observadores_130.csv
│   ├── estimaciones_130.csv          # Etapa 4, Carrea por individuo y hemiarcada
│   ├── resultados_carrea_130.csv     # Etapa 4, tabla resumen
│   ├── k_optimo_130.csv              # Etapa 4, k ajustado por minimos cuadrados
│   ├── precision_por_observador_130.csv  # precision por observador individual vs promedio
│   ├── *_O2.csv                      # replica del pipeline de Carrea solo con datos del Observador 2
│   └── *_corregido.csv, *.csv        # salidas de la Etapa 3 (archivada)
├── reporte/                  # documento de la Etapa 3 + figuras de ambas etapas
│   ├── Etapa3_ProyectoII.tex / .pdf
│   ├── Interpretacion_union_y_demografias.md
│   └── figuras/               # figuras de la Etapa 3 y Etapa 4 (ver prefijos arriba)
└── archivo/                  # scripts de Etapas 1-3 (superadas; ver archivo/README.md)
```

---

## Buenas practicas del proyecto

- **Rutas relativas + `.Rproj`**: ningun script usa `setwd()` con ruta absoluta.
  Abrir `Repositorio.Rproj` en RStudio fija el directorio de trabajo en la raiz
  automaticamente; los scripts se ejecutan con `source("Script.R")` desde ahi.
- **Dependencias con `renv`**: `renv.lock` fija las versiones de los paquetes
  usados (incluye `readxl`, `dplyr`, `tidyr`, `ggplot2`, `ggeffects`, `irr`).
  Al abrir el proyecto, `renv::restore()` reproduce el entorno exacto en otra
  maquina.
- **Funciones compartidas centralizadas**: `Funciones_Carrea.R` evita triplicar
  `solve_phi`/`cuerda_geo`/`prep_hemiarcada` en cada script (como ocurria en la
  Etapa 3); cualquier cambio a la formula de Carrea se hace en un solo lugar.
