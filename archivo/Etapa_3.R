# ================================================================
# Limpieza de outliers y análisis inferencial
# Servicio Social - Edson André Cortés Silva
# ================================================================

library(dplyr)
library(tidyr)

# ----------------------------------------------------------------
# Datos
# ----------------------------------------------------------------

# NOTA: datos_unidos.csv fue reemplazado por la base corregida (n=49, sin los
# falsos duplicados). Los resultados diferirán de los del reporte original.
# Para la versión vigente de este análisis ver ../Etapa_3_corregido.R
du <- read.csv("resultados/datos_unidos_corregido.csv",
               stringsAsFactors = FALSE, check.names = FALSE)

# ----------------------------------------------------------------
# Limpieza de outliers anatómicamente imposibles
#
# Criterio: valores fuera del rango anatómico de referencia para
# dientes permanentes inferiores en adultos:
#   Incisivo central (41/31): 3.5 – 6.5 mm
#   Incisivo lateral (42/32): 5.0 – 7.5 mm
#   Canino           (43/33): 5.5 – 8.5 mm
#
# Casos eliminados:
#   ID 26   → mm_43 = 8.84 mm (canino H3 supera límite anatómico)
#             se excluye solo de H3; no afecta H4
#   sin codigo → mm_31 = 8.58 mm (incisivo central H4 imposible)
#             W = 0.77 en mm_31, el peor Shapiro-Wilk del dataset
#             se excluye solo de H4; no afecta H3
#   ID 17   → mm_32 = 4.14 mm (incisivo lateral H4 bajo límite)
#             se excluye solo de H4
#
# ID 130 conservado: valores extremos pero anatómicamente plausibles
# y consistentes en todas sus piezas (individuo con dientes grandes).
# Outliers de cuerda (IDs 2, 4, 21, 22, 76) conservados: dentro del
# rango anatómico de 13–22 mm, representan variabilidad real.
# ----------------------------------------------------------------

h4 <- du %>%
  filter(mm_41 != 0, mm_42 != 0, mm_43 != 0, !is.na(Estatura)) %>%
  filter(!(ID == "26")) %>%                        # mm_43 = 8.84
  mutate(arco = mm_41 + mm_42 + mm_43, cuerda = mm_43_41)

h3 <- du %>%
  filter(mm_31 != 0, mm_32 != 0, mm_33 != 0, !is.na(Estatura)) %>%
  filter(!(ID == "sin codigo" & mm_31 > 8)) %>%   # mm_31 = 8.58
  filter(!(ID == "17")) %>%                        # mm_32 = 4.14
  mutate(arco = mm_31 + mm_32 + mm_33, cuerda = mm_33_31)

# ----------------------------------------------------------------
# 1. Verificación de normalidad — Shapiro-Wilk
#
# Se evalúa la normalidad de:
#   a) Estatura real (global y por sexo)
#   b) Medidas dentales individuales tras limpieza
#   c) Arco y cuerda por hemiarcada
#   d) Diferencias entre estatura real y estimada (Tmin, Tprom, Tmax)
#      — estas últimas se calculan tras aplicar el método de Carrea
#
# Criterio: p >= 0.05 → no se rechaza normalidad → pruebas paramétricas
#           p <  0.05 → se rechaza normalidad    → pruebas no paramétricas
# ----------------------------------------------------------------
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


# a) Estatura real
sw_estatura        <- shapiro.test(du$Estatura)
sw_estatura_F      <- shapiro.test(du$Estatura[du$Sexo == "F"])
sw_estatura_M      <- shapiro.test(du$Estatura[du$Sexo == "M"])

# b) Medidas dentales individuales (tras limpieza)
sw_mm41 <- shapiro.test(h3$mm_41)
sw_mm42 <- shapiro.test(h3$mm_42)
sw_mm43 <- shapiro.test(h3$mm_43)
sw_mm31 <- shapiro.test(h4$mm_31)
sw_mm32 <- shapiro.test(h4$mm_32)
sw_mm33 <- shapiro.test(h4$mm_33)

normalqq(h3$mm_31, h3$ID)
normalqq(h4$mm_42, h4$ID)

# c) Arco y cuerda — determina el método de correlación a usar
sw_arco_h3   <- shapiro.test(h3$arco)
sw_cuerda_h3 <- shapiro.test(h3$cuerda)
sw_arco_h4   <- shapiro.test(h4$arco)
sw_cuerda_h4 <- shapiro.test(h4$cuerda)

normalqq(h4$cuerda, h4$ID)
normalqq(h4$arco, h4$ID)

metodo_cor_h3 <- ifelse(sw_arco_h3$p.value   >= 0.05 &
                          sw_cuerda_h3$p.value >= 0.05,
                        "pearson", "spearman")
metodo_cor_h4 <- ifelse(sw_arco_h4$p.value   >= 0.05 &
                          sw_cuerda_h4$p.value >= 0.05,
                        "pearson", "spearman")

cor_h3 <- cor.test(h3$arco, h3$cuerda, method = metodo_cor_h3)
cor_h4 <- cor.test(h4$arco, h4$cuerda, method = metodo_cor_h4)

plot(h3$arco, h3$cuerda,       
     main = paste("Cuerda - Arco 3"),
     xlab = "Arco",
     ylab = "Cuerda")
plot(h4$arco, h4$cuerda,
     main = paste("Cuerda - Arco 4"),
     xlab = "Arco",
     ylab = "Cuerda")

# ----------------------------------------------------------------
# Método de Carrea — cálculo de Tmin, Tprom, Tmax
#
# T = medida × k / 1000  (resultado en metros)
# k_carrea = 30π ≈ 94.25
# Cuando cuerda > arco por error de medición: usar min/max
# ----------------------------------------------------------------

k_carrea <- 30 * pi

h3 <- h3 %>%
  mutate(
    Tmin  = pmin(cuerda, arco) / 1000 * k_carrea,
    Tmax  = pmax(cuerda, arco) / 1000 * k_carrea,
    Tprom = (Tmin + Tmax) / 2
  )
normalqq(h3$Tmin, h3$ID)

h4 <- h4 %>%
  mutate(
    Tmin  = pmin(cuerda, arco) / 1000 * k_carrea,
    Tmax  = pmax(cuerda, arco) / 1000 * k_carrea,
    Tprom = (Tmin + Tmax) / 2
  )

# d) Normalidad de diferencias (estatura real − estimada)
# Necesaria para elegir entre t pareada vs Wilcoxon en el paso siguiente
sw_estatura_h3  <- shapiro.test(h3$Estatura)
sw_tmin_h3 <- shapiro.test(h3$Tmin)
sw_tmax_h3  <- shapiro.test(h3$Tmax)

sw_estatura_h4  <- shapiro.test(h4$Estatura)
sw_tmin_h4 <- shapiro.test(h4$Tmin)
sw_tmax_h4  <- shapiro.test(h4$Tmax)

# ----------------------------------------------------------------
# 2. Correlación: estatura real vs Tmin, Tprom, Tmax
#
# Se usa Pearson si las diferencias son normales, Spearman si no.
# Cuantifica asociación lineal pero no concordancia.
# La concordancia se evaluará posteriormente con el índice de Lin.
# ----------------------------------------------------------------

# Método según normalidad de las diferencias en cada hemiarcada
metodo_h3 <- ifelse(all(sw_tmin_h3$p.value >= 0.05),
                    "pearson", "spearman")

metodo_h4 <- ifelse(all(sw_tmin_h4$p.value >= 0.05),
                    "pearson", "spearman")

cor_tmin_h3  <- cor.test(h3$Estatura, h3$Tmin,  method = metodo_h3)
plot(h3$Estatura, h3$Tmin,
     main = "Estatura real vs Tmin 3",
     xlab = "Estatura real",
     ylab = "Tmin 3")

plot(h4$Estatura, h4$Tmin,
     main = "Estatura real vs Tmin 4",
     xlab = "Estatura real",
     ylab = "Tmin 4")

plot(h3$Estatura, h3$Tmax,
     main = "Estatura real vs Tmax 3",
     xlab = "Estatura real",
     ylab = "Tmin 3")

plot(h4$Estatura, h4$Tmax,
     main = "Estatura real vs Tmax 4",
     xlab = "Estatura real",
     ylab = "Tmin 4")



cor_tprom_h3 <- cor.test(h3$Estatura, h3$Tprom, method = metodo_h3)
cor_tmax_h3  <- cor.test(h3$Estatura, h3$Tmax,  method = metodo_h3)

cor_tmin_h4  <- cor.test(h4$Estatura, h4$Tmin,  method = metodo_h4)
cor_tprom_h4 <- cor.test(h4$Estatura, h4$Tprom, method = metodo_h4)
cor_tmax_h4  <- cor.test(h4$Estatura, h4$Tmax,  method = metodo_h4)

# Correlaciones totalmente irreleventes usando carrea, esto prueba la ineficiencia 
# del método para estimar la estatura de nuestra muestra.

# ----------------------------------------------------------------
# Métricas de evaluación del método de Carrea
# Precisión, RMSE y correlación de Pearson para H3 y H4
# ----------------------------------------------------------------

calcular_metricas <- function(data, label) {
  
  # Precisión: % de individuos con estatura real dentro de [Tmin, Tmax]
  precision <- mean(data$Estatura >= data$Tmin &
                      data$Estatura <= data$Tmax, na.rm = TRUE) * 100
  
  # RMSE: entre estatura real y punto medio del rango predicho
  rmse <- sqrt(mean((data$Estatura - data$Tprom)^2, na.rm = TRUE))
  
  # Correlación de Pearson: estatura real vs Tprom
  # (ambas variables son normales según Shapiro-Wilk)
  cor_tmin  <- cor.test(data$Estatura, data$Tmin,  method = "pearson")
  cor_tprom <- cor.test(data$Estatura, data$Tprom, method = "pearson")
  cor_tmax  <- cor.test(data$Estatura, data$Tmax,  method = "pearson")
  
  list(
    label     = label,
    n         = nrow(data),
    precision = round(precision, 1),
    rmse      = round(rmse, 4),
    r_tmin    = round(cor_tmin$estimate,  4),
    p_tmin    = round(cor_tmin$p.value,   4),
    r_tprom   = round(cor_tprom$estimate, 4),
    p_tprom   = round(cor_tprom$p.value,  4),
    r_tmax    = round(cor_tmax$estimate,  4),
    p_tmax    = round(cor_tmax$p.value,   4)
  )
}

met_h3 <- calcular_metricas(h3, "H3 (31-33)")
met_h4 <- calcular_metricas(h4, "H4 (41-43)")


# ----------------------------------------------------------------
# ANOVA de medidas repetidas
#
# Cada individuo aporta 4 mediciones: Estatura, Tmin, Tprom, Tmax.
# El ANOVA de medidas repetidas descompone:
#   SC_total = SC_entre condiciones + SC_entre sujetos + SC_error residual
#
# Al extraer SC_entre sujetos el error residual se reduce, produciendo
# un estadístico F más sensible que el ANOVA clásico.
#
# H0: µ_real = µ_Tmin = µ_Tprom = µ_Tmax
# H1: al menos una media difiere
# Se rechaza H0 si p < 0.05
#
# Supuestos verificados:
#   - Normalidad de diferencias: Shapiro-Wilk (arriba)
#   - Esfericidad: prueba de Mauchly
#     Si se viola → corrección de Greenhouse-Geisser
#   - Ausencia de outliers extremos: revisada en la limpieza
#
# Nota: se usa aov() con Error(ID/condicion) para el modelo de
# medidas repetidas en R base. Se requiere formato largo.
# ----------------------------------------------------------------

# ----------------------------------------------------------------
# ANOVA de medidas repetidas — sin Tprom
#
# Tprom = (Tmin + Tmax) / 2 es combinación lineal exacta de Tmin
# y Tmax, lo que hace singular la matriz de covarianzas y produce
# NaN en log(det(U)) de la prueba de Mauchly.
# Se excluye Tprom y se trabaja con 3 condiciones: Estatura, Tmin, Tmax.
# Con 3 condiciones solo hay 2 diferencias posibles (Estatura-Tmin,
# Estatura-Tmax, Tmin-Tmax) y la prueba de esfericidad es evaluable.
# Si el ANOVA resulta significativo, el post hoc identificará cuál
# estimación es indistinguible de la estatura real.
# ----------------------------------------------------------------

h3_largo <- h3 %>%
  select(ID, Estatura, Tmin, Tmax) %>%
  mutate(sujeto = row_number()) %>%
  pivot_longer(cols      = c(Estatura, Tmin, Tmax),
               names_to  = "condicion",
               values_to = "valor") %>%
  mutate(condicion = factor(condicion,
                            levels = c("Estatura","Tmin","Tmax")),
         sujeto    = factor(sujeto))

h4_largo <- h4 %>%
  select(ID, Estatura, Tmin, Tmax) %>%
  mutate(sujeto = row_number()) %>%
  pivot_longer(cols      = c(Estatura, Tmin, Tmax),
               names_to  = "condicion",
               values_to = "valor") %>%
  mutate(condicion = factor(condicion,
                            levels = c("Estatura","Tmin","Tmax")),
         sujeto    = factor(sujeto))

ez_h3 <- ezANOVA(data       = h3_largo,
                 dv         = valor,
                 wid        = sujeto,
                 within     = condicion,
                 type       = 3,
                 return_aov = TRUE)

ez_h4 <- ezANOVA(data       = h4_largo,
                 dv         = valor,
                 wid        = sujeto,
                 within     = condicion,
                 type       = 3,
                 return_aov = TRUE)

# ez_h3$`Mauchly's Test of Sphericity`  → p < 0.05 indica violación
# ez_h3$`Sphericity Corrections`        → corrección GG si aplica
# ez_h3$ANOVA                           → F, p, ges


# k óptimo con el dataset actualizado
k_opt_h3 <- calcular_k_opt(h3$Estatura, h3$cuerda, h3$arco)
k_opt_h4 <- calcular_k_opt(h4$Estatura, h4$cuerda, h4$arco)

calcular_precision(h3$Estatura, h3$cuerda, h3$arco, k_opt_h3)
calcular_precision(h3$Estatura, h3$cuerda, h3$arco, k_carrea)
calcular_precision(h4$Estatura, h4$cuerda, h4$arco, k_opt_h4)
calcular_precision(h4$Estatura, h4$cuerda, h4$arco, k_carrea)
calcular_rmse(h3$Estatura, h3$cuerda, h3$arco, k_opt_h3)
calcular_rmse(h4$Estatura, h4$cuerda, h4$arco, k_opt_h4)
calcular_rmse(h3$Estatura, h3$cuerda, h3$arco, k_carrea)
calcular_rmse(h4$Estatura, h4$cuerda, h4$arco, k_carrea)

# Coeficientes del modelo lineal
coef(summary(mod_2c_h3))
coef(summary(mod_2c_h4))
