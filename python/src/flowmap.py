"""
Generate the files for flowmap of existing processed files
"""

import requests
import pandas as pd

from utils import PATHS

import plotly.express as px

def generate_flowmap_data():

    flows = pd.read_csv(PATHS.processed / "province_flux.csv", sep=";", encoding='latin1')

    # Load coordinates of places
    f = PATHS.processed / "flowmap_coord.csv"
    if not f.exists():
        lat, lon = [], []
        names = sorted(set(flows['province origin']))
        for province in names:
            url = 'https://nominatim.openstreetmap.org/search'
            if province in ['Ceuta', 'Melilla']:
                params = {'city': province, 'country': 'spain', 'format': 'json'}
            else:
                params = {'county': correct_provinces_name(province), 'country': 'spain', 'format': 'json'}
            r = requests.get(url, params=params)
            r = r.json()[0]
            lat.append(r['lat'])
            lon.append(r['lon'])

        coord = pd.DataFrame({'name': names, 'lat': lat, 'lon': lon})
        coord.to_csv(
            PATHS.processed / "flowmap_coord.csv",
            index=False, 
            encoding='latin1', 
            sep=";"
        )
    else:
        coord = pd.read_csv(f, encoding='latin1', sep=";")

    # Save locations
    locations = flows.groupby(['province origin', 'province id origin']).size().reset_index()
    locations = locations.drop(0, axis=1)
    locations = locations.rename(columns={"province origin": "name", "province id origin": "id"})
    locations = locations.merge(coord)
    locations = locations[['id', 'name', 'lat', 'lon']]

    locations.to_csv(
        PATHS.processed / "flowmap_locations.csv",
        index=False, sep=";", 
        encoding='latin1'
    )

    # Save flows
    flows = flows.rename(columns={"province id origin": "origin",
                                "province id destination": "dest",
                                "flux": "count",
                                "date": "time"})
    flows = flows.drop(['province origin', 'province destination'], axis=1)

    flows.to_csv(
        PATHS.processed / "flowmap_flows.csv",
        index=False, encoding='latin1', sep=";"
    )
    
    # Merge both dataframes to have names of locations associated to flows
    flows_locations = pd.merge(flows, locations, left_on='origin', right_on='id')
    flows_locations = flows_locations.drop(columns='id')
    flows_locations = flows_locations.rename(columns={'name':'origin_name','lat':'orig_lat','lon':'orig_lon'})
    flows_locations = pd.merge(flows_locations, locations, left_on='dest', right_on='id')
    flows_locations = flows_locations.drop(columns='id')
    flows_locations = flows_locations.rename(columns={'name':'dest_name','lat':'dest_lat','lon':'dest_lon'})
    
    flows_locations.to_csv(
        PATHS.processed / "flowmap_flows_location.csv",
        index=False, encoding='latin1', sep=";"
    )

def correct_provinces_name(province:str) -> str:
    """Correct name of the province in order to obtain correct latitude and longitude

    Args:
        province (str): name of the province, spanish encoded

    Returns:
        str: correct name of the province for openstreetmap website
    """
    if ("/" in province):
        return province.split("/")[0]
    elif (province == "Coruña, A"):
        return "A Coruna"
    elif ("," in province):
        return province.split(", ")[1] + " " + province.split(", ")[0]
    return province

if __name__ == '__main__':
    generate_flowmap_data() 
