# ================================================================
# Etapa 3 (versión corregida)
# Servicio Social - Edson André Cortés Silva
# ================================================================
# Difiere de Etapa_3.R en dos puntos:
#   (1) Usa la base unificada CORREGIDA (datos_unidos_corregido.csv),
#       sin los 5 falsos duplicados de código de catálogo.
#   (2) Repite todas las estimaciones de Carrea también con una CUERDA
#       TEÓRICA GEOMÉTRICA (ver Cuerda_geometrica.R), además de la medida.
#
# Script autocontenido: define sus propias funciones auxiliares y no
# depende de .RData ni de objetos creados en otros scripts.
# ================================================================

library(dplyr)
library(tidyr)

du <- read.csv("resultados/datos_unidos_corregido.csv",
               stringsAsFactors = FALSE, check.names = FALSE)

k_carrea <- 30 * pi

# ----------------------------------------------------------------
# Funciones auxiliares
# ----------------------------------------------------------------

# Resuelve φ en  sin(φ)/φ = q  (q en (0,1)) por bisección
solve_phi <- function(q) {
  if (is.na(q) || q >= 1) return(NA_real_)
  f  <- function(p) sin(p)/p - q
  lo <- 1e-6; hi <- pi - 1e-6
  for (i in 1:100) { mid <- (lo+hi)/2; if (f(mid) > 0) lo <- mid else hi <- mid }
  (lo + hi) / 2
}

# Cuerda teórica de una hemiarcada (arco_h) dado el arco total y la
# cuerda canino-canino (distancia intercanina) del individuo
cuerda_geo <- function(arco_h, L_full, C_full) {
  phi <- solve_phi(C_full / L_full)
  if (is.na(phi)) return(NA_real_)
  R <- L_full / (2 * phi)
  2 * R * sin((arco_h / R) / 2)
}

# k óptimo (mínimos cuadrados sin intercepto) para el punto medio del rango
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

# ----------------------------------------------------------------
# Limpieza anatómica + construcción de hemiarcadas
#   Incisivo central (41/31): 3.5–6.5 | lateral (42/32): 5.0–7.5 | canino (43/33): 5.5–8.5
# Exclusiones puntuales del documento: ID 26 (mm_43=8.84) de H4,
#   ID 17 (mm_32=4.14) de H3, "sin codigo" (mm_31=8.58) de H3.
# ----------------------------------------------------------------
prep <- function(d, t1, t2, t3, chord, excl_ids, central = NULL) {
  d <- d %>%
    filter(!is.na(.data[[t1]]), !is.na(.data[[t2]]), !is.na(.data[[t3]]),
           .data[[t1]] != 0, .data[[t2]] != 0, .data[[t3]] != 0,
           !is.na(Estatura), !(ID %in% excl_ids))
  if (!is.null(central))
    d <- d %>% filter(!(ID == "sin codigo" & .data[[central]] > 8))
  d %>%
    mutate(arco       = .data[[t1]] + .data[[t2]] + .data[[t3]],
           cuerda_med = .data[[chord]],
           L_full     = (mm_31+mm_32+mm_33) + (mm_41+mm_42+mm_43),
           C_full     = intercanina_inf) %>%
    rowwise() %>%
    mutate(cuerda_geo = cuerda_geo(arco, L_full, C_full)) %>%
    ungroup()
}

h3 <- prep(du, "mm_31","mm_32","mm_33","mm_33_31", c("17"), "mm_31")
h4 <- prep(du, "mm_41","mm_42","mm_43","mm_43_41", c("26"))

cat(sprintf("n corregido -> H3: %d | H4: %d  (base: %d individuos)\n\n",
            nrow(h3), nrow(h4), nrow(du)))

# ----------------------------------------------------------------
# 1. Normalidad (Shapiro-Wilk)
# ----------------------------------------------------------------
sw <- function(x) { t <- shapiro.test(x); sprintf("W=%.3f p=%.3f", t$statistic, t$p.value) }

cat("=== 1. Shapiro-Wilk ===\n")
cat("Estatura global :", sw(du$Estatura), "\n")
cat("Estatura F      :", sw(du$Estatura[du$Sexo=="F"]), "\n")
cat("Estatura M      :", sw(du$Estatura[du$Sexo=="M"]), "\n")
cat("Arco H3         :", sw(h3$arco), "  Cuerda(med) H3:", sw(h3$cuerda_med), "\n")
cat("Arco H4         :", sw(h4$arco), "  Cuerda(med) H4:", sw(h4$cuerda_med), "\n")
cat("Cuerda(geo) H3  :", sw(h3$cuerda_geo[!is.na(h3$cuerda_geo)]), "\n")
cat("Cuerda(geo) H4  :", sw(h4$cuerda_geo[!is.na(h4$cuerda_geo)]), "\n\n")

# ----------------------------------------------------------------
# 2. Correlación arco–cuerda
# ----------------------------------------------------------------
cat("=== 2. Correlación arco–cuerda (Pearson) ===\n")
c3 <- cor.test(h3$arco, h3$cuerda_med); c4 <- cor.test(h4$arco, h4$cuerda_med)
cat(sprintf("H3: r=%.3f IC[%.3f,%.3f] p=%.4f\n", c3$estimate, c3$conf.int[1], c3$conf.int[2], c3$p.value))
cat(sprintf("H4: r=%.3f IC[%.3f,%.3f] p=%.4f\n\n", c4$estimate, c4$conf.int[1], c4$conf.int[2], c4$p.value))

# ----------------------------------------------------------------
# 3 y 4. Carrea: cuerda MEDIDA vs GEOMÉTRICA, k Carrea y k óptimo
# ----------------------------------------------------------------
metricas <- function(d, chord_col, k, label) {
  d  <- d %>% filter(!is.na(.data[[chord_col]]))
  cu <- d[[chord_col]]; ar <- d$arco; est <- d$Estatura
  Tmin <- pmin(cu,ar)/1000*k; Tmax <- pmax(cu,ar)/1000*k; Tprom <- (Tmin+Tmax)/2
  data.frame(
    modelo     = label,
    n          = nrow(d),
    precision  = round(mean(est>=Tmin & est<=Tmax)*100,1),
    rmse       = round(sqrt(mean((est-Tprom)^2)),4),
    r_tmin     = round(suppressWarnings(cor(est,Tmin)),3),
    r_tprom    = round(suppressWarnings(cor(est,Tprom)),3),
    r_tmax     = round(suppressWarnings(cor(est,Tmax)),3),
    cuerda_arco= round(mean(cu/ar),3),
    imposibles = sum(cu>=ar)
  )
}

cat("=== 3. Carrea original (k=30π) y comparación de cuerdas ===\n")
tabla3 <- bind_rows(
  metricas(h3, "cuerda_med", k_carrea, "H3 medida"),
  metricas(h3, "cuerda_geo", k_carrea, "H3 geométrica"),
  metricas(h4, "cuerda_med", k_carrea, "H4 medida"),
  metricas(h4, "cuerda_geo", k_carrea, "H4 geométrica")
)
print(tabla3, row.names = FALSE)

cat("\n=== 4. k óptimo por hemiarcada (cuerda medida y geométrica) ===\n")
ko_tab <- function(d, chord_col, etq) {
  d  <- d %>% filter(!is.na(.data[[chord_col]]))
  ko <- calcular_k_opt(d$Estatura, d[[chord_col]], d$arco)
  data.frame(
    caso          = etq,
    k_carrea      = round(k_carrea,2),
    k_opt         = round(ko,2),
    prec_k_carrea = calcular_precision(d$Estatura, d[[chord_col]], d$arco, k_carrea),
    prec_k_opt    = calcular_precision(d$Estatura, d[[chord_col]], d$arco, ko),
    rmse_k_opt    = calcular_rmse(d$Estatura, d[[chord_col]], d$arco, ko)
  )
}
print(bind_rows(
  ko_tab(h3,"cuerda_med","H3 medida"), ko_tab(h3,"cuerda_geo","H3 geométrica"),
  ko_tab(h4,"cuerda_med","H4 medida"), ko_tab(h4,"cuerda_geo","H4 geométrica")
), row.names = FALSE)

# ----------------------------------------------------------------
# 5a. Regresión: dientes individuales
# ----------------------------------------------------------------
cat("\n=== 5a. estatura ~ dientes individuales ===\n")
m3 <- lm(Estatura ~ mm_31 + mm_32 + mm_33, data = h3)
m4 <- lm(Estatura ~ mm_41 + mm_42 + mm_43, data = h4)
resumen_lm <- function(m, etq) {
  s <- summary(m); f <- s$fstatistic
  data.frame(modelo = etq,
             R2 = round(s$r.squared,3), R2_adj = round(s$adj.r.squared,3),
             p_F = round(pf(f[1], f[2], f[3], lower.tail = FALSE), 4))
}
print(bind_rows(resumen_lm(m3,"H3 dientes"), resumen_lm(m4,"H4 dientes")), row.names = FALSE)

# ----------------------------------------------------------------
# 5b. Regresión: arco + sexo
# ----------------------------------------------------------------
cat("\n=== 5b. estatura ~ arco + sexo ===\n")
mb3 <- lm(Estatura ~ arco + Sexo, data = h3)
mb4 <- lm(Estatura ~ arco + Sexo, data = h4)
detalle_lm <- function(m, etq) {
  s <- summary(m); f <- s$fstatistic; co <- coef(s)
  data.frame(modelo = etq,
             R2 = round(s$r.squared,3), R2_adj = round(s$adj.r.squared,3),
             p_arco = round(co["arco","Pr(>|t|)"],4),
             p_sexo = round(co[grep("Sexo", rownames(co)),"Pr(>|t|)"][1],4),
             p_F = round(pf(f[1], f[2], f[3], lower.tail = FALSE), 4))
}
print(bind_rows(detalle_lm(mb3,"H3 arco+sexo"), detalle_lm(mb4,"H4 arco+sexo")), row.names = FALSE)

# 5b'. Variante con cuerda geométrica como predictor dental
cat("\n=== 5b'. estatura ~ cuerda_geo + sexo ===\n")
mg3 <- lm(Estatura ~ cuerda_geo + Sexo, data = h3 %>% filter(!is.na(cuerda_geo)))
mg4 <- lm(Estatura ~ cuerda_geo + Sexo, data = h4 %>% filter(!is.na(cuerda_geo)))
detalle_geo <- function(m, etq) {
  s <- summary(m); co <- coef(s)
  data.frame(modelo = etq, R2 = round(s$r.squared,3), R2_adj = round(s$adj.r.squared,3),
             p_cuerda_geo = round(co["cuerda_geo","Pr(>|t|)"],4),
             p_sexo = round(co[grep("Sexo", rownames(co)),"Pr(>|t|)"][1],4))
}
print(bind_rows(detalle_geo(mg3,"H3"), detalle_geo(mg4,"H4")), row.names = FALSE)

# ----------------------------------------------------------------
# 5c. Dimorfismo sexual (t de Student independiente)
# ----------------------------------------------------------------
cat("\n=== 5c. Dimorfismo sexual ===\n")
tt <- t.test(Estatura ~ Sexo, data = du)
cat(sprintf("Media F=%.3f  Media M=%.3f  dif=%.1f cm  t=%.2f  p=%.4f\n",
            tt$estimate[1], tt$estimate[2],
            (tt$estimate[2]-tt$estimate[1])*100, tt$statistic, tt$p.value))
cat(sprintf("Spearman(sexo, estatura): rho=%.3f p=%.4f\n",
            cor(as.integer(du$Sexo=="M"), du$Estatura, method="spearman"),
            cor.test(as.integer(du$Sexo=="M"), du$Estatura, method="spearman")$p.value))

# ----------------------------------------------------------------
# Exportar tabla resumen de Carrea (medida vs geométrica)
# ----------------------------------------------------------------
write.csv(tabla3, "resultados/resultados_carrea_corregido.csv", row.names = FALSE)
cat("\nGuardado: resultados/resultados_carrea_corregido.csv\n")
