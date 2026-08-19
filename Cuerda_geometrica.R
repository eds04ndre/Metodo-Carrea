# ================================================================
# Cuerda teórica geométrica y re-estimación de Carrea
# ================================================================
# Problema: la cuerda MEDIDA es ~igual al arco (cociente ~0.98) y en ~40%
# de los casos la supera, lo cual es geométricamente imposible y vuelve
# intercambiables Tmin y Tmax. Se propone derivar la cuerda a partir de la
# geometría del arco dental en lugar de medirla directamente.
#
# Modelo geométrico
# -----------------
# Los 6 dientes anteriores inferiores se disponen sobre un arco circular de
# radio R. Sea:
#   L = arco total      = (mm_31+mm_32+mm_33) + (mm_41+mm_42+mm_43)
#   C = cuerda canino–canino = distancia intercanina (mm_43_33)
# Para un arco circular:  arco = 2 R φ   y   cuerda = 2 R sin(φ).
# Por tanto:              C / L = sin(φ) / φ        ... (1)
# Se resuelve φ de (1) numéricamente y R = L / (2 φ).
#
# Para una hemiarcada con arco L_h, el ángulo que subtiende es θ = L_h / R y
# su cuerda teórica (la "radio-cuerda" de Carrea) es:
#   cuerda_geo = 2 R sin(θ / 2)
# Esta cuerda es SIEMPRE menor que el arco (válida), corrigiendo el defecto
# de la medición directa.
# ================================================================

library(dplyr)

du <- read.csv("resultados/datos_unidos_corregido.csv",
               stringsAsFactors = FALSE, check.names = FALSE)

k_carrea <- 30 * pi

# --- resolver φ en  sin(φ)/φ = q  (q en (0,1)), por bisección -----
solve_phi <- function(q) {
  if (is.na(q) || q >= 1) return(NA_real_)
  f  <- function(p) sin(p)/p - q
  lo <- 1e-6; hi <- pi - 1e-6
  for (i in 1:100) {
    mid <- (lo + hi) / 2
    if (f(mid) > 0) lo <- mid else hi <- mid
  }
  (lo + hi) / 2
}

# --- cuerda geométrica de una hemiarcada -------------------------
cuerda_geo <- function(arco_h, L_full, C_full) {
  phi <- solve_phi(C_full / L_full)
  if (is.na(phi)) return(NA_real_)
  R  <- L_full / (2 * phi)
  th <- arco_h / R
  2 * R * sin(th / 2)
}

# --- construir hemiarcadas con limpieza anatómica ----------------
prep <- function(d, t1, t2, t3, chord, excl_ids, central = NULL) {
  d <- d %>%
    filter(!is.na(.data[[t1]]), !is.na(.data[[t2]]), !is.na(.data[[t3]]),
           .data[[t1]] != 0, .data[[t2]] != 0, .data[[t3]] != 0,
           !is.na(Estatura), !(ID %in% excl_ids)) %>%
    mutate(arco   = .data[[t1]] + .data[[t2]] + .data[[t3]],
           cuerda_med = .data[[chord]],
           L_full = (mm_31 + mm_32 + mm_33) + (mm_41 + mm_42 + mm_43),
           C_full = intercanina_inf)
  if (!is.null(central))
    d <- d %>% filter(!(ID == "sin codigo" & .data[[central]] > 8))
  d %>% rowwise() %>%
    mutate(cuerda_geo = cuerda_geo(arco, L_full, C_full)) %>%
    ungroup()
}

h3 <- prep(du, "mm_31","mm_32","mm_33","mm_33_31", c("17"), "mm_31")
h4 <- prep(du, "mm_41","mm_42","mm_43","mm_43_41", c("26"))

# --- métricas de Carrea con una cuerda dada ----------------------
evalua <- function(d, chord_col, k = k_carrea) {
  d <- d %>% filter(!is.na(.data[[chord_col]]))
  cu <- d[[chord_col]]; ar <- d$arco; est <- d$Estatura
  Tmin  <- pmin(cu, ar) / 1000 * k
  Tmax  <- pmax(cu, ar) / 1000 * k
  Tprom <- (Tmin + Tmax) / 2
  carrea <- data.frame(
    n          = nrow(d),
    precision  = round(mean(est >= Tmin & est <= Tmax) * 100, 1),
    rmse       = round(sqrt(mean((est - Tprom)^2)), 4),
    r_tprom    = round(suppressWarnings(cor(est, Tprom)), 3),
    cuerda_arco= round(mean(cu / ar), 3),
    imposibles = sum(cu >= ar),
    ancho_cm   = round(mean(Tmax - Tmin) * 100, 1)
  )
  return (carrea)
}

cat("=== H3: cuerda medida vs geométrica ===\n")
print(rbind(MEDIDA = evalua(h3, "cuerda_med"),
            GEOMETRICA = evalua(h3, "cuerda_geo")))
cat("\n=== H4: cuerda medida vs geométrica ===\n")
print(rbind(MEDIDA = evalua(h4, "cuerda_med"),
            GEOMETRICA = evalua(h4, "cuerda_geo")))

# ----------------------------------------------------------------
# Gráficos de observación — cuerda medida vs geométrica
#   Paso crucial: el defecto que motiva todo el script. La cuerda
#   MEDIDA cae sobre/encima de la recta cuerda=arco (geométricamente
#   imposible); la cuerda GEOMÉTRICA queda siempre por debajo.
#   Figuras en reporte/figuras/.
# ----------------------------------------------------------------
dir_fig <- "reporte/figuras"
if (!dir.exists(dir_fig)) dir.create(dir_fig, recursive = TRUE)

# (a) Dispersión arco vs cuerda (medida y geométrica) con la recta límite.
plot_arco_cuerda <- function(d, etq, archivo) {
  d   <- d %>% filter(!is.na(cuerda_geo))
  rng <- range(c(d$arco, d$cuerda_med, d$cuerda_geo))
  # png(file.path(dir_fig, archivo), width = 1000, height = 800, res = 130)
  par(mar = c(4.5, 4.5, 3.5, 1))
  plot(d$arco, d$cuerda_med, pch = 19, col = "#D6604D",
       xlim = rng, ylim = rng,
       xlab = "Arco (mm)", ylab = "Cuerda (mm)",
       main = sprintf("Arco vs cuerda — %s", etq))
  points(d$arco, d$cuerda_geo, pch = 17, col = "#4393C3")
  abline(0, 1, lty = 2, col = "grey40")
  legend("topleft",
         c("Cuerda medida", "Cuerda geométrica", "cuerda = arco (límite)"),
         pch = c(19, 17, NA), lty = c(NA, NA, 2),
         col = c("#D6604D", "#4393C3", "grey40"), bty = "n")
  n_imp <- sum(d$cuerda_med >= d$arco)
  mtext(sprintf("Casos imposibles (medida >= arco): %d de %d", n_imp, nrow(d)),
        side = 3, line = 0.2, cex = 0.85, col = "#D6604D")
  # dev.off()
}
plot_arco_cuerda(h3, "H3 (31-33)", "geo_arco_cuerda_H3.png")
plot_arco_cuerda(h4, "H4 (41-43)", "geo_arco_cuerda_H4.png")

# (b) Boxplot comparativo: arco, cuerda medida y cuerda geométrica.
cmp <- na.omit(data.frame(
  valor = c(h3$arco, h3$cuerda_med, h3$cuerda_geo,
            h4$arco, h4$cuerda_med, h4$cuerda_geo),
  grupo = factor(c(
    rep("H3 arco", nrow(h3)), rep("H3 medida", nrow(h3)), rep("H3 geom.", nrow(h3)),
    rep("H4 arco", nrow(h4)), rep("H4 medida", nrow(h4)), rep("H4 geom.", nrow(h4))),
    levels = c("H3 arco", "H3 medida", "H3 geom.",
               "H4 arco", "H4 medida", "H4 geom."))))

# png(file.path(dir_fig, "geo_boxplot_cuerdas.png"), width = 1100, height = 700, res = 130)
par(mar = c(6, 4.5, 3, 1))
boxplot(valor ~ grupo, data = cmp, las = 2, xlab = "", ylab = "Medida (mm)",
        main = "Arco, cuerda medida y cuerda geométrica",
        col = rep(c("#B2ABD2", "#D6604D", "#4393C3"), 2))
# dev.off()

# cat("Figuras guardadas en", dir_fig, "(geo_*.png)\n")

# --- exportar estimaciones por individuo -------------------------
export <- function(d, hemi) {
  d %>% filter(!is.na(cuerda_geo)) %>% transmute(
    hemiarcada = hemi, ID, fuente, Sexo, Edad, Estatura, Lugar_origen,
    arco = round(arco,3), cuerda_medida = round(cuerda_med,3),
    cuerda_geometrica = round(cuerda_geo,3),
    Tmin_med = round(pmin(cuerda_med,arco)/1000*k_carrea,3),
    Tmax_med = round(pmax(cuerda_med,arco)/1000*k_carrea,3),
    acierto_med = as.integer(Estatura >= pmin(cuerda_med,arco)/1000*k_carrea &
                             Estatura <= pmax(cuerda_med,arco)/1000*k_carrea),
    Tmin_geo = round(pmin(cuerda_geo,arco)/1000*k_carrea,3),
    Tmax_geo = round(pmax(cuerda_geo,arco)/1000*k_carrea,3),
    acierto_geo = as.integer(Estatura >= pmin(cuerda_geo,arco)/1000*k_carrea &
                             Estatura <= pmax(cuerda_geo,arco)/1000*k_carrea))
}
write.csv(bind_rows(export(h3,"H3"), export(h4,"H4")),
          "resultados/estimaciones_cuerda_geometrica.csv", row.names = FALSE)
cat("\nGuardado: resultados/estimaciones_cuerda_geometrica.csv\n")

