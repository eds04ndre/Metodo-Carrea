library(readr)
library(dplyr)

# read.csv(file.choose())
setwd("C:/Users/ASUS/Documents/Edson/Servicio Social/Repositorio")
getwd()
data <- read_csv("Estatura_Tesis.csv", show_col_types = FALSE)

summary(data)
data$min_derecho <-((data$`Radio-cuerda derecho`)*(60)*(3.1416))/2
data$Max_derecho <-((data$`Arco derecho`)*(60)*(3.1416))/20

data$min_izquierdo <-((data$`Radio-cuerda izquierdo`)*(60)*(3.1416))/2 
data$Max_izquierdo <-((data$`Arco izquierdo`)*(60)*(3.1416))/20

write.csv(data, "resultados_tesis.csv", row.names = FALSE)
