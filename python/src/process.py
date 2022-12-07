"""
Process data downloaded from opendata mitma
"""
import datetime
from multiprocessing.pool import ThreadPool
import os

import pandas as pd
from tqdm import tqdm

from utils import PATHS

def process_day(tarfile):
    """Process data for a given day

    Args:
        tarfile (Path): path to the stored data for the given day

    Raises:
        Exception: Error if read_csv cannot read tarfile

    Returns:
        pd.DataFrame: Dataframe containing data for given day
    """
    try:
        df = pd.read_csv(tarfile,
                        sep='|',
                        thousands='.',
                        dtype={'origen': 'string', 'destino': 'string'},
                        compression='gzip', 
                        encoding='latin1')
    except Exception as e:
        print(f'Error processing {tarfile}')
        raise Exception(e)

    df['fecha'] = pd.to_datetime(df.fecha, format='%Y%m%d')
    df['fecha'] = df['fecha'].dt.date

    # Aggregate data inside same province
    df['origen'] = df['origen'].transform(lambda x: x[:2])
    df['destino'] = df['destino'].transform(lambda x: x[:2])

    # Aggregate across hours and distances
    df = df.groupby(['fecha', 'origen', 'destino']).sum(numeric_only=True).reset_index()
    df = df.drop(columns=['periodo', 'viajes_km'])

    return df


def process(day_files='all',
            exp='maestra1',
            res='municipios',
            update=False,
            force=False):
    """
    day_files : list, str
        List of absolute paths to day-tars to process.
        If 'all' is passed, it will process every file.
    """

    # Prepare files
    raw_dir = PATHS.raw / f'{exp}' / f'{res}'
    if day_files == 'all':
        day_files = sorted(os.listdir(raw_dir))
        day_files = [raw_dir / d for d in day_files]
    if not day_files:
        print('No files to process.')
        return

    # Load INE code_map to add names to the tables
    cod_path = PATHS.raw / 'codigos_ine' / '20_cod_prov.xls'
    cod_map = pd.read_excel(cod_path, dtype={'Codigo': 'string'})
    cod_map = dict(zip(cod_map.Codigo, cod_map.Literal))

    # Load existing files
    if update and (PATHS.processed / "province_flux.csv").exists():
        previous_df = pd.read_csv(PATHS.processed / "province_flux.csv")

        # Compare dates
        last = datetime.datetime.strptime(previous_df['date'].iloc[-1], '%Y-%m-%d')
        first = datetime.datetime.strptime(day_files[0].name[:8], '%Y%m%d')

        if last + datetime.timedelta(days=1) != first and not force:
            raise Exception(f'The last day ({last.date()}) saved and the first day ({first.date()}) '
                            'of the update are not consecutive. '
                            'You will probably be safer rerunning the download  '
                            'and running the whole processing from scratch (update=False). '
                            'You can use force=True if you want to append the data '
                            'nevertheless.')
    else:
        previous_df = pd.DataFrame([])

    # Parallelize the processing for speed
    print('Processing data ...')
    thread_num = 4
    results = []
    out = ThreadPool(thread_num).imap(process_day, day_files)
    for r in tqdm(out, total=len(day_files)):
        results.append(r)
    full_df = pd.concat(results).reset_index()

    # Clean and add id codes
    full_df = full_df.rename(columns={'fecha': 'date',
                                    'origen': 'province id origin',
                                    'destino': 'province id destination',
                                    'viajes': 'flux'})

    full_df['province origin'] = full_df['province id origin'].map(cod_map)
    full_df['province destination'] = full_df['province id destination'].map(cod_map)
    full_df = full_df[['date', 'province origin', 'province id origin',
                    'province destination', 'province id destination', 'flux']]

    # Append and save
    full_df = pd.concat([previous_df, full_df])

    full_df.to_csv(
        PATHS.processed / "province_flux.csv",
        index=False,
        sep=";", 
        encoding='latin1'
    )


if __name__ == '__main__':
    process()