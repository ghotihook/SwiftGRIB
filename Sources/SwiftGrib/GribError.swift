//
//  GribError.swift
//  SwiftGrib
//
//  Error types for GRIB parsing.
//

import Foundation

/// Errors that can occur during GRIB file parsing.
///
/// These errors are thrown by ``GribParser`` when encountering
/// issues while parsing GRIB data.
///
/// Example:
/// ```swift
/// do {
///     let messages = try parser.parse(data: data)
/// } catch GribError.invalidMagic {
///     print("Not a valid GRIB file")
/// } catch GribError.unsupportedEdition(let edition) {
///     print("GRIB edition \(edition) not supported")
/// }
/// ```
public enum GribError: Error, LocalizedError, Sendable {
    /// File does not start with "GRIB" magic bytes.
    /// This indicates the data is not a valid GRIB file.
    case invalidMagic
    
    /// File data is truncated or incomplete.
    /// The associated value indicates which section was truncated.
    case truncatedData(String)
    
    /// GRIB edition is not supported.
    /// Currently only GRIB Edition 1 is supported.
    /// The associated value is the unsupported edition number.
    case unsupportedEdition(UInt8)
    
    /// Grid type is not supported.
    /// Currently only latitude/longitude grids are supported.
    /// The associated value is the unsupported grid type code.
    case unsupportedGridType(UInt8)
    
    /// File could not be read from the specified URL.
    case fileReadError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidMagic:
            return "File does not contain valid GRIB data"
        case .truncatedData(let section):
            return "Truncated data in \(section) section"
        case .unsupportedEdition(let edition):
            return "Unsupported GRIB edition: \(edition). Only edition 1 is currently supported."
        case .unsupportedGridType(let type):
            return "Unsupported grid type: \(type)"
        case .fileReadError(let message):
            return "File read error: \(message)"
        }
    }
}
