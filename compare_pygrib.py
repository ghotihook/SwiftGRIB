#!/usr/bin/env python3
"""Extract GRIB data using pygrib for comparison with SwiftGrib."""

import pygrib
import json
import sys

GRIB_FILE = "Tests/SwiftGribTests/Resources/PWAI_WRCTP_50k_15d_3h_-31N_-44S_157E_145W_20260201_0540.grb"

def safe_get(grb, attr, default=None):
    """Safely get an attribute from a grib message."""
    try:
        return getattr(grb, attr)
    except (RuntimeError, KeyError, AttributeError):
        return default

def main():
    grbs = pygrib.open(GRIB_FILE)
    
    results = []
    
    for i, grb in enumerate(grbs):
        msg_num = i + 1
        
        # Get basic info
        info = {
            "message": msg_num,
            "parameterName": safe_get(grb, 'parameterName'),
            "shortName": safe_get(grb, 'shortName'),
            "indicatorOfParameter": safe_get(grb, 'indicatorOfParameter'),
            "table2Version": safe_get(grb, 'table2Version'),
            "level": safe_get(grb, 'level'),
            "levelType": safe_get(grb, 'levelType'),
            "typeOfLevel": safe_get(grb, 'typeOfLevel'),
            "validDate": str(grb.validDate),
            "analDate": str(safe_get(grb, 'analDate')),
            "dataDate": safe_get(grb, 'dataDate'),
            "dataTime": safe_get(grb, 'dataTime'),
            "year": safe_get(grb, 'year'),
            "month": safe_get(grb, 'month'),
            "day": safe_get(grb, 'day'),
            "hour": safe_get(grb, 'hour'),
            "minute": safe_get(grb, 'minute'),
        }
        
        # Get grid info
        info["Ni"] = safe_get(grb, 'Ni')
        info["Nj"] = safe_get(grb, 'Nj')
        info["latitudeOfFirstGridPoint"] = safe_get(grb, 'latitudeOfFirstGridPointInDegrees')
        info["longitudeOfFirstGridPoint"] = safe_get(grb, 'longitudeOfFirstGridPointInDegrees')
        info["latitudeOfLastGridPoint"] = safe_get(grb, 'latitudeOfLastGridPointInDegrees')
        info["longitudeOfLastGridPoint"] = safe_get(grb, 'longitudeOfLastGridPointInDegrees')
        info["iDirectionIncrement"] = safe_get(grb, 'iDirectionIncrementInDegrees')
        info["jDirectionIncrement"] = safe_get(grb, 'jDirectionIncrementInDegrees')
        
        # Get values
        values = grb.values.flatten()
        info["numValues"] = len(values)
        info["min"] = float(values.min())
        info["max"] = float(values.max())
        info["mean"] = float(values.mean())
        
        # Get first 10 and last 10 values for detailed comparison
        info["first10"] = [float(v) for v in values[:10]]
        info["last10"] = [float(v) for v in values[-10:]]
        
        # Get all values for complete comparison (for first few messages of each type)
        if msg_num <= 5 or (msg_num - 1) % 51 < 2:  # First 5, plus first 2 of each param type
            info["allValues"] = [float(v) for v in values]
        
        # Get values at specific indices for spot checks
        total = len(values)
        spot_indices = [0, 1, 2, total//4, total//2, 3*total//4, total-3, total-2, total-1]
        info["spotValues"] = {str(idx): float(values[idx]) for idx in spot_indices}
        
        # Get lats/lons
        lats, lons = grb.latlons()
        info["firstLat"] = float(lats.flatten()[0])
        info["firstLon"] = float(lons.flatten()[0])
        info["lastLat"] = float(lats.flatten()[-1])
        info["lastLon"] = float(lons.flatten()[-1])
        
        results.append(info)
    
    grbs.close()
    
    # Output as JSON for easy parsing
    print(json.dumps(results, indent=2))

if __name__ == "__main__":
    main()
