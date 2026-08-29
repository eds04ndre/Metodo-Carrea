# ================================================================
# Características DEMOGRÁFICAS de aciertos vs fallos del método de Carrea
# ================================================================
# Pregunta: ¿comparten algún rasgo demográfico (sexo, edad, estatura,
# lugar de origen) las personas cuya estimación de Carrea es CORRECTA
# (la estatura real cae dentro de [Tmin, Tmax]) frente a las que no?
#
# Se analizan los DOS modelos: cuerda MEDIDA (acierto_med, modelo original)
# y cuerda GEOMÉTRICA (acierto_geo). Los rangos e indicadores de acierto ya
# vienen materializados en resultados/estimaciones_cuerda_geometrica.csv.
# El análisis se hace por hemiarcada (H3, H4) porque el acierto se define
# por hemiarcada, y a nivel PERSONA (acierto en al menos una hemiarcada).
# ================================================================

library(dplyr)
est <- read.csv("resultados/estimaciones_cuerda_geometrica.csv",
                stringsAsFactors = FALSE, check.names = FALSE)

dir_fig <- "reporte/figuras"
if (!dir.exists(dir_fig)) dir.create(dir_fig, recursive = TRUE)

# Normalizar el lugar de origen: "CDMX" y "Ciudad de México" son el mismo
# lugar con etiqueta distinta según la fuente.
norm_origen <- function(x) {
  x <- trimws(x)
  dplyr::case_when(
    x %in% c("CDMX", "Ciudad de México") ~ "CDMX",
    x == "Estado de México"              ~ "Edo. Mex.",
    TRUE                                 ~ "Otro"
  )
}

est <- est %>% mutate(origen = norm_origen(Lugar_origen))

# ----------------------------------------------------------------
# Resúmenes y pruebas para un indicador de acierto (columna ok)
# ----------------------------------------------------------------
resumen_demo <- function(d, ok) {
  d %>% mutate(grupo = ifelse(.data[[ok]] == 1, "ACIERTO", "FALLO")) %>%
    group_by(grupo) %>% summarise(
      n            = n(),
      pct_F        = round(mean(Sexo == "F") * 100, 0),
      pct_M        = round(mean(Sexo == "M") * 100, 0),
      edad_media   = round(mean(Edad, na.rm = TRUE), 1),
      edad_sd      = round(sd(Edad,  na.rm = TRUE), 1),
      edad_mediana = median(Edad, na.rm = TRUE),
      estatura_m   = round(mean(Estatura), 3),
      estatura_sd  = round(sd(Estatura), 3),
      pct_CDMX     = round(mean(origen == "CDMX") * 100, 0),
      pct_EdoMex   = round(mean(origen == "Edo. Mex.") * 100, 0),
      pct_Otro     = round(mean(origen == "Otro") * 100, 0),
      .groups = "drop"
    ) %>% as.data.frame()
}

tests_demo <- function(d, ok) {
  d <- d %>% mutate(grupo = ifelse(.data[[ok]] == 1, "ACIERTO", "FALLO"))
  p <- function(expr) tryCatch(suppressWarnings(expr), error = function(e) NA_real_)
  data.frame(
    sexo_fisher_p     = round(p(fisher.test(table(d$grupo, d$Sexo))$p.value), 3),
    origen_fisher_p   = round(p(fisher.test(table(d$grupo, d$origen))$p.value), 3),
    edad_wilcox_p     = round(p(wilcox.test(Edad ~ grupo, data = d)$p.value), 3),
    estatura_wilcox_p = round(p(wilcox.test(Estatura ~ grupo, data = d)$p.value), 3)
  )
}

reporta <- function(d, etq, ok) {
  na <- sum(d[[ok]] == 1); nf <- sum(d[[ok]] == 0)
  cat(sprintf("\n----- %s: %d aciertos vs %d fallos -----\n", etq, na, nf))
  print(resumen_demo(d, ok), row.names = FALSE)
  cat("Pruebas (p-value):\n"); print(tests_demo(d, ok), row.names = FALSE)
}

# ---- nivel PERSONA: acierto si cae en el rango en >=1 hemiarcada ----
persona <- est %>%
  group_by(ID) %>%
  summarise(Sexo = first(Sexo), Edad = first(Edad),
            Estatura = first(Estatura), origen = first(origen),
            acierto_med = as.integer(any(acierto_med == 1)),
            acierto_geo = as.integer(any(acierto_geo == 1)),
            .groups = "drop") %>% as.data.frame()

for (modelo in list(c(ok = "acierto_med", nom = "CUERDA MEDIDA (modelo original)"),
                    c(ok = "acierto_geo", nom = "CUERDA GEOMÉTRICA"))) {
  cat(sprintf("\n================ %s ================\n", modelo["nom"]))
  reporta(est %>% filter(hemiarcada == "H3"), "H3 (31-33)", modelo["ok"])
  reporta(est %>% filter(hemiarcada == "H4"), "H4 (41-43)", modelo["ok"])
  reporta(persona, "PERSONA (>=1 hemiarcada)", modelo["ok"])
}

# ================================================================
# Figuras (nivel persona; comparan cuerda medida vs geométrica)
# ================================================================
COL_MED <- "#D6604D"   # cuerda medida
COL_GEO <- "#4393C3"   # cuerda geométrica

tasa_por <- function(grpvar) {
  rbind(Medida     = tapply(persona$acierto_med, persona[[grpvar]], mean) * 100,
        Geometrica = tapply(persona$acierto_geo, persona[[grpvar]], mean) * 100)
}

# (1) Tasa de acierto por SEXO
# png(file.path(dir_fig, "demo_aciertos_sexo.png"), width = 1000, height = 700, res = 130)
par(mar = c(4.5, 4.5, 3.5, 1))
m <- tasa_por("Sexo")
bp <- barplot(m, beside = TRUE, col = c(COL_MED, COL_GEO), ylim = c(0, 100),
              ylab = "% que acierta (nivel persona)", xlab = "Sexo",
              main = "Tasa de acierto de Carrea por sexo")
text(bp, m, labels = sprintf("%.0f%%", m), pos = 3, cex = 0.8)
legend("topright", c("Cuerda medida", "Cuerda geométrica"),
       fill = c(COL_MED, COL_GEO), bty = "n")
# dev.off()

# (2) Tasa de acierto por ORIGEN
# png(file.path(dir_fig, "demo_aciertos_origen.png"), width = 1000, height = 700, res = 130)
par(mar = c(4.5, 4.5, 3.5, 1))
m <- tasa_por("origen")
bp <- barplot(m, beside = TRUE, col = c(COL_MED, COL_GEO), ylim = c(0, 100),
              ylab = "% que acierta (nivel persona)", xlab = "Lugar de origen",
              main = "Tasa de acierto de Carrea por origen")
text(bp, m, labels = sprintf("%.0f%%", m), pos = 3, cex = 0.8)
legend("topright", c("Cuerda medida", "Cuerda geométrica"),
       fill = c(COL_MED, COL_GEO), bty = "n")
# dev.off()

# (3) Estatura y edad: distribución en aciertos vs fallos (ambos modelos)
long <- function(ok) data.frame(
  estatura = persona$Estatura, edad = persona$Edad,
  grupo = ifelse(persona[[ok]] == 1, "Acierto", "Fallo"))
bx <- rbind(cbind(long("acierto_med"), modelo = "Medida"),
            cbind(long("acierto_geo"), modelo = "Geométrica"))
bx$cat <- factor(paste(bx$modelo, bx$grupo),
                 levels = c("Medida Acierto", "Medida Fallo",
                            "Geométrica Acierto", "Geométrica Fallo"))
cols4 <- c("#1A9850", "#D73027", "#1A9850", "#D73027")

# png(file.path(dir_fig, "demo_aciertos_estatura_edad.png"), width = 1300, height = 650, res = 130)
par(mfrow = c(1, 2), mar = c(7, 4.5, 3, 1))
boxplot(estatura ~ cat, data = bx, col = cols4, las = 2, xlab = "",
        ylab = "Estatura (m)", main = "Estatura: acierto vs fallo")
boxplot(edad ~ cat, data = bx, col = cols4, las = 2, xlab = "",
        ylab = "Edad (años)", main = "Edad: acierto vs fallo")
par(mfrow = c(1, 1))
# dev.off()

cat("\nFiguras guardadas en", dir_fig, "(demo_aciertos_*.png)\n")
