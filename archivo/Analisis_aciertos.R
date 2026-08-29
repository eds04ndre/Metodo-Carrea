# ================================================================
# Características de los individuos con estimación CORRECTA
# por el modelo ORIGINAL de Carrea (cuerda medida, k = 30π)
# ================================================================
# "Acierto" = la estatura real cae dentro del rango [Tmin, Tmax].
# Objetivo: descubrir qué tienen en común los aciertos para entender
# si el éxito del método responde a un rasgo del individuo o a un
# artefacto de medición.
# ================================================================

library(dplyr)

du <- read.csv("resultados/datos_unidos_corregido.csv",
               stringsAsFactors = FALSE, check.names = FALSE)
k_carrea <- 30 * pi

prep <- function(d, t1, t2, t3, chord, excl_ids, central = NULL) {
  d <- d %>%
    filter(!is.na(.data[[t1]]), !is.na(.data[[t2]]), !is.na(.data[[t3]]),
           .data[[t1]] != 0, .data[[t2]] != 0, .data[[t3]] != 0,
           !is.na(Estatura), !(ID %in% excl_ids)) %>%
    mutate(arco = .data[[t1]] + .data[[t2]] + .data[[t3]],
           cuerda = .data[[chord]],
           Tmin = pmin(cuerda, arco) / 1000 * k_carrea,
           Tmax = pmax(cuerda, arco) / 1000 * k_carrea,
           acierto = Estatura >= Tmin & Estatura <= Tmax,
           debajo  = Estatura < Tmin,
           encima  = Estatura > Tmax,
           ratio   = cuerda / arco)
  if (!is.null(central))
    d <- d %>% filter(!(ID == "sin codigo" & .data[[central]] > 8))
  d
}

resumen <- function(d, etq) {
  data.frame(
    grupo      = etq,
    n          = nrow(d),
    estatura_m = round(mean(d$Estatura), 3),
    estatura_sd= round(sd(d$Estatura), 3),
    pct_H      = round(mean(d$Sexo == "M") * 100, 0),
    edad       = round(mean(d$Edad, na.rm = TRUE), 1),
    arco       = round(mean(d$arco), 2),
    cuerda     = round(mean(d$cuerda), 2),
    cuerda_arco= round(mean(d$ratio), 3)
  )
}

analiza <- function(d, hemi) {
  cat(sprintf("\n=== %s (n=%d) ===\n", hemi, nrow(d)))
  ac <- d %>% filter(acierto)
  fa <- d %>% filter(!acierto)
  cat(sprintf("Aciertos: %d (%.1f%%) | Fallos: %d (%d por DEBAJO de Tmin, %d por ENCIMA de Tmax)\n",
              nrow(ac), nrow(ac)/nrow(d)*100, nrow(fa),
              sum(d$debajo), sum(d$encima)))
  print(rbind(resumen(ac, "ACIERTOS"), resumen(fa, "FALLOS")), row.names = FALSE)
  cat(sprintf("Discriminante real = cociente cuerda/arco MEDIDO: %.3f (aciertos) vs %.3f (fallos).\n",
              mean(ac$ratio), mean(fa$ratio)))
}

h3 <- prep(du, "mm_31","mm_32","mm_33","mm_33_31", c("17"), "mm_31")
h4 <- prep(du, "mm_41","mm_42","mm_43","mm_43_41", c("26"))

analiza(h3, "H3 (31-33)")
analiza(h4, "H4 (41-43)")

# Modelo logístico: ¿el cociente cuerda/arco predice el acierto?
cat("\n=== ¿Qué predice el acierto? (regresión logística, H3+H4) ===\n")
# ggeffects (versiones recientes) exige factores en vez de lógicos: se
# construyen columnas factor explícitas para el modelo del gráfico.
todo <- bind_rows(h3 %>% mutate(hemi="H3"), h4 %>% mutate(hemi="H4")) %>%
  mutate(acierto_f = factor(ifelse(acierto, "si", "no"), levels = c("no","si")),
         Sexo_f    = factor(Sexo))
mod <- glm(acierto_f ~ ratio + Estatura + Sexo_f,
           data = todo, family = binomial)
print(summary(mod)$coefficients)

library(ggplot2)
library(ggeffects)
# 2. Calcular las predicciones marginales
# Esto calcula la probabilidad de acierto según el 'ratio' y el 'Sexo',
# manteniendo la 'Estatura' constante en su media muestral de forma automática.
predicciones <- ggpredict(mod, terms = c("ratio", "Sexo_f"))

# 3. Generar el gráfico de alta calidad
# png(file.path("reporte/figuras", "aciertos_prob_logistica.png"),
    # width = 1000, height = 700, res = 130)
print(
ggplot(predicciones, aes(x = x, y = predicted, color = group, fill = group)) +
  # Añade bandas de confianza del 95%
  geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = 0.15, color = NA) +
  # Añade las curvas logísticas para cada sexo
  geom_line(size = 1.2) +
  # Configuración estética del gráfico
  labs(
    title = "Efecto de las variables en la probabilidad de Acierto",
    subtitle = "Estatura fijada en su valor promedio",
    x = "Cociente cuerda/arco",
    y = "Probabilidad estimada de Acierto",
    color = "Sexo",
    fill = "Sexo"
  ) +
  scale_y_continuous(labels = scales::percent, limits = c(0, 1)) +
  theme_minimal(base_size = 14) +
  theme(legend.position = "top")
)
# dev.off()
# ----------------------------------------------------------------
# Gráficos de observación — qué distingue a los aciertos
#   Paso crucial: mostrar que el "acierto" no es un rasgo biológico
#   sino un artefacto del cociente cuerda/arco medido. Figuras en
#   reporte/figuras/.
# ----------------------------------------------------------------
dir_fig <- "reporte/figuras"
if (!dir.exists(dir_fig)) dir.create(dir_fig, recursive = TRUE)

# (a) Rango de Carrea [Tmin, Tmax] vs estatura real, individuo a individuo
#     (ordenados por estatura). Verde = la estatura cae dentro del rango.
#     Se dibuja con la cuerda MEDIDA y con la cuerda GEOMÉTRICA, lado a lado,
#     para comparar las estimaciones del modelo con cada cuerda. Los rangos y
#     aciertos ya vienen calculados en estimaciones_cuerda_geometrica.csv
#     (columnas Tmin_med/Tmax_med/acierto_med y Tmin_geo/Tmax_geo/acierto_geo).
est <- read.csv("resultados/estimaciones_cuerda_geometrica.csv",
                stringsAsFactors = FALSE, check.names = FALSE)

plot_brackets <- function(d, etq, tmin, tmax, ok, sub) {
  d <- d %>% filter(!is.na(.data[[tmin]]), !is.na(.data[[tmax]])) %>% arrange(Estatura)
  n <- nrow(d)
  par(mar = c(4.5, 4.5, 4, 1))
  plot(NA, xlim = range(c(d[[tmin]], d[[tmax]], d$Estatura)), ylim = c(0.5, n + 0.5),
       xlab = "Estatura (m)", ylab = "Individuo (ordenado por estatura)",
       main = sprintf("Rango de Carrea vs estatura real — %s", etq))
  mtext(sprintf("%s  |  aciertos: %d/%d (%.0f%%)",
                sub, sum(d[[ok]]), n, mean(d[[ok]]) * 100),
        side = 3, line = 0.2, cex = 0.8)
  segments(d[[tmin]], 1:n, d[[tmax]], 1:n, col = "grey75", lwd = 3)
  points(d$Estatura, 1:n, pch = 19,
         col = ifelse(d[[ok]] == 1, "#1A9850", "#D73027"))
  legend("bottomright",
         c("Dentro del rango (acierto)", "Fuera del rango (fallo)"),
         pch = 19, col = c("#1A9850", "#D73027"), bty = "n", cex = 0.85)
}

# Una figura por hemiarcada con los dos rangos lado a lado (cuerda medida
# como viene en los datos vs cuerda geométrica calculada).
comparaciones <- list(
  list(d = est %>% filter(hemiarcada == "H3"), etq = "H3 (31-33)",
       archivo = "aciertos_bracket_H3_comparacion.png"),
  list(d = est %>% filter(hemiarcada == "H4"), etq = "H4 (41-43)",
       archivo = "aciertos_bracket_H4_comparacion.png")
)
for (cmp in comparaciones) {
  # png(file.path(dir_fig, cmp$archivo), width = 1700, height = 850, res = 130)
  par(mfrow = c(1, 2))
  plot_brackets(cmp$d, cmp$etq, "Tmin_med", "Tmax_med", "acierto_med", "cuerda MEDIDA")
  plot_brackets(cmp$d, cmp$etq, "Tmin_geo", "Tmax_geo", "acierto_geo", "cuerda GEOMÉTRICA")
  # dev.off()
}
par(mfrow = c(1, 1))

# (b) El discriminante real: cociente cuerda/arco MEDIDO en aciertos vs fallos.
# png(file.path(dir_fig, "aciertos_ratio.png"), width = 1000, height = 700, res = 130)
par(mar = c(4.5, 4.5, 3.5, 1))
boxplot(ratio ~ acierto, data = todo,
        names = c("Fallo", "Acierto"), xlab = "",
        col = c("#D73027", "#1A9850"),
        ylab = "Cociente cuerda/arco (medido)",
        main = "El acierto lo marca el cociente cuerda/arco medido")
abline(h = 1, lty = 2, col = "grey40")
# dev.off()

cat("\nFiguras guardadas en", dir_fig, "(aciertos_*.png)\n")
