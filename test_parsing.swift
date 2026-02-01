import Foundation

// Add source files directory to the path
let sourceDir = "Sources/SwiftGrib"

// This is a manual test - run with: swift -I .build/arm64-apple-macosx/debug/Modules -L .build/arm64-apple-macosx/debug -lSwiftGrib test_parsing.swift

print("Loading SwiftGrib...")

// For now, let's just verify the file structure
let testFile = "Tests/SwiftGribTests/Resources/PWAI_WRCTP_50k_15d_3h_-31N_-44S_157E_145W_20260201_0540.grb"
let data = try! Data(contentsOf: URL(fileURLWithPath: testFile))

print("File size: \(data.count) bytes")
print("First 8 bytes: \(Array(data[0..<8]))")

// Parse manually to verify structure
var offset = 0
var messages: [(parameter: UInt8, values: Int)] = []

while offset < data.count - 8 {
    guard String(data: data[offset..<offset+4], encoding: .ascii) == "GRIB" else {
        offset += 1
        continue
    }
    
    let length = (Int(data[offset+4]) << 16) | (Int(data[offset+5]) << 8) | Int(data[offset+6])
    let edition = data[offset+7]
    
    // PDS starts at offset 8
    let pdsLength = (Int(data[offset+8]) << 16) | (Int(data[offset+9]) << 8) | Int(data[offset+10])
    let parameterId = data[offset+16]  // Parameter ID at byte 9 of PDS (offset 8 + 8 = 16)
    
    messages.append((parameter: parameterId, values: 0))
    offset += length
}

print("Parsed \(messages.count) messages")

// Count by parameter
let uWind = messages.filter { $0.parameter == 33 }.count
let vWind = messages.filter { $0.parameter == 34 }.count
let other = messages.count - uWind - vWind

print("U-wind messages: \(uWind)")
print("V-wind messages: \(vWind)")
print("Other messages: \(other)")

// Show first few unique parameters
let uniqueParams = Set(messages.map { $0.parameter })
print("Unique parameter IDs: \(uniqueParams.sorted())")
