//
//  GribTypes.swift
//  SwiftGrib
//
//  Public types for GRIB data representation.
//

import Foundation

// MARK: - Public Types

/// A single GRIB message containing meteorological data for one parameter at one time.
public struct GribMessage: Sendable {
    /// Message number within the file (1-based)
    public let messageNumber: Int
    
    /// Total length of this message in bytes
    public let totalLength: Int
    
    /// The meteorological parameter (e.g., wind, temperature)
    public let parameter: GribParameter
    
    /// The vertical level (e.g., surface, 10m above ground)
    public let level: GribLevel
    
    /// Reference timestamp for this data
    public let timestamp: Date
    
    /// Grid definition (nil if not present in message)
    public let grid: GribGrid?
    
    /// Decoded data values, one per grid point
    public let values: [Float]
    
    /// Raw grid definition section (for advanced use)
    internal let rawGDS: GridDefinition?
    
    /// Minimum value in the data
    public var minValue: Float? {
        values.min()
    }
    
    /// Maximum value in the data
    public var maxValue: Float? {
        values.max()
    }
    
    /// Get the value at a specific grid index.
    /// - Parameter index: Linear index into the grid (row-major order)
    /// - Returns: The value at that index, or nil if out of bounds
    public func value(at index: Int) -> Float? {
        guard index >= 0 && index < values.count else { return nil }
        return values[index]
    }
    
    /// Get the value at a specific grid position.
    /// - Parameters:
    ///   - i: Column index (longitude direction)
    ///   - j: Row index (latitude direction)
    /// - Returns: The value at that position, or nil if out of bounds
    public func value(i: Int, j: Int) -> Float? {
        guard let grid = grid else { return nil }
        let index = j * grid.ni + i
        return value(at: index)
    }
    
    /// Get the coordinate for a grid index.
    /// - Parameter index: Linear index into the grid
    /// - Returns: Tuple of (latitude, longitude), or nil if no grid defined
    public func coordinate(at index: Int) -> (latitude: Double, longitude: Double)? {
        guard let grid = grid, let gds = rawGDS else { return nil }
        
        let i = index % grid.ni
        let j = index / grid.ni
        
        let lon: Double
        let lat: Double
        
        // Bit 7 (0x80): 0 = West to East, 1 = East to West
        if (gds.scanningMode & 0x80) == 0 {
            lon = Double(gds.lon1) + Double(i) * Double(gds.di)
        } else {
            lon = Double(gds.lon1) - Double(i) * Double(gds.di)
        }
        
        // Bit 6 (0x40): 0 = North to South, 1 = South to North
        if (gds.scanningMode & 0x40) == 0 {
            lat = Double(gds.lat1) - Double(j) * Double(gds.dj)
        } else {
            lat = Double(gds.lat1) + Double(j) * Double(gds.dj)
        }
        
        return (lat, lon)
    }
}

/// Describes a meteorological parameter.
public struct GribParameter: CustomStringConvertible, Sendable {
    /// WMO parameter ID
    public let id: UInt8
    
    /// Human-readable name
    public let name: String
    
    /// Unit of measurement
    public let unit: String
    
    /// Creates a new GribParameter instance.
    /// - Parameters:
    ///   - id: WMO parameter ID
    ///   - name: Human-readable name
    ///   - unit: Unit of measurement
    public init(id: UInt8, name: String, unit: String) {
        self.id = id
        self.name = name
        self.unit = unit
    }
    
    public var description: String {
        "\(name) (\(unit))"
    }
    
    /// Common parameter IDs
    public static let uWind: UInt8 = 33
    public static let vWind: UInt8 = 34
    public static let temperature: UInt8 = 11
    public static let pressure: UInt8 = 1
    public static let geopotentialHeight: UInt8 = 7
    public static let relativeHumidity: UInt8 = 52
    public static let totalPrecipitation: UInt8 = 61
    public static let totalCloudCover: UInt8 = 71
}

/// Describes a vertical level.
public struct GribLevel: CustomStringConvertible, Sendable {
    /// Level type code
    public let type: UInt8
    
    /// Human-readable level type name
    public let typeName: String
    
    /// Level value (meaning depends on type)
    public let value: Double
    
    /// Creates a new GribLevel instance.
    /// - Parameters:
    ///   - type: Level type code
    ///   - typeName: Human-readable level type name
    ///   - value: Level value (meaning depends on type)
    public init(type: UInt8, typeName: String, value: Double) {
        self.type = type
        self.typeName = typeName
        self.value = value
    }
    
    public var description: String {
        "\(typeName): \(value)"
    }
    
    /// Common level type codes
    public static let surface: UInt8 = 1
    public static let cloudBase: UInt8 = 2
    public static let cloudTop: UInt8 = 3
    public static let isobaric: UInt8 = 100
    public static let meanSeaLevel: UInt8 = 102
    public static let heightAboveGround: UInt8 = 105
    public static let entireAtmosphere: UInt8 = 200
}

/// Grid definition for the data.
public struct GribGrid: Sendable {
    /// Number of points in the i direction (longitude)
    public let ni: Int
    
    /// Number of points in the j direction (latitude)
    public let nj: Int
    
    /// Geographic bounds of the grid
    public let bounds: GribBounds
    
    /// Grid spacing in latitude direction (degrees)
    public let latitudeIncrement: Double
    
    /// Grid spacing in longitude direction (degrees)
    public let longitudeIncrement: Double
    
    /// Scanning mode flags
    public let scanningMode: UInt8
    
    /// Creates a new GribGrid instance.
    /// - Parameters:
    ///   - ni: Number of points in i direction (longitude)
    ///   - nj: Number of points in j direction (latitude)
    ///   - bounds: Geographic bounds of the grid
    ///   - latitudeIncrement: Grid spacing in latitude direction (degrees)
    ///   - longitudeIncrement: Grid spacing in longitude direction (degrees)
    ///   - scanningMode: Scanning mode flags
    public init(ni: Int, nj: Int, bounds: GribBounds, latitudeIncrement: Double, longitudeIncrement: Double, scanningMode: UInt8) {
        self.ni = ni
        self.nj = nj
        self.bounds = bounds
        self.latitudeIncrement = latitudeIncrement
        self.longitudeIncrement = longitudeIncrement
        self.scanningMode = scanningMode
    }
    
    /// Total number of grid points
    public var totalPoints: Int {
        ni * nj
    }
    
    /// Whether the grid scans west to east
    public var scansWestToEast: Bool {
        (scanningMode & 0x80) == 0
    }
    
    /// Whether the grid scans north to south
    public var scansNorthToSouth: Bool {
        (scanningMode & 0x40) == 0
    }
}

/// Geographic bounds.
public struct GribBounds: Sendable {
    public let minLatitude: Double
    public let maxLatitude: Double
    public let minLongitude: Double
    public let maxLongitude: Double
    
    /// Creates a new GribBounds instance.
    /// - Parameters:
    ///   - minLatitude: Minimum latitude in degrees
    ///   - maxLatitude: Maximum latitude in degrees
    ///   - minLongitude: Minimum longitude in degrees
    ///   - maxLongitude: Maximum longitude in degrees
    public init(minLatitude: Double, maxLatitude: Double, minLongitude: Double, maxLongitude: Double) {
        self.minLatitude = minLatitude
        self.maxLatitude = maxLatitude
        self.minLongitude = minLongitude
        self.maxLongitude = maxLongitude
    }
    
    /// Center latitude of the bounds
    public var centerLatitude: Double {
        (minLatitude + maxLatitude) / 2
    }
    
    /// Center longitude of the bounds
    public var centerLongitude: Double {
        (minLongitude + maxLongitude) / 2
    }
    
    /// Latitude span
    public var latitudeSpan: Double {
        maxLatitude - minLatitude
    }
    
    /// Longitude span
    public var longitudeSpan: Double {
        maxLongitude - minLongitude
    }
    
    /// Check if a coordinate is within the bounds.
    /// - Parameters:
    ///   - latitude: Latitude to check
    ///   - longitude: Longitude to check
    /// - Returns: True if the coordinate is within bounds
    public func contains(latitude: Double, longitude: Double) -> Bool {
        latitude >= minLatitude && latitude <= maxLatitude &&
        longitude >= minLongitude && longitude <= maxLongitude
    }
}

// MARK: - Internal Types

/// Internal grid definition (mirrors GRIB1 GDS structure)
struct GridDefinition: Sendable {
    let dataRepresentationType: UInt8
    let ni: UInt16
    let nj: UInt16
    let lat1: Float
    let lon1: Float
    let lat2: Float
    let lon2: Float
    let di: Float
    let dj: Float
    let scanningMode: UInt8
    
    var totalPoints: Int {
        Int(ni) * Int(nj)
    }
}
