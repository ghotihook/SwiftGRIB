#!/usr/bin/env python3
"""Compare pygrib and SwiftGrib outputs in detail."""

import json
import sys

def load_json(filename):
    """Load JSON, handling potential build output prefix."""
    with open(filename, 'r') as f:
        content = f.read()
    
    # Find the start of JSON array - a line that is just '[' (possibly with whitespace)
    lines = content.split('\n')
    json_lines = []
    found_json = False
    
    for line in lines:
        stripped = line.strip()
        if not found_json:
            # JSON array starts with just '[' on its own line
            if stripped == '[':
                found_json = True
                json_lines.append(line)
        else:
            json_lines.append(line)
    
    json_content = '\n'.join(json_lines)
    return json.loads(json_content)

def compare_values(pygrib_vals, swift_vals, tolerance=1e-6):
    """Compare two lists of values with tolerance."""
    if len(pygrib_vals) != len(swift_vals):
        return False, f"Length mismatch: {len(pygrib_vals)} vs {len(swift_vals)}"
    
    max_diff = 0
    max_diff_idx = 0
    diffs = []
    
    for i, (pv, sv) in enumerate(zip(pygrib_vals, swift_vals)):
        diff = abs(pv - sv)
        if diff > max_diff:
            max_diff = diff
            max_diff_idx = i
        if diff > tolerance:
            diffs.append((i, pv, sv, diff))
    
    if diffs:
        return False, f"Max diff {max_diff:.10f} at index {max_diff_idx}, {len(diffs)} values differ"
    return True, f"Max diff {max_diff:.10e}"

def main():
    print("=" * 70)
    print("PYGRIB vs SWIFTGRIB DEEP COMPARISON")
    print("=" * 70)
    
    pygrib_data = load_json("pygrib_output.json")
    swift_data = load_json("swiftgrib_output.json")
    
    print(f"\nPygrib messages: {len(pygrib_data)}")
    print(f"SwiftGrib messages: {len(swift_data)}")
    
    if len(pygrib_data) != len(swift_data):
        print("ERROR: Message count mismatch!")
        return
    
    print(f"\nComparing {len(pygrib_data)} messages...\n")
    
    # Track issues by category
    issues = {
        "values": [],
        "metadata": [],
        "grid": [],
        "time": [],
    }
    
    all_match = True
    
    for i in range(len(pygrib_data)):
        pg = pygrib_data[i]
        sg = swift_data[i]
        msg_num = i + 1
        
        # Compare all values if available
        if "allValues" in pg and "allValues" in sg:
            match, detail = compare_values(pg["allValues"], sg["allValues"])
            if not match:
                all_match = False
                issues["values"].append(f"Msg {msg_num} ({pg['parameterName']}): {detail}")
                print(f"[FAIL] Message {msg_num}: VALUES MISMATCH")
                print(f"       Parameter: {pg['parameterName']}")
                print(f"       {detail}")
                
                # Show first few mismatches
                pg_vals = pg["allValues"]
                sg_vals = sg["allValues"]
                print(f"       First 5 values comparison:")
                for j in range(min(5, len(pg_vals))):
                    pv, sv = pg_vals[j], sg_vals[j]
                    diff = abs(pv - sv)
                    status = "✓" if diff < 1e-6 else "✗"
                    print(f"         [{j}] pygrib: {pv:.10f}, swift: {sv:.10f}, diff: {diff:.2e} {status}")
                print()
            else:
                print(f"[OK]   Message {msg_num}: {pg['parameterName'][:30]:30} {detail}")
        else:
            # Compare first10/last10
            if "first10" in pg and "first10" in sg:
                match1, detail1 = compare_values(pg["first10"], sg["first10"])
                match2, detail2 = compare_values(pg["last10"], sg["last10"])
                if not (match1 and match2):
                    all_match = False
                    issues["values"].append(f"Msg {msg_num}: first10/last10 mismatch")
                    print(f"[FAIL] Message {msg_num}: {pg['parameterName'][:30]:30}")
                    if not match1:
                        print(f"       First10: {detail1}")
                    if not match2:
                        print(f"       Last10: {detail2}")
                else:
                    print(f"[OK]   Message {msg_num}: {pg['parameterName'][:30]:30} (sampled)")
        
        # Compare statistics
        if abs(pg["min"] - sg["min"]) > 1e-6:
            issues["values"].append(f"Msg {msg_num}: min value differs: {pg['min']} vs {sg['min']}")
        if abs(pg["max"] - sg["max"]) > 1e-6:
            issues["values"].append(f"Msg {msg_num}: max value differs: {pg['max']} vs {sg['max']}")
        if abs(pg["mean"] - sg["mean"]) > 1e-4:
            issues["values"].append(f"Msg {msg_num}: mean value differs: {pg['mean']} vs {sg['mean']}")
        
        # Compare grid
        if pg.get("Ni") != sg.get("Ni") or pg.get("Nj") != sg.get("Nj"):
            issues["grid"].append(f"Msg {msg_num}: grid size differs")
        
        # Compare parameter ID
        if pg.get("indicatorOfParameter") != sg.get("indicatorOfParameter"):
            issues["metadata"].append(f"Msg {msg_num}: parameter ID differs: {pg.get('indicatorOfParameter')} vs {sg.get('indicatorOfParameter')}")
    
    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)
    
    if all_match:
        print("\n✓ ALL VALUES MATCH! SwiftGrib output is identical to pygrib.\n")
    else:
        print("\n✗ DISCREPANCIES FOUND\n")
        
        for category, items in issues.items():
            if items:
                print(f"\n{category.upper()} Issues ({len(items)}):")
                for item in items[:10]:  # Show first 10
                    print(f"  - {item}")
                if len(items) > 10:
                    print(f"  ... and {len(items) - 10} more")
    
    # Detailed first message comparison
    print("\n" + "=" * 70)
    print("FIRST MESSAGE DETAILED COMPARISON")
    print("=" * 70)
    
    pg = pygrib_data[0]
    sg = swift_data[0]
    
    print(f"\n{'Field':<35} {'Pygrib':>20} {'SwiftGrib':>20} {'Match':>8}")
    print("-" * 85)
    
    fields = [
        ("parameterName", "parameterName"),
        ("indicatorOfParameter", "indicatorOfParameter"),
        ("level", "level"),
        ("Ni (grid cols)", "Ni"),
        ("Nj (grid rows)", "Nj"),
        ("numValues", "numValues"),
        ("min", "min"),
        ("max", "max"),
        ("mean", "mean"),
        ("firstLat", "firstLat"),
        ("firstLon", "firstLon"),
        ("lastLat", "lastLat"),
        ("lastLon", "lastLon"),
        ("latitudeOfFirstGridPoint", "latitudeOfFirstGridPoint"),
        ("longitudeOfFirstGridPoint", "longitudeOfFirstGridPoint"),
        ("latitudeOfLastGridPoint", "latitudeOfLastGridPoint"),
        ("longitudeOfLastGridPoint", "longitudeOfLastGridPoint"),
        ("year", "year"),
        ("month", "month"),
        ("day", "day"),
        ("hour", "hour"),
        ("minute", "minute"),
    ]
    
    for label, key in fields:
        pv = pg.get(key, "N/A")
        sv = sg.get(key, "N/A")
        
        # Format values
        if isinstance(pv, float):
            pv_str = f"{pv:.6f}"
        else:
            pv_str = str(pv)[:20]
        
        if isinstance(sv, float):
            sv_str = f"{sv:.6f}"
        else:
            sv_str = str(sv)[:20]
        
        # Check match
        if pv == "N/A" or sv == "N/A":
            match = "N/A"
        elif isinstance(pv, (int, float)) and isinstance(sv, (int, float)):
            match = "✓" if abs(pv - sv) < 1e-6 else "✗"
        else:
            match = "✓" if pv == sv else "✗"
        
        print(f"{label:<35} {pv_str:>20} {sv_str:>20} {match:>8}")
    
    # Show first 20 values side by side
    print("\n" + "=" * 70)
    print("FIRST 20 VALUES COMPARISON (Message 1)")
    print("=" * 70)
    
    if "allValues" in pg and "allValues" in sg:
        print(f"\n{'Index':>6} {'Pygrib':>18} {'SwiftGrib':>18} {'Diff':>15} {'Match':>6}")
        print("-" * 65)
        
        for j in range(min(20, len(pg["allValues"]))):
            pv = pg["allValues"][j]
            sv = sg["allValues"][j]
            diff = abs(pv - sv)
            match = "✓" if diff < 1e-6 else "✗"
            print(f"{j:>6} {pv:>18.9f} {sv:>18.9f} {diff:>15.2e} {match:>6}")

if __name__ == "__main__":
    main()
