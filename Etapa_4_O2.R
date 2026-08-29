# ================================================================
# Etapa 4 - Analisis inferencial completo - Observador 2 (O2)
# ================================================================
# Replica de Etapa_4.R pero sobre resultados/datos_130_O2.csv
# (mediciones individuales del Observador 2, generado por
# Cuerda_geometrica_130_O2.R), en vez del promedio entre observadores.
#
# Se genero porque Analisis_por_observador_130.R mostro que O2 tiene
# mejor precision Y menor RMSE que el promedio entre observadores en
# H3 y H4 simultaneamente (ver resultados/precision_por_observador_130.csv):
#   H3: O2 precision=23.2% rmse=0.1253  vs Promedio precision=23.0% rmse=0.1314
#   H4: O2 precision=34.2% rmse=0.1203  vs Promedio precision=32.1% rmse=0.1218
# Ojo: las diferencias son pequeñas (n~112, ~1-2 puntos porcentuales) y
# podrian no ser estadisticamente significativas; este script sirve para
# verificar si el hallazgo central de la Etapa 4 (arco~estatura controlando
# sexo) se sostiene o se fortalece usando solo los datos de O2.
#
# Ejecutar despues de Cuerda_geometrica_130_O2.R.
# ================================================================

library(dplyr)
library(tidyr)
source("Funciones_Carrea.R")

du <- read.csv("resultados/datos_130_O2.csv", stringsAsFactors = FALSE, check.names = FALSE)

h3 <- prep_hemiarcada(du, "H3")
h4 <- prep_hemiarcada(du, "H4")

cat(sprintf("n -> H3: %d | H4: %d  (base O2: %d individuos con estatura conocida)\n\n",
            nrow(h3), nrow(h4), nrow(du)))
cat(sprintf("H3: %d fuera del rango anatomico de referencia (tolerancia %.1f mm)\n", sum(!h3$en_rango), TOLERANCIA_RANGO))
cat(sprintf("H4: %d fuera del rango anatomico de referencia (tolerancia %.1f mm)\n\n", sum(!h4$en_rango), TOLERANCIA_RANGO))

dir_fig <- "reporte/figuras"
if (!dir.exists(dir_fig)) dir.create(dir_fig, recursive = TRUE)

# ----------------------------------------------------------------
# 1. Normalidad (Shapiro-Wilk) + QQ-plot e histograma por variable
# ----------------------------------------------------------------
sw <- function(x) { t <- shapiro.test(x); sprintf("W=%.3f p=%.3f", t$statistic, t$p.value) }

cat("=== 1. Shapiro-Wilk (O2) ===\n")
cat("Estatura global :", sw(du$Estatura), "\n")
cat("Estatura F      :", sw(du$Estatura[du$Sexo == "F"]), "\n")
cat("Estatura M      :", sw(du$Estatura[du$Sexo == "M"]), "\n")
cat("Arco H3         :", sw(h3$arco), "  Cuerda(med) H3:", sw(h3$cuerda_med), "\n")
cat("Arco H4         :", sw(h4$arco), "  Cuerda(med) H4:", sw(h4$cuerda_med), "\n")
cat("Cuerda(geo) H3  :", sw(h3$cuerda_geo[!is.na(h3$cuerda_geo)]), "\n")
cat("Cuerda(geo) H4  :", sw(h4$cuerda_geo[!is.na(h4$cuerda_geo)]), "\n\n")

qq_hist <- function(x, etq, archivo) {
  png(file.path(dir_fig, archivo), width = 1100, height = 600, res = 120)
  par(mfrow = c(1, 2), mar = c(4.5, 4.5, 3, 1))
  qqnorm(x, main = sprintf("Q-Q normal - %s", etq), pch = 19, col = "#4393C3")
  qqline(x, col = "#D6604D", lwd = 2)
  hist(x, col = "#A8C5DA", border = "white", main = sprintf("Histograma - %s", etq), xlab = etq)
  dev.off()
}
qq_hist(du$Estatura, "Estatura (m) - O2", "etapa4_O2_qq_estatura.png")
qq_hist(h3$arco, "Arco H3 (mm) - O2", "etapa4_O2_qq_arco_H3.png")
qq_hist(h4$arco, "Arco H4 (mm) - O2", "etapa4_O2_qq_arco_H4.png")
qq_hist(h3$cuerda_med, "Cuerda medida H3 (mm) - O2", "etapa4_O2_qq_cuerda_H3.png")
qq_hist(h4$cuerda_med, "Cuerda medida H4 (mm) - O2", "etapa4_O2_qq_cuerda_H4.png")

# ----------------------------------------------------------------
# 2. Correlacion arco-cuerda
# ----------------------------------------------------------------
cat("=== 2. Correlacion arco-cuerda (Pearson, O2) ===\n")
c3 <- cor.test(h3$arco, h3$cuerda_med); c4 <- cor.test(h4$arco, h4$cuerda_med)
cat(sprintf("H3: r=%.3f IC[%.3f,%.3f] p=%.4f\n", c3$estimate, c3$conf.int[1], c3$conf.int[2], c3$p.value))
cat(sprintf("H4: r=%.3f IC[%.3f,%.3f] p=%.4f\n\n", c4$estimate, c4$conf.int[1], c4$conf.int[2], c4$p.value))

png(file.path(dir_fig, "etapa4_O2_arco_cuerda.png"), width = 1100, height = 600, res = 120)
par(mfrow = c(1, 2), mar = c(4.5, 4.5, 3, 1))
for (hh in list(list(d = h3, e = "H3 (33-31)"), list(d = h4, e = "H4 (43-41)"))) {
  d <- hh$d
  plot(d$arco, d$cuerda_med, pch = 19, col = "#4393C3",
       xlab = "Arco (mm)", ylab = "Cuerda medida (mm)",
       main = sprintf("Arco vs cuerda - %s (O2)", hh$e))
  abline(lm(cuerda_med ~ arco, data = d), col = "#D6604D", lwd = 2)
  legend("topleft", sprintf("r = %.3f", cor(d$arco, d$cuerda_med)), bty = "n")
}
dev.off()

# ----------------------------------------------------------------
# 3. Carrea: cuerda MEDIDA vs GEOMETRICA, k Carrea
# ----------------------------------------------------------------
cat("=== 3. Carrea original (k=30pi) y comparacion de cuerdas (O2) ===\n")
tabla3 <- bind_rows(
  metricas(h3, "cuerda_med", label = "H3 medida"),
  metricas(h3, "cuerda_geo", label = "H3 geometrica"),
  metricas(h4, "cuerda_med", label = "H4 medida"),
  metricas(h4, "cuerda_geo", label = "H4 geometrica")
)
print(tabla3, row.names = FALSE)

# 3(b). Hallazgo central: estimacion de Carrea (punto medio del rango) vs
# estatura real, cuerda medida.
plot_carrea_real <- function(d, chord_col, etq, archivo) {
  d   <- d %>% filter(!is.na(.data[[chord_col]]))
  cu  <- d[[chord_col]]; ar <- d$arco
  Tprom <- (pmin(cu, ar) + pmax(cu, ar)) / 2000 * k_carrea
  rng <- range(c(Tprom, d$Estatura))
  png(file.path(dir_fig, archivo), width = 1000, height = 800, res = 130)
  par(mar = c(4.5, 4.5, 3, 1))
  plot(Tprom, d$Estatura, pch = 19, col = "#4393C3", xlim = rng, ylim = rng,
       xlab = "Estatura estimada (Carrea, punto medio) [m]",
       ylab = "Estatura real [m]",
       main = sprintf("Carrea vs real - %s (O2)", etq))
  abline(0, 1, lty = 2, col = "grey50")
  abline(lm(d$Estatura ~ Tprom), col = "#D6604D", lwd = 2)
  legend("topleft", c("identidad (y = x)", "ajuste lineal"),
         lty = c(2, 1), col = c("grey50", "#D6604D"), bty = "n")
  mtext(sprintf("r = %.3f", cor(Tprom, d$Estatura)), side = 3, line = 0.1, cex = 0.85)
  dev.off()
}
plot_carrea_real(h3, "cuerda_med", "H3 medida", "etapa4_O2_carrea_real_H3.png")
plot_carrea_real(h4, "cuerda_med", "H4 medida", "etapa4_O2_carrea_real_H4.png")

png(file.path(dir_fig, "etapa4_O2_precision_medida_geo.png"), width = 1000, height = 700, res = 130)
par(mar = c(7, 4.5, 3, 1))
bp <- barplot(tabla3$precision, names.arg = tabla3$modelo, las = 2,
              col = rep(c("#D6604D", "#4393C3"), 2),
              ylim = c(0, max(tabla3$precision) * 1.3),
              ylab = "Precision del rango (%)",
              main = "Precision de Carrea: cuerda medida vs geometrica (O2)")
text(bp, tabla3$precision, labels = paste0(tabla3$precision, "%"), pos = 3, cex = 0.9)
dev.off()

# ----------------------------------------------------------------
# 4. k optimo por hemiarcada (cuerda medida y geometrica)
# ----------------------------------------------------------------
cat("\n=== 4. k optimo por hemiarcada (cuerda medida y geometrica, O2) ===\n")
ko_tab <- function(d, chord_col, etq) {
  d  <- d %>% filter(!is.na(.data[[chord_col]]))
  ko <- calcular_k_opt(d$Estatura, d[[chord_col]], d$arco)
  data.frame(
    caso          = etq,
    k_carrea      = round(k_carrea, 2),
    k_opt         = round(ko, 2),
    prec_k_carrea = calcular_precision(d$Estatura, d[[chord_col]], d$arco, k_carrea),
    prec_k_opt    = calcular_precision(d$Estatura, d[[chord_col]], d$arco, ko),
    rmse_k_opt    = calcular_rmse(d$Estatura, d[[chord_col]], d$arco, ko)
  )
}
tabla_k <- bind_rows(
  ko_tab(h3, "cuerda_med", "H3 medida"), ko_tab(h3, "cuerda_geo", "H3 geometrica"),
  ko_tab(h4, "cuerda_med", "H4 medida"), ko_tab(h4, "cuerda_geo", "H4 geometrica")
)
print(tabla_k, row.names = FALSE)

png(file.path(dir_fig, "etapa4_O2_k_opt_precision.png"), width = 1100, height = 700, res = 130)
par(mar = c(7, 4.5, 3, 1))
m <- rbind(k_carrea = tabla_k$prec_k_carrea, k_opt = tabla_k$prec_k_opt)
colnames(m) <- tabla_k$caso
bp <- barplot(m, beside = TRUE, las = 2, col = c("#D6604D", "#1A9850"),
              ylim = c(0, 100), ylab = "Precision del rango (%)",
              main = "Precision con k de Carrea (30pi) vs k optimo por minimos cuadrados (O2)")
text(bp, m, labels = sprintf("%.1f", m), pos = 3, cex = 0.75)
legend("topright", c("k = 30pi (Carrea)", "k optimo"), fill = c("#D6604D", "#1A9850"), bty = "n")
dev.off()

# ----------------------------------------------------------------
# 5a. Regresion: dientes individuales
# ----------------------------------------------------------------
cat("\n=== 5a. estatura ~ dientes individuales (O2) ===\n")
m3 <- lm(Estatura ~ mm_31 + mm_32 + mm_33, data = h3)
m4 <- lm(Estatura ~ mm_41 + mm_42 + mm_43, data = h4)
resumen_lm <- function(m, etq) {
  s <- summary(m); f <- s$fstatistic
  data.frame(modelo = etq, R2 = round(s$r.squared, 3), R2_adj = round(s$adj.r.squared, 3),
             p_F = round(pf(f[1], f[2], f[3], lower.tail = FALSE), 4))
}
print(bind_rows(resumen_lm(m3, "H3 dientes"), resumen_lm(m4, "H4 dientes")), row.names = FALSE)

png(file.path(dir_fig, "etapa4_O2_r2_modelos.png"), width = 1100, height = 700, res = 130)
par(mar = c(9, 4.5, 3, 1))
mb3 <- lm(Estatura ~ arco + Sexo, data = h3)
mb4 <- lm(Estatura ~ arco + Sexo, data = h4)
mg3 <- lm(Estatura ~ cuerda_geo + Sexo, data = h3 %>% filter(!is.na(cuerda_geo)))
mg4 <- lm(Estatura ~ cuerda_geo + Sexo, data = h4 %>% filter(!is.na(cuerda_geo)))
r2s <- c("H3 dientes" = summary(m3)$adj.r.squared, "H4 dientes" = summary(m4)$adj.r.squared,
         "H3 arco+sexo" = summary(mb3)$adj.r.squared, "H4 arco+sexo" = summary(mb4)$adj.r.squared,
         "H3 cuerda_geo+sexo" = summary(mg3)$adj.r.squared, "H4 cuerda_geo+sexo" = summary(mg4)$adj.r.squared)
bp <- barplot(r2s, las = 2, col = "#B2ABD2", ylim = c(0, max(r2s) * 1.3),
              ylab = "R2 ajustada", main = "Poder explicativo de los modelos sobre la estatura (O2)")
text(bp, r2s, labels = round(r2s, 3), pos = 3, cex = 0.8)
dev.off()

# ----------------------------------------------------------------
# 5b. Regresion: arco + sexo
# ----------------------------------------------------------------
cat("\n=== 5b. estatura ~ arco + sexo (O2) ===\n")
detalle_lm <- function(m, etq) {
  s <- summary(m); f <- s$fstatistic; co <- coef(s)
  data.frame(modelo = etq, R2 = round(s$r.squared, 3), R2_adj = round(s$adj.r.squared, 3),
             p_arco = round(co["arco", "Pr(>|t|)"], 4),
             p_sexo = round(co[grep("Sexo", rownames(co)), "Pr(>|t|)"][1], 4),
             p_F = round(pf(f[1], f[2], f[3], lower.tail = FALSE), 4))
}
print(bind_rows(detalle_lm(mb3, "H3 arco+sexo"), detalle_lm(mb4, "H4 arco+sexo")), row.names = FALSE)

cat("\n=== 5b'. estatura ~ cuerda_geo + sexo (O2) ===\n")
detalle_geo <- function(m, etq) {
  s <- summary(m); co <- coef(s)
  data.frame(modelo = etq, R2 = round(s$r.squared, 3), R2_adj = round(s$adj.r.squared, 3),
             p_cuerda_geo = round(co["cuerda_geo", "Pr(>|t|)"], 4),
             p_sexo = round(co[grep("Sexo", rownames(co)), "Pr(>|t|)"][1], 4))
}
print(bind_rows(detalle_geo(mg3, "H3"), detalle_geo(mg4, "H4")), row.names = FALSE)

# ----------------------------------------------------------------
# 5c. Dimorfismo sexual (t de Student independiente)
# ----------------------------------------------------------------
cat("\n=== 5c. Dimorfismo sexual (O2) ===\n")
tt <- t.test(Estatura ~ Sexo, data = du)
cat(sprintf("Media F=%.3f  Media M=%.3f  dif=%.1f cm  t=%.2f  p=%.4f\n",
            tt$estimate[1], tt$estimate[2], (tt$estimate[2] - tt$estimate[1]) * 100,
            tt$statistic, tt$p.value))
cat(sprintf("Spearman(sexo, estatura): rho=%.3f p=%.4f\n",
            cor(as.integer(du$Sexo == "M"), du$Estatura, method = "spearman"),
            cor.test(as.integer(du$Sexo == "M"), du$Estatura, method = "spearman")$p.value))

png(file.path(dir_fig, "etapa4_O2_dimorfismo_sexual.png"), width = 900, height = 700, res = 130)
par(mar = c(4.5, 4.5, 3.5, 1))
boxplot(Estatura ~ Sexo, data = du, col = c("#F4A582", "#A8C5DA"),
        xlab = "Sexo", ylab = "Estatura (m)",
        main = "Dimorfismo sexual en estatura (O2)")
mtext(sprintf("dif = %.1f cm | t = %.2f | p = %.4f",
              (tt$estimate[2] - tt$estimate[1]) * 100, tt$statistic, tt$p.value),
      side = 3, line = 0.2, cex = 0.85)
dev.off()

cat("\nFiguras guardadas en", dir_fig, "(etapa4_O2_*.png)\n")

# ----------------------------------------------------------------
# Exportar tabla resumen de Carrea (medida vs geometrica)
# ----------------------------------------------------------------
write.csv(tabla3, "resultados/resultados_carrea_130_O2.csv", row.names = FALSE)
write.csv(tabla_k, "resultados/k_optimo_130_O2.csv", row.names = FALSE)
cat("\nGuardado: resultados/resultados_carrea_130_O2.csv\n")
cat("Guardado: resultados/k_optimo_130_O2.csv\n")
