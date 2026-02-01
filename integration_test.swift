// Integration test for SwiftGrib
// Compile with: swiftc -I .build/arm64-apple-macosx/debug/Modules -L .build/arm64-apple-macosx/debug -lSwiftGrib integration_test.swift -o integration_test
// Or run with swift package: swift run --package-path . integration_test.swift

import Foundation
import SwiftGrib

print("=== SwiftGrib Integration Test ===\n")

let testFile = "Tests/SwiftGribTests/Resources/PWAI_WRCTP_50k_15d_3h_-31N_-44S_157E_145W_20260201_0540.grb"

do {
    let parser = GribParser()
    let url = URL(fileURLWithPath: testFile)
    let messages = try parser.parse(contentsOf: url)
    
    print("Parsed \(messages.count) messages\n")
    
    // Group by parameter
    let byParameter = Dictionary(grouping: messages) { $0.parameter.id }
    print("Messages by parameter:")
    for (id, msgs) in byParameter.sorted(by: { $0.key < $1.key }) {
        if let first = msgs.first {
            print("  \(first.parameter.name) (ID \(id)): \(msgs.count) messages")
        }
    }
    
    // Check first message details
    if let first = messages.first, let grid = first.grid {
        print("\nFirst message details:")
        print("  Parameter: \(first.parameter)")
        print("  Level: \(first.level)")
        print("  Timestamp: \(first.timestamp)")
        print("  Grid: \(grid.ni) x \(grid.nj) = \(grid.totalPoints) points")
        print("  Bounds: lat \(grid.bounds.minLatitude) to \(grid.bounds.maxLatitude)")
        print("          lon \(grid.bounds.minLongitude) to \(grid.bounds.maxLongitude)")
        print("  Values: count=\(first.values.count)")
        if let minV = first.minValue, let maxV = first.maxValue {
            print("  Range: \(minV) to \(maxV)")
        }
    }
    
    // Extract wind data
    let processor = WindProcessor()
    let windData = processor.extractWindData(from: messages, sampleStep: 5)
    
    print("\nExtracted \(windData.count) wind data points (sampled)")
    
    if !windData.isEmpty {
        print("\nFirst 5 wind data points:")
        for point in windData.prefix(5) {
            print("  (\(String(format: "%.2f", point.latitude)), \(String(format: "%.2f", point.longitude))): " +
                  "\(String(format: "%.1f", point.speed)) m/s (\(String(format: "%.1f", point.speedKnots)) kts) " +
                  "from \(String(format: "%.0f", point.direction))°")
        }
        
        // Check for reasonable values
        let speeds = windData.map { $0.speed }
        let minSpeed = speeds.min() ?? 0
        let maxSpeed = speeds.max() ?? 0
        let avgSpeed = speeds.reduce(0, +) / Double(speeds.count)
        
        print("\nWind speed statistics:")
        print("  Min: \(String(format: "%.2f", minSpeed)) m/s")
        print("  Max: \(String(format: "%.2f", maxSpeed)) m/s")
        print("  Avg: \(String(format: "%.2f", avgSpeed)) m/s")
        
        if minSpeed >= 0 && maxSpeed < 100 {
            print("\n✓ Wind speeds are in reasonable range")
        } else {
            print("\n✗ WARNING: Wind speeds may be incorrect!")
        }
    }
    
    print("\n=== Test Complete ===")
    
} catch {
    print("ERROR: \(error)")
    exit(1)
}
