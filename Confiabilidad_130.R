# ================================================================
# Confiabilidad entre observadores (ICC) - Etapa 4
# ================================================================
# Pregunta: que tan consistentes son las mediciones entre los 3
# observadores, y cual de ellos fue el mas consistente.
#
# Se calcula el Coeficiente de Correlacion Intraclase (ICC) por variable,
# modelo de dos vias con acuerdo absoluto y medida individual (ICC(2,1)):
# evalua si observadores distintos, midiendo al mismo individuo, dan el
# mismo valor en terminos absolutos (no solo si covarian).
#
# La consistencia POR observador se evalua aparte: para cada observador,
# la desviacion absoluta de su medicion respecto al promedio de los otros
# dos, en el mismo individuo y variable. El observador con menor desviacion
# promedio es el mas consistente con el resto del grupo.
#
# Fuente: resultados/datos_130_observadores.csv (una fila por observador x
# individuo, ya sin duplicados intra-observador y solo individuos con
# estatura conocida; ver Union_datos130.R). Se usan todas las variables
# dentales medidas (maxilares y mandibulares), no solo H3/H4: la
# confiabilidad de la medicion es una propiedad del observador y del
# instrumento, independiente de que hemiarcadas entren al analisis de
# Carrea.
# ================================================================

library(dplyr)
library(tidyr)
library(irr)

largo <- read.csv("resultados/datos_130_observadores.csv",
                   stringsAsFactors = FALSE, check.names = FALSE)

variables <- c("mm_11", "mm_12", "mm_13", "mm_21", "mm_22", "mm_23",
               "mm_13_11", "mm_23_21",
               "mm_31", "mm_32", "mm_33", "mm_41", "mm_42", "mm_43",
               "mm_33_31", "mm_43_41")

a_matriz <- function(var) {
  largo %>%
    select(ID, Evaluador, valor = all_of(var)) %>%
    pivot_wider(names_from = Evaluador, names_prefix = "Obs", values_from = valor) %>%
    filter(!is.na(Obs1), !is.na(Obs2), !is.na(Obs3))
}

calc_icc <- function(var) {
  m <- a_matriz(var)
  if (nrow(m) < 5) return(NULL)
  r <- icc(m[, c("Obs1", "Obs2", "Obs3")], model = "twoway", type = "agreement", unit = "single")
  data.frame(variable = var, n = nrow(m), icc = round(r$value, 3),
             ic_inf = round(r$lbound, 3), ic_sup = round(r$ubound, 3),
             p = round(r$p.value, 4))
}

tabla_icc <- bind_rows(lapply(variables, calc_icc))
cat("=== ICC(2,1) por variable (acuerdo absoluto, modelo de dos vias) ===\n")
print(tabla_icc, row.names = FALSE)
cat(sprintf("\nICC promedio (todas las variables): %.3f\n", mean(tabla_icc$icc)))
cat(sprintf("ICC promedio mandibulares (H3/H4: mm_31-33, mm_41-43, mm_33_31, mm_43_41): %.3f\n",
            mean(tabla_icc$icc[tabla_icc$variable %in%
                 c("mm_31","mm_32","mm_33","mm_41","mm_42","mm_43","mm_33_31","mm_43_41")])))

dir.create("resultados", showWarnings = FALSE)
write.csv(tabla_icc, "resultados/icc_por_variable_130.csv", row.names = FALSE)
cat("\nGuardado: resultados/icc_por_variable_130.csv\n")

# ----------------------------------------------------------------
# Consistencia por observador: desviacion absoluta respecto al promedio
# de los otros dos observadores, para cada individuo y variable.
# ----------------------------------------------------------------
desviacion_obs <- function(var) {
  m <- a_matriz(var)
  if (nrow(m) < 5) return(NULL)
  bind_rows(lapply(1:3, function(o) {
    otros <- setdiff(1:3, o)
    prom_otros <- rowMeans(m[, paste0("Obs", otros)])
    data.frame(variable = var, Evaluador = o,
               dev_abs = abs(m[[paste0("Obs", o)]] - prom_otros))
  }))
}
desviaciones <- bind_rows(lapply(variables, desviacion_obs))

resumen_obs <- desviaciones %>%
  group_by(Evaluador) %>%
  summarise(dev_media = round(mean(dev_abs), 3),
            dev_mediana = round(median(dev_abs), 3),
            n_comparaciones = n(), .groups = "drop") %>%
  as.data.frame()

cat("\n=== Consistencia por observador (desviacion absoluta vs. promedio de los otros 2) ===\n")
print(resumen_obs, row.names = FALSE)

mejor <- resumen_obs$Evaluador[which.min(resumen_obs$dev_media)]
cat(sprintf("\nObservador mas consistente (menor desviacion promedio respecto al grupo): Evaluador %d\n", mejor))

write.csv(resumen_obs, "resultados/consistencia_observadores_130.csv", row.names = FALSE)
cat("Guardado: resultados/consistencia_observadores_130.csv\n")

# ----------------------------------------------------------------
# Graficas
# ----------------------------------------------------------------
dir_fig <- "reporte/figuras"
if (!dir.exists(dir_fig)) dir.create(dir_fig, recursive = TRUE)

png(file.path(dir_fig, "icc130_por_variable.png"), width = 1300, height = 750, res = 130)
par(mar = c(7, 4.5, 3, 1))
bp <- barplot(tabla_icc$icc, names.arg = tabla_icc$variable, las = 2,
              col = ifelse(tabla_icc$icc >= 0.75, "#1A9850",
                     ifelse(tabla_icc$icc >= 0.5, "#F4A582", "#D73027")),
              ylim = c(0, 1), ylab = "ICC (acuerdo absoluto)",
              main = "Confiabilidad entre observadores por variable")
abline(h = c(0.5, 0.75), lty = 2, col = "grey50")
text(bp, tabla_icc$icc, labels = tabla_icc$icc, pos = 3, cex = 0.7)
legend("bottomright", c(">= 0.75: buena", "0.5 - 0.75: moderada", "< 0.5: pobre"),
       fill = c("#1A9850", "#F4A582", "#D73027"), bty = "n", cex = 0.75)
dev.off()

png(file.path(dir_fig, "icc130_consistencia_observador.png"), width = 1000, height = 700, res = 130)
par(mar = c(4.5, 4.5, 3, 1))
boxplot(dev_abs ~ Evaluador, data = desviaciones,
        col = c("#F4A582", "#A8C5DA", "#B2ABD2"),
        xlab = "Observador", ylab = "Desviacion absoluta vs. promedio de los otros 2 (mm)",
        main = "Consistencia por observador (todas las variables medidas)")
dev.off()

cat("\nFiguras guardadas en", dir_fig, "(icc130_*.png)\n")
