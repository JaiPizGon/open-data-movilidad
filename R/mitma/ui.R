#
# Shiny application to analyze data from MITMA data: https://www.mitma.gob.es/ministerio/covid-19/evolucion-movilidad-big-data/opendata-movilidad
#
# This application is used to analyze the effect of de-escalation measures on the mobility patterns between provinces
#
library(shiny)
library(shinyWidgets)
library(plotly)

Sys.setlocale(locale = "English")

regions <- c("Andalusia","Aragon","Asturias","Balearic Islands","Basque Country","Canary Islands",
             "Cantabria","Castile-La Mancha","Castile and Leon","Catalonia","Ceuta","Community of Madrid",
             "Extremadura","Galicia","La Rioja","Melilla","Navarre","Region of Murcia","Valencian Community")

# Define UI for application 
shinyUI(navbarPage(
    "Mobility patterns in Spain during the COVID-19 pandemic",
    tabPanel("Comparing different indicators across regions in spain",
             sidebarLayout(    
                 sidebarPanel(
                     p("This tab serves for regional analysis. Data of the plots can be downloaded in .csv format by clicking on the download buttons."),
                     pickerInput(inputId = "region",
                                 label = "Region:",
                                 choices = regions,
                                 selected = "Andalusia",
                                 options = list(`actions-box` = TRUE),
                                 multiple = T),
                     # checkboxGroupInput(inputId = "indicator",
                     #                    label = "Mobility indicators to display:",
                     #                    choices = unique(stack_data$time),
                     #                    selected = "JRC index"),
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
                     # pickerInput(inputId = "responseindex",
                     #             label = "Response indices to show:",
                     #             choices = unique(response_indices$variable),
                     #             options = list(`actions-box` = TRUE),
                     #             multiple = T),
                 ),
                 mainPanel(
                     #plotlyOutput("plot", width = 1200),                 # mobility indices
                     plotlyOutput("plot_covid_situation", width = 1000),           # number of cases/deaths
                 ))
    )
    
))
