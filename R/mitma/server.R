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

myTheme <- function(){
    theme_classic() +
        theme(
            axis.text.y = element_text(margin = margin(t = 0, r = 0, b = 0, l = 0, unit = "cm"), size = 8),
            axis.title.y = element_text(margin = margin(t = 0, r = 0, b = 0, l = 0, unit = "cm"), size = 10),
            plot.margin = unit(c(0, 0, 0, 0), "pt"),
            panel.grid.major = element_line(color = 'grey', linetype = 'dotted', size = 0.1),
            panel.grid.minor = element_line(color = 'grey', linetype = 'dotted', size = 0.1)
        )}

cases_regi <- fread("data/covid_cases_regional.csv")
cases_prov <- fread("data/covid_cases_provincial.csv")
stages_data <- fread("data/stages_data.csv")
stack_data <- fread("data/mobility_index2.csv")
flows_mitma_mobile_data <- fread("data/flows_mitma_mobile_data.csv")
flows_mitma <- fread("data/flows_mitma.csv")
provinces <- rgdal::readOGR("data/provincias.geojson", encoding = "UTF-8")
flows_chord <- fread("data/flowmap_flows_location.csv")

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

# Define server logic 
shinyServer(function(input, output) {
    
    # Regions
    
    datasetInput <- reactive({
        stack_data %>% 
            filter(CCAA %in% input$region) %>%
            filter(time > input$time_period[1] & time < input$time_period[2]) %>%
            filter(index %in% input$indicator)
    })

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
    
    # plot time series
    output$plot_index <- renderPlotly({
        ylabel <- paste0("Mobility indicator(s) in the selected region(s)")
        if (input$indicator_ref == 'FEB') {
            index_to_show <- "INDEX_FEB"
        } else {
            index_to_show <- "INDEX_MAY"
        }
        cases_data <- casesfunc() %>% rename(c(Value = value, Description = description, Location = english_name))
        
        
        dataset <- datasetInput() %>% rename(c(Date = time, Index = index, Location = CCAA))
        setnames(dataset, index_to_show, "Value")
        
        dataset <- dataset %>% group_by(Location, Date, Index) %>% summarise(Value = mean(Value))
        
        bg_data <- stages()       #restrictions data to visualize
        bg_data$start[1] <- input$time_period[1]
        bg_data$end[nrow(bg_data)] <- input$time_period[2]
        
        y_min = min(dataset$Value, na.rm = T)
        y_max = max(dataset$Value, na.rm = T)
        
        
        
        layer_rect <- geom_rect(
            data = bg_data,
            aes(xmin = start, 
                xmax = end,
                ymin = y_min,
                ymax = y_max,
                fill = stage
            ),
            alpha = 0.4
        )
        
        if ("TOTAL" %in% input$indicator) {
            total <- stack_data %>% 
                filter(CCAA %in% input$region) %>% 
                rename(c(Date = time, Location = CCAA)) %>%
                filter(Date > input$time_period[1] & Date < input$time_period[2]) %>% 
                group_by(Location, Date) %>% 
                summarise(INDEX_FEB = sum(INDEX_FEB), INDEX_MAY = sum(INDEX_MAY))
            total <- total 
            setnames(total, index_to_show, "Value")
            
            total <- total %>% select(Date, Location, Value)
            total$Index <- "TOTAL"
            dataset <- rbind(dataset, total)
            }
        
        layer_line <- geom_line(
            data = dataset,
            aes(x=Date, y=Value, colour=Location, linetype=Index)
        )
        
        if (nrow(cases_data) > 30) {
            date_scale <- "1 month"
            date_label <- "%m/%Y"
        } else {
            date_scale <- "1 day"
            date_label <- "%d/%m"
        } 
        
        if (input$bg==T) {
            plot <- ggplot()
            plot <- plot + layer_rect
            plot <- plot + layer_line
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
            plot <- plot + layer_line
            plot <- plot + labs(y = ylabel, x = "")
            
            plot <- plot + scale_x_date(date_breaks = date_scale, date_labels = date_label)
        }
        
        plot_reg <- plot + myTheme()
        plot_reg <- ggplotly(plot_reg)
        
        if (input$legend_reg == T){
            plot_reg <- plot_reg %>% layout(showlegend = TRUE)
        }
        else {
            plot_reg <- plot_reg %>% layout(showlegend = FALSE)
        }
        plot_reg
    })
    
    output$plot_covid_situation <- renderPlotly({
        ylabel <- "Number of cases / deaths (7-day rolling average)"
        cases_data <- casesfunc() %>% rename(c(Value = value, Description = description, Location = english_name))
        
        bg_data <- stages()
        bg_data$start[1] <- input$time_period[1]
        bg_data$end[nrow(bg_data)] <- input$time_period[2]
        
        y_min = min(cases_data$Value, na.rm = T)
        y_max = max(cases_data$Value, na.rm = T)
        
        layer_rect <- geom_rect(
            data = bg_data,
            aes(xmin = start, 
                xmax = end,
                ymin = y_min,
                ymax = y_max,
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
            date_label <- "%d/%m"
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
    
    # Provinces
    datasetInputProv <- reactive({
        stack_data %>% 
            filter(origin_name %in% input$province) %>%
            filter(time > input$time_period_province[1] & time < input$time_period_province[2]) %>%
            filter(index %in% input$indicator_prov)
    })
    
    casesfunc_prov <- reactive({
        cases_prov %>%
            filter(location_google %in% input$province) %>%
            filter(as.Date(date) > input$time_period_province[1] & as.Date(date) < input$time_period_province[2])
    })
    
    stages_prov <- reactive({
        stages_data %>%
            mutate(start = as.Date(start, format = "%d/%m/%Y")) %>%
            mutate(end = as.Date(end, format = "%d/%m/%Y")) %>%
            na.omit() %>%
            filter((start >= input$time_period_province[1] & end <= input$time_period_province[2]) |
                       (start < input$time_period_province[1] & end > input$time_period_province[1]) |
                       (start < input$time_period_province[2] & end > input$time_period_province[2]))
    })
    
    output$plot_index_prov <- renderPlotly({
        ylabel <- paste0("Mobility indicator(s) in the selected province(s)")
        if (input$indicator_ref_prov == 'FEB') {
            index_to_show <- "INDEX_FEB"
        } else {
            index_to_show <- "INDEX_MAY"
        }
        cases_data <- casesfunc_prov() %>% rename(c(Date = date, Daily_cases_per100k_inhabitants = daily_cases_per100k_mavg, Location = location_google))
        
        
        dataset <- datasetInputProv() %>% rename(c(Date = time, Index = index, Location = origin_name))
        setnames(dataset, index_to_show, "Value")
        
        bg_data <- stages_prov()       #restrictions data to visualize
        bg_data$start[1] <- input$time_period[1]
        bg_data$end[nrow(bg_data)] <- input$time_period[2]
        
        y_min = min(dataset$Value, na.rm = T)
        y_max = max(dataset$Value, na.rm = T)
        
        
        
        layer_rect <- geom_rect(
            data = bg_data,
            aes(xmin = start, 
                xmax = end,
                ymin = y_min,
                ymax = y_max,
                fill = stage
            ),
            alpha = 0.4
        )
        
        
        if ("TOTAL" %in% input$indicator_prov) {
            total <- stack_data %>% 
                filter(origin_name %in% input$province) %>%
                rename(c(Date = time, Location = origin_name)) %>%
                filter(Date > input$time_period[1] & Date < input$time_period[2]) %>% 
                group_by(Location, Date) %>% 
                summarise(INDEX_FEB = sum(INDEX_FEB), INDEX_MAY = sum(INDEX_MAY))
            total <- total 
            setnames(total, index_to_show, "Value")
            
            total <- total %>% select(Date, Location, Value)
            total$Index <- "TOTAL"
            dataset <- rbind(dataset, total, fill=TRUE)
        }
        layer_line <- geom_line(
            data = dataset,
            aes(x=Date, y=Value, colour=Location, linetype=Index)
        )
        
        if (nrow(cases_data) > 30) {
            date_scale <- "1 month"
            date_label <- "%m/%Y"
        } else {
            date_scale <- "1 day"
            date_label <- "%d/%m"
        } 
        
        if (input$bg_prov==T) {
            plot <- ggplot()
            plot <- plot + layer_rect
            plot <- plot + layer_line
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
            plot <- plot + layer_line
            plot <- plot + labs(y = ylabel, x = "")
            
            plot <- plot + scale_x_date(date_breaks = date_scale, date_labels = date_label)
        }
        
        plot_reg <- plot + myTheme()
        plot_reg <- ggplotly(plot_reg)
        
        if (input$legend_prov == T){
            plot_reg <- plot_reg %>% layout(showlegend = TRUE)
        }
        else {
            plot_reg <- plot_reg %>% layout(showlegend = FALSE)
        }
        plot_reg
        
    })
    
    output$plot_covid_situation_prov <- renderPlotly({
        ylabel <- "Number of cases / deaths (7-day rolling average)"
        cases_data <- casesfunc_prov() %>% rename(c(Date = date, Value = daily_cases_per100k_mavg, Location = location_google))
        
        bg_data <- stages_prov()
        bg_data$start[1] <- input$time_period[1]
        bg_data$end[nrow(bg_data)] <- input$time_period[2]
        
        y_min = min(cases_data$Value, na.rm = T)
        y_max = max(cases_data$Value, na.rm = T)
        
        layer_rect <- geom_rect(
            data = bg_data,
            aes(xmin = start, 
                xmax = end,
                ymin = y_min,
                ymax = y_max,
                fill = stage
            ),
            alpha = 0.4
        )
        
        layer_line_cases <- geom_line(
            data = cases_data,
            aes(x=Date, y=Value, colour=Location)
        )
        
        if (nrow(cases_data) > 30) {
            date_scale <- "1 month"
            date_label <- "%m/%Y"
        } else {
            date_scale <- "1 day"
            date_label <- "%d/%m"
        } 
        
        if (input$bg_prov==T) {
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
        
        if (input$legend_prov == T){
            plot <- plot %>% layout(showlegend = TRUE)
        }
        else {
            plot <- plot %>% layout(showlegend = FALSE)
        }
        plot
        
    })
    
    # Flowmaps
    flowfunc <- reactive({
        flows_mitma %>%
            filter(Nombre_Zona_origin %in% input$origen) %>%
            filter(Nombre_Zona_destination %in% input$destination) %>%
            filter(mode %in% input$mode)
        
    })
    
    mobile_data <- reactive({
        flows_mitma_mobile_data %>%
            filter(date > input$time_period_mobile[1] & date < input$time_period_mobile[2]) %>%
            filter(Nombre_Zona_origin %in% input$origen) %>%
            filter(Nombre_Zona_destination %in% input$destination) %>%
            group_by(Nombre_Zona_origin, Nombre_Zona_destination, xcoord_origin, ycoord_origin, xcoord_destination, ycoord_destination) %>%
            summarize(trips = sum(trips))
    })
    
    output$flowmap <- renderLeaflet({ 
        
        flows_data <- flowfunc()
        
        flows <- gcIntermediate( flows_data[,c("xcoord_origin", "ycoord_origin")],  flows_data[,c("xcoord_destination", "ycoord_destination")], sp = TRUE, addStartEnd = TRUE)
        
        flows$counts <- flows_data$counts                         
        
        flows$origins <- flows_data$Nombre_Zona_origin
        
        flows$destinations <- flows_data$Nombre_Zona_destination
        
        hover <- paste0(flows$origins, " to ",
                        flows$destinations, ': ',
                        as.character(flows$counts))
        
        pal <- colorFactor(brewer.pal(4, 'Set2'), flows$origins)
        
        
        leaflet(flows) %>%
            addProviderTiles('CartoDB.Positron') %>%
            setView(lat  = 40.416775, lng = -3.703790, zoom = 6) %>%
            addPolygons(data = provinces, color="grey", weight = 1, opacity = 0.5, fillOpacity = 0, label = ~provincia, group = "Provinces" )  %>%
            addPolylines(data = flows, weight = ~counts/max(flows$counts)*40, label = hover,
                         group = ~origins, color = ~pal(origins)) %>%
            addLayersControl(overlayGroups = c("Provinces"),
                             options = layersControlOptions(collapsed = FALSE))
        
    })
    
    output$flowmap2 <- renderLeaflet({ 
        
        flows_mitma_mobile_data <- mobile_data()
        
        flows_mobile <- gcIntermediate( flows_mitma_mobile_data[,c("xcoord_origin", "ycoord_origin")],  flows_mitma_mobile_data[,c("xcoord_destination", "ycoord_destination")], sp = TRUE, addStartEnd = TRUE)
        
        flows_mobile$counts <- flows_mitma_mobile_data$trips
        flows_mobile$origins <- flows_mitma_mobile_data$Nombre_Zona_origin
        flows_mobile$destinations <- flows_mitma_mobile_data$Nombre_Zona_destination
        
        hover <- paste0(flows_mobile$origins, " to ",
                        flows_mobile$destinations, ': ',
                        as.character(flows_mobile$counts))
        
        pal <- colorFactor(brewer.pal(4, 'Set2'), flows_mobile$origins)
        
        
        leaflet(flows_mobile) %>%
            addProviderTiles('CartoDB.Positron') %>%
            setView(lat  = 40.416775, lng = -3.703790, zoom = 6) %>%
            addPolygons(data = provinces, color="grey", weight = 1, opacity = 0.5, fillOpacity = 0, label = ~provincia, group = "Provinces" )  %>%
            addPolylines(data = flows_mobile, weight = ~counts/max(flows_mobile$counts)*40, label = hover,
                         group = ~origins, color = ~pal(origins)) %>%
            addLayersControl(overlayGroups = c("Provinces"),
                             options = layersControlOptions(collapsed = FALSE))
        
        
        
        
    })
    ## chord
    
    flowsChordInternal <- reactive({
        flows_chord %>% 
            filter(origin_name %in% input$origen_chord) %>%
            filter(dest_name %in% input$origen_chord) %>%
            filter(time > input$time_period_chord[1] & time < input$time_period_chord[2]) %>% 
            group_by(origin_name, time, dest_name) %>% 
            summarise(count = mean(count)) %>%
            select(count, origin_name, dest_name) 
    })
    
    output$chord_plot <- renderChorddiag({
        flows_data <- flowsChordInternal()
        chord_mat <- matrix(0, ncol=length(unique(flows_data$origin_name)), nrow=length(unique(flows_data$dest_name)))
        rownames(chord_mat) <- unique(flows_data$origin_name)
        colnames(chord_mat) <- unique(flows_data$origin_name)
        for (i in 1:nrow(chord_mat)) {
            for (j in 1:ncol(chord_mat)) {
                if (rownames(chord_mat)[i] %in% flows_data$origin_name && colnames(chord_mat)[j] %in% flows_data$dest_name) {
                    a <- flows_data[(flows_data$origin_name == rownames(chord_mat)[i] & flows_data$dest_name == colnames(chord_mat)[j]), "count"]/ 100000
                    chord_mat[i, j] <- mean(a[,1])
                }
            }
        }
        chord_mat <- chord_mat * 10^-round(log10(chord_mat)/4) * 10^-round(log10(chord_mat)/4) * 10^-round(log10(chord_mat)/4) * 10^-round(log10(chord_mat)/4)
        if (input$bg_chord==F) {
            for (i in 1:nrow(chord_mat)) {
                chord_mat[i,i] <- 0
            }
            
        }
        chorddiag(chord_mat, type = "directional", showTicks = F, groupnameFontsize = 14, groupnamePadding = 10, margin = 90)
    })
})
