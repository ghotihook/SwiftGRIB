#!/usr/bin/env python3
"""Verify wind direction output from SwiftGrib matches expected."""

import json
import numpy as np

def load_json(filename):
    """Load JSON, handling potential build output prefix."""
    with open(filename, 'r') as f:
        content = f.read()
    lines = content.split('\n')
    json_lines = []
    found_json = False
    for line in lines:
        stripped = line.strip()
        if not found_json:
            if stripped == '[':
                found_json = True
                json_lines.append(line)
        else:
            json_lines.append(line)
    return json.loads('\n'.join(json_lines))

# Load SwiftGrib output
swift_data = load_json("swiftgrib_output.json")

# Find first U and V messages
u_msg = None
v_msg = None
for msg in swift_data:
    if msg.get("indicatorOfParameter") == 33 and u_msg is None:  # U-wind
        u_msg = msg
    elif msg.get("indicatorOfParameter") == 34 and v_msg is None:  # V-wind
        v_msg = msg
    if u_msg and v_msg:
        break

if not u_msg or not v_msg:
    print("Could not find U/V messages")
    exit(1)

print("SwiftGrib U/V Data Analysis")
print("="*60)

u_vals = u_msg.get("allValues") or u_msg.get("first10")
v_vals = v_msg.get("allValues") or v_msg.get("first10")

print(f"U message param: {u_msg.get('parameterName')}")
print(f"V message param: {v_msg.get('parameterName')}")

# Calculate wind direction for first 10 points
print("\nFirst 10 points - Wind from SwiftGrib raw U/V:")
print(f"{'Idx':>4} {'U':>10} {'V':>10} {'Speed':>10} {'Dir FROM':>10}")
print("-"*50)

for i in range(min(10, len(u_vals))):
    u, v = u_vals[i], v_vals[i]
    speed = np.sqrt(u**2 + v**2)
    direction = np.degrees(np.arctan2(-u, -v))
    if direction < 0:
        direction += 360
    print(f"{i:>4} {u:>10.4f} {v:>10.4f} {speed:>10.4f} {direction:>10.1f}°")

# Check Sydney area (index 162 based on previous analysis)
sydney_idx = 162
if len(u_vals) > sydney_idx:
    u_syd = u_vals[sydney_idx]
    v_syd = v_vals[sydney_idx]
    speed_syd = np.sqrt(u_syd**2 + v_syd**2)
    dir_syd = np.degrees(np.arctan2(-u_syd, -v_syd))
    if dir_syd < 0:
        dir_syd += 360
    
    print(f"\nSydney area (index {sydney_idx}):")
    print(f"  U: {u_syd:.4f} m/s")
    print(f"  V: {v_syd:.4f} m/s")
    print(f"  Speed: {speed_syd:.2f} m/s")
    print(f"  Direction: {dir_syd:.1f}° (FROM)")
    
    # What the barb should look like
    dir_to = (dir_syd + 180) % 360
    print(f"\n  Wind barb should point TOWARDS: {dir_to:.1f}°")
    print(f"  (barb arrow points direction wind is GOING)")
