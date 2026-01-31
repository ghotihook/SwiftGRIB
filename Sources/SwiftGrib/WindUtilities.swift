//
//  WindUtilities.swift
//  SwiftGrib
//
//  Utilities for working with wind data from GRIB files.
//

import Foundation

// MARK: - Wind Data Point

/// Represents wind data at a single point.
///
/// WindDataPoint combines U and V wind components into a more intuitive
/// speed and direction representation. The direction uses meteorological
/// convention (direction wind is coming FROM, 0° = North, clockwise).
///
/// Example:
/// ```swift
/// let point = WindDataPoint(
///     latitude: -37.0,
///     longitude: 145.0,
///     speed: 10.0,  // m/s
///     direction: 270.0,  // From the west
///     timestamp: Date()
/// )
/// print("Wind: \(point.speedKnots) knots from \(point.direction)°")
/// ```
public struct WindDataPoint: Sendable {
    /// Latitude in degrees (-90 to 90)
    public let latitude: Double
    
    /// Longitude in degrees (-180 to 180 or 0 to 360)
    public let longitude: Double
    
    /// Wind speed in m/s
    public let speed: Double
    
    /// Wind direction in degrees (meteorological convention: direction wind comes FROM, 0° = North, clockwise)
    public let direction: Double
    
    /// Timestamp of the data
    public let timestamp: Date
    
    /// Optional altitude/level value (meaning depends on level type)
    public let altitude: Double?
    
    /// Wind speed in knots (1 m/s = 1.94384 knots)
    public var speedKnots: Double {
        speed * 1.94384
    }
    
    /// Wind speed in km/h (1 m/s = 3.6 km/h)
    public var speedKmh: Double {
        speed * 3.6
    }
    
    /// Wind speed in mph (1 m/s = 2.23694 mph)
    public var speedMph: Double {
        speed * 2.23694
    }
    
    /// U-component (eastward) of wind calculated from speed and direction
    public var uComponent: Double {
        -speed * sin(direction * .pi / 180.0)
    }
    
    /// V-component (northward) of wind calculated from speed and direction
    public var vComponent: Double {
        -speed * cos(direction * .pi / 180.0)
    }
    
    /// Creates a new WindDataPoint instance.
    /// - Parameters:
    ///   - latitude: Latitude in degrees
    ///   - longitude: Longitude in degrees
    ///   - speed: Wind speed in m/s
    ///   - direction: Wind direction in degrees (meteorological convention)
    ///   - timestamp: Timestamp of the data
    ///   - altitude: Optional altitude/level value
    public init(latitude: Double, longitude: Double, speed: Double, direction: Double, timestamp: Date, altitude: Double? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.speed = speed
        self.direction = direction
        self.timestamp = timestamp
        self.altitude = altitude
    }
}

// MARK: - Wind Processor

/// Processes GRIB messages to extract wind data.
///
/// WindProcessor provides utilities to combine U and V wind component
/// messages into human-readable speed and direction values.
///
/// Example:
/// ```swift
/// let parser = GribParser()
/// let messages = try parser.parse(contentsOf: url)
///
/// let processor = WindProcessor()
/// let windData = processor.extractWindData(from: messages, sampleStep: 3)
///
/// for point in windData {
///     print("(\(point.latitude), \(point.longitude)): \(point.speedKnots) knots from \(point.direction)°")
/// }
/// ```
public struct WindProcessor: Sendable {
    
    public init() {}
    
    /// Extract wind data points from paired U/V wind messages.
    ///
    /// - Parameters:
    ///   - messages: Array of GRIB messages (should contain matched U and V components)
    ///   - sampleStep: Sample every Nth point (default 1 = all points)
    /// - Returns: Array of wind data points
    public func extractWindData(from messages: [GribMessage], sampleStep: Int = 1) -> [WindDataPoint] {
        var windPoints: [WindDataPoint] = []
        
        // Group messages by timestamp
        let messagesByTime = Dictionary(grouping: messages) { $0.timestamp }
        
        for (timestamp, timeMessages) in messagesByTime.sorted(by: { $0.key < $1.key }) {
            // Find U and V components
            guard let uMessage = timeMessages.first(where: { $0.parameter.id == GribParameter.uWind }),
                  let vMessage = timeMessages.first(where: { $0.parameter.id == GribParameter.vWind }),
                  let grid = uMessage.grid else {
                continue
            }
            
            let step = max(1, sampleStep)
            
            for j in stride(from: 0, to: grid.nj, by: step) {
                for i in stride(from: 0, to: grid.ni, by: step) {
                    let index = j * grid.ni + i
                    
                    guard index < uMessage.values.count && index < vMessage.values.count,
                          let coord = uMessage.coordinate(at: index) else {
                        continue
                    }
                    
                    let u = Double(uMessage.values[index])
                    let v = Double(vMessage.values[index])
                    
                    let (speed, direction) = calculateWindSpeedAndDirection(u: u, v: v)
                    
                    let point = WindDataPoint(
                        latitude: coord.latitude,
                        longitude: coord.longitude,
                        speed: speed,
                        direction: direction,
                        timestamp: timestamp,
                        altitude: uMessage.level.value
                    )
                    
                    windPoints.append(point)
                }
            }
        }
        
        return windPoints
    }
    
    /// Calculate wind speed and direction from U and V components.
    ///
    /// - Parameters:
    ///   - u: U-component (positive = eastward)
    ///   - v: V-component (positive = northward)
    /// - Returns: Tuple of (speed in m/s, direction in degrees)
    public func calculateWindSpeedAndDirection(u: Double, v: Double) -> (speed: Double, direction: Double) {
        let speed = sqrt(u * u + v * v)
        
        // Calculate meteorological wind direction (where wind comes FROM)
        // atan2 gives direction wind is going TO, so we add 180°
        var direction = atan2(v, u) * 180.0 / .pi
        direction = fmod(270.0 - direction, 360.0)
        if direction < 0 {
            direction += 360.0
        }
        
        return (speed, direction)
    }
    
    /// Get available timestamps from a set of messages.
    /// - Parameter messages: Array of GRIB messages
    /// - Returns: Sorted array of unique timestamps
    public func availableTimestamps(in messages: [GribMessage]) -> [Date] {
        let timestamps = Set(messages.map { $0.timestamp })
        return timestamps.sorted()
    }
    
    /// Filter messages by parameter.
    /// - Parameters:
    ///   - messages: Array of GRIB messages
    ///   - parameterId: Parameter ID to filter by
    /// - Returns: Filtered messages
    public func filterMessages(_ messages: [GribMessage], byParameter parameterId: UInt8) -> [GribMessage] {
        messages.filter { $0.parameter.id == parameterId }
    }
}
