#
# Shiny application to analyze data from MITMA data: https://www.mitma.gob.es/ministerio/covid-19/evolucion-movilidad-big-data/opendata-movilidad
#
# This application is used to analyze the effect of de-escalation measures on the mobility patterns between provinces
#

library(shiny)
library(plotly)
library(tidyr)
library(ggplot2) 
library(dplyr)
library(data.table)

myTheme <- function(){
    theme_classic() +
        theme(
            axis.text.y = element_text(margin = margin(t = 0, r = 0, b = 0, l = 0, unit = "cm"), size = 8),
            axis.title.y = element_text(margin = margin(t = 0, r = 0, b = 0, l = 0, unit = "cm"), size = 10),
            plot.margin = unit(c(0, 0, 0, 0), "pt"),
            panel.grid.major = element_line(color = 'grey', linetype = 'dotted', size = 0.1),
            panel.grid.minor = element_line(color = 'grey', linetype = 'dotted', size = 0.1)
        )}

cases_regi <- fread("../data/covid_cases_regional.csv")
cases_prov <- fread("../data/covid_cases_provincial.csv")
stages_data <- fread("../data/stages_data.csv")
# Define server logic 
shinyServer(function(input, output) {

    casesfunc <- reactive({
        cases_regi %>%
            filter(english_name %in% input$region) %>%
            filter(description == input$cas_type) %>%
            filter(Date > input$time_period[1] & Date < input$time_period[2])
    })
    
    stages <- reactive({
        stages_data %>%
            mutate(start = as.Date(start, format = "%d/%m/%Y")) %>%
            mutate(end = as.Date(end, format = "%d/%m/%Y")) %>%
            na.omit() %>%
            filter((start >= input$time_period[1] & end <= input$time_period[2]) |
                   (start < input$time_period[1] & end > input$time_period[1]) |
                   (start < input$time_period[2] & end > input$time_period[2]))
    })
    
    output$plot_covid_situation <- renderPlotly({
        ylabel <- "Number of cases / deaths (7-day rolling average)"
        cases_data <- casesfunc() %>% rename(c(Value = value, Description = description, Location = english_name))
        
        bg_data <- stages()
        bg_data$start[1] <- input$time_period[1]
        bg_data$end[nrow(bg_data)] <- input$time_period[2]
        
        
        layer_rect <- geom_rect(
            data = bg_data,
            aes(xmin = start, 
                xmax = end,
                ymin = min(cases_data$Value),
                ymax = max(cases_data$Value),
                fill = stage
                ),
            alpha = 0.4
        )
        
        layer_line_cases <- geom_line(
            data = cases_data,
            aes(x=Date, y=Value, colour=Location, linetype=Description)
        )
        
        if (nrow(cases_data) > 30) {
            date_scale <- "1 month"
            date_label <- "%m/%Y"
        } else {
            date_scale <- "1 day"
            date_label <- "%d/%m/%Y"
        } 
        
        if (input$bg==T) {
            plot <- ggplot()
            plot <- plot + layer_rect
            plot <- plot + layer_line_cases
            plot <- plot + labs(y = ylabel, x = "")
            plot <- plot + scale_fill_manual(values = c("Before pandemic" = "#fafffa", 
                                                        "First cases" = "#BFD4DB", 
                                                        "Reference week of normality" = "#A020F0",
                                                        "Community transmission" = "#fcffe4",
                                                        "State of alarm" = "#f4cccc", 
                                                        "Halting of all non-essential activity" = "#f4cccc", 
                                                        "Lifting of some restrictions" = "#fcffe4",
                                                        "De-escalation" = "#BFD4DB", 
                                                        "Reference week of state of alarm" = "#A020F0", 
                                                        "W2" = "#FF6833", 
                                                        "W3" = "#FFA233", 
                                                        "W4" = "#FFFC33", 
                                                        "W5" = "#64FF33", 
                                                        "New normality" = "#fafffa", 
                                                        "Resurgence" = "#BFD4DB",
                                                        "State of emergency reimposed" = "#f4cccc", 
                                                        "Gradual return to normal" = "#fafffa"))
            
            plot <- plot + scale_x_date(date_breaks = date_scale, date_labels = date_label)
            
        }
        else {
            plot <- ggplot()
            plot <- plot + layer_line_cases
            plot <- plot + labs(y = ylabel, x = "")
            
            plot <- plot + scale_x_date(date_breaks = date_scale, date_labels = date_label)
        }
        
        plot <- plot + myTheme()
        plot <- ggplotly(plot)
        
        if (input$legend_reg == T){
            plot <- plot %>% layout(showlegend = TRUE)
        }
        else {
            plot <- plot %>% layout(showlegend = FALSE)
        }
        plot
        
    })
})
