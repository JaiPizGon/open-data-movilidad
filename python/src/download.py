"""
Download.py file download data from the opendata server.
"""
import pandas as pd
import os
import datetime
import urllib.parse

from utils import PATHS, BASE_URL, MAESTRA_VALID_VALUES, LOCATION_VALID_VALUES, check_dirs
from requests import Session
from tqdm import tqdm
from urllib3.exceptions import InsecureRequestWarning
from urllib3 import disable_warnings

import click

@click.command()
@click.option('--maestra-version', '-mv', default='maestra1', help="Version of maestra from where to download.")
@click.option('--location', '-l', default='municipios', help="Locations of data.")
@click.option('--update', '-u', is_flag=True, default='False', help="Update current files without overwriting.")
@click.option('--force', '-f', is_flag=True, default='False', help="Force to redownload data even if it is already downloaded.")
def download(maestra_version:str='maestra1', 
            location:str='municipios', 
            update:bool=False, 
            force:bool=False,
            start:datetime.date=datetime.date(2020, 2, 21),
            end:datetime.date=datetime.date(2021, 5, 9)) -> list:  
    """Download files from opendata-movilidad

    Args:
        maestra_version (str, optional): Version of maestra from where to download. Valid versions are 'maestra1' and 'maestra2'. Defaults to 'maestra1'.
        location (str, optional): Locations of data. Valid locations are 'distritos' and 'municipios'. Defaults to 'municipios'.
        update (bool, optional): Only download data not already downloaded. Defaults to False.
        force (bool, optional): Force to redownload data even if it is already downloaded. Defaults to False.

    Raises:
        ValueError: maestra_version must be one of the valid versions.
        ValueError: location must be one of the valid locations.

    Returns:
        list: list of paths to downloaded files
    """
    # Valid input data
    if maestra_version not in MAESTRA_VALID_VALUES:
        raise ValueError(f'maestra version {maestra_version} is not a valid input. Valid versions are: {", ".join(MAESTRA_VALID_VALUES)}')
    
    if location not in LOCATION_VALID_VALUES:
        raise ValueError(f'locations {location} is not a valid input. Valid locations are: {", ".join(LOCATION_VALID_VALUES)} ')
    
    # Avoid printing warnings due to unverified url
    disable_warnings(InsecureRequestWarning)

    # Prepare output dir
    files = []
    raw_dir = PATHS.raw / f'{maestra_version}' / f'{location}'
    raw_dir.exists() or os.makedirs(raw_dir)

    # Generate time range
    lsfiles = sorted(os.listdir(raw_dir))
    if update:
        start = datetime.datetime.strptime(lsfiles[-1][:8], '%Y%m%d').date()
        start += datetime.timedelta(days=1)
        end = datetime.datetime.today().date()
    dates = pd.date_range(start, end, freq='d')

    if dates.empty:
        print('Already up-to-date')
        return []

    # Download files
    print(f'Downloading files for the period {start} - {end}')
    s = Session()
    for d in tqdm(dates):
        url = f'{BASE_URL}/{maestra_version}-mitma-{location}/ficheros-diarios/{d:%Y}-{d:%m}/{d:%Y%m%d}_maestra_{maestra_version[-1]}_mitma_{location[:-1]}.txt.gz'

        aux = urllib.parse.urlparse(url)
        fpath = os.path.basename(aux.path)
        fpath = raw_dir / fpath

        if fpath.exists() and not force:
            print(f"\t {os.path.basename(url)} already downloaded, not overwriting it."
                " To overwrite it use (force=True)")
            continue

        try:
            resp = s.get(url, verify=False)
            if resp.status_code == 404:
                print(f'{d.date()} not available yet')
                continue
            with open(fpath, 'wb') as f:
                f.write(resp.content)
            files.append(fpath)

        except Exception as e:
            print(f'Error downloading {url} with error {e}')
    # Fix error in original dataset
    try:
        fix_1207()
    except:
        print('No fixes needed as 07-2020 is not in downloaded files')
    return files

def fix_1207():
    """
    Fix error in original dataset (see README)
    """
    raw_dir = PATHS.raw / 'maestra1' / 'municipios'
    src = raw_dir / '20200705_maestra_1_mitma_municipio.txt.gz'
    dst = raw_dir / '20200712_maestra_1_mitma_municipio.txt.gz'

    df = pd.read_csv(src,
                    sep='|',
                    thousands='.',
                    dtype={'origen': 'string', 'destino': 'string'},
                    compression='gzip')

    # Replace date
    df['fecha'] = '20200712'

    # Apply thousands separator
    def add_sep(x):
        x = str(x)
        if len(x) > 3:
            return f'{str(x)[:-3]}.{str(x)[-3:]}'
        else:
            return x

    df['viajes'] = df['viajes'].apply(add_sep)
    df['viajes_km'] = df['viajes_km'].apply(add_sep)

    df.to_csv(dst,
            sep='|',
            compression='gzip',
            index=False)
    
if __name__ == '__main__':
    download()