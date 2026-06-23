# ============================================================
# Análisis del Método de Carrea - Estimación de Estatura
# Proyecto II Etapa 2 - Edson André Cortés Silva
# ============================================================

library(dplyr)

# ============================================================
# 1. CARGA Y LIMPIEZA DE DATOS
# ============================================================
# Nota: el archivo xlsx fue pre-procesado a CSV con Python
# para mantener compatibilidad con el entorno de ejecución.
# En un entorno con readxl instalado, usar:

setwd("C:/Users/ASUS/Documents/Edson/Servicio Social/Repositorio/")
df <- readxl::read_excel("data/Mediciones_Estatura.xlsx", sheet = "Editado")

# df <- read.csv("/home/claude/mediciones.csv", stringsAsFactors = FALSE, check.names = FALSE)

# Renombrar columnas para facilitar manejo
df <- df %>%
  mutate(across(all_of(names(df)[10:27]), ~ ifelse(.x == 0, NA, .x))) %>%
  rename(
    evaluador    = Evaluador,
    observacion  = `Obsevación`,
    n_modelo     = `N Modelo`,
    id           = ID,
    instrumento  = Instrumento,
    edad         = Edad,
    sexo         = Sexo,
    estatura_raw = Estatura,
    lugar_origen = Lugar_origen,
    mm11 = `mm 11`, mm12 = `mm 12`, mm13 = `mm 13`,
    mm21 = `mm 21`, mm22 = `mm 22`, mm23 = `mm 23`,
    mm41 = `mm 41`, mm42 = `mm 42`, mm43 = `mm 43`,
    mm31 = `mm 31`, mm32 = `mm 32`, mm33 = `mm 33`,
    cuerda_13_11 = `mm 13 - 11`,
    cuerda_23_21 = `mm 23 - 21`,
    cuerda_43_41 = `mm 43 - 41`,
    cuerda_33_31 = `mm 33 - 31`
  )
summary(df)
# Convertir estatura a numérico (manejar comas como separador decimal)
df$estatura <- as.numeric(gsub(",", ".", as.character(df$estatura_raw)))

# cat("Estaturas faltantes (NA):", sum(is.na(df$estatura)), "\n\n")

# T_min = (cuerda × 60 × π) / 2
# T_max = (arco  × 60 × π) / 2
# La constante k = (60 × π) / 2 = 30π
k <- 30 * pi

# ============================================================
# 3. FUNCIÓN: CALCULAR T_MIN Y T_MAX POR HEMIARCADA
#    Devuelve NA si algún diente de la hemiarcada es 0 o NA
# ============================================================

calcular_tmin_tmax <- function(d1, d2, d3, cuerda) {
  # d1 = incisivo central, d2 = incisivo lateral, d3 = canino
  # Si cualquiera de los tres dientes es 0 o NA → excluir hemiarcada
  if (any(is.na(c(d1, d2, d3, cuerda))) || any(c(d1, d2, d3) == 0)) {
    return(c(T_min = NA_real_, T_max = NA_real_))
  }
  arco     <- d1 + d2 + d3
  T_cuerda <- (cuerda * k) / 1000
  T_arco   <- (arco   * k) / 1000
  # Corrección: min/max por si hay inversión debida a error de medición
  T_min <- min(T_cuerda, T_arco)
  T_max <- max(T_cuerda, T_arco)
  return(c(T_min = T_min, T_max = T_max))
}

# ============================================================
# 4. APLICAR MÉTODO A LAS 4 HEMIARCADAS
# ============================================================

resultados <- df %>%
  rowwise() %>%
  mutate(
    # Hemiarcada 1: cuadrante 1 (superior derecho: 11, 12, 13)
    h1 = list(calcular_tmin_tmax(mm11, mm12, mm13, cuerda_13_11)),
    T_min_h1 = h1["T_min"], T_max_h1 = h1["T_max"],
    
    # Hemiarcada 2: cuadrante 2 (superior izquierdo: 21, 22, 23)
    h2 = list(calcular_tmin_tmax(mm21, mm22, mm23, cuerda_23_21)),
    T_min_h2 = h2["T_min"], T_max_h2 = h2["T_max"],
    
    # Hemiarcada 3: cuadrante 4 (inferior derecho: 41, 42, 43)
    h3 = list(calcular_tmin_tmax(mm41, mm42, mm43, cuerda_43_41)),
    T_min_h3 = h3["T_min"], T_max_h3 = h3["T_max"],
    
    # Hemiarcada 4: cuadrante 3 (inferior izquierdo: 31, 32, 33)
    h4 = list(calcular_tmin_tmax(mm31, mm32, mm33, cuerda_33_31)),
    T_min_h4 = h4["T_min"], T_max_h4 = h4["T_max"]
  ) %>%
  select(-h1, -h2, -h3, -h4) %>%
  ungroup()

# ============================================================
# 5. VALIDACIÓN: ¿LA ESTATURA REAL ESTÁ EN EL RANGO PREDICHO?
#    Por hemiarcada (solo si tiene datos válidos)
# ============================================================

resultados <- resultados %>%
  mutate(
    dentro_h1 = ifelse(!is.na(T_min_h1) & !is.na(estatura),
                       estatura >= T_min_h1 & estatura <= T_max_h1, NA),
    dentro_h2 = ifelse(!is.na(T_min_h2) & !is.na(estatura),
                       estatura >= T_min_h2 & estatura <= T_max_h2, NA),
    dentro_h3 = ifelse(!is.na(T_min_h3) & !is.na(estatura),
                       estatura >= T_min_h3 & estatura <= T_max_h3, NA),
    dentro_h4 = ifelse(!is.na(T_min_h4) & !is.na(estatura),
                       estatura >= T_min_h4 & estatura <= T_max_h4, NA)
  )

# ============================================================
# 6. REPORTE DETALLADO POR INDIVIDUO
# ============================================================

cat("=== RESULTADOS POR INDIVIDUO ===\n\n")
cat(sprintf("%-10s %-10s %-8s | %-20s %-20s %-20s %-20s\n",
            "N_Modelo", "ID", "Est.Real",
            "H1 (11-13) [min,max]", "H2 (21-23) [min,max]",
            "H3 (41-43) [min,max]", "H4 (31-33) [min,max]"))
cat(strrep("-", 120), "\n")

for (i in seq_len(nrow(resultados))) {
  r <- resultados[i, ]
  
  fmt_hemi <- function(tmin, tmax, dentro) {
    if (is.na(tmin)) return(sprintf("%-20s", "EXCLUIDA"))
    simbolo <- ifelse(isTRUE(dentro), "✓", "✗")
    sprintf("%-20s", sprintf("[%.3f, %.3f] %s", tmin, tmax, simbolo))
  }
  
  cat(sprintf("%-10s %-10s %-8.3f | %s %s %s %s\n",
              r$n_modelo, r$id, r$estatura,
              fmt_hemi(r$T_min_h1, r$T_max_h1, r$dentro_h1),
              fmt_hemi(r$T_min_h2, r$T_max_h2, r$dentro_h2),
              fmt_hemi(r$T_min_h3, r$T_max_h3, r$dentro_h3),
              fmt_hemi(r$T_min_h4, r$T_max_h4, r$dentro_h4)))
}

# ============================================================
# 7. RESUMEN POR HEMIARCADA
# ============================================================

cat("\n\n=== RESUMEN POR HEMIARCADA ===\n\n")

hemiarcadas <- list(
  "H1 - Cuadrante 1 (11, 12, 13)" = "dentro_h1",
  "H2 - Cuadrante 2 (21, 22, 23)" = "dentro_h2",
  "H3 - Cuadrante 3 (31, 32, 33)" = "dentro_h3",
  "H4 - Cuadrante 4 (41, 42, 43)" = "dentro_h4"
)

resumen_hemi <- data.frame()

for (nombre in names(hemiarcadas)) {
  col     <- hemiarcadas[[nombre]]
  vals    <- resultados[[col]]
  n_valid <- sum(!is.na(vals))
  n_excl  <- sum(is.na(vals))
  n_si    <- sum(vals == TRUE,  na.rm = TRUE)
  n_no    <- sum(vals == FALSE, na.rm = TRUE)
  pct     <- ifelse(n_valid > 0, round(n_si / n_valid * 100, 1), NA)
  
  cat(sprintf("%-40s | n válidos: %2d | excluidos: %d | dentro: %2d | fuera: %2d | Precisión: %.1f%%\n",
              nombre, n_valid, n_excl, n_si, n_no, pct))
  
  resumen_hemi <- rbind(resumen_hemi, data.frame(
    Hemiarcada = nombre, n_validos = n_valid, excluidos = n_excl,
    dentro = n_si, fuera = n_no, precision_pct = pct
  ))
}

# ============================================================
# 8. RESUMEN GLOBAL (individuo válido en ≥1 hemiarcada)
# ============================================================

cat("\n\n=== RESUMEN GLOBAL ===\n\n")

# Un individuo se clasifica como "dentro" si en AL MENOS UNA hemiarcada válida
# la estatura real cae dentro del rango (criterio de Carrea original)
resultados <- resultados %>%
  rowwise() %>%
  mutate(
    n_hemi_validas  = sum(!is.na(c(dentro_h1, dentro_h2, dentro_h3, dentro_h4))),
    n_hemi_dentro   = sum(c(dentro_h1, dentro_h2, dentro_h3, dentro_h4), na.rm = TRUE),
    dentro_alguna   = ifelse(n_hemi_validas > 0, n_hemi_dentro >= 1, NA),
    dentro_todas    = ifelse(n_hemi_validas > 0, n_hemi_dentro == n_hemi_validas, NA)
  ) %>%
  ungroup()

n_total    <- nrow(resultados)
n_evaluab  <- sum(resultados$n_hemi_validas > 0)
n_excl_tot <- n_total - n_evaluab

# Criterio "en al menos una hemiarcada"
n_dentro_alguna <- sum(resultados$dentro_alguna == TRUE, na.rm = TRUE)
n_fuera_alguna  <- sum(resultados$dentro_alguna == FALSE, na.rm = TRUE)
pct_alguna      <- round(n_dentro_alguna / n_evaluab * 100, 1)

# Criterio "en todas las hemiarcadas válidas"
n_dentro_todas <- sum(resultados$dentro_todas == TRUE, na.rm = TRUE)
n_fuera_todas  <- sum(resultados$dentro_todas == FALSE, na.rm = TRUE)
pct_todas      <- round(n_dentro_todas / n_evaluab * 100, 1)

cat(sprintf("Total de individuos en la base:               %d\n", n_total))
cat(sprintf("Individuos con al menos 1 hemiarcada válida:  %d\n", n_evaluab))
cat(sprintf("Individuos completamente excluidos:           %d\n\n", n_excl_tot))

cat("─── Criterio: estatura dentro en AL MENOS UNA hemiarcada ───\n")
cat(sprintf("  Dentro del rango:  %d / %d  →  %.1f%%\n", n_dentro_alguna, n_evaluab, pct_alguna))
cat(sprintf("  Fuera del rango:   %d / %d  →  %.1f%%\n\n", n_fuera_alguna, n_evaluab, 100 - pct_alguna))

cat("─── Criterio: estatura dentro en TODAS las hemiarcadas válidas ───\n")
cat(sprintf("  Dentro del rango:  %d / %d  →  %.1f%%\n", n_dentro_todas, n_evaluab, pct_todas))
cat(sprintf("  Fuera del rango:   %d / %d  →  %.1f%%\n\n", n_fuera_todas, n_evaluab, 100 - pct_todas))

# ============================================================
# 9. DESGLOSE POR SEXO
# ============================================================

cat("=== DESGLOSE POR SEXO (criterio: al menos una hemiarcada) ===\n\n")

for (s in c("F", "M")) {
  sub <- resultados %>% filter(sexo == s, n_hemi_validas > 0)
  n_s  <- nrow(sub)
  n_d  <- sum(sub$dentro_alguna == TRUE)
  pct  <- round(n_d / n_s * 100, 1)
  cat(sprintf("  Sexo %s | n = %2d | dentro: %2d | %.1f%%\n", s, n_s, n_d, pct))
}

cat("\n")

# ============================================================
# 10. TABLA FINAL COMPLETA (para exportar / revisar)
# ============================================================

tabla_final <- resultados %>%
  select(n_modelo, id, sexo, estatura,
         T_min_h1, T_max_h1, dentro_h1,
         T_min_h2, T_max_h2, dentro_h2,
         T_min_h3, T_max_h3, dentro_h3,
         T_min_h4, T_max_h4, dentro_h4,
         n_hemi_validas, n_hemi_dentro,
         dentro_alguna, dentro_todas) %>%
  mutate(across(where(is.numeric), ~round(., 4)))

write.csv(tabla_final, "resultados/resultados_carrea.csv", row.names = FALSE)
cat("Tabla exportada a: resultados/resultados_carrea.csv\n")

