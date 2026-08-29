library(dplyr)


# NOTA: datos_unidos.csv fue reemplazado por la base corregida (n=49, sin los
# falsos duplicados). Los resultados diferirán de los del reporte original.
du <- read.csv("resultados/datos_unidos_corregido.csv",
               stringsAsFactors = FALSE, check.names = FALSE)

h4 <- du %>% filter(mm_41 != 0, mm_42 != 0, mm_43 != 0, !is.na(Estatura)) %>%
  mutate(arco = mm_41 + mm_42 + mm_43, cuerda = mm_43_41)

h3 <- du %>% filter(mm_31 != 0, mm_32 != 0, mm_33 != 0, !is.na(Estatura)) %>%
  mutate(arco = mm_31 + mm_32 + mm_33, cuerda = mm_33_31)

# ----------------------------------------------------------------
# Normalidad — Shapiro-Wilk sobre estatura
# Global:    W = 0.9625, p = 0.192  → no se rechaza normalidad
# Femenino:  W = 0.9693, p = 0.443  → no se rechaza normalidad
# Masculino: W = 0.8907, p = 0.279  → no se rechaza normalidad
# ----------------------------------------------------------------

sw_global <- shapiro.test(du$Estatura)
sw_F      <- shapiro.test(du$Estatura[du$Sexo == "F"])
sw_M      <- shapiro.test(du$Estatura[du$Sexo == "M"])

# ----------------------------------------------------------------
# Normalidad y correlación — arco y cuerda
#
# Se evalúa normalidad de arco y cuerda en H3 y H4 para elegir
# entre correlación de Pearson (si ambas son normales) o
# Spearman (si alguna no lo es).
#
# Resultados esperados (actualizar tras ejecutar):
#   H3 arco:   W = 0.99, p = 0.96
#   H3 cuerda: W = 0.97, p = 0.36
#   H4 arco:   W = 0.97, p = 0.49
#   H4 cuerda: W = 0.96, p = 0.077
#
# Si ambas normales → cor.test(..., method = "pearson")
# Si alguna no es normal → cor.test(..., method = "spearman")
#
# Correlación arco-cuerda H3: r/rho = ?, p = ?
# Correlación arco-cuerda H4: r/rho = ?, p = ?
#
# Una correlación alta (|r| > 0.8) confirma colinealidad y
# justifica usar solo el arco en los modelos de regresión.
# ----------------------------------------------------------------

sw_arco_h3   <- shapiro.test(h3$arco)
sw_cuerda_h3 <- shapiro.test(h3$cuerda)
sw_arco_h4   <- shapiro.test(h4$arco)
sw_cuerda_h4 <- shapiro.test(h4$cuerda)
qqnorm(h4$cuerda)
qqline(h4$cuerda)

qqnorm(h3$cuerda)
qqline(h3$cuerda)

metodo_cor_h3 <- ifelse(sw_arco_h3$p.value >= 0.05 & sw_cuerda_h3$p.value >= 0.05,
                        "pearson", "spearman")
metodo_cor_h4 <- ifelse(sw_arco_h4$p.value >= 0.05 & sw_cuerda_h4$p.value >= 0.05,
                        "pearson", "spearman")

cor_h3 <- cor.test(h3$arco, h3$cuerda, method = metodo_cor_h3)
cor_h4 <- cor.test(h4$arco, h4$cuerda, method = metodo_cor_h4)
plot(h3$arco, h3$cuerda)
plot(h4$arco, h4$cuerda)

normalqq <- function(medida, id, umbral = 1.5) {
  qq      <- qqnorm(medida, plot.it = FALSE)
  z_teo   <- qq$x   # cuantiles teóricos
  z_obs   <- qq$y   # cuantiles muestrales
  
  # Residual: desviación vertical respecto a la línea teórica
  # La línea QQ pasa por (Q1_teo, Q1_obs) y (Q3_teo, Q3_obs)
  q25 <- quantile(medida, 0.25, na.rm = TRUE)
  q75 <- quantile(medida, 0.75, na.rm = TRUE)
  z25 <- qnorm(0.25)
  z75 <- qnorm(0.75)
  
  pendiente   <- (q75 - q25) / (z75 - z25)
  intercepto  <- q25 - pendiente * z25
  
  residual    <- z_obs - (intercepto + pendiente * z_teo)
  outlier     <- abs(residual) > umbral * sd(residual, na.rm = TRUE)
  
  # Gráfico
  plot(z_teo, z_obs,
       main = paste("QQ —", deparse(substitute(medida))),
       xlab = "Cuantiles teóricos",
       ylab = "Cuantiles muestrales",
       pch  = ifelse(outlier, 16, 1),
       col  = ifelse(outlier, "tomato", "gray30"))
  abline(a = intercepto, b = pendiente, lty = 2, col = "gray50")
  text(z_teo[outlier], z_obs[outlier], labels = id[outlier],
       pos = 4, cex = 0.8, col = "tomato")
  
  # Devolver IDs de outliers
  return(id[outlier])
}

sw_mm31   <- shapiro.test(h3$mm_31)
sw_mm32   <- shapiro.test(h3$mm_32)
sw_mm33   <- shapiro.test(h3$mm_33)

sw_mm41   <- shapiro.test(h3$mm_41)
sw_mm42   <- shapiro.test(h3$mm_42)
sw_mm43   <- shapiro.test(h3$mm_43)

normalqq(h3$mm_31, h3$ID)
normalqq(h3$mm_32, h3$ID)
normalqq(h3$mm_33, h3$ID)

normalqq(h3$mm_41, h4$ID)
normalqq(h3$mm_42, h4$ID)
normalqq(h3$mm_43, h4$ID)

cor.test(h3$arco, h3$Estatura, method = metodo_cor_h3)
cor.test(h4$cuerda, h4$Estatura, method = metodo_cor_h3)

cor.test(h4$mm_33, h4$Estatura, method = metodo_cor_h3)

plot(h3$arco, h3$Estatura)
plot(h4$arco, h4$Estatura)

plot(h4$mm_33, h4$Estatura)
# ----------------------------------------------------------------
# Enfoque 1: k óptimo por hemiarcada
#
# Modelo de Carrea: T = medida × k / 1000
# Solución analítica: k_opt = Σ(estatura × x) / Σ(x²)
#   donde x = (cuerda + arco) / 2 / 1000
#
# H3: k_carrea=94.25 → RMSE=0.148 m, Precisión=22.0%
#     k_opt=89.05    → RMSE=0.116 m, Precisión=31.7%
#
# H4: k_carrea=94.25 → RMSE=0.160 m, Precisión=12.2%
#     k_opt=88.59    → RMSE=0.124 m, Precisión=26.8%
# ----------------------------------------------------------------

k_carrea <- 30 * pi

calcular_k_opt <- function(estatura, cuerda, arco) {
  x <- (cuerda + arco) / 2 / 1000
  sum(estatura * x) / sum(x^2)
}

calcular_rmse <- function(estatura, cuerda, arco, k) {
  x <- (cuerda + arco) / 2 / 1000
  sqrt(mean((estatura - x * k)^2))
}

calcular_precision <- function(estatura, cuerda, arco, k) {
  tmin <- pmin(cuerda, arco) / 1000 * k
  tmax <- pmax(cuerda, arco) / 1000 * k
  mean(estatura >= tmin & estatura <= tmax) * 100
}

k_opt_h3 <- calcular_k_opt(h3$Estatura, h3$cuerda, h3$arco)
k_opt_h4 <- calcular_k_opt(h4$Estatura, h4$cuerda, h4$arco)

# Estaturas predichas con k óptimo (punto medio del rango)
h3 <- h3 %>%
  mutate(
    T_medio_kopt = (cuerda + arco) / 2 / 1000 * k_opt_h3,
    T_min_kopt   = pmin(cuerda, arco) / 1000 * k_opt_h3,
    T_max_kopt   = pmax(cuerda, arco) / 1000 * k_opt_h3
  )

h4 <- h4 %>%
  mutate(
    T_medio_kopt = (cuerda + arco) / 2 / 1000 * k_opt_h4,
    T_min_kopt   = pmin(cuerda, arco) / 1000 * k_opt_h4,
    T_max_kopt   = pmax(cuerda, arco) / 1000 * k_opt_h4
  )

# ----------------------------------------------------------------
# Boxplot: estaturas predichas (k óptimo) vs reales
# ----------------------------------------------------------------

# pdf("boxplot_kopt_vs_real.pdf", width = 8, height = 6)

datos_box <- data.frame(
  valor = c(h3$Estatura,      h3$T_medio_kopt,
            h4$Estatura,      h4$T_medio_kopt),
  grupo = c(rep("Real H3",    nrow(h3)),
            rep("k-opt H3",   nrow(h3)),
            rep("Real H4",    nrow(h4)),
            rep("k-opt H4",   nrow(h4)))
)

# Orden de grupos para que Real y predicho queden contiguos
datos_box$grupo <- factor(datos_box$grupo,
                          levels = c("Real H3","k-opt H3",
                                     "Real H4","k-opt H4"))

par(mar = c(5, 4, 3, 1))
boxplot(valor ~ grupo, data = datos_box,
        main = "Estatura real vs predicha con k óptimo",
        ylab = "Estatura (m)",
        col  = c("#B2ABD2","#A8C5DA","#F4A582","#FDBB84"),
        las  = 2)
abline(h = mean(du$Estatura, na.rm = TRUE),
       lty = 2, col = "gray50")   # línea de referencia: media muestral

# dev.off()

# ----------------------------------------------------------------
# Enfoque 2a: Regresión con dientes individuales
#
# Modelo: estatura ~ d1 + d2 + d3
# La prueba F evalúa H0: todos los coeficientes = 0.
# p(F) > 0.05 indica que los predictores no aportan poder explicativo.
#
# H3: R²=0.034, R²adj=-0.044, F p=0.728 → no significativo
# H4: R²=0.009, R²adj=-0.071, F p=0.951 → no significativo
# ----------------------------------------------------------------

mod_2a_h4 <- lm(Estatura ~ mm_41 + mm_42 + mm_43, data = h4)
mod_2a_h3 <- lm(Estatura ~ mm_31 + mm_32 + mm_33, data = h3)

s_2a_h3 <- summary(mod_2a_h3)
s_2a_h4 <- summary(mod_2a_h4)

# p-valor de la prueba F global
pF_2a_h3 <- pf(s_2a_h3$fstatistic[1], s_2a_h3$fstatistic[2],
               s_2a_h3$fstatistic[3], lower.tail = FALSE)
pF_2a_h4 <- pf(s_2a_h4$fstatistic[1], s_2a_h4$fstatistic[2],
               s_2a_h4$fstatistic[3], lower.tail = FALSE)

# ----------------------------------------------------------------
# Enfoque 2b: Regresión con arco (modelo global)
#
# Modelo: estatura ~ arco
#
# La prueba F parcial compara este modelo contra el nulo (solo intercepto).
#
# Resultados esperados (actualizar tras ejecutar):
#   H3: R²=?, R²adj=?, p(F)=?
#   H4: R²=?, R²adj=?, p(F)=?
#
# Prueba t de Welch sobre residuales por sexo:
#   H3: t=?, p=?  →  ¿diferencia significativa?
#   H4: t=?, p=?  →  ¿diferencia significativa?
# ----------------------------------------------------------------

mod_2b_h3 <- lm(Estatura ~ arco, data = h3)
mod_2b_h4 <- lm(Estatura ~ arco, data = h4)

s_2b_h3 <- summary(mod_2b_h3)
s_2b_h4 <- summary(mod_2b_h4)

tt_2b_h3 <- t.test(residuals(mod_2b_h3)[h3$Sexo == "F"],
                   residuals(mod_2b_h3)[h3$Sexo == "M"],
                   var.equal = FALSE)

tt_2b_h4 <- t.test(residuals(mod_2b_h4)[h4$Sexo == "F"],
                   residuals(mod_2b_h4)[h4$Sexo == "M"],
                   var.equal = FALSE)

# ----------------------------------------------------------------
# Enfoque 2c: Regresión con arco y sexo como covariable
#
# Modelo: estatura ~ arco + Sexo
# El sexo se incluye para capturar el sesgo sistemático detectado
# en los residuales del Enfoque 2b.
#
# Prueba F parcial (anova): compara modelo sin sexo (2b) vs con sexo (2c)
# H0: incluir Sexo no mejora significativamente el ajuste
#
# Resultados esperados (actualizar tras ejecutar):
#   H3: R²=?, R²adj=?, coef Sexo=?, p Sexo=?, p anova=?
#   H4: R²=?, R²adj=?, coef Sexo=?, p Sexo=?, p anova=?
# ----------------------------------------------------------------

mod_2c_h3 <- lm(Estatura ~ arco + Sexo, data = h3)
mod_2c_h4 <- lm(Estatura ~ arco + Sexo, data = h4)

s_2c_h3 <- summary(mod_2c_h3)
s_2c_h4 <- summary(mod_2c_h4)

plot(h3$,h3$Estatura)
plot(h4$arco,h4$Estatura)

anova_h3 <- anova(mod_2b_h3, mod_2c_h3)   # H0: Sexo no aporta
anova_h4 <- anova(mod_2b_h4, mod_2c_h4)   # H0: Sexo no aporta

