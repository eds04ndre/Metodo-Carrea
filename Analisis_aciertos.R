# ================================================================
# Características de los individuos con estimación CORRECTA
# por el modelo ORIGINAL de Carrea (cuerda medida, k = 30π)
# Servicio Social - Edson André Cortés Silva
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
todo <- bind_rows(h3 %>% mutate(hemi="H3"), h4 %>% mutate(hemi="H4"))
mod <- glm(acierto ~ ratio + Estatura + I(Sexo=="M"),
           data = todo, family = binomial)
print(summary(mod)$coefficients)
