# ================================================================
# Pipeline: union de datos - Etapa 4 (130 individuos, 3 observadores)
# Servicio Social - Edson Andre Cortes Silva
# ================================================================
# Fuente unica: data/Datos_estatura130.xlsx
#   - Hoja "Datos": demografia de 130 individuos (Numero_Asignado, Edad,
#     Sexo, Estatura, Origen).
#   - Hojas "O1"/"O2"/"O3": mediciones dentales del observador 1/2/3
#     (arcada maxilar y mandibular completas).
#
# A diferencia de la Etapa 3 (archivo/Union_limpieza.R), NO se combina con
# Mediciones_Estatura.csv / datos_limpios_validados.csv: esta es una base
# nueva y autocontenida.
#
# Orden de limpieza:
#   1. Nombres de columna homologados entre O1/O2/O3 (solo difiere
#      "N Modelo" vs "N_Modelo"; el resto son identicos caracter a caracter).
#   2. Instrumento normalizado a "Vernier" (variantes "Verniere"/"vernier").
#   3. Placeholder "0" en columnas de medida -> NA (no medido); outliers
#      inverosimiles (cuerda de hemiarcada > 35 mm, imposible geometricamente)
#      -> NA, con aviso en consola.
#   4. Filas "ID == sin codigo" (solo en O1, 6 filas) se excluyen: no se
#      pueden vincular a la demografia de la hoja "Datos".
#   5. ANTES DE PROMEDIAR: se eliminan los registros de individuos SIN
#      estatura conocida (16 NA + 1 "no hay datos" en la hoja Datos). Todo
#      el resto del pipeline (duplicados intra-observador, ICC, Carrea)
#      trabaja solo sobre los individuos con estatura conocida.
#   6. Replicas no marcadas dentro de un mismo observador (O1: ID 69-72
#      medidos 2 veces; O2: ID 92 medido 2 veces) se colapsan promediando
#      por (Evaluador, ID), para que cada observador aporte un solo valor.
#   7. Promedio entre observadores -> base principal por individuo.
# ================================================================

library(readxl)
library(dplyr)
library(tidyr)

RUTA <- "data/Datos_estatura130.xlsx"

nombres_limpios <- c(
  "Evaluador", "Observacion", "N_Modelo", "ID", "Instrumento",
  "mm_11", "mm_12", "mm_13", "mm_21", "mm_22", "mm_23",
  "mm_13_11", "mm_23_21", "intercanina_sup",
  "mm_41", "mm_42", "mm_43", "mm_31", "mm_32", "mm_33",
  "mm_43_41", "mm_33_31", "intercanina_inf"
)
cols_medida <- c("mm_11","mm_12","mm_13","mm_21","mm_22","mm_23",
                 "mm_13_11","mm_23_21","intercanina_sup",
                 "mm_41","mm_42","mm_43","mm_31","mm_32","mm_33",
                 "mm_43_41","mm_33_31","intercanina_inf")
cols_cuerda <- c("mm_13_11", "mm_23_21", "mm_43_41", "mm_33_31")
CUERDA_MAX_PLAUSIBLE <- 35  # mm; valor inverosimil (maximo observado en la muestra ~27 mm)

# ----------------------------------------------------------------
# 1. Demografia
# ----------------------------------------------------------------
datos <- read_excel(RUTA, sheet = "Datos") %>%
  transmute(
    ID       = as.integer(Número_Asignado),
    Edad     = as.numeric(Edad),
    Sexo,
    Estatura = as.numeric(gsub(",", ".", ifelse(Estatura == "no hay datos", NA, Estatura))),
    Origen   = na_if(trimws(Origen), "-")
  )

cat(sprintf("Datos: %d individuos | con Estatura: %d | con Sexo: %d | con Origen: %d\n",
            nrow(datos), sum(!is.na(datos$Estatura)), sum(!is.na(datos$Sexo)),
            sum(!is.na(datos$Origen))))

# ----------------------------------------------------------------
# 2. Mediciones por observador: nombres, instrumento, placeholders y
#    outliers inverosimiles (pasos 1-4)
# ----------------------------------------------------------------
leer_observador <- function(hoja, evaluador_esperado) {
  d <- read_excel(RUTA, sheet = hoja)
  names(d) <- nombres_limpios
  n_sin_codigo <- sum(d$ID == "sin codigo")
  d <- d %>% filter(ID != "sin codigo") %>% mutate(ID = as.integer(ID))
  stopifnot(all(d$Evaluador == evaluador_esperado))
  d <- d %>%
    mutate(Instrumento = "Vernier") %>%
    mutate(across(all_of(cols_medida), as.numeric)) %>%
    mutate(across(all_of(cols_medida), ~ na_if(., 0)))
  # Outlier inverosimil en columnas de cuerda (geometricamente imposible).
  for (cc in cols_cuerda) {
    malos <- which(d[[cc]] > CUERDA_MAX_PLAUSIBLE)
    if (length(malos) > 0) {
      cat(sprintf("  [%s] outlier inverosimil en %s: ID %s = %.2f mm -> NA\n",
                  hoja, cc, d$ID[malos], d[[cc]][malos]))
      d[[cc]][malos] <- NA
    }
  }
  cat(sprintf("%s: %d filas (%d 'sin codigo' excluidas), %d IDs unicos\n",
              hoja, nrow(d) + n_sin_codigo, n_sin_codigo, n_distinct(d$ID)))
  d
}

O1 <- leer_observador("O1", 1)
O2 <- leer_observador("O2", 2)
O3 <- leer_observador("O3", 3)

mediciones_largo <- bind_rows(O1, O2, O3) %>%
  left_join(datos, by = "ID")

# ----------------------------------------------------------------
# 3. ANTES DE PROMEDIAR: eliminar registros sin estatura conocida (paso 5)
# ----------------------------------------------------------------
n_antes <- nrow(mediciones_largo)
mediciones_largo <- mediciones_largo %>% filter(!is.na(Estatura))
cat(sprintf(
  "\nRegistros sin estatura eliminados: %d (%d -> %d filas). Individuos con estatura: %d\n",
  n_antes - nrow(mediciones_largo), n_antes, nrow(mediciones_largo), n_distinct(mediciones_largo$ID)))

# ----------------------------------------------------------------
# 4. Colapsar replicas no marcadas dentro de un mismo observador (paso 6)
# ----------------------------------------------------------------
n_replicas <- mediciones_largo %>% count(Evaluador, ID) %>% filter(n > 1)
if (nrow(n_replicas) > 0) {
  cat("\nReplicas colapsadas (mismo observador midio 2 veces al mismo individuo):\n")
  print(as.data.frame(n_replicas))
}

mediciones_por_observador <- mediciones_largo %>%
  group_by(Evaluador, ID) %>%
  summarise(across(all_of(cols_medida), ~ mean(., na.rm = TRUE)), .groups = "drop") %>%
  mutate(across(all_of(cols_medida), ~ ifelse(is.nan(.), NA_real_, .))) %>%
  left_join(datos, by = "ID")

cat(sprintf(
  "\nCobertura por observador (ya sin duplicados) -> O1: %d | O2: %d | O3: %d individuos\n",
  sum(mediciones_por_observador$Evaluador == 1),
  sum(mediciones_por_observador$Evaluador == 2),
  sum(mediciones_por_observador$Evaluador == 3)))

# ----------------------------------------------------------------
# 5. Promedio entre observadores (paso 7) -> dataset principal por individuo
# ----------------------------------------------------------------
promedio_individuo <- mediciones_por_observador %>%
  group_by(ID) %>%
  summarise(n_observadores = n(),
            across(all_of(cols_medida), ~ mean(., na.rm = TRUE)),
            .groups = "drop") %>%
  mutate(across(all_of(cols_medida), ~ ifelse(is.nan(.), NA_real_, .)))

datos_130 <- promedio_individuo %>%
  left_join(datos, by = "ID") %>%
  arrange(ID)

cat(sprintf(
  "\nBase por individuo (con estatura conocida): %d filas | medidos por 3 observadores: %d | por 2: %d | por 1: %d\n",
  nrow(datos_130), sum(datos_130$n_observadores == 3),
  sum(datos_130$n_observadores == 2), sum(datos_130$n_observadores == 1)))

# ----------------------------------------------------------------
# 6. Exportar
# ----------------------------------------------------------------
dir.create("resultados", showWarnings = FALSE)

write.csv(mediciones_por_observador, "resultados/datos_130_observadores.csv", row.names = FALSE)
cat("\nGuardado: resultados/datos_130_observadores.csv (una fila por observador x individuo)\n")

write.csv(datos_130, "resultados/datos_130_promedio.csv", row.names = FALSE)
cat("Guardado: resultados/datos_130_promedio.csv (promedio entre observadores, por individuo)\n")

# ----------------------------------------------------------------
# 7. Graficos de observacion - cobertura y composicion de la base nueva
# ----------------------------------------------------------------
dir_fig <- "reporte/figuras"
if (!dir.exists(dir_fig)) dir.create(dir_fig, recursive = TRUE)

COL_F <- "#F4A582"; COL_M <- "#A8C5DA"

png(file.path(dir_fig, "u130_cobertura_observadores.png"), width = 1000, height = 700, res = 130)
par(mar = c(4.5, 4.5, 3, 1))
barplot(table(datos_130$n_observadores), col = "#B2ABD2",
        xlab = "Numero de observadores con medicion valida", ylab = "Numero de individuos",
        main = "Cobertura por individuo (de 3 observadores posibles)")
dev.off()

est_F <- datos_130$Estatura[datos_130$Sexo == "F"]
est_M <- datos_130$Estatura[datos_130$Sexo == "M"]
brks  <- seq(floor(min(c(est_F, est_M)) / 0.05) * 0.05,
             ceiling(max(c(est_F, est_M)) / 0.05) * 0.05, by = 0.05)

png(file.path(dir_fig, "u130_estatura_por_sexo.png"), width = 1000, height = 700, res = 130)
par(mar = c(4.5, 4.5, 3, 1))
hist(est_F, breaks = brks, col = adjustcolor(COL_F, .6), border = "white",
     ylim = c(0, max(hist(est_F, breaks = brks, plot = FALSE)$counts,
                     hist(est_M, breaks = brks, plot = FALSE)$counts)),
     main = sprintf("Distribucion de la estatura por sexo (n=%d)", nrow(datos_130)),
     xlab = "Estatura (m)", ylab = "Frecuencia")
hist(est_M, breaks = brks, col = adjustcolor(COL_M, .6), border = "white", add = TRUE)
abline(v = mean(est_F), col = COL_F, lwd = 2, lty = 2)
abline(v = mean(est_M), col = COL_M, lwd = 2, lty = 2)
legend("topright", c("Femenino", "Masculino"),
       fill = c(adjustcolor(COL_F, .6), adjustcolor(COL_M, .6)), bty = "n")
dev.off()

png(file.path(dir_fig, "u130_composicion_origen.png"), width = 1000, height = 700, res = 130)
par(mar = c(7, 4.5, 3, 1))
tab_origen <- sort(table(ifelse(is.na(datos_130$Origen), "Desconocido", datos_130$Origen)), decreasing = TRUE)
barplot(tab_origen, las = 2, col = "#4393C3",
        ylab = "Numero de individuos", main = "Composicion de la muestra por lugar de origen")
dev.off()

cat("\nFiguras guardadas en", dir_fig, "(u130_*.png)\n")
