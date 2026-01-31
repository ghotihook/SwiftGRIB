# SwiftGrib

A Swift library for parsing GRIB (GRIdded Binary) meteorological data files.

[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20|%20iOS%20|%20tvOS%20|%20watchOS%20|%20visionOS-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)

## Features

- Parse GRIB Edition 1 files
- Extract decoded values with proper coordinate mapping
- Wind data utilities for processing U/V components
- Clean, type-safe API with full documentation
- Sendable-compliant types for Swift concurrency
- Cross-platform support (macOS, iOS, tvOS, watchOS, visionOS)

## Requirements

- Swift 5.9+
- macOS 13.0+ / iOS 16.0+ / tvOS 16.0+ / watchOS 9.0+ / visionOS 1.0+

## Installation

### Swift Package Manager

Add SwiftGrib to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/SwiftGrib.git", from: "1.0.0")
]
```

Then add it to your target dependencies:

```swift
.target(
    name: "YourApp",
    dependencies: ["SwiftGrib"]
)
```

### Xcode Project

1. File > Add Package Dependencies
2. Enter the package URL
3. Add to your target

## Usage

### Basic Parsing

```swift
import SwiftGrib

let parser = GribParser()

// Parse from file
let messages = try parser.parse(contentsOf: url)

// Or from data
let messages = try parser.parse(data: gribData)

// Iterate through messages
for message in messages {
    print("Parameter: \(message.parameter.name)")
    print("Level: \(message.level)")
    print("Time: \(message.timestamp)")
    print("Grid: \(message.grid?.ni ?? 0) x \(message.grid?.nj ?? 0)")
    print("Values: \(message.values.count)")
}
```

### Accessing Values

```swift
// Get value by linear index
if let value = message.value(at: 0) {
    print("First value: \(value)")
}

// Get value by grid position
if let value = message.value(i: 10, j: 5) {
    print("Value at (10, 5): \(value)")
}

// Get coordinate for an index
if let coord = message.coordinate(at: 100) {
    print("Lat: \(coord.latitude), Lon: \(coord.longitude)")
}

// Get min/max values
if let min = message.minValue, let max = message.maxValue {
    print("Range: \(min) to \(max)")
}
```

### Wind Data Processing

```swift
import SwiftGrib

let parser = GribParser()
let messages = try parser.parse(contentsOf: url)

let windProcessor = WindProcessor()

// Extract wind data points (combines U and V components)
let windData = windProcessor.extractWindData(from: messages, sampleStep: 3)

for point in windData {
    print("Location: (\(point.latitude), \(point.longitude))")
    print("Speed: \(point.speed) m/s (\(point.speedKnots) knots)")
    print("Direction: \(point.direction) degrees")
}

// Get available timestamps
let timestamps = windProcessor.availableTimestamps(in: messages)

// Filter by parameter
let uWindMessages = windProcessor.filterMessages(messages, byParameter: GribParameter.uWind)
```

### Grid Information

```swift
if let grid = message.grid {
    print("Grid size: \(grid.ni) x \(grid.nj) = \(grid.totalPoints) points")
    print("Bounds: \(grid.bounds.minLatitude) to \(grid.bounds.maxLatitude)")
    print("Resolution: \(grid.latitudeIncrement) x \(grid.longitudeIncrement)")
    print("Scans W-E: \(grid.scansWestToEast)")
    print("Scans N-S: \(grid.scansNorthToSouth)")
    
    // Check if a point is within bounds
    if grid.bounds.contains(latitude: -37.0, longitude: 145.0) {
        print("Point is within grid bounds")
    }
}
```

## Types

### GribParser

The main parser class. Thread-safe and Sendable-compliant.

### GribMessage

A single GRIB message containing:
- `parameter` - What's being measured (wind, temperature, etc.)
- `level` - Vertical level (surface, altitude, pressure level)
- `timestamp` - Reference time
- `grid` - Grid definition
- `values` - Decoded data values
- `minValue` / `maxValue` - Data range

### GribParameter

Meteorological parameter information:
- `id` - WMO parameter code
- `name` - Human-readable name
- `unit` - Unit of measurement

Common parameter IDs:
- `GribParameter.uWind` (33) - U-component of wind
- `GribParameter.vWind` (34) - V-component of wind
- `GribParameter.temperature` (11) - Temperature
- `GribParameter.pressure` (1) - Pressure
- `GribParameter.relativeHumidity` (52) - Relative humidity

### GribLevel

Vertical level information:
- `type` - Level type code
- `typeName` - Human-readable type name
- `value` - Level value

Common level types:
- `GribLevel.surface` (1) - Surface
- `GribLevel.isobaric` (100) - Isobaric (pressure) level
- `GribLevel.heightAboveGround` (105) - Height above ground

### GribGrid

Grid definition:
- `ni`, `nj` - Grid dimensions
- `bounds` - Geographic bounds
- `latitudeIncrement`, `longitudeIncrement` - Grid spacing
- `scanningMode` - How the grid is traversed

### GribBounds

Geographic bounds with helper methods:
- `minLatitude`, `maxLatitude`, `minLongitude`, `maxLongitude`
- `centerLatitude`, `centerLongitude`
- `latitudeSpan`, `longitudeSpan`
- `contains(latitude:longitude:)`

### WindDataPoint

Combined wind data at a point:
- `latitude`, `longitude` - Location
- `speed` - Wind speed (m/s)
- `direction` - Meteorological direction (degrees, 0 = North)
- `speedKnots`, `speedKmh`, `speedMph` - Unit conversions
- `uComponent`, `vComponent` - Calculated components

### WindProcessor

Utilities for wind data processing:
- `extractWindData(from:sampleStep:)` - Combine U/V into speed/direction
- `calculateWindSpeedAndDirection(u:v:)` - Single point calculation
- `availableTimestamps(in:)` - Get unique timestamps
- `filterMessages(_:byParameter:)` - Filter by parameter

## Error Handling

```swift
do {
    let messages = try parser.parse(contentsOf: url)
} catch GribError.invalidMagic {
    print("Not a valid GRIB file")
} catch GribError.unsupportedEdition(let edition) {
    print("GRIB edition \(edition) not supported")
} catch GribError.truncatedData(let section) {
    print("File truncated in \(section)")
} catch {
    print("Error: \(error)")
}
```

## Supported Features

### GRIB Edition 1
- Indicator Section (IS)
- Product Definition Section (PDS)
- Grid Definition Section (GDS) - Lat/Lon grids
- Binary Data Section (BDS)
- Sign-magnitude encoding for coordinates and scale factors
- Bit-packed data extraction

### Not Yet Supported
- GRIB Edition 2
- Complex packing schemes
- Bitmap sections (BMS)
- Non-rectangular grids (polar stereographic, Lambert conformal, etc.)

## Thread Safety

All types in SwiftGrib are Sendable-compliant and safe to use with Swift concurrency:

```swift
await withTaskGroup(of: [GribMessage].self) { group in
    for url in gribFiles {
        group.addTask {
            let parser = GribParser()
            return try! parser.parse(contentsOf: url)
        }
    }
    // ...
}
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

SwiftGrib is available under the Apache License, Version 2.0. See the [LICENSE](LICENSE) file for more info.
