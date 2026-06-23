# ================================================================
# Cuerda teórica geométrica y re-estimación de Carrea
# Servicio Social - Edson André Cortés Silva
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

du <- read.csv("datos_unidos_corregido.csv",
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
  data.frame(
    n          = nrow(d),
    precision  = round(mean(est >= Tmin & est <= Tmax) * 100, 1),
    rmse       = round(sqrt(mean((est - Tprom)^2)), 4),
    r_tprom    = round(suppressWarnings(cor(est, Tprom)), 3),
    cuerda_arco= round(mean(cu / ar), 3),
    imposibles = sum(cu >= ar),
    ancho_cm   = round(mean(Tmax - Tmin) * 100, 1)
  )
}

cat("=== H3: cuerda medida vs geométrica ===\n")
print(rbind(MEDIDA = evalua(h3, "cuerda_med"),
            GEOMETRICA = evalua(h3, "cuerda_geo")))
cat("\n=== H4: cuerda medida vs geométrica ===\n")
print(rbind(MEDIDA = evalua(h4, "cuerda_med"),
            GEOMETRICA = evalua(h4, "cuerda_geo")))

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
          "estimaciones_cuerda_geometrica.csv", row.names = FALSE)
cat("\nGuardado: estimaciones_cuerda_geometrica.csv\n")
