"""
Generate input and output mobility index for each province based on flows
"""
import pandas as pd
from utils import PATHS
import numpy as np

def generate_index():
    flows = pd.read_csv(PATHS.processed / 'flowmap_flows_location.csv', encoding='latin1', sep=';')
    indexes = flows.drop(columns=['origin', 'dest','orig_lat', 'orig_lon', 'dest_lat', 'dest_lon']).groupby(by=['time','origin_name','dest_name'], as_index=False).sum(numeric_only=True)
    
    ## INTERNAL INDEX
    internal_indexes = indexes[indexes['origin_name'] == indexes['dest_name']]
    internal_indexes = internal_indexes.drop(columns=['dest_name'])
    internal_indexes.reset_index(drop=True, inplace=True)
    
    # OUTWARD INDEX
    outward_indexes = indexes[indexes['origin_name'] != indexes['dest_name']]
    outward_indexes.reset_index(drop=True, inplace=True)
    outward_indexes = outward_indexes.groupby(by=['time','origin_name'], as_index=False).sum(numeric_only=True)
    
    # INWARD INDEX
    inward_indexes = indexes[indexes['origin_name'] != indexes['dest_name']]
    inward_indexes.reset_index(drop=True, inplace=True)
    inward_indexes = inward_indexes.groupby(by=['time','dest_name'], as_index=False).sum(numeric_only=True) 
    
    # INDEX NAME
    internal_indexes['index'] = 'INTERNAL'
    outward_indexes['index'] = 'OUTWARD'
    inward_indexes['index'] = 'INWARD'
    
    # Include whole spain
    spain_internal_index = internal_indexes.groupby(by=['time','index'], as_index=False).sum(numeric_only=True)
    spain_outward_index = outward_indexes.groupby(by=['time','index'], as_index=False).sum(numeric_only=True)
    spain_inward_index = inward_indexes.groupby(by=['time','index'], as_index=False).sum(numeric_only=True)
    spain_internal_index['origin_name'] = 'Spain (Total)'
    spain_outward_index['origin_name'] = 'Spain (Total)'
    spain_inward_index['origin_name'] = 'Spain (Total)'
    internal_indexes = pd.concat([internal_indexes, spain_internal_index], axis=0)
    outward_indexes = pd.concat([outward_indexes, spain_outward_index], axis=0)
    inward_indexes = pd.concat([inward_indexes, spain_inward_index], axis=0)
    internal_indexes['time'] = pd.to_datetime(internal_indexes['time'])
    outward_indexes['time'] = pd.to_datetime(outward_indexes['time'])
    inward_indexes['time'] = pd.to_datetime(inward_indexes['time'])
    internal_indexes['weekday'] = np.array([i.weekday() for i in internal_indexes['time']])
    outward_indexes['weekday'] = np.array([i.weekday() for i in outward_indexes['time']])
    inward_indexes['weekday'] = np.array([i.weekday() for i in inward_indexes['time']])
    index = pd.concat([internal_indexes, outward_indexes, inward_indexes], axis=0)
    
    # Create reference indexes
    internal_indexes['time'] = pd.to_datetime(internal_indexes['time'])
    outward_indexes['time'] = pd.to_datetime(outward_indexes['time'])
    inward_indexes['time'] = pd.to_datetime(inward_indexes['time'])
    # Create range of reference for MAY
    ref2_date_range = pd.date_range("2020-05-04", periods=7, freq="d")
    mask_inward = (inward_indexes['time'] >= ref2_date_range[0]) & (inward_indexes['time'] <= ref2_date_range[-1])
    mask_outward = (outward_indexes['time'] >= ref2_date_range[0]) & (outward_indexes['time'] <= ref2_date_range[-1])
    mask_internal = (internal_indexes['time'] >= ref2_date_range[0]) & (internal_indexes['time'] <= ref2_date_range[-1])
    ref2_internal_indexes = internal_indexes.loc[mask_internal]
    ref2_outward_indexes = outward_indexes.loc[mask_outward]
    ref2_inward_indexes = inward_indexes.loc[mask_inward]
    ref2_index = pd.concat([ref2_internal_indexes, ref2_outward_indexes, ref2_inward_indexes], axis=0)
    
    # Read references for FEB
    ref_flows = pd.read_csv(PATHS.processed / 'ref_flowmap_flows_location.csv', encoding='latin1', sep=';')
    ref_indexes = ref_flows.drop(columns=['origin', 'dest','orig_lat', 'orig_lon', 'dest_lat', 'dest_lon']).groupby(by=['time','origin_name','dest_name'], as_index=False).sum(numeric_only=True)
    ref_internal_indexes = ref_indexes[ref_indexes['origin_name'] == ref_indexes['dest_name']]
    ref_internal_indexes = ref_internal_indexes.drop(columns=['dest_name'])
    ref_internal_indexes.reset_index(drop=True, inplace=True)
    ref_outward_indexes = ref_indexes[ref_indexes['origin_name'] != ref_indexes['dest_name']]
    ref_outward_indexes.reset_index(drop=True, inplace=True)
    ref_outward_indexes = ref_outward_indexes.groupby(by=['time','origin_name'], as_index=False).sum(numeric_only=True)
    ref_inward_indexes = ref_indexes[ref_indexes['origin_name'] != ref_indexes['dest_name']]
    ref_inward_indexes.reset_index(drop=True, inplace=True)
    ref_inward_indexes = ref_inward_indexes.groupby(by=['time','dest_name'], as_index=False).sum(numeric_only=True)
    ref_inward_indexes = ref_inward_indexes.rename(columns={'dest_name': 'origin_name'})
    ref_internal_indexes['index'] = 'INTERNAL'
    ref_outward_indexes['index'] = 'OUTWARD'
    ref_inward_indexes['index'] = 'INWARD'
    ref_spain_internal_index = ref_internal_indexes.groupby(by=['time','index'], as_index=False).sum(numeric_only=True)
    ref_spain_outward_index = ref_outward_indexes.groupby(by=['time','index'], as_index=False).sum(numeric_only=True)
    ref_spain_inward_index = ref_inward_indexes.groupby(by=['time','index'], as_index=False).sum(numeric_only=True)
    ref_spain_internal_index['origin_name'] = 'Spain (Total)'
    ref_spain_outward_index['origin_name'] = 'Spain (Total)'
    ref_spain_inward_index['origin_name'] = 'Spain (Total)'
    ref_internal_indexes = pd.concat([ref_internal_indexes, ref_spain_internal_index], axis=0)
    ref_outward_indexes = pd.concat([ref_outward_indexes, ref_spain_outward_index], axis=0)
    ref_inward_indexes = pd.concat([ref_inward_indexes, ref_spain_inward_index], axis=0)
    ref_internal_indexes['time'] = pd.to_datetime(ref_internal_indexes['time'])
    ref_outward_indexes['time'] = pd.to_datetime(ref_outward_indexes['time'])
    ref_inward_indexes['time'] = pd.to_datetime(ref_inward_indexes['time'])
    ref_internal_indexes['weekday'] = np.array([i.weekday() for i in ref_internal_indexes['time']])
    ref_outward_indexes['weekday'] = np.array([i.weekday() for i in ref_outward_indexes['time']])
    ref_inward_indexes['weekday'] = np.array([i.weekday() for i in ref_inward_indexes['time']])
    ref_index = pd.concat([ref_internal_indexes, ref_outward_indexes, ref_inward_indexes], axis=0)
    
    # Calculate mobility indexes
    index['INDEX_FEB'] = np.nan
    index['INDEX_MAY'] = np.nan
    for i in range(index.shape[0]):
        origin_name_ind = index['origin_name'].iloc[i]
        index_ind = index['index'].iloc[i]
        weekday_ind = index['weekday'].iloc[i]
        count_ind = index['count'].iloc[i]
        ref_ind = ref_index.loc[(ref_index['origin_name'] == origin_name_ind) & (ref_index['index'] == index_ind) & (ref_index['weekday'] == weekday_ind),'count']
        ref2_ind = ref2_index.loc[(ref2_index['origin_name'] == origin_name_ind) & (ref2_index['index'] == index_ind) & (ref2_index['weekday'] == weekday_ind),'count']

        index['INDEX_FEB'].iloc[i] = count_ind / ref_ind
        index['INDEX_MAY'].iloc[i] = count_ind / ref2_ind
        
    # ADD CCAA
    provinces = pd.read_csv(
        PATHS.processed / "provincias.csv",
        encoding='latin1', sep=";"
        )
    provinces = provinces.iloc[:,0:2].dropna()
    index = pd.merge(index, provinces, how='inner', left_on='origin_name', right_on='Provincia').drop(columns=['Provincia'])
    
    # CONCATENATE INTERNAL & OUTWARD & INWARD INDEXES
    index.to_csv(
        PATHS.processed / "mobility_index.csv",
        index=False, encoding='latin1', sep=";"
    )

if __name__ == '__main__':
    generate_index() 