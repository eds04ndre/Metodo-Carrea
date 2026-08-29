# ================================================================
# Eficacia de Carrea por observador individual — Etapa 4
# ================================================================
# Aplica el metodo de Carrea (cuerda MEDIDA, k=30pi) usando las
# mediciones de CADA observador por separado (sin promediar entre
# observadores, a diferencia de Cuerda_geometrica_130.R /
# resultados/datos_130_promedio.csv), y compara la precision del
# rango [Tmin,Tmax] resultante contra la base promediada.
#
# Fuente: resultados/datos_130_observadores.csv (una fila por
# Evaluador x ID, generada por Union_datos130.R). Solo hemiarcadas
# mandibulares H3/H4 (ver Funciones_Carrea.R).
# ================================================================

library(dplyr)
source("Funciones_Carrea.R")

obs_data <- read.csv("resultados/datos_130_observadores.csv", stringsAsFactors = FALSE, check.names = FALSE)
du_prom  <- read.csv("resultados/datos_130_promedio.csv",     stringsAsFactors = FALSE, check.names = FALSE)

etiquetas_hemi <- c(H3 = "H3 (33-31)", H4 = "H4 (43-41)")
dir_fig <- "reporte/figuras"
if (!dir.exists(dir_fig)) dir.create(dir_fig, recursive = TRUE)

fila_metricas <- function(dh, observador, h) {
  m <- metricas(dh, "cuerda_med", label = sprintf("%s-%s", observador, h))
  data.frame(observador = observador, hemiarcada = h, n = m$n, precision = m$precision,
             rmse = m$rmse, r_tprom = m$r_tprom, cuerda_arco = m$cuerda_arco,
             imposibles = m$imposibles)
}

# ----------------------------------------------------------------
# 1. Precision por observador individual (sin promediar) y baseline
#    (promedio entre observadores), ambas por el MISMO camino:
#    prep_hemiarcada() + metricas() sobre cuerda medida.
# ----------------------------------------------------------------
resultados_obs   <- list()
brackets_datos   <- list()

for (obs in 1:3) {
  d_obs <- obs_data %>% filter(Evaluador == obs)
  for (h in names(HEMIARCADAS)) {
    dh <- prep_hemiarcada(d_obs, h)
    if (nrow(dh) == 0) next
    key <- sprintf("O%d_%s", obs, h)
    resultados_obs[[key]] <- fila_metricas(dh, sprintf("O%d", obs), h)
    brackets_datos[[key]] <- dh %>% mutate(
      Tmin_med    = pmin(cuerda_med, arco) / 1000 * k_carrea,
      Tmax_med    = pmax(cuerda_med, arco) / 1000 * k_carrea,
      acierto_med = as.integer(Estatura >= Tmin_med & Estatura <= Tmax_med))
  }
}
tabla_obs <- do.call(rbind, resultados_obs)

baseline <- do.call(rbind, lapply(names(HEMIARCADAS), function(h) {
  dh <- prep_hemiarcada(du_prom, h)
  fila_metricas(dh, "Promedio", h)
}))

tabla_comparacion <- rbind(tabla_obs, baseline)
rownames(tabla_comparacion) <- NULL

cat("=== Precision de Carrea (cuerda medida, k=30pi) por observador vs promedio ===\n")
print(tabla_comparacion, row.names = FALSE)

write.csv(tabla_comparacion, "resultados/precision_por_observador_130.csv", row.names = FALSE)
cat("\nGuardado: resultados/precision_por_observador_130.csv\n")

# ----------------------------------------------------------------
# 2. Graficas bracket por observador (mismo formato que
#    aciertos130_bracket_H3_H4.png, una figura H3+H4 por observador)
# ----------------------------------------------------------------
plot_brackets <- function(d, etq, sub) {
  d <- d %>% arrange(Estatura)
  n <- nrow(d)
  plot(NA, xlim = range(c(d$Tmin_med, d$Tmax_med, d$Estatura)), ylim = c(0.5, n + 0.5),
       xlab = "Estatura (m)", ylab = "Individuo (ordenado por estatura)",
       main = sprintf("Rango de Carrea vs estatura real — %s", etq))
  mtext(sprintf("%s | aciertos: %d/%d (%.0f%%)", sub, sum(d$acierto_med), n, mean(d$acierto_med) * 100),
        side = 3, line = 0.2, cex = 0.8)
  segments(d$Tmin_med, 1:n, d$Tmax_med, 1:n, col = "grey75", lwd = 3)
  points(d$Estatura, 1:n, pch = 19, col = ifelse(d$acierto_med == 1, "#1A9850", "#D73027"))
  legend("bottomright", c("Dentro del rango (acierto)", "Fuera del rango (fallo)"),
         pch = 19, col = c("#1A9850", "#D73027"), bty = "n", cex = 0.8)
}

for (obs in 1:3) {
  png(file.path(dir_fig, sprintf("aciertos130_bracket_O%d_H3_H4.png", obs)),
      width = 1700, height = 850, res = 130)
  par(mfrow = c(1, 2), mar = c(4.5, 4.5, 4, 1))
  plot_brackets(brackets_datos[[sprintf("O%d_H3", obs)]], sprintf("Observador %d — %s", obs, etiquetas_hemi["H3"]), "cuerda MEDIDA, individual")
  plot_brackets(brackets_datos[[sprintf("O%d_H4", obs)]], sprintf("Observador %d — %s", obs, etiquetas_hemi["H4"]), "cuerda MEDIDA, individual")
  dev.off()
}
par(mfrow = c(1, 1))

# ----------------------------------------------------------------
# 3. Grafica comparativa: precision por observador individual vs
#    promedio, agrupada por hemiarcada.
# ----------------------------------------------------------------
niveles_obs <- c("O1", "O2", "O3", "Promedio")
m <- matrix(NA_real_, nrow = length(niveles_obs), ncol = length(etiquetas_hemi),
            dimnames = list(niveles_obs, names(etiquetas_hemi)))
for (i in seq_len(nrow(tabla_comparacion))) {
  m[tabla_comparacion$observador[i], tabla_comparacion$hemiarcada[i]] <- tabla_comparacion$precision[i]
}

png(file.path(dir_fig, "comparacion130_precision_observadores.png"), width = 1100, height = 750, res = 130)
par(mar = c(4.5, 4.5, 3.5, 1))
cols <- c("#D6604D", "#F4A582", "#4393C3", "#1A9850")
bp <- barplot(m, beside = TRUE, col = cols, ylim = c(0, 100),
              ylab = "Precision del rango [Tmin,Tmax] (%)", xlab = "",
              names.arg = etiquetas_hemi,
              main = "Precision de Carrea: observador individual vs promedio (cuerda medida)")
text(bp, m, labels = sprintf("%.1f%%", m), pos = 3, cex = 0.75)
legend("topright", niveles_obs, fill = cols, bty = "n", ncol = 2)
dev.off()

cat("\nFiguras guardadas en", dir_fig,
    "(aciertos130_bracket_O1/O2/O3_H3_H4.png, comparacion130_precision_observadores.png)\n")

# ----------------------------------------------------------------
# 4. Veredicto: ¿algun observador individual supera al promedio?
# ----------------------------------------------------------------
cat("\n=== Veredicto: observador individual vs promedio ===\n")
mejor <- tabla_comparacion %>%
  group_by(hemiarcada) %>%
  arrange(desc(precision), .by_group = TRUE) %>%
  slice(1) %>%
  ungroup()
print(as.data.frame(mejor), row.names = FALSE)

gana_individual <- tabla_comparacion %>%
  filter(observador != "Promedio") %>%
  inner_join(baseline %>% select(hemiarcada, precision_prom = precision), by = "hemiarcada") %>%
  filter(precision > precision_prom)

if (nrow(gana_individual) > 0) {
  cat("\nAl menos un observador individual SUPERA al promedio en al menos una hemiarcada:\n")
  print(as.data.frame(gana_individual), row.names = FALSE)
  cat("\n-> Revisar si algun observador supera al promedio en AMBAS hemiarcadas (H3 y H4)\n",
      "   antes de decidir si vale la pena replicar todo el pipeline para ese observador.\n")
} else {
  cat("\nNingun observador individual supera al promedio en ninguna hemiarcada.\n",
      "-> No se justifica replicar el pipeline completo para un observador especifico;\n",
      "   promediar entre observadores sigue siendo la mejor base.\n")
}
