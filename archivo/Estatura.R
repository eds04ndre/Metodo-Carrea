library(readxl)
datos <- read_excel("C:/Users/ASUS/Documents/Edson/Servicio Social/Datos_observadores.xlsx", sheet = "General_T")
estatura_real <- read_excel("Datos_Estatura.xlsx")
#Solo esta para m 11 
na<-names(datos)
data<-subset(datos,Evaluador==1&Instrumento=="Vernier")


library(dplyr)

medianas <- data %>%
  group_by(ID) %>%
  summarise(
    across(
      c(na[6:23]),   # agrega aquí más variables si quieres
      ~ median(.x, na.rm = TRUE),
      .names = "median_{.col}"
    )
  )

promedios <- data %>%
  group_by(ID) %>%
  summarise(
    across(
      c(na[6:23]),   # agrega aquí más variables si quieres
      ~ mean(.x, na.rm = TRUE),
      .names = "mean_{.col}"
    )
  )

summary(data)

data1<-as.data.frame(medianas)
data1<-as.data.frame(promedios)

# Maxilares
data1$range_mm_m11 <- data1$mean_mm_11 >= 7 & 
  data1$mean_mm_11 <= 10.6
data1$range_mm_m12 <- data1$mean_mm_12 >= 5.2 & 
  data1$mean_mm_12 <= 9.2
data1$range_mm_m13 <- data1$mean_mm_13 >= 6 & 
  data1$mean_mm_13 <= 10

# Mandibulares
data1$range_mm_m31 <- data1$mean_mm_31 >= 4.1 & 
  data1$mean_mm_31 <= 6.8
data1$range_mm_m32 <- data1$mean_mm_32 >= 4.7 & 
  data1$mean_mm_32 <= 7.8
data1$range_mm_m33 <- data1$mean_mm_33 >= 5.4 & 
  data1$mean_mm_33 <= 9


#nuevas variables 
data1$arco13_11<-data1$mean_mm_11+data1$mean_mm_12+data1$mean_mm_13
data1$arco23_21<-data1$mean_mm_21+data1$mean_mm_22+data1$mean_mm_23
data1$arco33_31<-data1$mean_mm_31+data1$mean_mm_32+data1$mean_mm_33
data1$arco43_41<-data1$mean_mm_41+data1$mean_mm_42+data1$mean_mm_43

# Agregamos los datos de la estatura
data1 <- data1 %>%
  left_join(estatura_real %>% select(ID, Estatura), by = "ID")

# Validación 1: arco13_11 > cuerda13_11
val1 <- data1$arco13_11 > data1$mean_mm_13_11
cat("1. arco13_11 > cuerda13_11:\n")
cat("   Válidos: ", sum(val1), "/", nrow(data1), " (", round(100*sum(val1)/nrow(data1), 1), "%)\n")
if (sum(!val1) > 0) cat("Inválidos: ID", data1$ID[!val1], "\n")

# Validación 2: arco23_21 > cuerda23_21
val2 <- data1$arco23_21 > data1$mean_mm_23_21
cat("2. arco23_21 > cuerda23_21:\n")
cat("   Válidos: ", sum(val2), "/", nrow(data1), " (", round(100*sum(val2)/nrow(data1), 1), "%)\n")
if (sum(!val2) > 0) cat("Inválidos: ID", data1$ID[!val2], "\n")

# Validación 3: arco33_31 > cuerda33_31
val3 <- data1$arco33_31 > data1$mean_mm_33_31
cat("3. arco33_31 > cuerda33_31: \n")
cat("   Válidos: ", sum(val3), "/", nrow(data1), " (", round(100*sum(val3)/nrow(data1), 1), "%)\n")
if (sum(!val3) > 0) cat("Inválidos: ID", data1$ID[!val3], "\n")

# Validación 4: arco43_41 > cuerda43_41
val4 <- data1$arco43_41 > data1$mean_mm_43_41
cat("4. arco43_41 > cuerda43_41 \n")
cat("   Válidos: ", sum(val4), "/", nrow(data1), " (", round(100*sum(val4)/nrow(data1), 1), "%)\n")
if (sum(!val4) > 0) cat("Inválidos: ID", data1$ID[!val4], "\n")


data1$T_Min13_11<-((data1$mean_mm_13_11)*(60)*(3.1416))/2
data1$T_Max13_11<-((data1$arco13_11)*(60)*(3.1416))/2

data1$T_Min23_21<-((data1$mean_mm_23_21)*(60)*(3.1416))/2
data1$T_Max23_21<-((data1$arco23_21)*(60)*(3.1416))/2

data1$T_Min33_31<-((data1$mean_mm_33_31)*(60)*(3.1416))/2
data1$T_Max33_31<-((data1$arco33_31)*(60)*(3.1416))/2

data1$T_Min43_41<-((data1$mean_mm_43_41)*(60)*(3.1416))/2
data1$T_Max43_41<-((data1$arco43_41)*(60)*(3.1416))/2

data1$Dentro_Rango <- data1$Estatura >= data1$T_Min43_41/1000 & 
                      data1$Estatura <= data1$T_Max43_41/1000

plot(data$)