# ================================================================
# Cuerda teorica geometrica y re-estimacion de Carrea - Observador 2 (O2)
# ================================================================
# Replica de Cuerda_geometrica_130.R pero SOLO con las mediciones
# individuales del Observador 2 (sin promediar entre observadores).
# Se genero porque Analisis_por_observador_130.R mostro que O2 tiene
# mejor precision Y menor RMSE que el promedio entre observadores en
# H3 y H4 simultaneamente (ver resultados/precision_por_observador_130.csv).
# ================================================================

library(dplyr)
source("Funciones_Carrea.R")

obs_data <- read.csv("resultados/datos_130_observadores.csv", stringsAsFactors = FALSE, check.names = FALSE)
du <- obs_data %>% filter(Evaluador == 2)
write.csv(du, "resultados/datos_130_O2.csv", row.names = FALSE)
cat(sprintf("Observador 2: %d individuos (guardado en resultados/datos_130_O2.csv)\n", nrow(du)))

hemis <- lapply(names(HEMIARCADAS), function(h) prep_hemiarcada(du, h))
names(hemis) <- names(HEMIARCADAS)

evalua <- function(d, chord_col, k = k_carrea) {
  d <- d %>% filter(!is.na(.data[[chord_col]]))
  cu <- d[[chord_col]]; ar <- d$arco; est <- d$Estatura
  Tmin  <- pmin(cu, ar) / 1000 * k
  Tmax  <- pmax(cu, ar) / 1000 * k
  Tprom <- (Tmin + Tmax) / 2
  data.frame(
    n           = nrow(d),
    precision   = round(mean(est >= Tmin & est <= Tmax) * 100, 1),
    rmse        = round(sqrt(mean((est - Tprom)^2)), 4),
    r_tprom     = round(suppressWarnings(cor(est, Tprom)), 3),
    cuerda_arco = round(mean(cu / ar), 3),
    imposibles  = sum(cu >= ar),
    ancho_cm    = round(mean(Tmax - Tmin) * 100, 1)
  )
}

for (h in names(hemis)) {
  cat(sprintf("=== %s (O2): cuerda medida vs geometrica ===\n", h))
  print(rbind(MEDIDA = evalua(hemis[[h]], "cuerda_med"),
              GEOMETRICA = evalua(hemis[[h]], "cuerda_geo")))
  cat("\n")
}

# ----------------------------------------------------------------
# Graficas de observacion - arco vs cuerda medida/geometrica, y boxplot
# comparativo entre las 2 hemiarcadas. Figuras en reporte/figuras/.
# ----------------------------------------------------------------
dir_fig <- "reporte/figuras"
if (!dir.exists(dir_fig)) dir.create(dir_fig, recursive = TRUE)

plot_arco_cuerda <- function(d, etq, archivo) {
  d   <- d %>% filter(!is.na(cuerda_geo))
  rng <- range(c(d$arco, d$cuerda_med, d$cuerda_geo))
  png(file.path(dir_fig, archivo), width = 1000, height = 800, res = 130)
  par(mar = c(4.5, 4.5, 3.5, 1))
  plot(d$arco, d$cuerda_med, pch = 19, col = "#D6604D",
       xlim = rng, ylim = rng,
       xlab = "Arco (mm)", ylab = "Cuerda (mm)",
       main = sprintf("Arco vs cuerda - %s (O2)", etq))
  points(d$arco, d$cuerda_geo, pch = 17, col = "#4393C3")
  abline(0, 1, lty = 2, col = "grey40")
  legend("topleft",
         c("Cuerda medida", "Cuerda geometrica", "cuerda = arco (limite)"),
         pch = c(19, 17, NA), lty = c(NA, NA, 2),
         col = c("#D6604D", "#4393C3", "grey40"), bty = "n")
  n_imp <- sum(d$cuerda_med >= d$arco)
  mtext(sprintf("Casos imposibles (medida >= arco): %d de %d", n_imp, nrow(d)),
        side = 3, line = 0.2, cex = 0.85, col = "#D6604D")
  dev.off()
}
etiquetas <- c(H3 = "H3 (33-31)", H4 = "H4 (43-41)")
for (h in names(hemis)) {
  plot_arco_cuerda(hemis[[h]], etiquetas[h], sprintf("geo130_O2_arco_cuerda_%s.png", h))
}

cmp <- na.omit(do.call(rbind, lapply(names(hemis), function(h) {
  d <- hemis[[h]]
  rbind(
    data.frame(valor = d$arco,       grupo = sprintf("%s arco",  h)),
    data.frame(valor = d$cuerda_med, grupo = sprintf("%s medida", h)),
    data.frame(valor = d$cuerda_geo, grupo = sprintf("%s geom.",  h))
  )
})))
cmp$grupo <- factor(cmp$grupo, levels = unique(cmp$grupo))

png(file.path(dir_fig, "geo130_O2_boxplot_cuerdas.png"), width = 1100, height = 750, res = 130)
par(mar = c(7, 4.5, 3, 1))
boxplot(valor ~ grupo, data = cmp, las = 2, xlab = "", ylab = "Medida (mm)",
        main = "Arco, cuerda medida y cuerda geometrica - H3 y H4 (O2)",
        col = rep(c("#B2ABD2", "#D6604D", "#4393C3"), length(hemis)))
dev.off()

# Precision del bracket [Tmin,Tmax]: cuerda medida vs geometrica, H3 y H4.
tabla_precision <- do.call(rbind, lapply(names(hemis), function(h) {
  rbind(
    data.frame(hemiarcada = etiquetas[h], tipo = "Medida",
               precision = evalua(hemis[[h]], "cuerda_med")$precision),
    data.frame(hemiarcada = etiquetas[h], tipo = "Geometrica",
               precision = evalua(hemis[[h]], "cuerda_geo")$precision)
  )
}))
png(file.path(dir_fig, "geo130_O2_precision.png"), width = 1000, height = 700, res = 130)
par(mar = c(4.5, 4.5, 3.5, 1))
m <- matrix(tabla_precision$precision, nrow = 2, dimnames = list(c("Medida", "Geometrica"), etiquetas))
bp <- barplot(m, beside = TRUE, col = c("#D6604D", "#4393C3"), ylim = c(0, 100),
              ylab = "Precision del rango [Tmin,Tmax] (%)",
              main = "Precision de Carrea: cuerda medida vs geometrica (H3, H4) - O2")
text(bp, m, labels = sprintf("%.1f%%", m), pos = 3, cex = 0.85)
legend("topright", c("Cuerda medida", "Cuerda geometrica"), fill = c("#D6604D", "#4393C3"), bty = "n")
dev.off()

cat("Figuras guardadas en", dir_fig, "(geo130_O2_*.png)\n")

# ----------------------------------------------------------------
# Exportar estimaciones por individuo y hemiarcada
# ----------------------------------------------------------------
export <- function(d, hemi) {
  d %>% filter(!is.na(cuerda_geo)) %>% transmute(
    hemiarcada = hemi, ID, Sexo, Edad, Estatura, Origen,
    arco = round(arco, 3), cuerda_medida = round(cuerda_med, 3),
    cuerda_geometrica = round(cuerda_geo, 3),
    Tmin_med = round(pmin(cuerda_med, arco) / 1000 * k_carrea, 3),
    Tmax_med = round(pmax(cuerda_med, arco) / 1000 * k_carrea, 3),
    acierto_med = as.integer(Estatura >= pmin(cuerda_med, arco) / 1000 * k_carrea &
                             Estatura <= pmax(cuerda_med, arco) / 1000 * k_carrea),
    Tmin_geo = round(pmin(cuerda_geo, arco) / 1000 * k_carrea, 3),
    Tmax_geo = round(pmax(cuerda_geo, arco) / 1000 * k_carrea, 3),
    acierto_geo = as.integer(Estatura >= pmin(cuerda_geo, arco) / 1000 * k_carrea &
                             Estatura <= pmax(cuerda_geo, arco) / 1000 * k_carrea))
}
estimaciones <- do.call(bind_rows, lapply(names(hemis), function(h) export(hemis[[h]], h)))
write.csv(estimaciones, "resultados/estimaciones_130_O2.csv", row.names = FALSE)
cat("\nGuardado: resultados/estimaciones_130_O2.csv\n")
