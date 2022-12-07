#
# Shiny application to analyze data from MITMA data: https://www.mitma.gob.es/ministerio/covid-19/evolucion-movilidad-big-data/opendata-movilidad
#
# This application is used to analyze the effect of de-escalation measures on the mobility patterns between provinces
#
library(shiny)
library(shinyWidgets)
library(datasets)
library(data.table)
library(ggplot2) 
library(dplyr)
library(leaflet)
library(rgeos)
library(RColorBrewer)
library(geosphere)
library(plotly)
library(ggrepel)
library(tidyr)
library(chorddiag)

Sys.setlocale(locale = "English")

regions_english <- c("Andalusia","Aragon","Asturias","Balearic Islands","Basque Country","Canary Islands",
             "Cantabria","Castile-La Mancha","Castile and Leon","Catalonia","Ceuta","Community of Madrid",
             "Extremadura","Galicia","La Rioja","Melilla","Navarre","Region of Murcia","Valencian Community", "Spain (Total)")

provinces_spanish <- c("Coruña, A","Araba/Álava",  "Albacete", "Alicante/Alacant", "Almería", "Asturias", 
                       "Ávila", "Badajoz", "Balears, Illes", "Barcelona", "Bizkaia", 
                       "Burgos", "Cáceres", "Cádiz", "Cantabria", "Castellón/Castelló", 
                       "Ceuta", "Ciudad Real", "Madrid", 
                       "Córdoba", "Cuenca", "Girona", 
                       "Granada", "Guadalajara", "Huelva", "Huesca", "Jaén", "Rioja, La", "Palmas, Las", "León", 
                       "Lleida", "Lugo", "Málaga", "Melilla", "Navarra", 
                        "Palencia",  "Pontevedra","Ourense", "Murcia",  
                       "Salamanca", "Santa Cruz de Tenerife", "Segovia", "Sevilla", 
                       "Soria", "Tarragona", "Teruel", "Toledo", "Valencia/València", 
                       "Valladolid", "Zamora", "Zaragoza", "Spain (Total)")

provinces_english <- c("A Coruna", "Alava", "Albacete", "Alicante", "Almeria", "Asturias", 
                       "Avila", "Badajoz", "Balearic Islands", "Barcelona", "Biscay", 
                       "Burgos", "Caceres", "Cadiz", "Cantabria", "Castellon", "Ceuta", 
                       "Ciudad Real", 
                       "Community of Madrid", "Cordoba", "Cuenca",  
                       "Girona", "Granada", "Guadalajara", "Huelva", "Huesca", "Jaen", 
                       "La Rioja", "Las Palmas", "Leon", "Lleida", "Lugo", "Malaga", 
                       "Melilla", "Navarre", "Palencia", "Pontevedra", "Province of Ourense", 
                       "Region of Murcia", "Salamanca", "Santa Cruz de Tenerife", "Segovia", 
                       "Seville", "Soria", "Tarragona", "Teruel", "Toledo", 
                       "Valencia", "Valladolid", "Zamora", "Zaragoza", "Spain (Total)")

regions_spanish <- c("Andalucía", "Aragón", "Asturias, Principado de", "Illes Balears", "País Vasco",  "Canarias", 
                     "Cantabria", "Castilla - La Mancha", "Castilla y León", "Cataluña", 
                     "Ceuta", "Comunidad de Madrid", "Extremadura", "Galicia", "Rioja, La",
                     "Melilla", "Comunidad Foral de Navarra", "Región de Murcia", 
                     "Comunitat Valenciana", "Spain (Total)")

stack_data <- fread("data/mobility_index.csv")
flows_mitma_mobile_data <- fread("data/flows_mitma_mobile_data.csv")
flows_mitma <- fread("data/flows_mitma.csv")

# Define UI for application 
shinyUI(navbarPage(
    "Mobility patterns in Spain during the COVID-19 pandemic",
    tabPanel("Comparing different indicators across regions in spain",
             sidebarLayout(    
                 sidebarPanel(
                     pickerInput(inputId = "region",
                                 label = "Region:",
                                 choices = regions_english,
                                 selected = "Andalusia",
                                 options = list(`actions-box` = TRUE),
                                 multiple = T),
                     checkboxGroupInput(inputId = "indicator",
                                        label = "Mobility indicators to display:",
                                        choices = c(unique(stack_data$index), "TOTAL"),
                                        selected = "INTERNAL"),
                     radioButtons(inputId = "indicator_ref",
                                label = "Reference to display:",
                                choiceNames = list(
                                    "FEB","MAY"
                                ),
                                choiceValues  = c("FEB","MAY"),
                                selected = "FEB"),
                     sliderInput(inputId = "time_period",
                                 label = "Time period of analysis",
                                 min = as.Date("2020-01-01","%Y-%m-%d"),
                                 max = as.Date("2021-12-31","%Y-%m-%d"),
                                 value = c(as.Date("2020-06-01"),as.Date("2020-06-30")),
                                 timeFormat="%Y-%m-%d"),
                     materialSwitch(inputId = "bg", 
                                    label = "Show stage indices", 
                                    status = "info"),
                     materialSwitch(inputId = "legend_reg",
                                    label = "Show legends",
                                    status = "info"),
                     checkboxGroupInput(inputId = "cas_type",
                                        label = "Cases / deaths to show:",
                                        choiceNames = c("Number of daily new infections per 100,000 inhabitants (7-day rolling average)", 
                                                        "Number of daily new deaths per 100,000 inhabitants (7-day rolling average)"),
                                        choiceValues = c("daily_cases_per100k_mavg", "daily_deaths_per100k_mavg"),
                                        selected = "daily_cases_per100k_mavg"),
                 ),
                 mainPanel(
                     plotlyOutput("plot_index", width = 1000),                 # mobility indices
                     plotlyOutput("plot_covid_situation", width = 1000),           # number of cases/deaths
                 ))
    ),
    tabPanel("Comparing different indicators across provinces in spain",
             sidebarLayout(    
                 sidebarPanel(
                     pickerInput(inputId = "province",
                                 label = "Provinces:",
                                 choices = provinces_english,
                                 selected = "Community of Madrid",
                                 options = list(`actions-box` = TRUE),
                                 multiple = T),
                     checkboxGroupInput(inputId = "indicator_prov",
                                        label = "Mobility indicators to display:",
                                        choices = c(unique(stack_data$index), "TOTAL"),
                                        selected = "INTERNAL"),
                     radioButtons(inputId = "indicator_ref_prov",
                                  label = "Reference to display:",
                                  choiceNames = list(
                                      "FEB","MAY"
                                  ),
                                  choiceValues  = c("FEB","MAY"),
                                  selected = "FEB"),
                     sliderInput(inputId = "time_period_province",
                                 label = "Time period of analysis",
                                 min = as.Date("2020-01-01","%Y-%m-%d"),
                                 max = as.Date("2021-12-31","%Y-%m-%d"),
                                 value = c(as.Date("2020-06-01"),as.Date("2020-06-30")),
                                 timeFormat="%Y-%m-%d"),
                     materialSwitch(inputId = "bg_prov", 
                                    label = "Show stage indices", 
                                    status = "info"),
                     materialSwitch(inputId = "legend_prov",
                                    label = "Show legends",
                                    status = "info"),
                     radioButtons(inputId = "cas_type_prov",
                                  label = "Cases to show:",
                                  choiceNames = list(
                                      "Number of daily new infections per 100,000 inhabitants (7-day rolling average)"
                                  ),
                                  choiceValues  = c("Number of daily new infections per 100,000 inhabitants (7-day rolling average)"),
                                  selected = "Number of daily new infections per 100,000 inhabitants (7-day rolling average)")
                 ),
                 mainPanel(
                     plotlyOutput("plot_index_prov", width = 1000),                 # mobility indices
                     plotlyOutput("plot_covid_situation_prov", width = 1000),           # number of cases/deaths
                 ))
    ),
    
    tabPanel("MITMA flow maps",
             sidebarLayout(    
                 sidebarPanel(
                     p("The annual total number of trips between provinces can be visualized on this tab (data source: National Transport Model of MITMA, data can be downloaded in .csv format by clicking on the download button)."),
                     width=2,
                     pickerInput(inputId = "origen",
                                 label = "Origin (province):",
                                 choices = unique(flows_mitma$Nombre_Zona_origin),
                                 selected = "Sevilla",
                                 options = list(`actions-box` = TRUE),
                                 multiple = T),
                     pickerInput(inputId = "destination",
                                 label = "Destination (province):",
                                 choices = unique(flows_mitma$Nombre_Zona_destination),
                                 selected = unique(flows_mitma$Nombre_Zona_destination),
                                 options = list(`actions-box` = TRUE),
                                 multiple = T),
                     pickerInput(inputId = "mode",
                                 label = "Selected mode:",
                                 choices = unique(flows_mitma$mode),
                                 options = list(`actions-box` = TRUE),
                                 multiple = F),
                     sliderInput(inputId = "time_period_mobile",
                                 label = "Time period of analysis",
                                 min = as.Date("2020-01-01","%Y-%m-%d"),
                                 max = as.Date("2021-12-31","%Y-%m-%d"),
                                 value = c(as.Date("2020-06-01"),as.Date("2020-06-30")),
                                 timeFormat="%Y-%m-%d"),
                 ),
                 
                 mainPanel(
                     fluidRow(
                         column(6,leafletOutput("flowmap", width = 400, height = 400)),
                         column(6,leafletOutput("flowmap2", width = 400, height = 400)),
                         
                     )
                 )
             )
    ),
    
    tabPanel('Chord diagram',
             sidebarLayout(    
                 sidebarPanel(
                     p("All trips are scaled by total number of trips from origin. Shows kilometers from each origin to each destiny."),
                     width=2,
                     pickerInput(inputId = "origen_chord",
                                 label = "Origin (province):",
                                 choices = provinces_english,
                                 selected = c("Seville","Barcelona","Albacete"),
                                 options = list(`actions-box` = TRUE),
                                 multiple = T),
                     
                     materialSwitch(inputId = "bg_chord", 
                                    label = "Show same province trips", 
                                    status = "info"),
                     # pickerInput(inputId = "destination_chord",
                     #             label = "Destination (province):",
                     #             choices = provinces_english,
                     #             selected = provinces_english,
                     #             options = list(`actions-box` = TRUE),
                     #             multiple = T),
                     sliderInput(inputId = "time_period_chord",
                                 label = "Time period of analysis",
                                 min = as.Date("2020-01-01","%Y-%m-%d"),
                                 max = as.Date("2021-12-31","%Y-%m-%d"),
                                 value = c(as.Date("2020-06-01"),as.Date("2020-06-30")),
                                 timeFormat="%Y-%m-%d"),
                 ),
                 
                 mainPanel(
                     chorddiagOutput("chord_plot", width = 800, height = 800)
                 )
             ))
    
))
