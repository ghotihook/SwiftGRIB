#!/usr/bin/env swift

// Quick verification script for SwiftGrib parsing
// Run with: swift verify_grib.swift

import Foundation

// We need to compile this with the package, so let's use a simpler approach
// This script just verifies the test file exists and has expected structure

let testFile = "Tests/SwiftGribTests/Resources/PWAI_WRCTP_50k_15d_3h_-31N_-44S_157E_145W_20260201_0540.grb"

guard FileManager.default.fileExists(atPath: testFile) else {
    print("ERROR: Test file not found at \(testFile)")
    exit(1)
}

guard let data = FileManager.default.contents(atPath: testFile) else {
    print("ERROR: Could not read test file")
    exit(1)
}

print("Test file size: \(data.count) bytes")

// Check for GRIB magic bytes
if data.count >= 4 {
    let magic = String(data: data[0..<4], encoding: .ascii)
    if magic == "GRIB" {
        print("GRIB magic bytes found")
    } else {
        print("ERROR: Not a valid GRIB file (magic bytes: \(magic ?? "nil"))")
        exit(1)
    }
}

// Count GRIB messages
var messageCount = 0
var offset = 0
let gribMagic = "GRIB".data(using: .ascii)!

while offset < data.count - 4 {
    if data[offset..<offset+4] == gribMagic {
        messageCount += 1
        // Read message length (bytes 4-6 are the length in GRIB1)
        if offset + 7 < data.count {
            let length = (Int(data[offset+4]) << 16) | (Int(data[offset+5]) << 8) | Int(data[offset+6])
            offset += length
        } else {
            break
        }
    } else {
        offset += 1
    }
}

print("Found \(messageCount) GRIB messages")

if messageCount > 0 {
    print("SUCCESS: GRIB file appears valid")
} else {
    print("WARNING: No GRIB messages found")
}
