# =============================================================================
# MÉTODO DE CARREA — Análisis por evaluador, instrumento y cuadrante
# =============================================================================

library(readxl)
library(dplyr)

RUTA_DATOS    <- "data/Datos_observadores.xlsx"
RUTA_ESTATURA <- "data/Datos_Estatura.xlsx"

EVALUADORES   <- c(1, 2, 3)
INSTRUMENTOS  <- c("Vernier", "Calibrador")

# Cuadrantes disponibles: "13_11" | "23_21" | "33_31" | "43_41"
CUADRANTES    <- c("13_11", "23_21", "33_31", "43_41")

FACTOR_T      <- (60 * pi) / 2

# Rangos clínicos de referencia por diente
RANGOS <- list(
  mm_11 = c(7.0, 10.6), mm_12 = c(5.2,  9.2), mm_13 = c(6.0, 10.0),
  mm_31 = c(4.1,  6.8), mm_32 = c(4.7,  7.8), mm_33 = c(5.4,  9.0)
)

# Dientes que componen cada cuadrante
DIENTES_CUADRANTE <- list(
  "13_11" = c("mean_mm_11", "mean_mm_12", "mean_mm_13"),
  "23_21" = c("mean_mm_21", "mean_mm_22", "mean_mm_23"),
  "33_31" = c("mean_mm_31", "mean_mm_32", "mean_mm_33"),
  "43_41" = c("mean_mm_41", "mean_mm_42", "mean_mm_43")
)

# =============================================================================
# 2. CARGA DE DATOS
# =============================================================================

datos         <- read_excel(RUTA_DATOS, sheet = "General_T")
estatura_real <- read_excel(RUTA_ESTATURA)
cols_medicion <- names(datos)[6:23]

# =============================================================================
# 3. FUNCIONES
# =============================================================================

# Filtra, promedia por ID y une con estatura real.
# Reemplaza mediciones de 0 con NA para no calcular estaturas inválidas.
preparar_datos <- function(datos, estatura, evaluador, instrumento, cols) {
  datos %>%
    filter(Evaluador == evaluador, Instrumento == instrumento) %>%
    mutate(across(all_of(cols), ~ ifelse(.x == 0, NA, .x))) %>%
    group_by(ID) %>%
    summarise(across(all_of(cols), ~ mean(.x, na.rm = TRUE), .names = "mean_{.col}"),
              .groups = "drop") %>%
    left_join(estatura %>% select(ID, Estatura), by = "ID") %>%
    as.data.frame()
}

# Agrega columnas de rango clínico (TRUE/FALSE) por diente.
agregar_rangos <- function(df, rangos) {
  for (diente in names(rangos)) {
    col <- paste0("mean_", diente)
    if (col %in% names(df)) {
      df[[paste0("range_", diente)]] <- df[[col]] >= rangos[[diente]][1] &
        df[[col]] <= rangos[[diente]][2]
    }
  }
  df
}

# Calcula columnas de arco (suma de dientes por cuadrante).
agregar_arcos <- function(df, dientes_cuad) {
  for (cuad in names(dientes_cuad)) {
    cols <- dientes_cuad[[cuad]]
    if (all(cols %in% names(df)))
      df[[paste0("arco", cuad)]] <- rowSums(df[, cols], na.rm = FALSE)
  }
  df
}

# Valida arco > cuerda e imprime resumen.
validar_arco_cuerda <- function(df, cuad) {
  col_arco   <- paste0("arco", cuad)
  col_cuerda <- paste0("mean_mm_", cuad)
  if (!all(c(col_arco, col_cuerda) %in% names(df))) return(invisible(NULL))
  
  valido <- df[[col_arco]] > df[[col_cuerda]]
  n      <- sum(!is.na(valido))
  cat(sprintf("  arco%s > cuerda%s: %d/%d válidos (%.1f%%)\n",
              cuad, cuad, sum(valido, na.rm = TRUE), n,
              100 * mean(valido, na.rm = TRUE)))
  ids_inv <- df$ID[!is.na(valido) & !valido]
  if (length(ids_inv) > 0) cat("    Inválidos ID:", ids_inv, "\n")
}

# Calcula T_Min y T_Max (en mm) para cada cuadrante.
agregar_T <- function(df, dientes_cuad, factor) {
  for (cuad in names(dientes_cuad)) {
    col_cuerda <- paste0("mean_mm_", cuad)
    col_arco   <- paste0("arco", cuad)
    if (all(c(col_cuerda, col_arco) %in% names(df))) {
      df[[paste0("T_Min", cuad)]] <- df[[col_cuerda]] * factor
      df[[paste0("T_Max", cuad)]] <- df[[col_arco]]   * factor
    }
  }
  df
}

# Valida si la estatura real cae dentro del rango estimado por cuadrante.
# Convierte T_Min/T_Max de mm a metros (/1000) para comparar con Estatura.
validar_estatura <- function(df, cuad) {
  tmin <- paste0("T_Min", cuad)
  tmax <- paste0("T_Max", cuad)
  if (!all(c(tmin, tmax, "Estatura") %in% names(df))) return(df)
  
  df[[paste0("Dentro_Rango_", cuad)]] <-
    df$Estatura >= df[[tmin]] / 1000 &
    df$Estatura <= df[[tmax]] / 1000
  df
}

# Correlación de Pearson entre medidas dentales (arcos/cuerdas) y estatura.
correlacion_dental_estatura <- function(df, cuadrantes) {
  vars_num <- c(
    paste0("arco",     cuadrantes),
    paste0("mean_mm_", cuadrantes)
  )
  vars_num <- vars_num[vars_num %in% names(df)]
  
  cat("  Correlación con Estatura real:\n")
  for (v in vars_num) {
    r <- cor(df[[v]], df$Estatura, use = "complete.obs")
    cat(sprintf("    %-25s r = %.3f\n", v, r))
  }
}

# Resumen de validación de estatura dentro del rango estimado por cuadrante.
resumen_dentro_rango <- function(df, cuadrantes) {
  cat("  Estatura dentro del rango estimado:\n")
  for (cuad in cuadrantes) {
    col <- paste0("Dentro_Rango_", cuad)
    if (col %in% names(df)) {
      n <- sum(!is.na(df[[col]]))
      cat(sprintf("    Cuadrante %s: %d/%d (%.1f%%)\n",
                  cuad,
                  sum(df[[col]], na.rm = TRUE), n,
                  100 * mean(df[[col]], na.rm = TRUE)))
    }
  }
}

# =============================================================================
# 4. PIPELINE PRINCIPAL — Itera sobre todas las combinaciones
# =============================================================================

resultados <- list()

for (ev in EVALUADORES) {
  for (inst in INSTRUMENTOS) {
    
    etiqueta <- sprintf("Evaluador %d | %s", ev, inst)
    cat("\n", strrep("=", 55), "\n", etiqueta, "\n", strrep("=", 55), "\n")
    
    # --- Preparación ---
    df <- preparar_datos(datos, estatura_real, ev, inst, cols_medicion)
    
    if (nrow(df) == 0) {
      cat("  Sin datos para esta combinación.\n")
      next
    }
    
    # --- Enriquecimiento ---
    df <- agregar_rangos(df, RANGOS)
    df <- agregar_arcos(df, DIENTES_CUADRANTE)
    df <- agregar_T(df, DIENTES_CUADRANTE, FACTOR_T)
    for (cuad in CUADRANTES) df <- validar_estatura(df, cuad)
    
    # --- Validaciones geométricas ---
    cat("Validaciones arco > cuerda:\n")
    for (cuad in CUADRANTES) validar_arco_cuerda(df, cuad)
    
    # --- Estatura dentro de rango ---
    resumen_dentro_rango(df, CUADRANTES)
    
    # --- Correlaciones ---
    correlacion_dental_estatura(df, CUADRANTES)
    
    # Guardar resultado
    resultados[[paste(ev, inst, sep = "_")]] <- df
  }
}

# ======================================================= 
#   Evaluador 1 | Vernier 
# ======================================================= 
#   Validaciones arco > cuerda:
#   arco13_11 > cuerda13_11: 5/12 válidos (41.7%)
# Inválidos ID: 27 50 55 60 71 95 116 
# arco23_21 > cuerda23_21: 8/13 válidos (61.5%)
# Inválidos ID: 3 18 50 60 71 
# arco33_31 > cuerda33_31: 7/13 válidos (53.8%)
# Inválidos ID: 3 14 55 60 71 130 
# arco43_41 > cuerda43_41: 9/13 válidos (69.2%)
# Inválidos ID: 18 55 60 71 
# Estatura dentro del rango estimado:
#   Cuadrante 13_11: 0/12 (0.0%)
# Cuadrante 23_21: 0/13 (0.0%)
# Cuadrante 33_31: 2/13 (15.4%)
# Cuadrante 43_41: 2/13 (15.4%)
# Correlación con Estatura real:
#   arco13_11               r = 0.022
# arco23_21                 r = 0.261
# arco33_31                 r = 0.308
# arco43_41                 r = 0.377
# mean_mm_13_11             r = 0.107
# mean_mm_23_21             r = 0.346
# mean_mm_33_31             r = 0.240
# mean_mm_43_41             r = 0.230
# 
# ======================================================= 
#   Evaluador 1 | Calibrador 
# ======================================================= 
#   Validaciones arco > cuerda:
#   arco13_11 > cuerda13_11: 7/12 válidos (58.3%)
# Inválidos ID: 55 71 76 95 116 
# arco23_21 > cuerda23_21: 7/13 válidos (53.8%)
# Inválidos ID: 3 18 50 55 60 71 
# arco33_31 > cuerda33_31: 8/13 válidos (61.5%)
# Inválidos ID: 55 60 71 79 130 
# arco43_41 > cuerda43_41: 9/13 válidos (69.2%)
# Inválidos ID: 3 18 71 116 
# Estatura dentro del rango estimado:
#   Cuadrante 13_11: 0/12 (0.0%)
# Cuadrante 23_21: 1/13 (7.7%)
# Cuadrante 33_31: 4/13 (30.8%)
# Cuadrante 43_41: 4/13 (30.8%)
# Correlación con Estatura real:
#   arco13_11                 r = 0.082
# arco23_21                 r = 0.421
# arco33_31                 r = 0.395
# arco43_41                 r = 0.249
# mean_mm_13_11             r = 0.136
# mean_mm_23_21             r = 0.046
# mean_mm_33_31             r = 0.419
# mean_mm_43_41             r = 0.291
# 
# ======================================================= 
#   Evaluador 2 | Vernier 
# ======================================================= 
#   Validaciones arco > cuerda:
#   arco13_11 > cuerda13_11: 8/12 válidos (66.7%)
# Inválidos ID: 3 50 55 60 
# arco23_21 > cuerda23_21: 9/13 válidos (69.2%)
# Inválidos ID: 3 50 55 60 
# arco33_31 > cuerda33_31: 11/13 válidos (84.6%)
# Inválidos ID: 3 60 
# arco43_41 > cuerda43_41: 9/13 válidos (69.2%)
# Inválidos ID: 3 18 55 60 
# Estatura dentro del rango estimado:
#   Cuadrante 13_11: 0/12 (0.0%)
# Cuadrante 23_21: 0/13 (0.0%)
# Cuadrante 33_31: 4/13 (30.8%)
# Cuadrante 43_41: 4/13 (30.8%)
# Correlación con Estatura real:
#   arco13_11                 r = -0.070
# arco23_21                 r = 0.235
# arco33_31                 r = 0.316
# arco43_41                 r = 0.236
# mean_mm_13_11             r = -0.095
# mean_mm_23_21             r = 0.260
# mean_mm_33_31             r = 0.394
# mean_mm_43_41             r = -0.017
# 
# ======================================================= 
#   Evaluador 2 | Calibrador 
# ======================================================= 
#   Validaciones arco > cuerda:
#   arco13_11 > cuerda13_11: 5/12 válidos (41.7%)
# Inválidos ID: 14 27 50 55 60 95 130 
# arco23_21 > cuerda23_21: 5/13 válidos (38.5%)
# Inválidos ID: 3 14 27 50 55 60 71 95 
# arco33_31 > cuerda33_31: 12/13 válidos (92.3%)
# Inválidos ID: 79 
# arco43_41 > cuerda43_41: 8/13 válidos (61.5%)
# Inválidos ID: 3 14 55 60 71 
# Estatura dentro del rango estimado:
#   Cuadrante 13_11: 0/12 (0.0%)
# Cuadrante 23_21: 0/13 (0.0%)
# Cuadrante 33_31: 4/13 (30.8%)
# Cuadrante 43_41: 2/13 (15.4%)
# Correlación con Estatura real:
#   arco13_11                 r = -0.181
# arco23_21                 r = 0.510
# arco33_31                 r = 0.427
# arco43_41                 r = 0.515
# mean_mm_13_11             r = 0.146
# mean_mm_23_21             r = 0.450
# mean_mm_33_31             r = 0.404
# mean_mm_43_41             r = 0.110
# 
# ======================================================= 
#   Evaluador 3 | Vernier 
# ======================================================= 
#   Validaciones arco > cuerda:
#   arco13_11 > cuerda13_11: 6/12 válidos (50.0%)
# Inválidos ID: 50 55 60 95 116 130 
# arco23_21 > cuerda23_21: 7/13 válidos (53.8%)
# Inválidos ID: 3 50 55 71 79 130 
# arco33_31 > cuerda33_31: 9/13 válidos (69.2%)
# Inválidos ID: 55 60 79 130 
# arco43_41 > cuerda43_41: 12/13 válidos (92.3%)
# Inválidos ID: 76 
# Estatura dentro del rango estimado:
#   Cuadrante 13_11: 0/12 (0.0%)
# Cuadrante 23_21: 0/13 (0.0%)
# Cuadrante 33_31: 2/13 (15.4%)
# Cuadrante 43_41: 5/13 (38.5%)
# Correlación con Estatura real:
#   arco13_11                 r = 0.009
# arco23_21                 r = 0.190
# arco33_31                 r = 0.297
# arco43_41                 r = 0.355
# mean_mm_13_11             r = 0.476
# mean_mm_23_21             r = 0.353
# mean_mm_33_31             r = 0.458
# mean_mm_43_41             r = 0.096
# 
# ======================================================= 
#   Evaluador 3 | Calibrador 
# ======================================================= 
#   Validaciones arco > cuerda:
#   arco13_11 > cuerda13_11: 3/12 válidos (25.0%)
# Inválidos ID: 3 27 50 55 60 71 76 95 130 
# arco23_21 > cuerda23_21: 4/13 válidos (30.8%)
# Inválidos ID: 3 18 27 50 55 60 71 95 130 
# arco33_31 > cuerda33_31: 6/13 válidos (46.2%)
# Inválidos ID: 3 27 55 60 71 79 130 
# arco43_41 > cuerda43_41: 6/13 válidos (46.2%)
# Inválidos ID: 3 18 55 76 79 116 130 
# Estatura dentro del rango estimado:
#   Cuadrante 13_11: 0/12 (0.0%)
# Cuadrante 23_21: 0/13 (0.0%)
# Cuadrante 33_31: 2/13 (15.4%)
# Cuadrante 43_41: 1/13 (7.7%)
# Correlación con Estatura real:
#   arco13_11                 r = 0.170
# arco23_21                 r = 0.614
# arco33_31                 r = 0.157
# arco43_41                 r = 0.073
# mean_mm_13_11             r = 0.294
# mean_mm_23_21             r = 0.572
# mean_mm_33_31             r = 0.476
# mean_mm_43_41             r = 0.097
