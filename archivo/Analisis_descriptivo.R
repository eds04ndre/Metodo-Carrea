library(dplyr)

# ----------------------------------------------------------------
# 1. Carga
# ----------------------------------------------------------------

# NOTA: datos_unidos.csv fue reemplazado por la base corregida (n=49, sin los
# falsos duplicados). Los resultados diferirán de los del reporte original.
du <- read.csv("resultados/datos_unidos_corregido.csv",
               stringsAsFactors = FALSE, check.names = FALSE)
ae <- read.csv("data/Anexo_E.csv",
               stringsAsFactors = FALSE, check.names = FALSE)

names(ae) <- trimws(names(ae))

cols_dentales <- c("mm_41","mm_42","mm_43","mm_31","mm_32","mm_33",
                   "mm_43_41","mm_33_31","intercanina_inf")

k_carrea <- 30 * pi   # constante original de Carrea

# ----------------------------------------------------------------
# 2. Descriptivo general
# Ejecutar cada bloque por separado para ver los resultados en consola
# ----------------------------------------------------------------

# Tamaño de muestra: total de filas, IDs únicos y distribución por fuente
nrow(du)
n_distinct(du$ID)
table(du$fuente)

# Distribución por sexo (incluye NAs si los hay)
table(du$Sexo, useNA = "ifany")

# Resumen de edad: mínimo, Q1, mediana, media, Q3, máximo y desviación estándar
summary(du$Edad)
sd(du$Edad, na.rm = TRUE)

# Resumen de estatura en metros
summary(du$Estatura)
sd(du$Estatura, na.rm = TRUE)

# Estadísticos de estatura desagregados por sexo: n, media, DE, mín y máx
du %>%
  group_by(Sexo) %>%
  summarise(n     = n(),
            media = mean(Estatura, na.rm = TRUE),
            DE    = sd(Estatura,   na.rm = TRUE),
            min   = min(Estatura,  na.rm = TRUE),
            max   = max(Estatura,  na.rm = TRUE),
            .groups = "drop")

# Distribución por lugar de origen
table(du$Lugar_origen, useNA = "ifany")
1/54

# Resumen de las nueve medidas dentales inferiores
du %>% select(all_of(cols_dentales)) %>% summary()

# Desviación estándar de cada variable dental (redondeada a 4 decimales)
du %>%
  summarise(across(all_of(cols_dentales), ~round(sd(., na.rm = TRUE), 4)))

# Conteo de valores ausentes por columna (solo columnas con al menos un NA)
du %>%
  summarise(across(everything(), ~sum(is.na(.)))) %>%
  t() %>%
  as.data.frame() %>%
  setNames("n_NA") %>%
  filter(n_NA > 0)

# ----------------------------------------------------------------
# 3. Boxplots — medidas dentales de datos_unidos
# Genera boxplots_medidas_dentales.pdf en el directorio de trabajo
# ----------------------------------------------------------------

# pdf("boxplots_medidas_dentales.pdf", width = 10, height = 6)

# Diámetros mesiodistales por diente; azul = cuadrante 4, naranja = cuadrante 3
par(mar = c(6, 4, 3, 1))
boxplot(du[, c("mm_41","mm_42","mm_43","mm_31","mm_32","mm_33")],
        names = c("mm 41","mm 42","mm 43","mm 31","mm 32","mm 33"),
        main  = "Diámetros mesiodistales — hemiarcadas inferiores",
        ylab  = "Medida (mm)",
        col   = c(rep("#A8C5DA", 3), rep("#F4A582", 3)),
        las   = 2)
legend("topright",
       legend = c("Cuadrante 4 (derecho)","Cuadrante 3 (izquierdo)"),
       fill   = c("#A8C5DA","#F4A582"), bty = "n")

# Cuerdas de hemiarcada e intercanina inferior
par(mar = c(6, 4, 3, 1))
boxplot(du[, c("mm_43_41","mm_33_31","intercanina_inf")],
        names = c("Cuerda H3","Cuerda H4","Intercanina inf."),
        main  = "Cuerda e intercanina — hemiarcadas inferiores",
        ylab  = "Medida (mm)",
        col   = c("#A8C5DA","#F4A582","#B2ABD2"),
        las   = 2)

# dev.off()

# ----------------------------------------------------------------
# 4. Aplicación del método de Carrea a datos_unidos
# diente == 0 indica ausencia → se excluye la hemiarcada completa
# cuando cuerda > arco por error de medición se usa min/max para el rango
# ----------------------------------------------------------------

carrea_rango <- function(d1, d2, d3, cuerda) {
  if (any(is.na(c(d1, d2, d3, cuerda))) || any(c(d1, d2, d3) == 0))
    return(c(T_min = NA_real_, T_max = NA_real_, T_medio = NA_real_))
  arco  <- d1 + d2 + d3
  T_c   <- cuerda / 1000 * k_carrea
  T_a   <- arco   / 1000 * k_carrea
  T_min <- min(T_c, T_a)
  T_max <- max(T_c, T_a)
  c(T_min = T_min, T_max = T_max, T_medio = (T_min + T_max) / 2)
}

du_carrea <- du %>%
  rowwise() %>%
  mutate(
    h3 = list(carrea_rango(mm_41, mm_42, mm_43, mm_43_41)),
    T_min_h3   = h3["T_min"],
    T_max_h3   = h3["T_max"],
    T_medio_h3 = h3["T_medio"],
    # TRUE si la estatura real cae dentro del intervalo [T_min, T_max]
    dentro_h3  = ifelse(!is.na(T_min_h3) & !is.na(Estatura),
                        Estatura >= T_min_h3 & Estatura <= T_max_h3, NA),
    h4 = list(carrea_rango(mm_31, mm_32, mm_33, mm_33_31)),
    T_min_h4   = h4["T_min"],
    T_max_h4   = h4["T_max"],
    T_medio_h4 = h4["T_medio"],
    dentro_h4  = ifelse(!is.na(T_min_h4) & !is.na(Estatura),
                        Estatura >= T_min_h4 & Estatura <= T_max_h4, NA)
  ) %>%
  select(-h3, -h4) %>%
  ungroup()

# Precisión de Carrea por hemiarcada: n válidos, aciertos y porcentaje
for (h in c("h3", "h4")) {
  lbl    <- ifelse(h == "h3", "H3 (41-43)", "H4 (31-33)")
  dentro <- du_carrea[[paste0("dentro_", h)]]
  n_val  <- sum(!is.na(dentro))
  n_si   <- sum(dentro == TRUE, na.rm = TRUE)
  message(sprintf("%s | n válidos: %d | dentro: %d | Precisión: %.1f%%",
                  lbl, n_val, n_si, n_si / n_val * 100))
}

# ----------------------------------------------------------------
# 5. Carrea desde Anexo_E (estimaciones ya calculadas en el archivo)
# ----------------------------------------------------------------

# Resumen de radios-cuerda, arcos y estaturas estimadas y real
summary(ae[, c("Radio-cuerda derecho","Arco derecho",
               "Radio-cuerda izquierdo","Arco izquierdo",
               "Estatura estimada derecha","Estatura estimada izquierda",
               "Estatura real")])

# Desviaciones estándar de las estaturas (real y estimadas)
sd(ae$`Estatura real`,               na.rm = TRUE)
sd(ae$`Estatura estimada derecha`,   na.rm = TRUE)
sd(ae$`Estatura estimada izquierda`, na.rm = TRUE)

# Recalcular rango [T_min, T_max] desde cuerda y arco para verificar precisión
ae <- ae %>%
  rowwise() %>%
  mutate(
    T_min_d  = min(`Radio-cuerda derecho`,    `Arco derecho`)    / 1000 * k_carrea,
    T_max_d  = max(`Radio-cuerda derecho`,    `Arco derecho`)    / 1000 * k_carrea,
    T_min_i  = min(`Radio-cuerda izquierdo`,  `Arco izquierdo`)  / 1000 * k_carrea,
    T_max_i  = max(`Radio-cuerda izquierdo`,  `Arco izquierdo`)  / 1000 * k_carrea,
    # TRUE si la estatura real cae dentro del intervalo estimado
    dentro_d = `Estatura real` >= T_min_d & `Estatura real` <= T_max_d,
    dentro_i = `Estatura real` >= T_min_i & `Estatura real` <= T_max_i
  ) %>%
  ungroup()

# Precisión derecho e izquierdo: aciertos sobre total de casos en Anexo_E
message(sprintf("Precisión derecho:   %d / %d → %.1f%%",
                sum(ae$dentro_d, na.rm = TRUE), nrow(ae),
                mean(ae$dentro_d, na.rm = TRUE) * 100))
message(sprintf("Precisión izquierdo: %d / %d → %.1f%%",
                sum(ae$dentro_i, na.rm = TRUE), nrow(ae),
                mean(ae$dentro_i, na.rm = TRUE) * 100))

# ----------------------------------------------------------------
# 6. Boxplots — estimaciones Carrea (ambos datasets)
# Genera boxplots_carrea_estimaciones.pdf en el directorio de trabajo
# ----------------------------------------------------------------

# pdf("boxplots_carrea_estimaciones.pdf", width = 10, height = 6)

# Datos en formato largo para comparación dentro de cada dataset
est_du <- na.omit(data.frame(
  valor  = c(du_carrea$T_medio_h3, du_carrea$T_medio_h4, du_carrea$Estatura),
  grupo  = c(rep("Carrea H3", nrow(du_carrea)),
             rep("Carrea H4", nrow(du_carrea)),
             rep("Real",      nrow(du_carrea))),
  dataset = "datos_unidos"
))

est_ae <- na.omit(data.frame(
  valor  = c(ae$`Estatura estimada derecha`,
             ae$`Estatura estimada izquierda`,
             ae$`Estatura real`),
  grupo  = c(rep("Carrea derecho",   nrow(ae)),
             rep("Carrea izquierdo", nrow(ae)),
             rep("Real",             nrow(ae))),
  dataset = "Anexo_E"
))

# Carrea vs real — datos_unidos
par(mar = c(5, 4, 3, 1))
boxplot(valor ~ grupo, data = est_du,
        main = "Estaturas Carrea vs real — datos_unidos",
        ylab = "Estatura (m)",
        col  = c("#A8C5DA","#F4A582","#B2ABD2"),
        las  = 2)

# Carrea vs real — Anexo_E
boxplot(valor ~ grupo, data = est_ae,
        main = "Estaturas Carrea vs real — Anexo_E",
        ylab = "Estatura (m)",
        col  = c("#A8C5DA","#F4A582","#B2ABD2"),
        las  = 2)

# Comparativo entre datasets: estaturas en cm para homogeneizar escala
# (datos_unidos está en metros → ×100; Anexo_E ya viene en cm)
comp <- na.omit(data.frame(
  valor = c(du_carrea$T_medio_h3 * 100, du_carrea$T_medio_h4 * 100,
            du_carrea$Estatura * 100,
            ae$`Estatura estimada derecha`,
            ae$`Estatura estimada izquierda`,
            ae$`Estatura real`),
  grupo = c(rep("DU — H3",       nrow(du_carrea)),
            rep("DU — H4",       nrow(du_carrea)),
            rep("DU — Real",     nrow(du_carrea)),
            rep("AE — derecho",  nrow(ae)),
            rep("AE — izquierdo",nrow(ae)),
            rep("AE — Real",     nrow(ae)))
))

boxplot(valor ~ grupo, data = comp,
        main = "Comparación estimaciones Carrea — datos_unidos vs Anexo_E",
        ylab = "Estatura estimada (cm)",
        col  = c("#F4A582","#FDBB84","#FDBB84","#A8C5DA","#74ADD1","#74ADD1"),
        las  = 2)

# dev.off()

