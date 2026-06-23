# Archivo — scripts de Etapas 1–2

Scripts exploratorios del trabajo previo, **superados por el pipeline corregido**
de la raíz del repositorio. Se conservan como registro histórico y porque algunas
tablas del reporte (`reporte/Etapa3_ProyectoII.tex`) provienen de aquí.

> ⚠️ No están actualizados a la nueva estructura de carpetas (`data/`,
> `resultados/`): sus rutas (`read.csv("datos_unidos.csv")`, `setwd(...)`, etc.)
> apuntan al layout plano anterior y a `datos_unidos.csv`, que fue eliminado y
> reemplazado por `resultados/datos_unidos_corregido.csv`. Para volver a correrlos
> habría que ajustar rutas.

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
