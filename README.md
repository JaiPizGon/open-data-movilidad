# open-data-movilidad
Analysis of mobility data in Spain during June 2020 to detect how mobility has changed due to COVID-19

## Data sources
1.	Mobile phone records. This data for the extraction of mobility indicators. It consists of a set of records of mobile phone antennas which, once anonymized, comply with current data protection regulations. This data set is provided by the Spanish ministry of transport, mobility and urban agenda [here](https://www.mitma.gob.es/ministerio/covid-19/evolucion-movilidad-big-data/opendata-movilidad). 
2.	Data on State of Alarm phases and measures. They come from the Royal Decree of the Ministry of the Presidency of the Government of Spain published in the Official State Gazette [here](https://www.lamoncloa.gob.es/consejodeministros/Paginas/enlaces/280420-enlace-desescalada.aspx).
3.	Epidemic data. Data on the number of coronavirus infections and deaths. This data is important as the mobility patterns shall not only be affected by the de-escalation measures but also by the COVID-19 situation in the different provinces. [here](https://www.narrativa.com/navigating-the-covid-19-pandemic-artificial-intelligence-natural-language-generation-and-the-covid-19-tracking-project/ ) and [here](https://www.datadista.com/coronavirus/evolucion-de-la-vacunacion-en-espana/ )
4.	Geographic data. Data in geojson format with provinces and regions geographic limits were downloaded from [here](https://data.opendatasoft.com/explore/dataset/georef-spain-municipio%40public/export/?disjunctive.acom_code&amp;disjunctive.acom_name&amp;disjunctive.prov_code&amp;disjunctive.prov_name&amp;disjunctive.mun_code&amp;disjunctive.mun_name ).

## Methodology
![image](https://user-images.githubusercontent.com/50148386/206300946-9b5dffe3-2ea6-4498-835a-fb8d45550584.png)

## Dashboard
Result of the project was a dashboard to analyze the data obtained from MITMA, it can be accessed [here](https://jaipizgon.shinyapps.io/mitma/)
