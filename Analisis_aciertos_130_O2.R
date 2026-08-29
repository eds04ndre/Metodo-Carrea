# ================================================================
# Caracteristicas de los individuos con estimacion CORRECTA - Observador 2
# ================================================================
# Replica de Analisis_aciertos_130.R sobre resultados/estimaciones_130_O2.csv
# (mediciones individuales del Observador 2, generado por
# Cuerda_geometrica_130_O2.R). Ejecutar despues de ese script.
# ================================================================

library(dplyr)
library(ggplot2)
library(ggeffects)

est <- read.csv("resultados/estimaciones_130_O2.csv", stringsAsFactors = FALSE, check.names = FALSE)
est <- est %>% mutate(ratio = cuerda_medida / arco, acierto = acierto_med == 1)

etiquetas <- c(H3 = "H3 (33-31)", H4 = "H4 (43-41)")

resumen <- function(d, etq) {
  data.frame(
    grupo       = etq,
    n           = nrow(d),
    estatura_m  = round(mean(d$Estatura), 3),
    estatura_sd = round(sd(d$Estatura), 3),
    pct_H       = round(mean(d$Sexo == "M") * 100, 0),
    edad        = round(mean(d$Edad, na.rm = TRUE), 1),
    arco        = round(mean(d$arco), 2),
    cuerda      = round(mean(d$cuerda_medida), 2),
    cuerda_arco = round(mean(d$ratio), 3)
  )
}

for (h in names(etiquetas)) {
  d  <- est %>% filter(hemiarcada == h)
  ac <- d %>% filter(acierto); fa <- d %>% filter(!acierto)
  cat(sprintf("\n=== %s O2 (n=%d) ===\n", etiquetas[h], nrow(d)))
  cat(sprintf("Aciertos: %d (%.1f%%) | Fallos: %d\n",
              nrow(ac), nrow(ac) / nrow(d) * 100, nrow(fa)))
  if (nrow(ac) > 0 && nrow(fa) > 0) {
    print(rbind(resumen(ac, "ACIERTOS"), resumen(fa, "FALLOS")), row.names = FALSE)
    cat(sprintf("Discriminante: cociente cuerda/arco MEDIDO %.3f (aciertos) vs %.3f (fallos).\n",
                mean(ac$ratio), mean(fa$ratio)))
  } else {
    cat("(sin variacion de acierto/fallo en esta hemiarcada - no aplica comparacion)\n")
  }
}

# Modelo logistico: el cociente cuerda/arco (y la hemiarcada) predicen el acierto?
cat("\n=== Que predice el acierto? (regresion logistica, H3-H4, O2) ===\n")
est <- est %>%
  mutate(acierto_f = factor(ifelse(acierto, "si", "no"), levels = c("no", "si")),
         Sexo_f    = factor(Sexo),
         hemi_f    = factor(hemiarcada))
mod <- glm(acierto_f ~ ratio + Estatura + Sexo_f + hemi_f, data = est, family = binomial)
print(summary(mod)$coefficients)

dir_fig <- "reporte/figuras"
if (!dir.exists(dir_fig)) dir.create(dir_fig, recursive = TRUE)

predicciones <- ggpredict(mod, terms = c("ratio", "hemi_f"))
png(file.path(dir_fig, "aciertos130_O2_prob_logistica.png"), width = 1100, height = 700, res = 130)
print(
  ggplot(predicciones, aes(x = x, y = predicted, color = group, fill = group)) +
    geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = 0.12, color = NA) +
    geom_line(linewidth = 1.1) +
    labs(title = "Probabilidad de acierto segun cociente cuerda/arco, por hemiarcada (O2)",
         subtitle = "Estatura y sexo fijados en su valor/nivel promedio",
         x = "Cociente cuerda/arco (medido)", y = "Probabilidad estimada de acierto",
         color = "Hemiarcada", fill = "Hemiarcada") +
    scale_y_continuous(labels = scales::percent, limits = c(0, 1)) +
    theme_minimal(base_size = 13) + theme(legend.position = "top")
)
dev.off()

# ----------------------------------------------------------------
# Graficos de observacion
# ----------------------------------------------------------------
png(file.path(dir_fig, "aciertos130_O2_ratio.png"), width = 1000, height = 700, res = 130)
par(mar = c(4.5, 4.5, 3.5, 1))
boxplot(ratio ~ acierto, data = est, names = c("Fallo", "Acierto"), xlab = "",
        col = c("#D73027", "#1A9850"), ylab = "Cociente cuerda/arco (medido)",
        main = "El acierto lo marca el cociente cuerda/arco medido (O2, H3-H4)")
abline(h = 1, lty = 2, col = "grey40")
dev.off()

plot_brackets <- function(d, etq, tmin, tmax, ok, sub) {
  d <- d %>% filter(!is.na(.data[[tmin]]), !is.na(.data[[tmax]])) %>% arrange(Estatura)
  n <- nrow(d)
  plot(NA, xlim = range(c(d[[tmin]], d[[tmax]], d$Estatura)), ylim = c(0.5, n + 0.5),
       xlab = "Estatura (m)", ylab = "Individuo (ordenado por estatura)",
       main = sprintf("Rango de Carrea vs estatura real - %s", etq))
  mtext(sprintf("%s | aciertos: %d/%d (%.0f%%)", sub, sum(d[[ok]]), n, mean(d[[ok]]) * 100),
        side = 3, line = 0.2, cex = 0.8)
  segments(d[[tmin]], 1:n, d[[tmax]], 1:n, col = "grey75", lwd = 3)
  points(d$Estatura, 1:n, pch = 19, col = ifelse(d[[ok]] == 1, "#1A9850", "#D73027"))
  legend("bottomright", c("Dentro del rango (acierto)", "Fuera del rango (fallo)"),
         pch = 19, col = c("#1A9850", "#D73027"), bty = "n", cex = 0.8)
}

png(file.path(dir_fig, "aciertos130_O2_bracket_H3_H4.png"), width = 1700, height = 850, res = 130)
par(mfrow = c(1, 2), mar = c(4.5, 4.5, 4, 1))
plot_brackets(est %>% filter(hemiarcada == "H3"), paste(etiquetas["H3"], "- O2"), "Tmin_med", "Tmax_med", "acierto_med", "cuerda MEDIDA")
plot_brackets(est %>% filter(hemiarcada == "H4"), paste(etiquetas["H4"], "- O2"), "Tmin_med", "Tmax_med", "acierto_med", "cuerda MEDIDA")
dev.off()
par(mfrow = c(1, 1))

cat("\nFiguras guardadas en", dir_fig, "(aciertos130_O2_*.png)\n")
