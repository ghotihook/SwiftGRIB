// SwiftGribDemo - Integration test and comparison output for SwiftGrib library
import Foundation
import SwiftGrib

// Check for comparison mode
let comparisonMode = CommandLine.arguments.contains("--compare")

if comparisonMode {
    runComparison()
} else {
    runDemo()
}

func runComparison() {
    // Output in JSON format for comparison with pygrib
    let testFilePath = "Tests/SwiftGribTests/Resources/PWAI_WRCTP_50k_15d_3h_-31N_-44S_157E_145W_20260201_0540.grb"
    
    guard FileManager.default.fileExists(atPath: testFilePath) else {
        print("{\"error\": \"File not found\"}")
        return
    }
    
    do {
        let parser = GribParser()
        let url = URL(fileURLWithPath: testFilePath)
        let messages = try parser.parse(contentsOf: url)
        
        var results: [[String: Any]] = []
        
        for (i, msg) in messages.enumerated() {
            var info: [String: Any] = [:]
            info["message"] = i + 1
            info["parameterName"] = msg.parameter.name
            info["indicatorOfParameter"] = msg.parameter.id
            
            // Level info
            info["level"] = msg.level.value
            info["levelType"] = msg.level.type
            
            // Time info
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate, .withTime, .withSpaceBetweenDateAndTime, .withColonSeparatorInTime]
            info["validDate"] = formatter.string(from: msg.timestamp)
            
            let cal = Calendar(identifier: .gregorian)
            let comps = cal.dateComponents(in: TimeZone(identifier: "UTC")!, from: msg.timestamp)
            info["year"] = comps.year
            info["month"] = comps.month
            info["day"] = comps.day
            info["hour"] = comps.hour
            info["minute"] = comps.minute
            
            // Grid info
            if let grid = msg.grid {
                info["Ni"] = grid.ni
                info["Nj"] = grid.nj
                info["latitudeOfFirstGridPoint"] = grid.bounds.maxLatitude  // First point lat
                info["longitudeOfFirstGridPoint"] = grid.bounds.minLongitude
                info["latitudeOfLastGridPoint"] = grid.bounds.minLatitude   // Last point lat  
                info["longitudeOfLastGridPoint"] = grid.bounds.maxLongitude
            }
            
            // Values
            info["numValues"] = msg.values.count
            info["min"] = msg.minValue
            info["max"] = msg.maxValue
            if !msg.values.isEmpty {
                let sum = msg.values.reduce(0, +)
                info["mean"] = sum / Float(msg.values.count)
            }
            
            // First/last values
            info["first10"] = Array(msg.values.prefix(10))
            info["last10"] = Array(msg.values.suffix(10))
            
            // All values for first few messages
            if i < 5 || i % 51 < 2 {
                info["allValues"] = msg.values
            }
            
            // Spot values
            let total = msg.values.count
            let spotIndices = [0, 1, 2, total/4, total/2, 3*total/4, total-3, total-2, total-1]
            var spotValues: [String: Float] = [:]
            for idx in spotIndices {
                if idx >= 0 && idx < total {
                    spotValues["\(idx)"] = msg.values[idx]
                }
            }
            info["spotValues"] = spotValues
            
            // Coordinates
            if let coord0 = msg.coordinate(at: 0) {
                info["firstLat"] = coord0.latitude
                info["firstLon"] = coord0.longitude
            }
            if let coordLast = msg.coordinate(at: msg.values.count - 1) {
                info["lastLat"] = coordLast.latitude
                info["lastLon"] = coordLast.longitude
            }
            
            results.append(info)
        }
        
        // Output as JSON
        if let jsonData = try? JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
        
    } catch {
        print("{\"error\": \"\(error)\"}")
    }
}

func runDemo() {
    print("=== SwiftGrib Integration Test ===\n")

    // Try to find the test file
    let possiblePaths = [
        "Tests/SwiftGribTests/Resources/PWAI_WRCTP_50k_15d_3h_-31N_-44S_157E_145W_20260201_0540.grb",
        Bundle.module.path(forResource: "PWAI_WRCTP_50k_15d_3h_-31N_-44S_157E_145W_20260201_0540", ofType: "grb", inDirectory: "Resources"),
    ].compactMap { $0 }

    guard let testFilePath = possiblePaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
        print("ERROR: Could not find test GRIB file")
        print("Searched paths:")
        for path in possiblePaths {
            print("  - \(path ?? "nil")")
        }
        exit(1)
    }

    print("Using test file: \(testFilePath)\n")

    do {
        let parser = GribParser()
        let url = URL(fileURLWithPath: testFilePath)
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
            print("  Bounds: lat \(String(format: "%.3f", grid.bounds.minLatitude)) to \(String(format: "%.3f", grid.bounds.maxLatitude))")
            print("          lon \(String(format: "%.3f", grid.bounds.minLongitude)) to \(String(format: "%.3f", grid.bounds.maxLongitude))")
            print("  Values: count=\(first.values.count)")
            if let minV = first.minValue, let maxV = first.maxValue {
                print("  Range: \(String(format: "%.4f", minV)) to \(String(format: "%.4f", maxV))")
            }
            
            // Show some coordinates
            print("\n  Sample coordinates:")
            if let coord0 = first.coordinate(at: 0) {
                print("    Index 0: (\(String(format: "%.3f", coord0.latitude)), \(String(format: "%.3f", coord0.longitude)))")
            }
            if let coordLast = first.coordinate(at: grid.totalPoints - 1) {
                print("    Index \(grid.totalPoints - 1): (\(String(format: "%.3f", coordLast.latitude)), \(String(format: "%.3f", coordLast.longitude)))")
            }
        }
        
        // Timestamp analysis
        print("\n--- Timestamp Analysis ---")
        let processor = WindProcessor()
        let timestamps = processor.availableTimestamps(in: messages)
        print("Available timestamps: \(timestamps.count)")
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        
        print("\nFirst 5 timestamps:")
        for (i, ts) in timestamps.prefix(5).enumerated() {
            print("  \(i+1). \(formatter.string(from: ts)) UTC")
        }
        if timestamps.count > 5 {
            print("  ...")
            print("  \(timestamps.count). \(formatter.string(from: timestamps.last!)) UTC")
        }
        
        // Check time intervals
        if timestamps.count >= 2 {
            print("\nTime intervals:")
            for i in 1..<min(4, timestamps.count) {
                let interval = timestamps[i].timeIntervalSince(timestamps[i-1])
                print("  Step \(i) -> \(i+1): \(Int(interval / 3600)) hours")
            }
            
            if let first = timestamps.first, let last = timestamps.last {
                let totalSpan = last.timeIntervalSince(first)
                print("\nTotal time span: \(String(format: "%.1f", totalSpan / (24 * 3600))) days")
            }
        }
        
        // Extract wind data
        print("\n--- Wind Data Extraction ---")
        
        let windData = processor.extractWindData(from: messages, sampleStep: 5)
        print("Extracted \(windData.count) wind data points (sampled every 5th point)")
        
        if !windData.isEmpty {
            print("\nFirst 10 wind data points:")
            for (i, point) in windData.prefix(10).enumerated() {
                print("  \(i+1). (\(String(format: "%7.2f", point.latitude)), \(String(format: "%7.2f", point.longitude))): " +
                      "\(String(format: "%5.1f", point.speed)) m/s (\(String(format: "%5.1f", point.speedKnots)) kts) " +
                      "from \(String(format: "%3.0f", point.direction))°")
            }
            
            // Check for reasonable values
            let speeds = windData.map { $0.speed }
            let minSpeed = speeds.min() ?? 0
            let maxSpeed = speeds.max() ?? 0
            let avgSpeed = speeds.reduce(0, +) / Double(speeds.count)
            
            print("\nWind speed statistics:")
            print("  Min: \(String(format: "%.2f", minSpeed)) m/s (\(String(format: "%.2f", minSpeed * 1.94384)) kts)")
            print("  Max: \(String(format: "%.2f", maxSpeed)) m/s (\(String(format: "%.2f", maxSpeed * 1.94384)) kts)")
            print("  Avg: \(String(format: "%.2f", avgSpeed)) m/s (\(String(format: "%.2f", avgSpeed * 1.94384)) kts)")
            
            // Direction distribution
            let directions = windData.map { $0.direction }
            let avgDirection = directions.reduce(0, +) / Double(directions.count)
            print("\nWind direction statistics:")
            print("  Avg direction: \(String(format: "%.1f", avgDirection))°")
            
            // Validation
            print("\n--- Validation ---")
            var errors: [String] = []
            
            if minSpeed < 0 {
                errors.append("Negative wind speed detected: \(minSpeed)")
            }
            if maxSpeed > 100 {
                errors.append("Unreasonably high wind speed: \(maxSpeed) m/s")
            }
            if windData.contains(where: { $0.direction < 0 || $0.direction >= 360 }) {
                errors.append("Direction out of 0-360 range")
            }
            
            if errors.isEmpty {
                print("✓ All values within expected ranges")
            } else {
                for error in errors {
                    print("✗ \(error)")
                }
            }
        }
        
        print("\n=== Test Complete ===")
        
    } catch {
        print("ERROR: \(error)")
        exit(1)
    }
}
