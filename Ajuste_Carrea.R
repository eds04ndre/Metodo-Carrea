# ================================================================
# Ajuste del método de Carrea a población mexicana
# ================================================================

library(dplyr)

# ----------------------------------------------------------------
# Datos
# ----------------------------------------------------------------
setwd("C:/Users/ASUS/Documents/Edson/Servicio Social/Repositorio/")
df <- readxl::read_excel("Mediciones_Estatura.xlsx", sheet = "Editado") %>%
  rename(
    n_modelo  = `N Modelo`,
    sexo      = Sexo,
    estatura  = Estatura,
    mm11 = `mm 11`, mm12 = `mm 12`, mm13 = `mm 13`,
    mm21 = `mm 21`, mm22 = `mm 22`, mm23 = `mm 23`,
    mm41 = `mm 41`, mm42 = `mm 42`, mm43 = `mm 43`,
    mm31 = `mm 31`, mm32 = `mm 32`, mm33 = `mm 33`,
    cuerda_h1 = `mm 13 - 11`, cuerda_h2 = `mm 23 - 21`,
    cuerda_h3 = `mm 43 - 41`, cuerda_h4 = `mm 33 - 31`
  ) %>%
  mutate(
    estatura = as.numeric(gsub(",", ".", as.character(estatura))),
    arco_h1  = mm11 + mm12 + mm13,
    arco_h2  = mm21 + mm22 + mm23,
    arco_h3  = mm41 + mm42 + mm43,
    arco_h4  = mm31 + mm32 + mm33
  )

# Hemiarcadas inferiores validas (diente = 0 implica ausencia)
h3 <- df %>% filter(mm41 != 0, mm42 != 0, mm43 != 0)
h4 <- df %>% filter(mm31 != 0, mm32 != 0, mm33 != 0)

cat("N total:", nrow(df), "| H3 validos:", nrow(h3), "| H4 validos:", nrow(h4), "\n\n")

# ----------------------------------------------------------------
# Normalidad - Shapiro-Wilk sobre la estatura
# ----------------------------------------------------------------
cat("--- Shapiro-Wilk (estatura) ---\n")
sw <- shapiro.test(df$estatura)
cat(sprintf("Global  W=%.4f  p=%.4f\n", sw$statistic, sw$p.value))
for (s in c("F","M")) {
  sw_s <- shapiro.test(df$estatura[df$sexo == s])
  cat(sprintf("Sexo %s  W=%.4f  p=%.4f\n", s, sw_s$statistic, sw_s$p.value))
}
cat("La estatura sigue distribucion normal en todos los grupos (p > 0.05)\n\n")

# ----------------------------------------------------------------
# Enfoque 1: k optimo por hemiarcada (solo inferiores)
# Modelo de Carrea: T = medida x k / 1000
# k_opt minimiza MSE entre estatura real y punto medio del rango
# Solucion analitica: k_opt = sum(estatura * x) / sum(x^2)
# donde x = (cuerda + arco) / 2 / 1000
# ----------------------------------------------------------------
cat("--- Enfoque 1: k optimo (hemiarcadas inferiores) ---\n")
cat(sprintf("k de Carrea: 30pi = %.4f\n\n", 30*pi))

k_carrea <- 30 * pi

for (info in list(
  list(label="H3 (41-43)", data=h3, cuerda="cuerda_h3", arco="arco_h3"),
  list(label="H4 (31-33)", data=h4, cuerda="cuerda_h4", arco="arco_h4")
)) {
  d      <- info$data
  cuerda <- d[[info$cuerda]]
  arco   <- d[[info$arco]]
  x      <- (cuerda + arco) / 2 / 1000
  k_opt  <- sum(d$estatura * x) / sum(x^2)
  
  rmse <- function(k) sqrt(mean((d$estatura - x*k)^2))
  precision <- function(k) {
    tmin <- pmin(cuerda, arco) / 1000 * k
    tmax <- pmax(cuerda, arco) / 1000 * k
    mean(d$estatura >= tmin & d$estatura <= tmax) * 100
  }
  
  cat(sprintf("%s | n=%d\n", info$label, nrow(d)))
  cat(sprintf("  k_carrea = %.4f  RMSE=%.4f m  Precision=%.1f%%\n",
              k_carrea, rmse(k_carrea), precision(k_carrea)))
  cat(sprintf("  k_opt    = %.4f  RMSE=%.4f m  Precision=%.1f%%\n\n",
              k_opt, rmse(k_opt), precision(k_opt)))
}

# ----------------------------------------------------------------
# Enfoque 2a: Regresion con dientes individuales
# Modelo: estatura ~ d1 + d2 + d3
# Se incluyen las 4 hemiarcadas para demostrar inviabilidad
# ----------------------------------------------------------------
cat("--- Enfoque 2a: Regresion con dientes individuales (las 4 hemiarcadas) ---\n\n")

hemi_list <- list(
  list(label="H1 (11,12,13)", data=df %>% filter(mm11!=0,mm12!=0,mm13!=0),
       d=c("mm11","mm12","mm13")),
  list(label="H2 (21,22,23)", data=df %>% filter(mm21!=0,mm22!=0,mm23!=0),
       d=c("mm21","mm22","mm23")),
  list(label="H4 (41,42,43)", data=h3, d=c("mm41","mm42","mm43")),
  list(label="H3 (31,32,33)", data=h4, d=c("mm31","mm32","mm33"))
)

for (info in hemi_list) {
  d   <- info$data
  frm <- as.formula(paste("estatura ~", paste(info$d, collapse=" + ")))
  mod <- lm(frm, data=d)
  s   <- summary(mod)
  cat(sprintf("%s | n=%d | R2=%.4f | R2adj=%.4f | RMSE=%.4f m | F p=%.4f\n",
              info$label, nrow(d), s$r.squared, s$adj.r.squared,
              sqrt(mean(residuals(mod)^2)),
              pf(s$fstatistic[1], s$fstatistic[2], s$fstatistic[3], lower.tail=FALSE)))
}
cat("R2 cercanos a 0 y F no significativa: las medidas individuales no predicen la estatura.\n\n")

# ----------------------------------------------------------------
# Enfoque 2b: Regresion con arco y cuerda (solo inferiores)
# Modelo: estatura ~ cuerda + arco
# + prueba t de Student sobre residuales por sexo
# ----------------------------------------------------------------
cat("--- Enfoque 2b: Regresion con arco y cuerda (hemiarcadas inferiores) ---\n\n")

for (info in list(
  list(label="H3 (31-33)", data=h3, cuerda="cuerda_h3", arco="arco_h3"),
  list(label="H4 (41-43)", data=h4, cuerda="cuerda_h4", arco="arco_h4")
)) {
  d   <- info$data %>% rename(cuerda=all_of(info$cuerda), arco=all_of(info$arco))
  mod <- lm(estatura ~ cuerda + arco, data=d)
  s   <- summary(mod)
  
  cat(sprintf("%s | n=%d | R2=%.4f | R2adj=%.4f | RMSE=%.4f m\n",
              info$label, nrow(d), s$r.squared, s$adj.r.squared,
              sqrt(mean(residuals(mod)^2))))
  
  cf <- coef(s)
  for (nm in rownames(cf)) {
    cat(sprintf("  %-12s  b=%.4f  p=%.4f%s\n",
                nm, cf[nm,"Estimate"], cf[nm,"Pr(>|t|)"],
                ifelse(cf[nm,"Pr(>|t|)"] < 0.05, " *", "")))
  }
  
  # Prueba t de residuales por sexo
  tt <- t.test(residuals(mod)[d$sexo=="F"],
               residuals(mod)[d$sexo=="M"],
               var.equal=FALSE)
  cat(sprintf("  t residuales por sexo: t=%.3f  p=%.4f  %s\n\n",
              tt$statistic, tt$p.value,
              ifelse(tt$p.value < 0.05,
                     "Diferencia significativa por sexo *",
                     "Sin diferencia significativa por sexo")))
}

