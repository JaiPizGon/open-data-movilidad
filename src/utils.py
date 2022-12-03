"""
Utils.py files define a Paths object to manage paths to different folders in the project.
"""

import pathlib
import os
import shutil


class Paths():
    def __init__(self):
        # Detect parent path
        b = pathlib.Path(__file__).resolve()
        # Define path to data folder
        self._data = b.parents[1] / 'data'
        # Define path to src folder
        self._src = b.parents[1] / 'src'
        # Define path to notebooks folder
        self._notebooks = b.parents[1] / 'notebooks'
        # Define path to reports folder
        self._reports = b.parents[1] / 'reports'

    @property
    def data(self):
        return self._data

    @data.setter
    def data(self, val):
        self._data = pathlib.Path(val)

    @property
    def src(self):
        return self._src

    @src.setter
    def src(self, val):
        self._src = pathlib.Path(val)

    @property
    def notebooks(self):
        return self._notebooks

    @notebooks.setter
    def notebooks(self, val):
        self._notebooks = pathlib.Path(val)

    @property
    def reports(self):
        return self._reports

    @reports.setter
    def reports(self, val):
        self._reports = pathlib.Path(val)
        
    @property
    def raw(self):
        return self.data / "raw"

    @property
    def processed(self):
        return self.data / "processed"
    
    def __str__(self):
        return f"""
                Data path:                {self.data}
                INE data download path:   {self.raw}
                Processed data path:      {self.processed}
                Reports directory path:   {self.reports}
                Source directory path:    {self.src}
                Notebooks directory path: {self.notebooks}
                Reports directory path:   {self.reports}
                """

PATHS = Paths()


def check_dirs():
    """Function to check project directories, create not detected folders.

    Returns:
        bool: True if no error is produced during function execution
    """
    print("Checking directories...")
        
    for attr, path in vars(PATHS).items():
        if not attr.startswith('__'):
            if not path.exists():
                print(f"{path} folder not detected, creating it.")
                os.makedirs(path)
            else:
                print(f"{path} folder detected.")
    
    if not PATHS.processed.exists():
        print(f"{PATHS.processed} folder not detected, creating it.")
        os.makedirs(PATHS.processed)
    else:
        print(f"{PATHS.processed} folder detected.")
        
    if not PATHS.raw.exists():
        print(f"{PATHS.raw} folder not detected, creating it.")
        os.makedirs(PATHS.raw)
    else:
        print(f"{PATHS.raw} folder detected.")
    
    return True

if __name__ == '__main__':
    check_dirs()