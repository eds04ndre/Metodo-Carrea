# Archivo — scripts de Etapas 1–2

Scripts exploratorios del trabajo previo, **superados por el pipeline corregido**
de la raíz del repositorio. Se conservan como registro histórico y porque algunas
tablas del reporte (`reporte/Etapa3_ProyectoII.tex`) provienen de aquí.

> ℹ️ Las rutas **ya fueron actualizadas** a la nueva estructura (`data/`,
> `resultados/`). Ejecutar desde la **raíz del repositorio**. Los scripts que
> usaban `datos_unidos.csv` ahora leen `resultados/datos_unidos_corregido.csv`
> (la base corregida, n=49 sin los falsos duplicados), por lo que sus resultados
> **diferirán de los del reporte original** basado en la base de 54.

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
