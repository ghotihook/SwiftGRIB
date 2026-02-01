#!/usr/bin/env python3
"""Check wind calculations between pygrib and expected values."""

import pygrib
import numpy as np

GRIB_FILE = "Tests/SwiftGribTests/Resources/PWAI_WRCTP_50k_15d_3h_-31N_-44S_157E_145W_20260201_0540.grb"

def calc_wind_direction(u, v):
    """Calculate meteorological wind direction (where wind comes FROM)."""
    speed = np.sqrt(u**2 + v**2)
    # Meteorological convention: direction wind is coming FROM
    direction = np.degrees(np.arctan2(-u, -v))
    direction = np.where(direction < 0, direction + 360, direction)
    return speed, direction

grbs = pygrib.open(GRIB_FILE)

# Get first U and V messages (message 2 and 3)
grbs.seek(0)
messages = list(grbs)

# Find first U and V at same time
u_msg = None
v_msg = None
for msg in messages:
    if msg.shortName == '10u' or 'U-component' in str(msg):
        if u_msg is None:
            u_msg = msg
    elif msg.shortName == '10v' or 'V-component' in str(msg):
        if v_msg is None:
            v_msg = msg
    if u_msg and v_msg:
        break

print(f"U message: {u_msg}")
print(f"V message: {v_msg}")
print(f"Valid date: {u_msg.validDate}")

u_vals = u_msg.values.flatten()
v_vals = v_msg.values.flatten()

print(f"\nGrid: {u_msg.Ni} x {u_msg.Nj}")
print(f"First point: lat={u_msg.latitudeOfFirstGridPointInDegrees}, lon={u_msg.longitudeOfFirstGridPointInDegrees}")

# Calculate wind for first 10 points
print("\n" + "="*80)
print("FIRST 10 GRID POINTS - WIND ANALYSIS")
print("="*80)
print(f"{'Idx':>4} {'U (m/s)':>10} {'V (m/s)':>10} {'Speed':>10} {'Dir FROM':>10}")
print("-"*50)

for i in range(10):
    u, v = u_vals[i], v_vals[i]
    speed, direction = calc_wind_direction(u, v)
    print(f"{i:>4} {u:>10.4f} {v:>10.4f} {speed:>10.4f} {direction:>10.1f}°")

# Find point near Sydney (-33.87, 151.21)
# Grid goes from -31 to -44 lat, 145 to 157 lon
# Grid spacing is 0.5 degrees
# Sydney is at approx row (33.87-31)/0.5 = 5.74 ≈ 6, col (151.21-145)/0.5 = 12.42 ≈ 12

print("\n" + "="*80)
print("NEAR SYDNEY (approx -34, 151)")
print("="*80)

lats, lons = u_msg.latlons()
lats_flat = lats.flatten()
lons_flat = lons.flatten()

# Find closest point to Sydney
sydney_lat, sydney_lon = -34.0, 151.0
distances = np.sqrt((lats_flat - sydney_lat)**2 + (lons_flat - sydney_lon)**2)
sydney_idx = np.argmin(distances)

print(f"Closest grid point to Sydney: index {sydney_idx}")
print(f"  Lat: {lats_flat[sydney_idx]:.2f}, Lon: {lons_flat[sydney_idx]:.2f}")

u_sydney = u_vals[sydney_idx]
v_sydney = v_vals[sydney_idx]
speed_sydney, dir_sydney = calc_wind_direction(u_sydney, v_sydney)

print(f"  U: {u_sydney:.4f} m/s")
print(f"  V: {v_sydney:.4f} m/s")
print(f"  Speed: {speed_sydney:.2f} m/s ({speed_sydney * 1.94384:.1f} kts)")
print(f"  Direction: {dir_sydney:.1f}° (wind coming FROM)")

# Direction interpretation
if 337.5 <= dir_sydney or dir_sydney < 22.5:
    compass = "N"
elif 22.5 <= dir_sydney < 67.5:
    compass = "NE"
elif 67.5 <= dir_sydney < 112.5:
    compass = "E"
elif 112.5 <= dir_sydney < 157.5:
    compass = "SE"
elif 157.5 <= dir_sydney < 202.5:
    compass = "S"
elif 202.5 <= dir_sydney < 247.5:
    compass = "SW"
elif 247.5 <= dir_sydney < 292.5:
    compass = "W"
else:
    compass = "NW"

print(f"  Compass: {compass} wind")

# Show what direction the wind is GOING TO (for visualization)
dir_to = (dir_sydney + 180) % 360
print(f"  Wind blowing TOWARDS: {dir_to:.1f}°")

grbs.close()

# Test specific U/V combinations
print("\n" + "="*80)
print("UNIT TESTS - DIRECTION CALCULATION")
print("="*80)
print("Testing standard cases:")
test_cases = [
    (0, -1, "Wind FROM North (blowing south)"),
    (1, 0, "Wind FROM West (blowing east)"),
    (0, 1, "Wind FROM South (blowing north)"),
    (-1, 0, "Wind FROM East (blowing west)"),
    (1, -1, "Wind FROM NW (blowing SE)"),
    (-1, -1, "Wind FROM NE (blowing SW)"),
    (-1, 1, "Wind FROM SE (blowing NW)"),
    (1, 1, "Wind FROM SW (blowing NE)"),
]

for u, v, desc in test_cases:
    speed, direction = calc_wind_direction(u, v)
    print(f"  U={u:>2}, V={v:>2} -> Dir={direction:>6.1f}° : {desc}")
