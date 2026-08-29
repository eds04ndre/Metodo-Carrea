# ================================================================
# Pipeline: unión de datos Carrea
# Servicio Social - Edson André Cortés Silva
# ================================================================
# Fuentes:
#   A) Mediciones_Estatura.csv       — 41 individuos
#   B) datos_limpios_validados.csv   — 13 individuos, 2 obs por individuo
#   C) Datos_Estatura.csv            — demografía de los 13 individuos de B
#
# Filtros: Evaluador == 1, Instrumento == "Vernier"
# B se promedia entre observación 1 y 2 antes del join
# ================================================================

library(dplyr)

# ----------------------------------------------------------------
# 1. Carga
# ----------------------------------------------------------------
A_raw  <- read.csv("data/Mediciones_Estatura.csv",
                   stringsAsFactors = FALSE, check.names = FALSE)
B_raw  <- read.csv("data/datos_limpios_validados.csv",
                   stringsAsFactors = FALSE, check.names = FALSE)
DE_raw <- read.csv("data/Datos_Estatura.csv",
                   stringsAsFactors = FALSE, check.names = FALSE)

names(DE_raw) <- trimws(names(DE_raw))   # elimina espacios en nombres de columnas

cols_dentales <- c("mm_41","mm_42","mm_43","mm_31","mm_32","mm_33",
                   "mm_43_41","mm_33_31","intercanina_inf")

# ----------------------------------------------------------------
# 2. Preparar A
# ----------------------------------------------------------------

A <- A_raw %>%
  filter(Evaluador == 1, Instrumento == "Verniere") %>%   # typo en datos originales
  transmute(
    fuente       = "Mediciones_Estatura",
    Evaluador, `N Modelo`,
    ID           = as.character(ID),
    Instrumento  = "Vernier",
    Edad, Sexo,
    Estatura     = as.numeric(gsub(",", ".", as.character(Estatura))),
    Lugar_origen = Lugar_origen,
    mm_41 = `mm 41`, mm_42 = `mm 42`, mm_43 = `mm 43`,
    mm_31 = `mm 31`, mm_32 = `mm 32`, mm_33 = `mm 33`,
    mm_43_41 = `mm 43 - 41`, mm_33_31 = `mm 33 - 31`,
    intercanina_inf = `Distancia_intercanina mm 43 - 33`
  )

# ----------------------------------------------------------------
# 3. Preparar B: promediar observación 1 y 2
# ----------------------------------------------------------------

B <- B_raw %>%
  filter(Evaluador == 1, Instrumento == "Vernier") %>%
  transmute(
    Evaluador, `N Modelo`,
    ID = as.character(ID),
    Instrumento,
    mm_41 = mm_41, mm_42 = mm_42, mm_43 = mm_43,
    mm_31 = mm_31, mm_32 = mm_32, mm_33 = mm_33,
    mm_43_41 = mm_43_41, mm_33_31 = mm_33_31,
    intercanina_inf = mm_43_33
  ) %>%
  group_by(ID, `N Modelo`) %>%
  summarise(
    Evaluador   = first(Evaluador),
    Instrumento = first(Instrumento),
    across(all_of(cols_dentales), mean),
    .groups = "drop"
  ) %>%
  mutate(fuente = "datos_limpios_validados")

# ----------------------------------------------------------------
# 4. Agregar demografía a B desde Datos_Estatura.csv
# ----------------------------------------------------------------

DE <- DE_raw %>%
  transmute(
    ID           = as.character(ID),
    Edad, Sexo, Estatura,
    Lugar_origen = Lugar_Origen
  )

B <- B %>% left_join(DE, by = "ID")

cat("A:", nrow(A), "filas | B (promediado):", nrow(B), "filas\n\n")

# ----------------------------------------------------------------
# 5. IDs en común: validar IDENTIDAD (misma persona) vs DEMOGRAFÍAS
#    DISTINTAS — SIN eliminar registros en bloque.
#
# El `ID` es el código de catálogo del modelo en AMBAS fuentes (en la base
# de 41, `N Modelo` es sólo el orden secuencial 1–41; el código real es `ID`,
# con "sin codigo" cuando se desconoce). Que dos filas compartan código NO
# implica que sean la misma persona: el código pudo reutilizarse o transcribirse
# mal. Por eso, para cada código presente en ambas fuentes se COMPARA la
# demografía y se clasifica el caso:
#
#   - MISMA_PERSONA        : mismo Sexo y |ΔEstatura| ≤ TOL_EST.
#       Es un duplicado real del mismo individuo. Se conserva el registro
#       VALIDADO (base de 13: réplicas promediadas + demografía dedicada) y se
#       consolida el duplicado para no contar dos veces a una misma persona.
#   - DEMOGRAFIA_DISTINTA  : el sexo difiere o |ΔEstatura| > TOL_EST.
#       NO son la misma persona: son individuos distintos que coinciden en el
#       código de catálogo. NO se eliminan. Se les asigna un CÓDIGO NUEVO DE
#       4 DÍGITOS (9000 + código original, p. ej. 18 → 9018) y se INTEGRAN al
#       análisis como individuos propios.
#
# Las filas "sin codigo" no tienen llave de identidad y nunca son duplicados.
# La versión previa eliminaba en bloque las 5 filas con código compartido,
# tratando como duplicado lo que en 4 de 5 casos eran personas distintas
# (el sexo se invierte en los códigos 18 y 71). Aquí sólo se consolida el
# único duplicado real y se recuperan los 4 individuos perdidos.
# ----------------------------------------------------------------

TOL_EST <- 0.02   # metros

ids_comunes <- intersect(A$ID[A$ID != "sin codigo"], B$ID)
cat("IDs en común (código de catálogo):", length(ids_comunes), "-",
    paste(sort(as.numeric(ids_comunes)), collapse = ", "), "\n\n")

# Tabla de auditoría: una fila por código compartido con su veredicto.
auditoria <- do.call(rbind, lapply(ids_comunes, function(id) {
  a <- A %>% filter(ID == id) %>% slice(1)
  b <- B %>% filter(ID == id) %>% slice(1)
  sexo_ok <- identical(a$Sexo, b$Sexo)
  dEst    <- if (!is.na(a$Estatura) && !is.na(b$Estatura))
               abs(a$Estatura - b$Estatura) else NA_real_
  est_ok  <- !is.na(dEst) && dEst <= TOL_EST
  data.frame(
    ID            = id,
    clasificacion = ifelse(sexo_ok && est_ok, "MISMA_PERSONA", "DEMOGRAFIA_DISTINTA"),
    codigo_nuevo  = ifelse(sexo_ok && est_ok, NA_character_,
                           as.character(9000L + as.integer(id))),
    sexo_A = a$Sexo, sexo_B = b$Sexo,
    est_A  = a$Estatura, est_B = b$Estatura,
    edad_A = a$Edad, edad_B = b$Edad,
    origen_A = a$Lugar_origen, origen_B = b$Lugar_origen,
    dEst   = ifelse(is.na(dEst), NA_real_, round(dEst, 3)),
    stringsAsFactors = FALSE
  )
}))

for (i in seq_len(nrow(auditoria))) {
  r <- auditoria[i, ]
  cat(sprintf("  ID %-4s [%-18s] sexo %s→%s | est %s→%s | edad %s→%s | origen %s → %s%s\n",
              r$ID, r$clasificacion, r$sexo_A, r$sexo_B, r$est_A, r$est_B,
              r$edad_A, r$edad_B, r$origen_A, r$origen_B,
              ifelse(is.na(r$codigo_nuevo), "",
                     sprintf("  → código nuevo %s", r$codigo_nuevo))))
}

ids_misma_persona <- auditoria$ID[auditoria$clasificacion == "MISMA_PERSONA"]
ids_distintos     <- auditoria$ID[auditoria$clasificacion == "DEMOGRAFIA_DISTINTA"]

# (a) Individuos de DEMOGRAFÍA DISTINTA: se recuperan con código de 4 dígitos.
A_recuperados <- A %>%
  filter(ID %in% ids_distintos) %>%
  mutate(codigo_original     = ID,
         ID                  = as.character(9000L + as.integer(ID)),
         clasificacion_union = "demografia_distinta_recodificada")

# (b) Filas de la base de 41 que se conservan con su código original:
#     todas las "sin codigo" + las que no colisionan con un código validado.
#     Quedan fuera las MISMA_PERSONA (consolidadas en el registro validado).
A_propios <- A %>%
  filter(ID == "sin codigo" | !(ID %in% ids_comunes)) %>%
  mutate(codigo_original = ID, clasificacion_union = "unico")

cat(sprintf(paste0("\nCódigos compartidos: %d  →  misma persona (consolidados): %d  |  ",
                   "demografías distintas (recuperados con código 9xxx): %d\n\n"),
            length(ids_comunes), length(ids_misma_persona), length(ids_distintos)))

# ----------------------------------------------------------------
# 6. Unión final
# ----------------------------------------------------------------

col_order <- c("fuente", "Evaluador", "N Modelo", "ID", "codigo_original",
               "clasificacion_union", "Instrumento",
               "Edad", "Sexo", "Estatura", "Lugar_origen", cols_dentales)

B_out <- B %>% mutate(codigo_original = ID, clasificacion_union = "validado")

datos_unidos <- bind_rows(
  B_out         %>% select(any_of(col_order)),
  A_propios     %>% select(any_of(col_order)),
  A_recuperados %>% select(any_of(col_order))
) %>%
  arrange(suppressWarnings(as.numeric(ifelse(ID == "sin codigo", NA, ID))))

cat("=== Resultado final ===\n")
cat("Total filas:                  ", nrow(datos_unidos), "\n")
cat("De Mediciones_Estatura:       ",
    sum(datos_unidos$fuente == "Mediciones_Estatura"), "\n")
cat("De datos_limpios_validados:   ",
    sum(datos_unidos$fuente == "datos_limpios_validados"), "\n")
cat("  · recuperados (demografía distinta, código 9xxx):",
    sum(datos_unidos$clasificacion_union == "demografia_distinta_recodificada"), "\n")
cat("IDs únicos:                   ", n_distinct(datos_unidos$ID), "\n")
cat("Con Estatura conocida:        ", sum(!is.na(datos_unidos$Estatura)), "\n")
cat("Sin Estatura:                 ", sum(is.na(datos_unidos$Estatura)), "\n\n")

write.csv(datos_unidos, "resultados/datos_unidos_corregido.csv", row.names = FALSE)
cat("Guardado: resultados/datos_unidos_corregido.csv\n")

write.csv(auditoria, "resultados/auditoria_union_demografias.csv", row.names = FALSE)
cat("Guardado: resultados/auditoria_union_demografias.csv\n")

# ----------------------------------------------------------------
# 7. Gráficos de observación — base unificada
#   Paso crucial: verificar la composición de la muestra y auditar
#   visualmente la decisión de unión (qué códigos en común eran
#   individuos consistentes y cuáles demografías contradictorias).
#   Las figuras se guardan en reporte/figuras/.
# ----------------------------------------------------------------

dir_fig <- "reporte/figuras"
if (!dir.exists(dir_fig)) dir.create(dir_fig, recursive = TRUE)

COL_F <- "#F4A582"   # femenino
COL_M <- "#A8C5DA"   # masculino

# (a) Distribución de la estatura por sexo
#     (el sexo es el único predictor con poder real en este estudio).
est_F <- datos_unidos$Estatura[datos_unidos$Sexo == "F" & !is.na(datos_unidos$Estatura)]
est_M <- datos_unidos$Estatura[datos_unidos$Sexo == "M" & !is.na(datos_unidos$Estatura)]
brks  <- seq(floor(min(c(est_F, est_M)) / 0.05) * 0.05,
             ceiling(max(c(est_F, est_M)) / 0.05) * 0.05, by = 0.05)

# png(file.path(dir_fig, "union_estatura_por_sexo.png"), width = 1000, height = 700, res = 130)
par(mar = c(4.5, 4.5, 3, 1))
hist(est_F, breaks = brks, col = adjustcolor(COL_F, .6), border = "white",
     ylim = c(0, max(hist(est_F, breaks = brks, plot = FALSE)$counts,
                     hist(est_M, breaks = brks, plot = FALSE)$counts)),
     main = "Distribución de la estatura por sexo (base unificada)",
     xlab = "Estatura (m)", ylab = "Frecuencia")
hist(est_M, breaks = brks, col = adjustcolor(COL_M, .6), border = "white", add = TRUE)
abline(v = mean(est_F), col = COL_F, lwd = 2, lty = 2)
abline(v = mean(est_M), col = COL_M, lwd = 2, lty = 2)
legend("topright", c("Femenino", "Masculino"),
       fill = c(adjustcolor(COL_F, .6), adjustcolor(COL_M, .6)), bty = "n")
dev.off()

# (b) Composición de la muestra: fuente x sexo.
png(file.path(dir_fig, "union_composicion.png"), width = 1000, height = 700, res = 130)
par(mar = c(4.5, 4.5, 3, 1))
tab <- table(datos_unidos$Sexo, datos_unidos$fuente)
barplot(tab, beside = TRUE, col = c(COL_F, COL_M),
        legend.text = rownames(tab),
        args.legend = list(x = "topright", bty = "n"),
        ylab = "N.º de individuos",
        main = "Composición de la base unificada (fuente x sexo)")
dev.off()

# (c) Auditoría de la unión: para cada código compartido, diferencia de
#     estatura entre fuentes; rojo = demografía distinta (sexo invertido o
#     |Δestatura| > TOL_EST) recuperada con código 9xxx; gris = misma persona.
if (nrow(auditoria) > 0) {
  aud <- auditoria
  aud$dEst      <- ifelse(is.na(aud$dEst), 0, aud$dEst)
  aud$conflicto <- aud$clasificacion == "DEMOGRAFIA_DISTINTA"
  aud <- aud[order(-aud$dEst), ]

  png(file.path(dir_fig, "union_auditoria_conflictos.png"), width = 1000, height = 700, res = 130)
  par(mar = c(4.5, 4.5, 3, 1))
  bp <- barplot(aud$dEst, names.arg = aud$ID,
                col = ifelse(aud$conflicto, "#D6604D", "grey70"),
                ylab = "|Δ estatura entre fuentes| (m)", xlab = "Código de catálogo compartido",
                main = "Auditoría de la unión por código de catálogo")
  abline(h = TOL_EST, lty = 2, col = "grey40")
  text(max(bp), TOL_EST, sprintf("TOL = %.2f m", TOL_EST), pos = 3, cex = 0.8, col = "grey30")
  legend("topright", c("Demografía distinta (recuperada con código 9xxx)",
                       "Misma persona (consolidada)"),
         fill = c("#D6604D", "grey70"), bty = "n", cex = 0.85)
  dev.off()
}

cat("Figuras guardadas en", dir_fig, "(union_*.png)\n")
