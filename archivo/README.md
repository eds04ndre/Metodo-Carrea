# Archivo — scripts de Etapas 1–3

Scripts de trabajo previo, **superados por el pipeline de la Etapa 4** (raíz del
repositorio, datos de `data/Datos_estatura130.xlsx`). Se conservan como registro
histórico y porque algunas tablas de los reportes (`reporte/Etapa3_ProyectoII.tex`,
`reporte/Interpretacion_union_y_demografias.md`) provienen de aquí.

> Nota: las rutas **ya fueron actualizadas** a la nueva estructura (`data/`,
> `resultados/`) y **ya no usan `setwd()` absoluto** — se ejecutan igual que el
> resto del proyecto, desde la **raíz del repositorio** (el `.Rproj` fija el
> directorio de trabajo automáticamente). Los scripts que usaban `datos_unidos.csv`
> ahora leen `resultados/datos_unidos_corregido.csv` (la base corregida, n=53 sin
> los falsos duplicados), por lo que sus resultados **diferirán de los del reporte
> original** basado en la base de 54.

## Etapas 1–2 (exploratorias)

| Script | Propósito |
|---|---|
| `Analisis_previo.R` | Validación inicial (Etapa 1): limpieza y regla arco > cuerda. |
| `Estatura.R` | Exploración temprana: medianas/promedios por individuo. |
| `Estatura_ordenado.R` | Análisis por evaluador, instrumento y cuadrante. |
| `Exploracion_datos2.R` | Análisis de la Etapa 2. |
| `Ajuste_Carrea.R` | Primer ajuste del método de Carrea. |
| `Ajuste_Carrea2.R` | Precursor del análisis inferencial (sobre `datos_unidos.csv`). |
| `Analisis_descriptivo.R` | Descriptivos sobre `datos_unidos.csv` + `Anexo_E.csv`. |
| `Error_obs.R` | Error intra/inter-observador. |
| `Etapa_3.R` | Etapa 3 original (incluye ANOVA de medidas repetidas y Mauchly). |

## Etapa 3 (pipeline corregido — 53 individuos, solo hemiarcadas mandibulares)

Movidos aquí porque la **Etapa 4** (raíz del repo) los sustituye: trabaja con
`data/Datos_estatura130.xlsx` (130 individuos, 3 observadores, 4 hemiarcadas —
maxilares y mandibulares) en vez de la unión de `Mediciones_Estatura.csv` +
`datos_limpios_validados.csv`. Sus salidas en `resultados/` y `reporte/figuras/`
**no se sobrescriben** y siguen siendo la base de `reporte/Etapa3_ProyectoII.tex`
y `reporte/Interpretacion_union_y_demografias.md`.

| Script | Función → Salida |
|---|---|
| `Union_limpieza.R` | Une `Mediciones_Estatura.csv` + `datos_limpios_validados.csv` por código de catálogo → `resultados/datos_unidos_corregido.csv` |
| `Cuerda_geometrica.R` | Cuerda teórica geométrica + re-estimación de Carrea (H3/H4) → `resultados/estimaciones_cuerda_geometrica.csv` |
| `Analisis_aciertos.R` | Caracteriza a los individuos con estimación correcta → `resultados/caracteristicas_aciertos.md` |
| `Analisis_demografico_aciertos.R` | Demografía de aciertos vs fallos (sexo, edad, origen) |
| `Etapa_3_corregido.R` | Análisis inferencial completo (normalidad, correlación, Carrea, k óptimo, regresiones, dimorfismo) → `resultados/resultados_carrea_corregido.csv` |
| `pipeline_correccion.py` | Equivalente en Python de todo lo anterior. |
