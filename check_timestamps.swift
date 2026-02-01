import Foundation
import SwiftGrib

let testFile = "Tests/SwiftGribTests/Resources/PWAI_WRCTP_50k_15d_3h_-31N_-44S_157E_145W_20260201_0540.grb"
let parser = GribParser()
let messages = try! parser.parse(contentsOf: URL(fileURLWithPath: testFile))

print("=== Timestamp Analysis ===\n")

// Get unique timestamps
let processor = WindProcessor()
let timestamps = processor.availableTimestamps(in: messages)

print("Total messages: \(messages.count)")
print("Unique timestamps: \(timestamps.count)")

let formatter = DateFormatter()
formatter.dateFormat = "yyyy-MM-dd HH:mm"
formatter.timeZone = TimeZone(identifier: "UTC")

print("\nFirst 10 timestamps:")
for (i, ts) in timestamps.prefix(10).enumerated() {
    print("  \(i+1). \(formatter.string(from: ts)) UTC")
}

if timestamps.count > 10 {
    print("  ...")
    print("  \(timestamps.count). \(formatter.string(from: timestamps.last!)) UTC")
}

// Check time intervals
if timestamps.count >= 2 {
    print("\nTime intervals between consecutive timestamps:")
    var intervals: [TimeInterval] = []
    for i in 1..<min(6, timestamps.count) {
        let interval = timestamps[i].timeIntervalSince(timestamps[i-1])
        intervals.append(interval)
        let hours = interval / 3600
        print("  \(i) -> \(i+1): \(Int(hours)) hours")
    }
    
    let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
    print("\nAverage interval: \(avgInterval / 3600) hours")
    
    // Total time span
    if let first = timestamps.first, let last = timestamps.last {
        let totalSpan = last.timeIntervalSince(first)
        let days = totalSpan / (24 * 3600)
        print("Total time span: \(String(format: "%.1f", days)) days")
    }
}

// Check file name suggests 15 days at 3-hour intervals
// 15 days * 24 hours / 3 hours = 120 time steps
// But we have 51 timestamps, which is about 15 days / 3 hours = ~6.4 days
// Let's check what the actual data shows

print("\n=== Message Details (first of each timestamp) ===")
for ts in timestamps.prefix(5) {
    let msgsAtTime = messages.filter { $0.timestamp == ts }
    print("\nTimestamp: \(formatter.string(from: ts)) UTC")
    print("  Messages at this time: \(msgsAtTime.count)")
    for msg in msgsAtTime.prefix(2) {
        print("    - \(msg.parameter.name)")
    }
}

// Check if timestamps match expected 3-hour pattern
print("\n=== Validation ===")
let expectedInterval: TimeInterval = 3 * 3600  // 3 hours in seconds
var allIntervalsCorrect = true
for i in 1..<timestamps.count {
    let interval = timestamps[i].timeIntervalSince(timestamps[i-1])
    if abs(interval - expectedInterval) > 60 {  // Allow 1 minute tolerance
        print("WARNING: Unexpected interval at index \(i): \(interval/3600) hours")
        allIntervalsCorrect = false
    }
}

if allIntervalsCorrect {
    print("✓ All timestamps are at 3-hour intervals as expected")
} else {
    print("✗ Some timestamps have unexpected intervals")
}
