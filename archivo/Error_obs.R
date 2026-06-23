library(readxl)
datos <- read_excel("C:/Users/ASUS/Documents/Edson/Servicio Social/Datos_observadores.xlsx", sheet = "General_T")
#Solo esta para m 11 
# datos<-subset(datos,Evaluador==1|Evaluador==2)
names(datos)
me<- names(datos[23]) # 6-23

library(dplyr)
datos <- datos %>%
  mutate(
    Evaluador = factor(Evaluador),
    Observación = factor(Obsevación),
    Instrumento = factor(Instrumento)
  )

library(tidyr)
library(irr)

icc_inter <- datos %>%
  group_by(Instrumento, Obsevación) %>%
  do({
    wide <- pivot_wider(
      .,
      id_cols = ID,
      names_from = Evaluador,
      values_from = me
    )
    
    icc_res <- icc(
      wide[,-1],                 # columnas = evaluadores
      model = "twoway",
      type  = "agreement",
      unit  = "single"
    )
    
    data.frame(
      ICC = icc_res$value,
      LCI = icc_res$lbound,
      UCI = icc_res$ubound
    )
  })

icc_inter #Los valores de ICC son mejores para el vernier  


#TEM de la medida 
tem_inter <- datos %>%
  group_by(ID, Instrumento, Obsevación) %>%
  summarise(
    sd_eval = sd(.data[[me]]),
    .groups = "drop"
  ) %>%
  summarise(
    TEM = sqrt(mean(sd_eval^2))
  )


#Tem Instrumentos
tem_inter_instr <- datos %>%
  group_by(ID, Instrumento, Obsevación) %>%
  summarise(sd_eval = sd(.data[[me]]), .groups = "drop") %>%
  group_by(Instrumento) %>%
  summarise(
    TEM = sqrt(mean(sd_eval^2))
  )


#Error intra-observador (TEM) por evaluador
#Se calcula comparando tiempo 1 vs tiempo 2 del mismo evaluador, para el mismo individuo e instrumento.

library(dplyr)
library(tidyr)

tem_intra <- datos %>%
  pivot_wider(
    id_cols = c(ID, Evaluador, Instrumento),
    names_from = Obsevación,
    values_from = me,
    names_prefix = "T"
  ) %>%
  mutate(
    d = T1 - T2
  ) %>%
  group_by(Evaluador, Instrumento) %>%
  summarise(
    n = n(),
    TEM = sqrt(sum(d^2) / (2 * n)),
    .groups = "drop"
  )

me
print("ICC")
icc_inter 
print("TEM medida")
tem_inter
print("TEM instrumento")
tem_inter_instr
print("TEM evaluador")
tem_intra 


