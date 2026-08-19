# Método de Carrea en población mexicana

Validación del método odontométrico de **Carrea** para estimar la estatura a
partir de medidas interdentales en población mexicana del área metropolitana.

> **Pregunta de investigación:** ¿Es el método de estimación de estatura mediante
> medidas interdentales propuesto por el Dr. Ubaldo Carrea (1920) válido para la
> población mexicana?

Proyecto de Servicio Social — Cortés Silva Edson André, Facultad de Ciencias, UNAM.
Datos de la Escuela Nacional de Ciencias Forenses (ENCF) y la Colección Nacional
Odontológica de la UNAM.

---

## El método de Carrea

Para una hemiarcada anterior inferior se mide:

- **Arco** = suma de los diámetros mesiodistales del incisivo central, lateral y
  canino.
- **Cuerda (radio-cuerda)** = distancia lineal entre los mismos extremos.

La estatura estimada se obtiene con `T = medida × 30π / 1000` (m), generando un
rango `[Tmin, Tmax]` a partir de la cuerda y el arco. Se considera **acierto** si
la estatura real cae dentro de ese rango.

---

## Hallazgos principales

1. **El método no predice la estatura en esta muestra.** La correlación entre las
   estimaciones de Carrea y la estatura real es nula (r ≈ 0); el único predictor
   con poder real es el **sexo** (dimorfismo de ~9 cm, p < 0.001).
2. **La cuerda medida es poco fiable.** Su cociente respecto al arco es ~0.98 y en
   ~40 % de los casos la cuerda *supera* al arco, lo cual es geométricamente
   imposible y vuelve intercambiables `Tmin` y `Tmax`.
3. **Cuerda teórica geométrica.** Se propone derivar la cuerda de la geometría del
   arco dental (modelo de arco circular usando la distancia intercanina). La cuerda
   geométrica es siempre menor que el arco, elimina los casos imposibles y
   **duplica la precisión** del bracket (≈15 % → ≈30 %), pero **no genera
   correlación**: corrige la geometría del método, no su capacidad predictiva.
4. **Los "aciertos" del modelo original son un artefacto de medición.** Lo que
   distingue a un acierto no es un rasgo biológico (estatura/sexo) sino un cociente
   cuerda/arco medido más bajo, dominado por el error de medición.

---

## Estructura del repositorio

```
.
├── Union_limpieza.R          # une fuentes por código de catálogo (ID)
├── Cuerda_geometrica.R       # cuerda teórica geométrica + re-estimación
├── Analisis_aciertos.R       # qué tienen en común los aciertos
├── Etapa_3_corregido.R       # análisis inferencial completo (base corregida)
├── pipeline_correccion.py    # equivalente en Python (materializa las salidas)
├── data/                     # fuentes (no modificar)
│   ├── Mediciones_Estatura.csv      # 41 individuos (1 obs, vernier)
│   ├── datos_limpios_validados.csv  # 13 individuos con réplicas
│   ├── Datos_Estatura.csv           # demografía de la base validada
│   ├── Anexo_E.csv
│   └── *.xlsx                        # originales en Excel
├── resultados/               # salidas generadas (regenerables)
│   ├── datos_unidos_corregido.csv         # base unificada (53 individuos)
│   ├── auditoria_union_demografias.csv    # veredicto por código compartido
│   ├── estimaciones_cuerda_geometrica.csv # cuerda medida vs geométrica
│   ├── caracteristicas_aciertos.md        # reporte de aciertos
│   └── resultados_carrea_corregido.csv    # tabla resumen de Carrea
├── reporte/                  # documento de la Etapa 3
│   ├── Etapa3_ProyectoII.tex / .pdf
│   ├── Interpretacion_union_y_demografias.md  # interpretación detallada
│   ├── boxplots_*.pdf
│   └── figuras/              # figuras del análisis (.png)
└── archivo/                  # scripts de Etapas 1–2 (superados; ver archivo/README.md)
```

### Pipeline de corrección (este trabajo)

| Script | Función → Salida |
|---|---|
| `Union_limpieza.R` | Une las fuentes por **código de catálogo** (`ID`) validando misma persona vs demografías distintas (estas se recuperan con código de 4 dígitos) → `resultados/datos_unidos_corregido.csv`, `resultados/auditoria_union_demografias.csv` |
| `Cuerda_geometrica.R` | Calcula la cuerda teórica y re-estima Carrea → `resultados/estimaciones_cuerda_geometrica.csv` |
| `Analisis_aciertos.R` | Caracteriza a los individuos con estimación correcta → `resultados/caracteristicas_aciertos.md` |
| `Analisis_demografico_aciertos.R` | Compara la demografía (sexo, edad, estatura, origen) de aciertos vs fallos, con cuerda medida y geométrica → figuras `reporte/figuras/demo_aciertos_*.png` |
| `Etapa_3_corregido.R` | Análisis inferencial completo (normalidad, correlación, Carrea, k óptimo, regresiones, dimorfismo) sobre la base corregida y con cuerda geométrica → `resultados/resultados_carrea_corregido.csv` |
| `pipeline_correccion.py` | Equivalente en Python que materializa todas las salidas anteriores. |

### Gráficos de observación

Cada script de R, además de sus tablas, guarda en `reporte/figuras/` figuras
para observar los datos en los pasos cruciales (paleta y estilo base de R):

| Script | Figuras (`reporte/figuras/`) |
|---|---|
| `Union_limpieza.R` | `union_estatura_por_sexo.png` (distribución por sexo), `union_composicion.png` (fuente × sexo), `union_auditoria_conflictos.png` (auditoría de la unión por código) |
| `Cuerda_geometrica.R` | `geo_arco_cuerda_H3/H4.png` (arco vs cuerda con la recta límite cuerda=arco), `geo_boxplot_cuerdas.png` (arco vs cuerda medida vs geométrica) |
| `Analisis_aciertos.R` | `aciertos_bracket_H3/H4_comparacion.png` (rango `[Tmin,Tmax]` vs estatura real por individuo, **cuerda medida vs geométrica** lado a lado). Los gráficos del cociente cuerda/arco y de la probabilidad logística se dibujan en pantalla (sus `png()` están comentados). |
| `Analisis_demografico_aciertos.R` | `demo_aciertos_sexo.png`, `demo_aciertos_origen.png` (tasa de acierto por sexo/origen, medida vs geométrica), `demo_aciertos_estatura_edad.png` (estatura y edad: acierto vs fallo) |
| `Etapa_3_corregido.R` | `etapa3_estatura_qq.png` (normalidad), `etapa3_arco_cuerda.png` (correlación), `etapa3_carrea_real_H3/H4.png` (**hallazgo central**: Carrea vs real, r≈0), `etapa3_precision.png` (precisión medida vs geométrica) |

---

## Nota sobre la corrección de la unión

Cinco códigos de catálogo aparecen en ambas fuentes (3, 14, 18, 27, 71). Compartir
código **no** implica ser la misma persona, así que cada caso se valida comparando la
demografía:

- **Misma persona** (mismo sexo y `|Δestatura| ≤ 0.02 m`): solo el código **3**. Se
  consolida en el registro validado para no contar dos veces a una persona.
- **Demografías distintas** (sexo invertido en 18 y 71; estatura/origen/edad distintos
  en 14 y 27): son **individuos diferentes**. **No se eliminan**: se recuperan con un
  **código nuevo de 4 dígitos** (`9000 + código`, → 9014, 9018, 9027, 9071) y se
  integran al análisis.

Resultado: **53 individuos** (la versión previa eliminaba en bloque los 5 códigos
compartidos y se quedaba en 49, perdiendo a los 4 individuos distintos). El veredicto
por código queda en `resultados/auditoria_union_demografias.csv` y la interpretación
completa en `reporte/Interpretacion_union_y_demografias.md`. Recuperar a esos 4
individuos **no altera las conclusiones**, lo que refuerza su robustez.

---

## Cómo reproducir

```r
# En R, desde la raíz del repositorio:
source("Union_limpieza.R")       # -> datos_unidos_corregido.csv
source("Cuerda_geometrica.R")    # -> estimaciones_cuerda_geometrica.csv
source("Analisis_aciertos.R")    # -> caracteristicas_aciertos.md
source("Etapa_3_corregido.R")    # -> resultados_carrea_corregido.csv
```

```bash
# Alternativa en Python (genera todas las salidas):
python pipeline_correccion.py
```

Dependencias R: `dplyr`, `tidyr` (y `ez` para el ANOVA de medidas repetidas en
`Etapa_3.R`). Python: solo biblioteca estándar.
