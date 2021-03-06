#---
#title: "Data visualization with Shiny"
#author: "Mehdi Khan"
#date: "December 11, 2018"
#output: html_document
#---
  
knitr::opts_chunk$set(echo = TRUE)

# load the libraries
suppressMessages(suppressWarnings(library(ggplot2)))
suppressMessages(suppressWarnings(library(leaflet)))
suppressMessages(suppressWarnings(library(maps)))
suppressMessages(suppressWarnings(library(shiny)))
suppressMessages(suppressWarnings(library(shinyWidgets)))
#suppressMessages(suppressWarnings(library(sp)))
suppressMessages(suppressWarnings(library(plotly)))
suppressMessages(suppressWarnings(library(dplyr)))
suppressMessages(suppressWarnings(library(stringr)))
suppressMessages(suppressWarnings(library(rgdal)))
#suppressMessages(suppressWarnings(library(sqldf)))
suppressMessages(suppressWarnings(library(sf)))
suppressMessages(suppressWarnings(library(sp)))
suppressMessages(suppressWarnings(library(RColorBrewer)))
suppressMessages(suppressWarnings(library(reshape2)))
suppressMessages(suppressWarnings(library(rmapshaper)))
#suppressMessages(suppressWarnings(library(geojsonio)))
suppressMessages(suppressWarnings(library(rgeos)))
#suppressMessages(suppressWarnings(library(mapview)))

# load data
hlthDF <- read.csv("./data/revised_malnutrition.csv",sep = ",", stringsAsFactors = FALSE)
names(hlthDF)[12]<-"Under.5.population"

# simplifying column names
locations <- which(!is.na(str_locate(hlthDF$Country, "\\.?[:blank:]\\(")[,1]))
hlthDF$Country[locations] <- str_sub(hlthDF$Country[locations],1,str_locate(hlthDF$Country[locations], "\\.?[:blank:]\\(")[,1]-1)


#loading geographic data and subdivided then into regions
geodata <- readOGR("./data","TM_WORLD_BORDERS_SIMPL-0")
#geodata <- ms_simplify(geodata,keep=0.5,keep_shapes=TRUE)

#str(geodata)
asia <- unique(hlthDF$ISO.code[hlthDF$Region=="Asia"])
europe <- unique(hlthDF$ISO.code[hlthDF$Region=="Europe"])
africa <- unique(hlthDF$ISO.code[hlthDF$Region=="Africa"])
latin_america <- unique(hlthDF$ISO.code[hlthDF$Region=="Latin America and the Caribbean"])
oceania <- unique(hlthDF$ISO.code[hlthDF$Region=="Oceania"])
america <- unique(hlthDF$ISO.code[hlthDF$Region=="Northern America"])

geoAsia <- geodata[which(!is.na(pmatch(geodata$ISO3, asia))),]
geoAsia <- (geoAsia[order(geoAsia$ISO3),])

geoEurope <- geodata[which(!is.na(pmatch(geodata$ISO3, europe))),]
geoEurope <- (geoEurope[order(geoEurope$ISO3),])

geoAfrica <- geodata[which(!is.na(pmatch(geodata$ISO3, africa))),]
geoAfrica <- (geoAfrica[order(geoAfrica$ISO3),])

geoLatin_america <- geodata[which(!is.na(pmatch(geodata$ISO3, latin_america))),]
geoLatin_america <- (geoLatin_america[order(geoLatin_america$ISO3),])

geoOceania <- geodata[which(!is.na(pmatch(geodata$ISO3, oceania))),]
geoOceania <- (geoOceania[order(geoOceania$ISO3),])

geoAmerica <- geodata[which(!is.na(pmatch(geodata$ISO3, america))),]
geoAmerica <- (geoAmerica[order(geoAmerica$ISO3),])


# dissolve polygons to make one singlr polygons for regions
dissolve_region <- function(x,id){
  dissolve <- aggregate(x["AREA"],FUN=mean,dissolve=TRUE )
  dissolve$ID[1]<-id
  return (dissolve)
}

asia_region <- dissolve_region(geoAsia,"Asia")
europe_region <- dissolve_region(geoEurope,"Europe")
africa_region <- dissolve_region(geoAfrica,"Africa")
latina_region <- dissolve_region(geoLatin_america,"Latin America and the Caribbean")
oceania_region <- dissolve_region(geoOceania,"Oceania")
america_region <- dissolve_region(geoAmerica,"Northern America")

geoRegions <-  rbind(asia_region, europe_region, africa_region,latina_region,oceania_region,america_region, makeUniqueIDs = TRUE) 


#function to create subset of data on clicks on map etc.
regionData <- function(x=NULL,yr){
  allcountries <- unique(hlthDF$ISO.code)
  allregions <- unique(hlthDF$Region)  
  
  if (is.null(x)) {
    regionDF <- region_agg(allregions[1],yr)
    for (i in 2:length(allregions)){
      regionDF <- rbind(regionDF,region_agg(allregions[i],yr))
      
    }
    
  }
  
  
  else if (x %in% allregions){
    regionDF <- hlthDF[(hlthDF$Region==x) & (hlthDF$Year==yr),c("Country", "Severe.wasting","Wasting","Overweight","Stunting","Underweight","Under.5.population","Year","Region","ISO.code")] 
    
    regionDF[is.na(regionDF)] <- 0
    for (i in 2:6){
      regionDF[i]<- round(((( regionDF[i]*regionDF$Under.5.population)/100)/sum(regionDF$Under.5.population))*100,2)}
    
    regionDF <-  regionDF %>% group_by(Region,Country,Year,ISO.code)%>% summarise(
      Severe.wasting = sum(Severe.wasting),
      Wasting = sum(Wasting),
      Overweight = sum(Overweight),
      Stunting = sum(Stunting),
      Underweight = sum(Underweight),
      Under.5.population = sum(Under.5.population)
    )
  }
  else if (x %in% allcountries) {
    regionDF <- hlthDF[(hlthDF$ISO.code==x) & (hlthDF$Year==yr),c("Country", "Severe.wasting","Wasting","Overweight","Stunting","Underweight","Under.5.population","Year","ISO.code")] 
    regionDF[is.na(regionDF)] <- 0
    for (i in 2:6){
      regionDF[i]<- round(((( regionDF[i]*regionDF$Under.5.population)/100)/sum(regionDF$Under.5.population))*100,2)}
    
    regionDF <-  regionDF %>% group_by(Country,ISO.code,Year)%>% summarise(
      Severe.wasting = sum(Severe.wasting),
      Wasting = sum(Wasting),
      Overweight = sum(Overweight),
      Stunting = sum(Stunting),
      Underweight = sum(Underweight),
      Under.5.population = sum(Under.5.population)
    )
    
  }
  
  return(regionDF)
}


# subset and agrregate regional data
region_agg <- function(x,yr){
  
  regionDF <- hlthDF[(hlthDF$Region==x) & (hlthDF$Year==yr),c("Region", "Severe.wasting","Wasting","Overweight","Stunting","Underweight","Under.5.population","Year")] 
  
  regionDF[is.na(regionDF)] <- 0
  for (i in 2:6){
    regionDF[i]<- round(((( regionDF[i]*regionDF$Under.5.population)/100)/sum(regionDF$Under.5.population))*100,2)}
  
  regionDF <-  regionDF %>% group_by(Region,Year)%>% summarise(
    Severe.wasting = sum(Severe.wasting),
    Wasting = sum(Wasting),
    Overweight = sum(Overweight),
    Stunting = sum(Stunting),
    Underweight = sum(Underweight),
    Under.5.population = sum(Under.5.population)
  )
  
  return(regionDF)
  
}

# subset of data for all years
region_allYear <- function(x){
  regions <- unique(hlthDF$Region)
  countries <- unique(hlthDF$ISO.code)
  
  if (x %in% regions) {
    regionDF <- hlthDF[hlthDF$Region==x,c("Region", "Severe.wasting","Wasting","Overweight","Stunting","Underweight","Under.5.population","Year")] 
    regionDF[is.na(regionDF)] <- 0
    for (i in 2:6){
      regionDF[i]<- round(((( regionDF[i]*regionDF$Under.5.population)/100)/sum(regionDF$Under.5.population))*100,2)}
    regionDF <-  regionDF %>% group_by(Region,Year)%>% summarise(
      Severe.wasting = sum(Severe.wasting),
      Wasting = sum(Wasting),
      Overweight = sum(Overweight),
      Stunting = sum(Stunting),
      Underweight = sum(Underweight),
      Under.5.population = sum(Under.5.population)
    )
    
  }
  else if (x %in% countries) {
    regionDF <- hlthDF[hlthDF$ISO.code==x,c("Region", "Severe.wasting","Wasting","Overweight","Stunting","Underweight","Under.5.population","Year","ISO.code")] 
    regionDF[is.na(regionDF)] <- 0
    for (i in 2:6){
      regionDF[i]<- round(((( regionDF[i]*regionDF$Under.5.population)/100)/sum(regionDF$Under.5.population))*100,2)}
    
    
    regionDF <-  regionDF %>% group_by(ISO.code,Year)%>% summarise(
      Severe.wasting = sum(Severe.wasting),
      Wasting = sum(Wasting),
      Overweight = sum(Overweight),
      Stunting = sum(Stunting),
      Underweight = sum(Underweight),
      Under.5.population = sum(Under.5.population)
    )
    
  }
  
  
  
  return(regionDF)
  
}


# plottig function 
plotdata <- function(id=NULL,yr){
  df <- regionData(id,yr)
  regions <- unique(hlthDF$Region)
  countries <- unique(hlthDF$ISO.code)
  if (is.null(id)) {  
    meltData <- melt(df, id.vars = "Region",measure.vars = c('Severe.wasting','Wasting','Stunting','Underweight',"Overweight"))
    p <- ggplot(meltData,aes(x=Region,y=value))+geom_bar(aes(fill = variable),stat = "identity", position = 'dodge', width = .5)+ggtitle(paste("proportion of types among all children in each region in ",yr))+theme(axis.text.x = element_text(vjust = 1, size = 8), legend.position = 'top', legend.text = element_text(size = 7),plot.title = element_text(size=8),axis.title = element_text(size=8))+ylab("malnutrition type(%)")
  }
  
  else if(id %in% regions){
    meltData <- melt(df, id.vars = "ISO.code",measure.vars = c('Severe.wasting','Wasting','Stunting','Underweight',"Overweight"))
    p <- ggplot(meltData,aes(x=ISO.code,y=value))+geom_bar(aes(fill = variable),stat = "identity", position = 'dodge', width = .5)+ggtitle(paste("proportion of types among all children in each country in ",yr))+xlab("Country (ISO codes)")+ theme(axis.text.x = element_text(vjust = 1, size = 8), legend.position = "top", legend.text = element_text(size = 7),plot.title = element_text(size=8),axis.title = element_text(size=8))+ylab("malnutrition type(%)")
  }
  
  else if(id %in% countries){
    meltData <- melt(df, id.vars = "ISO.code",measure.vars = c('Severe.wasting','Wasting','Stunting','Underweight',"Overweight"))
    p <- ggplot(meltData,aes(x=variable,y=value))+geom_bar(aes(fill = variable),stat = "identity", position = 'dodge', width = .5)+ggtitle(paste("proportion of types among all children in the selected country in ",yr))+xlab("Country (ISO codes)")+ theme(axis.text.x = element_text(vjust = 1, size = 8), legend.position = "top", legend.text = element_text(size = 7),plot.title = element_text(size=8),axis.title = element_text(size=8))+ylab("malnutrition type(%)")
  }
  
  
  ggplotly(p) %>% config(displaylogo = FALSE,
                         modeBarButtonsToRemove = list(
                           'sendDataToCloud',
                           'toImage',
                           'autoScale2d',
                           'resetScale2d',
                           'hoverClosestCartesian',
                           'hoverCompareCartesian'
                         ))
  
}



# function to plot piechart of regional data
plotpie <- function(id,yr){
  df <- region_agg(id,yr)
  
  meltData <- melt(df, id.vars = "Region",measure.vars = c('Severe.wasting','Wasting','Stunting','Underweight',"Overweight"))
  
  p <- plot_ly(meltData, labels=~variable, values=~value, type = 'pie', width=300,height=250)%>%
    layout(title= paste("proportion among all sick children in \n",id,"in",yr),titlefont=list("size"=11),
           legend=list(orientation = "v", x=-5,y = .5,font=list(size=8))
    )%>% config(displaylogo = FALSE,
                modeBarButtonsToRemove = list(
                  'sendDataToCloud',
                  'toImage',
                  'autoScale2d',
                  'resetScale2d',
                  'hoverClosestCartesian',
                  'hoverCompareCartesian'
                ))
  
  return(p)
} 


# function to plot piechart of country data
plotpie_country <- function(id,yr){
  df <- regionData(id,yr)
  
  
  meltData <- melt(df, id.vars = "ISO.code",measure.vars = c('Severe.wasting','Wasting','Stunting','Underweight',"Overweight"))
  
  p <- plot_ly(meltData, labels=~variable, values=~value, type = 'pie', width=300,height=250)%>%
    layout(title= paste("proportion among all sick children in \n",df$Country,"in",yr),titlefont=list("size"=11),
           legend=list(orientation = "v", x=-5,y = .5,font=list(size=8))
    )%>% config(displaylogo = FALSE,
                modeBarButtonsToRemove = list(
                  'sendDataToCloud',
                  'toImage',
                  'autoScale2d',
                  'resetScale2d',
                  'hoverClosestCartesian',
                  'hoverCompareCartesian'
                ))
  
  return(p)
} 

# plot data over the years
plotcompareHealth <- function(region){
  data <- region_allYear(region)
  
  meltData <- melt(data, id.vars = "Year",measure.vars = c('Severe.wasting','Wasting','Stunting','Underweight',"Overweight"))
  #meltData$variable <- as.character(meltData$variable)
  p <- ggplot(meltData,aes(Year))+geom_line(aes(y=value,colour=variable), size=.5)+ggtitle(paste("Trend of different types of nutrition over the years in ",region)) +  theme(legend.position=c(.9, 0.85),legend.title=element_text(size=8),plot.title = element_text(size=9),axis.title = element_text(size=8))+ylab("malnutrition type(%)")
  
  ggplotly(p) %>% config(displaylogo = FALSE,
                         modeBarButtonsToRemove = list(
                           'sendDataToCloud',
                           'toImage',
                           'autoScale2d',
                           'resetScale2d',
                           'hoverClosestCartesian',
                           'hoverCompareCartesian'
                         )) 
  
  
}


# function to get region center
getCenter <- function(id){
  
  if (id=="Asia") {
    centerLat <- 34.047863
    centerLng <- 100.619652
  }
  else if (id=="Africa") {
    centerLat <- 8.548430
    centerLng <- 22.999753
  }
  
  else if (id=="Latin America and the Caribbean") {
    centerLat <- -7.917793
    centerLng <- -75.043300
  }
  
  else if (id=="Oceania") {
    centerLat <- -23.433009
    centerLng <- 135.450567
  }
  
  else if (id=="Europe") {
    centerLat <- 47.920024
    centerLng <- 14.315220
  }
  
  else if (id=="Northern America") {
    centerLat <- 55.658996
    centerLng <- -103.172296
  }
  return (c(centerLat,centerLng))
}


# shiny user interface
ui <-fluidPage(
  
  fluidRow(
    
    column(width = 12,align='center',
           #tags$div(align="center",tags$h4('Visualization of Child Malnutrition data')),
           withTags({
             div(align="center",
                 HTML("<font style='font-weight: bold; text-decoration: underline;' color='#000080' size='4'>
                      Visualization of Child Malnutrition data</font><br>
                      <font style='font-weight: bold;' color='#000080' size='3'>Mehdi M Khan</font><br><br>
                      <font style='text-align:left; font-weight: bold;' color='#000080'size='3'>Introduction:</font><br> 
                      This application uses Shiny package in R to create an interactive data visualization environment through map navigation and other tools to provide insights in child malnutrition data acquired by the joint efforts of UNICEF, WHO and World Bank. R Packages such as <font style='font-weight: bold'>leaflet,rgdal,sf,sp,rgeos, and rmapshaper</font> were used to create the map, map tools and to deal with spatial data. Both <font style='font-weight: bold'>ggplot2 and plotly</font> packages were used to create the plots.
                      <br></br> 
                      
                      <font style='font-weight: bold;' color='#000080' size='3'>Functionalities:</font><br> 
                      The page loads with a world map with six major regions defined by the World Bank (hovering over the regions will show their names) along with two visualizations that provide information about the status 
                      of child Malnutrition in the selected regions. The slider bar above the visualizations allows the users to get and compare data in different years. The layer control tool on the top-right corner on the map 
                      allows users to access to specific countries and get similar information from country level data. <br>
                      <font style='font-weight: bold'>Note:</font> The data is not available for all regions and countries for all years. The slider bar updates itself with the years that the selected region or country has the data avilable for...<br>"
                 ))
             
             
           }),
           
           tabsetPanel(
             tabPanel("Data Visualization", value=1, 
                      fluidRow(
                        column(12,align="center",
                               
                               conditionalPanel(condition = "output.slide == 0",  uiOutput("yearSlider")),
                               conditionalPanel(condition = "output.slide == 1",  uiOutput("lyrSlider")),
                               tags$div(align='left',
                                        fluidRow(column(8,align="center",plotlyOutput("barchart", height = 300)),
                                                 column(4,align="center",plotlyOutput("piechart", height = 300))),tags$br(),
                                        fluidRow(column(12,align="center",plotlyOutput("linechart", height = 200))),
                                        tags$br(),  tags$div(align='center',HTML("<font style='font-weight: bold;' color='#000080' size='2'>World Map with World Bank defined regions and countries. Country level data can be added by using the layer control tool(top-right) on the map</font><br>
                                                                                 
                                                                                 ")),    
                                        leafletOutput("map",height = 450, width = '100%'))) 
                        
                               )),                      
             tabPanel("Definitions and References", value=2,
                      fluidRow(
                        
                        column(12,
                               
                               withTags({
                                 div(align="left",
                                     HTML("<font style='font-weight: bold;' color='#000080' size='3'>Data prepration:</font><br> 
                                          The oroginal data was downloaded from UNICEF website in .xsl format, which was then converted into .csv format and loaded in R environment. The R packages such as dplyr, tidyr, reshape3, and plyr were used 
                                          to clean and simplify the data, which would be suitable to create visualization. The spatial data was downloaded from thematicmapping.org in shape file format. The shape file was loaded into R using rgdal 
                                          package and then process with several other packages as mentioned in the introduction<br></br>
                                          <font style='font-weight: bold;' color='#000080' size='3'>Child malnutrition estimates (Definitions):</font><br> 
                                          <font style='font-weight: bold'>Severe Wasting:</font> 
                                          Percentage of children aged 0-59 months who are below minus three standard deviations from median weight-for-height of the WHO Child Growth Standards.<br>		
                                          <font style='font-weight: bold'>Wasting:</font>
                                          Moderate and severe: Percentage of children aged 0-59 months who are below minus two standard deviations from median weight-for-height of the WHO Child Growth Standards.<br>	
                                          <font style='font-weight: bold'>Overweight:</font>Moderate and severe: Percentage of children aged 0-59 months who are above two standard deviations from median weight-for-height of the WHO Child Growth Standards.<br> 		
                                          <font style='font-weight: bold'>Stunting:</font> 
                                          Moderate and severe: Percentage of children aged 0-59 months who are below minus two standard deviations from median height-for-age of the WHO Child Growth Standards.<br>		
                                          <font style='font-weight: bold'>Underweight:</font> 
                                          Moderate and severe: Percentage of children aged 0-59 months who are below minus two standard deviations from median weight-for-age of the World Health Organization (WHO) Child Growth Standards.<br><br>
                                          <font style='font-weight: bold;' color='#000080' size='3'>References:</font><br> 
                                          1. UNICEF web page at https://data.unicef.org/topic/nutrition/malnutrition/ (for child malnutrition data) <br>
                                          2. http://thematicmapping.org/downloads/world_borders.php (for spatial data, 
                                          The dataset is available under a Creative Commons Attribution-Share Alike License at the following link:<br>
                                          https://creativecommons.org/licenses/by-sa/3.0/)"
                                          
                                     ))}))
                      )
                      
                                 )), 
           id = "tabselected"
           
                               )
                        )
                               )



# shiny server side codes
server <- function(input,output, session){
  years <- sort(unique(hlthDF$Year)) 
  
  output$slide <- reactive(0)
  
  #Add a slider
  addslider <- function(theyear,selectedyr=max(theyear)){
    
    output$yearSlider <- renderUI({
      if (is.null(theyear)) return(NULL)
      sliderTextInput("sliderYr", "Year",
                      choices = as.character(theyear),
                      selected = selectedyr,
                      width='100%',
                      grid = TRUE)
      
    })
    
  }
  
  output$lyrSlider <- renderUI({
    sliderTextInput("sliderLayer", "Year",
                    choices = as.character(years),
                    selected = max(years),
                    width='100%',
                    grid = TRUE)
    
  })
  
  
  
  addslider(years)
  
  
  
  
  
  
  createContent <- function(selectedyear, df, region){
    content <-  paste ( selectedyear,"<br>",
                        "<strong>Region/Country: </strong>",region,"<br>",
                        "<strong>Severe Wasting: </strong>",df$Severe.wasting, "%<br>",
                        "<strong>Wasting: </strong>",df$Wasting,"%<br>",
                        "<strong>Stunting: </strong>",df$Stunting,"%<br>",
                        "<strong>Underweight: </strong>",df$Underweight,"%<br>",
                        "<strong>Under 5 population: </strong>",df$Under.5.population,"<br>"
    )
    return (content)
  }
  
  
  output$map <- renderLeaflet({
    
    col=brewer.pal(n = 6, name = "Set2")
    hlthmap <- leaflet(data=geodata, options = leafletOptions(worldCopyJump = FALSE, minZoom = 2 ) )  
    hlthmap <- addProviderTiles (hlthmap, "OpenStreetMap",options = providerTileOptions(noWrap = FALSE)) %>% setView(9.1,23.24, zoom=1) %>% addPolygons(
      fillColor = ~col, weight=1, opacity=1,color="black",fillOpacity = 0.7,
      data=geoRegions, label=~ID, highlightOptions  = highlightOptions(
        weight = 3,
        color = "darkgreen",
        fillOpacity = 0.6,
        bringToFront = TRUE),
      layerId = ~ID, group = "All Regions"
      
    )%>% addPolygons(
      fillColor = ~col, weight=1, opacity=1,color="black",fillOpacity = 0.7,
      data=geoAsia, label=~NAME, highlightOptions  = highlightOptions(
        weight = 3,
        color = "darkgreen",
        fillOpacity = 0.6,
        bringToFront = TRUE),
      layerId = ~ISO3, group = "Asian countries"
      
    )%>% addPolygons(
      fillColor = ~col, weight=1, opacity=1,color="black",fillOpacity = 0.7,
      data=geoAfrica, label=~NAME, highlightOptions  = highlightOptions(
        weight = 3,
        color = "darkgreen",
        fillOpacity = 0.6,
        bringToFront = TRUE),
      layerId = ~ISO3, group = "African countries"
      
    )%>% addPolygons(
      fillColor = ~col, weight=1, opacity=1,color="black",fillOpacity = 0.7,
      data=geoAmerica, label=~NAME, highlightOptions  = highlightOptions(
        weight = 3,
        color = "darkgreen",
        fillOpacity = 0.6,
        bringToFront = TRUE),
      layerId = ~ISO3, group = "American countries"
    )%>% addPolygons(
      fillColor = ~col, weight=1, opacity=1,color="black",fillOpacity = 0.7,
      data=geoEurope, label=~NAME, highlightOptions  = highlightOptions(
        weight = 3,
        color = "darkgreen",
        fillOpacity = 0.6,
        bringToFront = TRUE),
      layerId = ~ISO3, group = "European countries"
    )%>% addPolygons(
      fillColor = ~col, weight=1, opacity=1,color="black",fillOpacity = 0.7,
      data=geoOceania, label=~NAME, highlightOptions  = highlightOptions(
        weight = 3,
        color = "darkgreen",
        fillOpacity = 0.6,
        bringToFront = TRUE),
      layerId = ~ISO3, group = "Oceanian countries"
    )%>% addPolygons(
      fillColor = ~col, weight=1, opacity=1,color="black",fillOpacity = 0.7,
      data=geoLatin_america, label=~NAME, highlightOptions  = highlightOptions(
        weight = 3,
        color = "darkgreen",
        fillOpacity = 0.6,
        bringToFront = TRUE),
      layerId = ~ISO3, group = "Latin American countries"
      
    )%>%addLayersControl(
      
      baseGroups = c("All Regions", "Asian countries", "African countries","American countries","European countries","Oceanian countries","Latin American countries"), position = "topright",    options = layersControlOptions(collapsed = TRUE)
    )
    
  })
  
  
  
  # observe click on poygons
  
  observeEvent({input$map_shape_click
    input$sliderYr
    
  } ,{
    
    click <- input$map_shape_click
    
    
    if (is.null(click))
      return()
    
    lat <- click$lat
    lon <- click$lng
    
    
    
    if (click$id %in% unique(hlthDF$Region)) {
      
      centerpt <- getCenter(click$id)
      centerLat <- centerpt[1]
      centerLng <- centerpt[2]
      
      #line chart  
      output$linechart <- renderPlotly({
        plotcompareHealth(click$id)%>%layout(legend = list(
          orientation = "h" , y=1))
      } )
      
      regionyears <- sort(unique(hlthDF$Year[hlthDF$Region==click$id]))
      if (input$sliderYr %in% regionyears){
        df <- region_agg(click$id,input$sliderYr)
        selectedyear <- paste("<strong>year:</strong>",df$Year,"<br>")
        addslider(regionyears,input$sliderYr)
        pchart <- plotpie(click$id,input$sliderYr)
        output$piechart <- renderPlotly({pchart})
        output$barchart <- renderPlotly({
          plotdata(NULL,input$sliderYr)%>%layout(legend = list(
            orientation = "h" , y=1))
        } )
      }
      else
      { df <- region_agg(click$id,max(regionyears))
      selectedyear <- paste("data unavailable for",input$sliderYr, "<br>",
                            "the year", df$Year,"was used <br>",
                            "please use aviable years <br>from the updated year bar<br>"
                            
      )
      #contentgraph <- plotpie(click$id,input$sliderYr)
      addslider(regionyears)
      pchart <- plotpie(click$id,input$sliderYr)
      output$piechart <- renderPlotly({pchart})
      output$barchart <- renderPlotly({
        plotdata(NULL,input$sliderYr)%>%layout(legend = list(
          orientation = "h" , y=1))
      } )
      
      }
      
      content <- createContent(selectedyear,df,click$id) 
      leafletProxy("map") %>%
        clearPopups() %>%setView(centerLng,centerLat,zoom = 2 )%>%
        #addMarkers(lng = lon, lat =lat, popup = input$map_shape_click$id)
        addPopups(lon,lat,content)
    }
    
    
    
    
    if (click$id %in% unique(hlthDF$ISO.code)) {
      cntryyears <- sort(unique(hlthDF$Year[hlthDF$ISO.code==click$id]))
      regionid <- unique(hlthDF$Region[hlthDF$ISO.code==click$id])
      
      #line chart  
      output$linechart <- renderPlotly({
        plotcompareHealth(click$id)%>%layout(legend = list(
          orientation = "h" , y=1))
      } )
      
      if (input$sliderYr %in% cntryyears){
        df <- regionData(click$id,input$sliderYr)
        selectedyear <- paste("<strong>year:</strong>",df$Year,"<br>")
        addslider(cntryyears,input$sliderYr)
        pchart <- plotpie_country(click$id,input$sliderYr)
        output$piechart <- renderPlotly({pchart})
        output$barchart <- renderPlotly({ 
          plotdata(regionid,input$sliderYr)%>%layout(legend = list(
            orientation = "h" , y=1))
        } )
      }
      else
      { df <- regionData(click$id,max(cntryyears))
      selectedyear <- paste("data unavailable for",input$sliderYr, "<br>",
                            "the year", df$Year,"was used <br>",
                            "please use aviable years <br>from the updated year bar<br>"
                            
      )
      
      addslider(cntryyears)
      pchart <- plotpie_country(click$id,input$sliderYr)
      output$piechart <- renderPlotly({pchart})
      output$barchart <- renderPlotly({ 
        plotdata(regionid,input$sliderYr)%>%layout(legend = list(
          orientation = "h" , y=1))
      } )
      
      }
      
      content <- createContent(selectedyear,df,df$Country) 
      leafletProxy("map") %>%
        clearPopups() %>%
        #addMarkers(lng = lon, lat =lat, popup = input$map_shape_click$id)
        addPopups(lon,lat,content)
    }
    
    output$slide <- reactive(0)
    
  }) # end ob observe event for click 
  
  
  # observe add layers events
  
  observeEvent({input$map_groups
    input$sliderLayer},
    {
      
      output$slide <- reactive(if (input$map_groups %in%  
                                   c("All Regions","Asian countries", 
                                     "African countries",
                                     "American countries",
                                     "European countries",
                                     "Oceanian countries",
                                     "Latin American countries")) 1 else 0)
      
      change_plot_on_layer_change(input$map_groups,input$sliderLayer)   
      
      
      
    })# end of observe map_groups
  
  
  change_plot_on_layer_change <- function(id,yr){
    
    if (is.null(id)) 
      return()
    
    leafletProxy("map") %>%
      clearPopups()
    
    if (id == "All Regions" ){
      
      output$barchart <- renderPlotly({ 
        plotdata(NULL,yr)%>%
          layout(legend = list(
            orientation = "h" , y=1))
      } )
      first_region <- sort(unique(hlthDF$Region))[1]
      
      #line chart  
      output$linechart <- renderPlotly({
        plotcompareHealth(first_region)%>%layout(legend = list(
          orientation = "h" , y=1))
      } )
      
      checkyears2 <- sort(unique(hlthDF$Year[hlthDF$Region==first_region]))
      if (yr %in% checkyears2 ){
        
        pchart <- plotpie(first_region,yr)
        output$piechart <- renderPlotly({pchart})
      }
      else
      {
        output$lyrSlider <- renderUI({
          sliderTextInput("sliderLayer", "Year",
                          choices = as.character(years),
                          selected = max(checkyears2),
                          width='100%',
                          grid = TRUE)
          
        })
        pchart <- plotpie(first_region,input$sliderLayer)
        output$piechart <- renderPlotly({pchart})
      }
      
    } else {
      plotid=""
      if (id == "Asian countries" ) {plotid = "Asia"}
      else if (id == "African countries" ) {plotid = "Africa"}
      else if (id == "American countries" ){ plotid = "Northern America"}
      else if (id == "European countries" ){ plotid = "Europe"}
      else if (id == "Oceanian countries" ){ plotid = "Oceania"}
      else if (id == "Latin American countries" ){ plotid = "Latin America and the Caribbean"}
      else
        return()
      
      leafletProxy("map") %>%
        clearPopups()%>%setView(getCenter(plotid)[2],getCenter(plotid)[1],zoom = 3)
      
      checkyears <- sort(unique(hlthDF$Year[hlthDF$Region==plotid]))
      
      #line chart  
      output$linechart <- renderPlotly({
        plotcompareHealth(plotid)%>%layout(legend = list(
          orientation = "h" , y=1))
      } )
      
      # adding plots and the second sliders
      if (yr %in% checkyears){
        output$lyrSlider <- renderUI({
          sliderTextInput("sliderLayer", "Year",
                          choices = as.character(checkyears),
                          selected = yr,
                          width='100%',
                          grid = TRUE)
          
        })
        
        output$barchart <- renderPlotly({ 
          plotdata(plotid,yr)%>%layout(legend = list(
            orientation = "h" , y=1))
        } )
        
        pchart <- plotpie(plotid,yr)
        output$piechart <- renderPlotly({pchart})
      }
      else{
        output$lyrSlider <- renderUI({
          sliderTextInput("sliderLayer", "Year",
                          choices = as.character(checkyears),
                          selected = max(checkyears),
                          width='100%',
                          grid = TRUE)
          
        })
        output$barchart <- renderPlotly({
          plotdata(plotid,max(checkyears))%>%layout(legend = list(
            orientation = "h" , y=1))
        } )
        pchart <- plotpie(plotid,input$sliderLayer)
        output$piechart <- renderPlotly({pchart})
        
      }
    }
    
  }
  
  
  outputOptions(output, "slide", suspendWhenHidden = FALSE)
}



shinyApp(ui=ui, server = server) 

