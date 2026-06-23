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
# 5. Revisar IDs en común y RESOLVER por identidad de catálogo
#
# CORRECCIÓN respecto a la versión previa:
# El `ID` es el código de catálogo del modelo en AMBAS fuentes (en la base
# de 41, `N Modelo` es sólo el orden secuencial 1–41; el código real es `ID`,
# con "sin codigo" cuando se desconoce). Por tanto el cruce por ID SÍ compara
# identidades. El error previo estaba en la DECISIÓN: "si las medidas dentales
# difieren → conservar ambas filas". Eso trataba como variabilidad de medición
# lo que en 4 de 5 casos son DEMOGRAFÍAS CONTRADICTORIAS (el sexo se invierte
# en los códigos 18 y 71), es decir errores de integridad / personas distintas.
#
# Regla corregida: para cada código presente en ambas fuentes
#   - CONSISTENTE : mismo Sexo y |ΔEstatura| ≤ TOL_EST  → mismo individuo
#   - CONFLICTO   : el sexo difiere o |ΔEstatura| > TOL_EST → integridad rota
# En ambos casos se CONSERVA el registro validado (base de 13: réplicas
# promediadas + demografía dedicada) y se descarta la fila de la base de 41,
# eliminando el doble conteo y las demografías contradictorias. Los conflictos
# se imprimen para auditoría. Las filas "sin codigo" nunca son duplicados.
# ----------------------------------------------------------------

TOL_EST <- 0.02   # metros

ids_comunes <- intersect(A$ID[A$ID != "sin codigo"], B$ID)
cat("IDs en común (código de catálogo):", length(ids_comunes), "-",
    paste(sort(as.numeric(ids_comunes)), collapse = ", "), "\n\n")

for (id in ids_comunes) {
  a <- A %>% filter(ID == id) %>% slice(1)
  b <- B %>% filter(ID == id) %>% slice(1)
  sexo_ok <- identical(a$Sexo, b$Sexo)
  est_ok  <- !is.na(a$Estatura) && !is.na(b$Estatura) &&
             abs(a$Estatura - b$Estatura) <= TOL_EST
  estado  <- ifelse(sexo_ok && est_ok, "CONSISTENTE", "CONFLICTO")
  cat(sprintf("  ID %-4s [%-11s] sexo %s→%s | est %s→%s | origen %s → %s\n",
              id, estado, a$Sexo, b$Sexo, a$Estatura, b$Estatura,
              a$Lugar_origen, b$Lugar_origen))
}

# Se conservan TODOS los registros validados (B) y de A sólo los que no
# colisionan en código (incluye todos los "sin codigo").
A_filtrado <- A %>% filter(ID == "sin codigo" | !(ID %in% ids_comunes))
cat(sprintf("\nFilas de la base de 41 descartadas por duplicado de catálogo: %d\n\n",
            length(ids_comunes)))

# ----------------------------------------------------------------
# 6. Unión final
# ----------------------------------------------------------------

col_order <- c("fuente", "Evaluador", "N Modelo", "ID", "Instrumento",
               "Edad", "Sexo", "Estatura", "Lugar_origen", cols_dentales)

datos_unidos <- bind_rows(
  B          %>% select(any_of(col_order)),
  A_filtrado %>% select(any_of(col_order))
) %>%
  arrange(suppressWarnings(as.numeric(ifelse(ID == "sin codigo", NA, ID))))

cat("=== Resultado final ===\n")
cat("Total filas:                  ", nrow(datos_unidos), "\n")
cat("De Mediciones_Estatura:       ",
    sum(datos_unidos$fuente == "Mediciones_Estatura"), "\n")
cat("De datos_limpios_validados:   ",
    sum(datos_unidos$fuente == "datos_limpios_validados"), "\n")
cat("IDs únicos:                   ", n_distinct(datos_unidos$ID), "\n")
cat("Con Estatura conocida:        ", sum(!is.na(datos_unidos$Estatura)), "\n")
cat("Sin Estatura:                 ", sum(is.na(datos_unidos$Estatura)), "\n\n")

write.csv(datos_unidos, "resultados/datos_unidos_corregido.csv", row.names = FALSE)
cat("Guardado: resultados/datos_unidos_corregido.csv\n")
