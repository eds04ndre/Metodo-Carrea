# ================================================================
# Funciones compartidas — método de Carrea (Etapa 4)
# ================================================================
# Centraliza lo que en la Etapa 3 estaba triplicado casi idéntico en
# Cuerda_geometrica.R, Analisis_aciertos.R y Etapa_3_corregido.R
# (ver archivo/), y lo generaliza de 2 a 4 hemiarcadas: además de las
# mandibulares H3 (33-31) y H4 (43-41), añade las maxilares H1 (13-11)
# y H2 (23-21), presentes en data/Datos_estatura130.xlsx.
#
# Se espera que el data.frame de entrada tenga las columnas producidas
# por Union_datos130.R: mm_11..mm_43 (dientes), mm_13_11/mm_23_21 (cuerda
# maxilar medida), mm_33_31/mm_43_41 (cuerda mandibular medida),
# intercanina_sup, intercanina_inf, Estatura, ID, Sexo, Edad, Origen.
# ================================================================

k_carrea <- 30 * pi

# Definición de las hemiarcadas que entran al análisis de Carrea: el
# método se define y calibra sobre la arcada mandibular anterior, así que
# solo se usan H3 (33-31) y H4 (43-41). Las hemiarcadas maxilares (H1
# 13-11, H2 23-21) quedan fuera del análisis de Carrea (ver
# Confiabilidad_130.R para su uso en el análisis de consistencia entre
# observadores, donde sí se incluyen todos los dientes medidos).
HEMIARCADAS <- list(
  H3 = list(t1 = "mm_31", t2 = "mm_32", t3 = "mm_33", chord = "mm_33_31", arcada = "inf"),
  H4 = list(t1 = "mm_41", t2 = "mm_42", t3 = "mm_43", chord = "mm_43_41", arcada = "inf")
)

# Rangos anatómicos de referencia (mm), tomados de archivo/Estatura.R.
RANGOS_ANATOMICOS <- list(
  mm_11 = c(7, 10.6), mm_12 = c(5.2, 9.2), mm_13 = c(6, 10),
  mm_21 = c(7, 10.6), mm_22 = c(5.2, 9.2), mm_23 = c(6, 10),
  mm_31 = c(4.1, 6.8), mm_32 = c(4.7, 7.8), mm_33 = c(5.4, 9),
  mm_41 = c(4.1, 6.8), mm_42 = c(4.7, 7.8), mm_43 = c(5.4, 9)
)

# Tolerancia: una medida que se desvía del rango de referencia por menos de
# esto NO cuenta como outlier (variabilidad interobservador normal); solo
# se marca cuando la desviación es mayor, es decir, cuando el valor es
# anatómicamente inverosímil.
TOLERANCIA_RANGO <- 0.5  # mm

# ----------------------------------------------------------------
# Cuerda teórica geométrica (modelo de arco circular; ver
# archivo/Cuerda_geometrica.R para la derivación completa)
# ----------------------------------------------------------------

# Resuelve φ en sin(φ)/φ = q (q en (0,1)) por bisección.
solve_phi <- function(q) {
  if (is.na(q) || q <= 0 || q >= 1) return(NA_real_)
  f  <- function(p) sin(p) / p - q
  lo <- 1e-6; hi <- pi - 1e-6
  for (i in 1:100) { mid <- (lo + hi) / 2; if (f(mid) > 0) lo <- mid else hi <- mid }
  (lo + hi) / 2
}

# Cuerda teórica de una hemiarcada (arco_h) dado el arco total (L_full) y
# la cuerda canino-canino (C_full) de la arcada completa a la que pertenece.
cuerda_geo <- function(arco_h, L_full, C_full) {
  phi <- solve_phi(C_full / L_full)
  if (is.na(phi)) return(NA_real_)
  R <- L_full / (2 * phi)
  2 * R * sin((arco_h / R) / 2)
}

# ----------------------------------------------------------------
# Preparación de una hemiarcada: arco, cuerda medida y cuerda geométrica.
#
#   d      : data.frame con columnas mm_11..mm_43, intercanina_sup/inf, Estatura
#   hemi   : nombre en HEMIARCADAS ("H1".."H4")
#   flaggear_rango : si TRUE (default), añade columna lógica `en_rango`
#                     marcando valores fuera de RANGOS_ANATOMICOS SIN excluir
#                     filas (con 3 observadores y 130 individuos se espera
#                     variabilidad natural; excluir de más resta potencia).
# ----------------------------------------------------------------
prep_hemiarcada <- function(d, hemi, flaggear_rango = TRUE) {
  h <- HEMIARCADAS[[hemi]]
  t1 <- h$t1; t2 <- h$t2; t3 <- h$t3; chord <- h$chord

  if (h$arcada == "sup") {
    L_full_expr <- quote(mm_11 + mm_12 + mm_13 + mm_21 + mm_22 + mm_23)
    C_full_col  <- "intercanina_sup"
  } else {
    L_full_expr <- quote(mm_31 + mm_32 + mm_33 + mm_41 + mm_42 + mm_43)
    C_full_col  <- "intercanina_inf"
  }

  d <- d %>%
    dplyr::filter(!is.na(.data[[t1]]), !is.na(.data[[t2]]), !is.na(.data[[t3]]),
                  !is.na(.data[[chord]]), !is.na(Estatura)) %>%
    dplyr::mutate(arco       = .data[[t1]] + .data[[t2]] + .data[[t3]],
                   cuerda_med = .data[[chord]],
                   L_full     = eval(L_full_expr),
                   C_full     = .data[[C_full_col]]) %>%
    dplyr::rowwise() %>%
    dplyr::mutate(cuerda_geo = cuerda_geo(arco, L_full, C_full)) %>%
    dplyr::ungroup()

  if (flaggear_rango) {
    rng1 <- RANGOS_ANATOMICOS[[t1]]; rng2 <- RANGOS_ANATOMICOS[[t2]]; rng3 <- RANGOS_ANATOMICOS[[t3]]
    tol  <- TOLERANCIA_RANGO
    d <- d %>% dplyr::mutate(
      en_rango = .data[[t1]] >= rng1[1] - tol & .data[[t1]] <= rng1[2] + tol &
                 .data[[t2]] >= rng2[1] - tol & .data[[t2]] <= rng2[2] + tol &
                 .data[[t3]] >= rng3[1] - tol & .data[[t3]] <= rng3[2] + tol)
  }
  d
}

# ----------------------------------------------------------------
# Métricas de Carrea (idénticas a la Etapa 3, genéricas por vector)
# ----------------------------------------------------------------

# k óptimo (mínimos cuadrados sin intercepto) para el punto medio del rango.
calcular_k_opt <- function(est, cuerda, arco) {
  x <- (cuerda + arco) / 2000
  sum(est * x) / sum(x^2)
}

calcular_precision <- function(est, cuerda, arco, k) {
  Tmin <- pmin(cuerda, arco) / 1000 * k
  Tmax <- pmax(cuerda, arco) / 1000 * k
  round(mean(est >= Tmin & est <= Tmax) * 100, 1)
}

calcular_rmse <- function(est, cuerda, arco, k) {
  Tprom <- (pmin(cuerda, arco) + pmax(cuerda, arco)) / 2000 * k
  round(sqrt(mean((est - Tprom)^2)), 4)
}

# Tabla resumen de un modelo de Carrea ya preparado (arco/Estatura/chord_col).
metricas <- function(d, chord_col, k = k_carrea, label) {
  d  <- d %>% dplyr::filter(!is.na(.data[[chord_col]]))
  cu <- d[[chord_col]]; ar <- d$arco; est <- d$Estatura
  Tmin <- pmin(cu, ar) / 1000 * k; Tmax <- pmax(cu, ar) / 1000 * k; Tprom <- (Tmin + Tmax) / 2
  data.frame(
    modelo      = label,
    n           = nrow(d),
    precision   = round(mean(est >= Tmin & est <= Tmax) * 100, 1),
    rmse        = round(sqrt(mean((est - Tprom)^2)), 4),
    r_tmin      = round(suppressWarnings(cor(est, Tmin)), 3),
    r_tprom     = round(suppressWarnings(cor(est, Tprom)), 3),
    r_tmax      = round(suppressWarnings(cor(est, Tmax)), 3),
    cuerda_arco = round(mean(cu / ar), 3),
    imposibles  = sum(cu >= ar)
  )
}
