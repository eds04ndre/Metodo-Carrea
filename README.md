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

Reproducir en orden:

```r
source("Union_datos130.R")
source("Confiabilidad_130.R")
source("Cuerda_geometrica_130.R")
source("Analisis_aciertos_130.R")
source("Analisis_demografico_130.R")
source("Etapa_4.R")
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
