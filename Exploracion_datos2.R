# =============================================================================
# MÉTODO DE CARREA — Análisis por evaluador, instrumento y cuadrante
# =============================================================================

library(readxl)
library(dplyr)

setwd("C:/Users/ASUS/Documents/Edson/Servicio Social/Repositorio/")

RUTA_ESTATURA    <- "Mediciones_Estatura.xlsx"

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

# Columnas de arco y cuerda por cuadrante
# Arco    = suma de los tres dientes del cuadrante (mm13 + mm12 + mm11, etc.)
# Cuerda  = distancia intercanina ya registrada en los datos
CUADRANTE_COLS <- list(
  "13_11" = list(
    dientes = c("mm 13", "mm 12", "mm 11"),
    cuerda  = "mm 13 - 11"
  ),
  "23_21" = list(
    dientes = c("mm 23", "mm 22", "mm 21"),
    cuerda  = "mm 23 - 21"
  ),
  "33_31" = list(
    dientes = c("mm 33", "mm 32", "mm 31"),
    cuerda  = "mm 33 - 31"
  ),
  "43_41" = list(
    dientes = c("mm 43", "mm 42", "mm 41"),
    cuerda  = "mm 43 - 41"
  )
)

# =============================================================================
# CARGA DE DATOS
# =============================================================================

datos         <- read_excel(RUTA_ESTATURA, sheet = "Editado")
datos         <- as_tibble(datos)
datos$Estatura <- as.numeric(gsub(",", ".", datos$Estatura))
glimpse(estatura_real)
cols_medicion <- names(datos)[9:27]

# =============================================================================
# 3. FUNCIONES
# =============================================================================

# Filtra, promedia por ID y une con estatura real.
# Reemplaza mediciones de 0 con NA para no calcular estaturas inválidas.
preparar_datos <- function(datos, evaluador, cols){
  datos %>%
    filter(Evaluador == evaluador) %>%
    mutate(across(all_of(cols), ~ ifelse(.x == 0, NA, .x)))
}

preparar_datos(datos, "1", cols_medicion)

# Calcula arco, cuerda, estaturas estimadas y ejecuta las dos validaciones:
#   (1) arco > cuerda — condición geométrica obligatoria del método
#   (2) estatura real dentro del intervalo [est_min, est_max]
calcular_carrea <- function(datos, cuadrante, estatura_real) {
  
  info    <- CUADRANTE_COLS[[cuadrante]]
  d       <- info$dientes      # columnas de los tres dientes
  col_cuerda <- info$cuerda    # columna de distancia intercanina
  
  datos %>%
    mutate(
      # --- Medidas geométricas ---
      arco   = .data[[d[1]]] + .data[[d[2]]] + .data[[d[3]]],
      cuerda = .data[[col_cuerda]],
      
      # --- Validación 1: el arco debe ser mayor que la cuerda ---
      # Si no se cumple, la geometría del método no es válida para esa fila
      arco_valido = arco > cuerda,
      print(arco_valido)
      
      est_min = (cuerda * FACTOR_T),
      est_max = (arco   * FACTOR_T),
      
      # Estatura real adjuntada por posición (misma fila que el tibble filtrado)
      estatura_real = estatura_real,
      
      # --- Validación 2: la estatura real cae dentro del intervalo estimado ---
      estatura_en_rango = estatura_real >= est_min & estatura_real <= est_max
    ) %>%
    select(Evaluador, Instrumento, N modelo, cuadrante,
           arco, cuerda, arco_valido,
           est_min, est_max, estatura_real, estatura_en_rango)
}

# Imprime un resumen legible de las validaciones para un cuadrante dado
resumir_validaciones <- function(resultado, cuadrante) {
  
  n_total        <- nrow(resultado)
  n_arco_ok      <- sum(resultado$arco_valido,      na.rm = TRUE)
  n_estatura_ok  <- sum(resultado$estatura_en_rango, na.rm = TRUE)
  
  cat("─────────────────────────────────────────\n")
  cat(sprintf("Cuadrante: %s\n", cuadrante))
  cat(sprintf("  Arco > cuerda:              %d / %d\n", n_arco_ok,     n_total))
  cat(sprintf("  Estatura real en intervalo: %d / %d\n", n_estatura_ok, n_total))
  
  # Casos donde el arco NO supera la cuerda (posible error de medición)
  invalidos <- resultado %>% filter(!arco_valido)
  if (nrow(invalidos) > 0) {
    cat("  ⚠ IDs con arco ≤ cuerda:", paste(invalidos$ID, collapse = ", "), "\n")
  }
  
  # Casos donde la estatura real queda fuera del rango estimado
  fuera <- resultado %>% filter(!estatura_en_rango)
  if (nrow(fuera) > 0) {
    cat("  ⚠ IDs fuera del intervalo estimado:", paste(fuera$ID, collapse = ", "), "\n")
  }
}

# =============================================================================
# EJECUCIÓN — itera sobre evaluadores, instrumentos y cuadrantes
# =============================================================================
evaluadores   <- unique(datos$Evaluador)

# for (ev in evaluadores) {
  # for (cuad in CUADRANTES) {
    
    # Filtrar y limpiar el subconjunto correspondiente
    sub <- preparar_datos(datos, "1", cols_medicion)
    
    if (nrow(sub) == 0) next   # omitir combinaciones sin datos
    
    # Extraer estatura real del subconjunto filtrado
    est_sub <- as.numeric(gsub(",", ".", sub$Estatura))
    
    # Calcular arco, cuerda e intervalos; ejecutar validaciones
    # resultado <- calcular_carrea(sub, cuad, est_sub)
    resultado <- calcular_carrea(sub, CUADRANTES[1], est_sub)
    
    # Imprimir resumen de validaciones en consola
    cat(sprintf("\nEvaluador: %s | Instrumento: %s\n", ev, inst))
    resumir_validaciones(resultado, cuad)
    # }
# }
