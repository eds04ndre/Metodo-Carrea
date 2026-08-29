library(tidyverse)
library(readxl)

# =====================================================================
# MÉTODO DE CARREA (1920) - VALIDACIÓN DE DATOS
# =====================================================================
# Funciones:
# 1. Limpieza: Excluir ID 79 en cálculos relacionados a mm_13
# 2. Validación: Arco > Cuerda
# =====================================================================

# ==================== 1. CARGA DE DATOS ====================
estatura <- read_excel("data/Datos_Estatura.xlsx")
observadores <- read_excel("data/Datos_observadores.xlsx")

cat("  - Estatura: ", nrow(estatura), " filas\n")
cat("  - Observadores: ", nrow(observadores), " filas\n\n")

# ==================== 2. FUNCIÓN: LIMPIAR DATOS ====================
limpiar_datos <- function(df, id_excluir, columna_excluir) {
  # id_excluir: ID a excluir
  # columna_excluir: nombre de la columna a poner NA
  
  df_limpio <- df
  
  # Poner NA en la columna especificada para el ID excluido
  df_limpio <- df_limpio %>%
    mutate(
      !!columna_excluir := ifelse(ID == id_excluir, NA, !!rlang::sym(columna_excluir))
    )
  
  # Reportar cambios
  n_cambios <- sum(df$ID == id_excluir)
  cat("🧹 LIMPIEZA DE DATOS\n")
  cat("  ID 79 excluido de mm_13: ", n_cambios, " registros afectados\n\n")
  
  return(df_limpio)
}

# Aplicar limpieza
observadores <- limpiar_datos(observadores, id_excluir = 79, columna_excluir = "mm_13")

# ==================== 3. FUNCIÓN: VALIDAR ARCO > CUERDA ====================
validar_arco_cuerda <- function(df, col_arco, col_cuerda, nombre_par) {
  # col_arco: nombre columna del arco
  # col_cuerda: nombre columna de la cuerda
  # nombre_par: nombre del par para reportes
  
  cat("✓ VALIDACIÓN GEOMÉTRICA: ARCO > CUERDA\n")
  cat("  Par medido: ", nombre_par, "\n\n")
  
  # Extraer columnas
  arco <- df[[col_arco]]
  cuerda <- df[[col_cuerda]]
  
  # Validar que arco > cuerda (propiedad geométrica)
  validacion <- data.frame(
    ID = df$ID,
    Evaluador = df$Evaluador,
    Instrumento = df$Instrumento,
    Arco = arco,
    Cuerda = cuerda,
    Arco_Mayor = arco > cuerda,
    Diferencia = arco - cuerda
  )
  
  # Filtrar registros válidos e inválidos
  validos <- validacion %>% filter(Arco_Mayor == TRUE | is.na(Arco) | is.na(Cuerda))
  invalidos <- validacion %>% filter(Arco_Mayor == FALSE)
  
  # Reportes
  cat("  Total de observaciones: ", nrow(validacion), "\n")
  cat("  Registros válidos (Arco > Cuerda): ", nrow(validos), "\n")
  cat("  Registros inválidos (Arco ≤ Cuerda): ", nrow(invalidos), "\n")
  
  if (nrow(invalidos) > 0) {
    cat("\n  ⚠️  REGISTROS PROBLEMÁTICOS:\n")
    print(invalidos %>% select(ID, Evaluador, Instrumento, Arco, Cuerda, Diferencia))
  } else {
    cat("  ✓ Ningún registro problemático encontrado\n")
  }
  
  cat("\n")
  
  return(list(
    validacion = validacion,
    validos = nrow(validos),
    invalidos = nrow(invalidos)
  ))
}

# ==================== 4. APLICAR VALIDACIONES ====================

# Definir pares arco-cuerda según Carrea
# Arco: mm_13 (o mm_23, mm_43, mm_33) = suma de tres medidas
# Cuerda: medida directa (mm_11, mm_21, mm_41, mm_31)

# Validación 1: Par mandibular anterior (mm_13 vs mm_11)
val_1 <- validar_arco_cuerda(
  observadores,
  col_arco = "mm_13",
  col_cuerda = "mm_13_11",
  nombre_par = "mm_13 (arco) vs mm_11 (cuerda)"
)

# Validación 2: Par mandibular posterior (mm_23 vs mm_21)
val_2 <- validar_arco_cuerda(
  observadores,
  col_arco = "mm_23",
  col_cuerda = "mm_21",
  nombre_par = "mm_23 (arco) vs mm_21 (cuerda)"
)

# Validación 3: Par maxilar anterior (mm_43 vs mm_41)
val_3 <- validar_arco_cuerda(
  observadores,
  col_arco = "mm_43",
  col_cuerda = "mm_41",
  nombre_par = "mm_43 (arco) vs mm_41 (cuerda)"
)

# Validación 4: Par maxilar posterior (mm_33 vs mm_31)

val_4 <- validar_arco_cuerda(
  observadores,
  col_arco = "mm_33",
  col_cuerda = "mm_31",
  nombre_par = "mm_33 (arco) vs mm_31 (cuerda)"
)


resumen <- tibble(
  `Par Medido` = c(
    "mm_13 (Arco) > mm_11 (Cuerda)",
    "mm_23 (Arco) > mm_21 (Cuerda)",
    "mm_43 (Arco) > mm_41 (Cuerda)",
    "mm_33 (Arco) > mm_31 (Cuerda)"
  ),
  `Total Observaciones` = c(
    nrow(val_1$validacion),
    nrow(val_2$validacion),
    nrow(val_3$validacion),
    nrow(val_4$validacion)
  ),
  `Válidos` = c(
    val_1$validos,
    val_2$validos,
    val_3$validos,
    val_4$validos
  ),
  `Inválidos` = c(
    val_1$invalidos,
    val_2$invalidos,
    val_3$invalidos,
    val_4$invalidos
  ),
  `% Válidos` = c(
    round(100 * val_1$validos / nrow(val_1$validacion), 1),
    round(100 * val_2$validos / nrow(val_2$validacion), 1),
    round(100 * val_3$validos / nrow(val_3$validacion), 1),
    round(100 * val_4$validos / nrow(val_4$validacion), 1)
  )
)

print(resumen)

total_invalidos <- val_1$invalidos + val_2$invalidos + val_3$invalidos + val_4$invalidos



# Guardar csv
# write.csv(observadores, "data/datos_limpios_validados.csv", row.names = FALSE)
