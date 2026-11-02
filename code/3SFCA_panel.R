


setwd("C:/Users/Utente/Dropbox/Debiaes_fusco/Dati/Database")



load("DB_finale_distanze_stazione.RData")
DB_finale

names(DB_finale)

colnames(DB_finale)[8] <- "PRO_COM"


DB_finale$Duration_min<-DB_finale$Duration_min*60


unique(DB_finale$PRO_COM_com)




DB_finale_2016<-DB_finale
DB_finale_2017<-DB_finale
DB_finale_2018<-DB_finale
DB_finale_2019<-DB_finale
DB_finale_2020<-DB_finale
DB_finale_2021<-DB_finale
DB_finale_2022<-DB_finale
DB_finale_2023<-DB_finale
DB_finale_2024<-DB_finale







DB_finale_2016$anno<-2016
DB_finale_2017$anno<-2017
DB_finale_2018$anno<-2018
DB_finale_2019$anno<-2019
DB_finale_2020$anno<-2020
DB_finale_2021$anno<-2021
DB_finale_2022$anno<-2022
DB_finale_2023$anno<-2023
DB_finale_2024$anno<-2024











DB_finale_tot<-rbind(
  DB_finale_2016,
  DB_finale_2017,
  DB_finale_2018,
  DB_finale_2019,
  DB_finale_2020,
  DB_finale_2021,
  DB_finale_2022,
  DB_finale_2023,
  DB_finale_2024
)





DB_finale<-filter(DB_finale, DB_finale$Duration_min<=60)






load("dip_indip_panel.RData")
load("Covariate_panel.RData")





table(db_controlli_3$Popolazione_fine_Totale.x, db_controlli_3$anno)



variabili_principali
db_controlli_3


nrow(DB_finale_tot)
nrow(variabili_principali)
nrow(db_controlli_3)






library(dplyr)
library(sf)



DB_long <- DB_finale %>%
  inner_join(
    db_controlli_3 %>%
      st_drop_geometry() %>%          # 👈 rimuove la colonna geometry
      select(everything()),
    by = c("PRO_COM_com" = "PRO_COM")
  )%>%
  # 2️⃣ unisci le info della stazione
  left_join(
    variabili_principali %>%
      select(SEDE_TECNICA_DEF, CLUSTER_NUM, NUOVA_CLASSIFICAZIONE, anno),
    by = c("SEDE_TECNICA_DEF", "anno")            # <-- Stazione
  )















quantile(DB_long$Duration_min, probs = seq(0, 1, 0.2), na.rm = TRUE)







str(DB_long)










library(dplyr)

DB_long <- DB_long %>%
  mutate(
    fascia_accesso = cut(
      Duration_min,
      breaks = c(-Inf, 16.22, 22, 26.50, 31.61, Inf),
      labels = c("zona1", "zona2", "zona3", "zona4", "zona5"),
      right = TRUE
    )
  )
















DB_long <- DB_long %>%
  mutate(
    peso_fascia = case_when(
      fascia_accesso == "zona1" ~ 1.0,
      fascia_accesso == "zona2" ~ 0.8,
      fascia_accesso == "zona3" ~ 0.6,
      fascia_accesso == "zona4" ~ 0.4,
      fascia_accesso == "zona5" ~ 0.2,
      TRUE ~ NA_real_
    )
  )






x<-data.frame(DB_long$tasso_motorizzazione, DB_long$anno)

table(DB_long$tasso_motorizzazione, DB_long$anno)



mediana_motorizzazione <- DB_long %>%
  filter(anno %in% c(2021, 2022), !is.na(tasso_motorizzazione)) %>%
  summarise(mediana = median(tasso_motorizzazione, na.rm = TRUE)) %>%
  pull(mediana)

DB_long <- DB_long %>%
  mutate(
    tasso_motorizzazione = ifelse(
      anno %in% c(2023, 2024) & is.na(tasso_motorizzazione),
      mediana_motorizzazione,
      tasso_motorizzazione
    )
  )



table(DB_long$tasso_motorizzazione)



DB_long<-filter(DB_long, !is.na(DB_long$tasso_motorizzazione))


x<-data.frame(DB_long$tasso_motorizzazione, DB_long$anno, DB_long$comuni)





DB_long<-filter(DB_long, !is.na(DB_long$tasso_motorizzazione))







unique(DB_long$CLUSTER_NUM)




R_i_popolazione_intervalli <- DB_long %>%
  group_by(SEDE_TECNICA_DEF, anno) %>%
  summarise(
    domanda_pesata_popolazione_intervalli = sum(Popolazione_fine_Totale.x * tasso_motorizzazione * peso_fascia, na.rm = TRUE),
    S_i_popolazione_intervalli = mean(CLUSTER_NUM, na.rm = TRUE),
    R_i_popolazione_intervalli = S_i_popolazione_intervalli / domanda_pesata_popolazione_intervalli
  )












#
#
#R_i_popolazione_cluster <- DB_long %>%
#  group_by(SEDE_TECNICA_DEF, anno) %>%
#  summarise(
#    domanda_pesata_popolazione_cluster = sum(Popolazione_fine_Totale.x * tasso_motorizzazione * peso_fascia, na.rm = TRUE),
#    S_i_popolazione_cluster = mean(NUOVA_CLASSIFICAZIONE.y, na.rm = TRUE),
#    R_i_popolazione_cluster = S_i_popolazione_intervalli / domanda_pesata_popolazione_cluster
#  )
#
#
#
#
#
#
#
#
#
#R_i_densita_intervalli <- DB_long %>%
#  group_by(SEDE_TECNICA_DEF, anno) %>%
#  summarise(
#    domanda_densita_pesata_intervalli = sum(densita * tasso_motorizzazione * peso_fascia, na.rm = TRUE),
#    S_i_densita_intervalli = mean(CLUSTER_NUM, na.rm = TRUE),
#    R_i_densita_intervalli = S_i_popolazione_intervalli / domanda_densita_pesata_intervalli
#  )
#
#
#



#############################################################
### CREAZIONE DB VUOTI PER EVITARE ERRORI
#############################################################

# --- R_i_popolazione_cluster (vuoto ma coerente)
R_i_popolazione_cluster <- DB_long %>%
  group_by(SEDE_TECNICA_DEF, anno) %>%
  summarise(
    domanda_pesata_popolazione_cluster = sum(Popolazione_fine_Totale.x * tasso_motorizzazione * peso_fascia, na.rm = TRUE),
    S_i_popolazione_cluster = mean(NUOVA_CLASSIFICAZIONE.y, na.rm = TRUE),
    R_i_popolazione_cluster = NA_real_     # 👈 colonna vuota
  )

# --- R_i_densita_intervalli (vuoto ma coerente)
R_i_densita_intervalli <- DB_long %>%
  group_by(SEDE_TECNICA_DEF, anno) %>%
  summarise(
    domanda_densita_pesata_intervalli = sum(densita * tasso_motorizzazione * peso_fascia, na.rm = TRUE),
    S_i_densita_intervalli = mean(CLUSTER_NUM, na.rm = TRUE),
    R_i_densita_intervalli = NA_real_      # 👈 colonna vuota
  )






R_i_densita_cluster <- DB_long %>%
  group_by(SEDE_TECNICA_DEF, anno) %>%
  summarise(
    domanda_pesata_densita_cluster = sum(densita * tasso_motorizzazione * peso_fascia, na.rm = TRUE),
    S_i_densita_cluster = mean(NUOVA_CLASSIFICAZIONE.y, na.rm = TRUE),
    R_i_densita_cluster = (S_i_densita_cluster*365) / domanda_pesata_densita_cluster
  )
















R_i_combined <- R_i_popolazione_intervalli %>%
  inner_join(R_i_popolazione_cluster, by = c("SEDE_TECNICA_DEF", "anno")) %>%
  inner_join(R_i_densita_intervalli,  by = c("SEDE_TECNICA_DEF", "anno")) %>%
  inner_join(R_i_densita_cluster,     by = c("SEDE_TECNICA_DEF", "anno"))







R_i_combined_flag <- R_i_combined %>%
  group_by(SEDE_TECNICA_DEF, anno) %>%
  mutate(
    same_values = if_else(
      all(
        n_distinct(R_i_popolazione_intervalli) == 1,
        n_distinct(R_i_popolazione_cluster) == 1,
        n_distinct(R_i_densita_intervalli) == 1,
        n_distinct(R_i_densita_cluster) == 1
      ),
      1, 0
    )
  ) %>%
  ungroup()











DB_long_select<-select(DB_long, 
                       PRO_COM, 
                       SEDE_TECNICA_DEF)







DB_long_select<-DB_long_select%>%
  distinct(SEDE_TECNICA_DEF, PRO_COM, .keep_all = T)







R_i_combined<-inner_join(R_i_combined, DB_long_select)










# 1️⃣ Fai prima solo il merge (senza calcoli)
R_merge <- R_i_combined %>%
  inner_join(
    DB_long,
    by = c("SEDE_TECNICA_DEF", "anno")
  )














# 2️⃣ Poi calcoli i tuoi R ponderati per comune–anno
R_comune <- R_merge %>%
  group_by(PRO_COM.x, anno) %>%
  summarise(
    Access_pop_intervalli = sum(R_i_popolazione_intervalli * peso_fascia * Popolazione_fine_Totale.x, na.rm = TRUE) /
      sum(Popolazione_fine_Totale.x, na.rm = TRUE),
    Access_pop_cluster    = sum(R_i_popolazione_cluster * peso_fascia * Popolazione_fine_Totale.x, na.rm = TRUE) /
      sum(Popolazione_fine_Totale.x, na.rm = TRUE),
    Access_den_intervalli     = sum(R_i_densita_intervalli * peso_fascia * densita, na.rm = TRUE) /
      sum(densita, na.rm = TRUE),
    Access_den_cluster        = sum(R_i_densita_cluster * peso_fascia * densita, na.rm = TRUE) /
      sum(densita, na.rm = TRUE)
  ) %>%
  rename(pro_com = PRO_COM.x)








# STEP 3 - Accessibilità finale per tutti i comuni (con e senza stazione)

# 1️⃣ Calcolo accessibilità da tutte le stazioni raggiungibili
Access_comuni_collegati <- R_i_combined %>%
  inner_join(DB_long, by = c("SEDE_TECNICA_DEF", "anno")) %>%
  group_by(PRO_COM_com, anno) %>%
  summarise(
    Access_pop_intervalli = sum(R_i_popolazione_intervalli * peso_fascia, na.rm = TRUE),
    Access_pop_cluster    = sum(R_i_popolazione_cluster * peso_fascia, na.rm = TRUE),
    Access_den_intervalli = sum(R_i_densita_intervalli * peso_fascia, na.rm = TRUE),
    Access_den_cluster    = sum(R_i_densita_cluster * peso_fascia, na.rm = TRUE)
  ) %>%
  rename(pro_com = PRO_COM_com)








# 2️⃣ Unisci ai comuni con stazione (che già hanno forza interna)
Access_finale <- R_comune %>%
  full_join(Access_comuni_collegati, by = c("pro_com", "anno"), suffix = c("_int", "_col")) %>%
  mutate(
    Access_pop_intervalli_final = coalesce(Access_pop_intervalli_int, 0) + coalesce(Access_pop_intervalli_col, 0),
    Access_pop_cluster_final    = coalesce(Access_pop_cluster_int, 0)    + coalesce(Access_pop_cluster_col, 0),
    Access_den_intervalli_final = coalesce(Access_den_intervalli_int, 0) + coalesce(Access_den_intervalli_col, 0),
    Access_den_cluster_final    = coalesce(Access_den_cluster_int, 0)    + coalesce(Access_den_cluster_col, 0)
  ) %>%
  select(pro_com, anno,
         Access_pop_intervalli_final,
         Access_pop_cluster_final,
         Access_den_intervalli_final,
         Access_den_cluster_final)












DB_final_access <- variabili_principali  %>%
  left_join(Access_finale, by = c("pro_com", "anno"))







DB_final_access_unique<-DB_final_access%>%
  distinct(pro_com, anno, .keep_all = T)








table(DB_final_access_unique$anno)








DB_final_access_unique <- DB_final_access_unique %>%
  mutate(across(c(Access_pop_intervalli_final,
                  Access_pop_cluster_final,
                  Access_den_intervalli_final,
                  Access_den_cluster_final), ~ ifelse(is.na(.x), 0, .x)))






colnames(DB_final_access_unique)[16]<-"PRO_COM"





DB_final_access_tot_panel <- DB_final_access_unique  %>%
  inner_join(db_controlli_3, by = c("PRO_COM", "anno"))




table(DB_final_access_tot_panel$anno)







quantile(DB_final_access_tot_panel$Access_pop_intervalli_final)
quantile(DB_final_access_tot_panel$Access_pop_cluster_final)
quantile(DB_final_access_tot_panel$Access_den_intervalli_final)
quantile(DB_final_access_tot_panel$Access_den_cluster_final)







names(DB_final_access_tot_panel)
table(DB_final_access_tot_panel$anno)



setwd("C:/Users/Utente/Dropbox/Debiaes_fusco/Dati/Database")


save(DB_final_access_tot_panel, file = "DB_finale_3SFCA_panel_non_noramlizzato.RData")




















library(dplyr)
library(ggplot2)
library(moments)

df <- DB_final_access_tot_panel  # 👈 questo è il tuo dataframe

vars <- c("Access_pop_intervalli_final",
          "Access_pop_cluster_final",
          "Access_den_intervalli_final",
          "Access_den_cluster_final")

# 1️⃣ Statistiche per anno
stats_per_anno <- df %>%
  group_by(anno) %>%
  summarise(across(all_of(vars),
                   list(
                     mean = ~ mean(.x, na.rm = TRUE),
                     median = ~ median(.x, na.rm = TRUE),
                     sd = ~ sd(.x, na.rm = TRUE),
                     skew = ~ skewness(.x, na.rm = TRUE),
                     kurt = ~ kurtosis(.x, na.rm = TRUE)
                   ),
                   .names = "{.col}_{.fn}"))

print(stats_per_anno)












Access_norm <- DB_final_access_tot_panel %>%
  group_by(anno) %>%
  mutate(across(
    c(Access_pop_intervalli_final,
      Access_pop_cluster_final,
      Access_den_intervalli_final,
      Access_den_cluster_final),
    ~ {
      x <- log1p(.x)
      (x - min(x, na.rm = TRUE)) / (max(x, na.rm = TRUE) - min(x, na.rm = TRUE))
    },
    .names = "{.col}_log_norm"
  )) %>% ungroup()




save(Access_norm, file = "DB_finale_3SFCA_panel.RData")