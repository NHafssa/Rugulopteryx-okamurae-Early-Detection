# IMPORTS
import ___creds_gbif as creds
from pygbif import occurrences as occ

# MAIN
def main():
    ''' Request GBIF occurrences of R. okamurae. '''
    gbif_keys = ["5824863"] # Taxon key associated with R. okamurae in GBIF.
    download_keys = [] # Keep track of download task IDs.
    query = {
        "type": "and",
        "predicates": [
            {"type": "in", "key": "TAXON_KEY", "values": gbif_keys},
            {"type": "equals", "key": "HAS_COORDINATE", "value": "true"},
            {"type": "equals", "key": "HAS_GEOSPATIAL_ISSUE", "value": "false"},
        ]
    }
    dk = occ.download(queries=query,
                      user=creds.GBIF_USER,
                      pwd=creds.GBIF_PWD,
                      email=creds.GBIF_EMAIL,
                      format="SIMPLE_CSV")
    download_keys.append(dk[0])
    print("Download Keys =", download_keys)

if __name__ == "__main__":
    main()