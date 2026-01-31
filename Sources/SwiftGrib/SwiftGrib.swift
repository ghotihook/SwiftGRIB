//
//  SwiftGrib.swift
//  SwiftGrib
//
//  A Swift library for parsing GRIB (GRIdded Binary) meteorological data files.
//  Currently supports GRIB Edition 1 format.
//
//  Usage:
//      let parser = GribParser()
//      let messages = try parser.parse(data: gribData)
//      for message in messages {
//          print(message.parameter.name)
//          print(message.grid.bounds)
//          print(message.values)
//      }
//

import Foundation

// MARK: - Main Parser

/// Parser for GRIB meteorological data files.
///
/// GribParser reads GRIB (GRIdded Binary) format files commonly used
/// for meteorological data. Currently supports GRIB Edition 1 format.
///
/// Example:
/// ```swift
/// let parser = GribParser()
///
/// // Parse from file
/// let messages = try parser.parse(contentsOf: url)
///
/// // Or from data
/// let messages = try parser.parse(data: gribData)
///
/// for message in messages {
///     print("Parameter: \(message.parameter.name)")
///     print("Level: \(message.level)")
///     print("Grid: \(message.grid?.ni ?? 0) x \(message.grid?.nj ?? 0)")
/// }
/// ```
public final class GribParser: Sendable {
    
    /// Creates a new GRIB parser instance.
    public init() {}
    
    /// Parse a GRIB file from raw data.
    /// - Parameter data: The raw bytes of the GRIB file
    /// - Returns: Array of parsed GRIB messages
    /// - Throws: `GribError` if parsing fails
    public func parse(data: Data) throws -> [GribMessage] {
        var messages: [GribMessage] = []
        var offset = 0
        var messageNum = 0
        
        while offset < data.count - 8 {
            // Look for "GRIB" magic bytes
            guard let magic = String(data: data[offset..<offset+4], encoding: .ascii),
                  magic == "GRIB" else {
                if let nextGrib = findNextGRIB(in: data, from: offset) {
                    offset = nextGrib
                    continue
                }
                break
            }
            
            messageNum += 1
            
            do {
                let message = try parseMessage(data: data, offset: offset, messageNumber: messageNum)
                messages.append(message)
                offset += message.totalLength
            } catch {
                // Skip malformed message and continue
                offset += 1
            }
        }
        
        return messages
    }
    
    /// Parse a GRIB file from a URL.
    /// - Parameter url: File URL to the GRIB file
    /// - Returns: Array of parsed GRIB messages
    /// - Throws: `GribError` if parsing fails or file cannot be read
    public func parse(contentsOf url: URL) throws -> [GribMessage] {
        let data = try Data(contentsOf: url)
        return try parse(data: data)
    }
    
    // MARK: - Private Implementation
    
    private func findNextGRIB(in data: Data, from start: Int) -> Int? {
        let target = "GRIB".data(using: .ascii)!
        for i in start..<(data.count - 4) {
            if data[i..<i+4] == target {
                return i
            }
        }
        return nil
    }
    
    private func parseMessage(data: Data, offset: Int, messageNumber: Int) throws -> GribMessage {
        var pos = offset
        
        // Parse Indicator Section
        let (totalLength, edition) = try parseIndicatorSection(data: data, offset: &pos)
        
        guard edition == 1 else {
            throw GribError.unsupportedEdition(edition)
        }
        
        // Parse PDS
        let pds = try parseProductDefinitionSection(data: data, offset: &pos)
        
        // Parse GDS if present
        var gds: GridDefinition? = nil
        if pds.hasGDS {
            gds = try parseGridDefinitionSection(data: data, offset: &pos)
        }
        
        // Skip BMS if present
        if pds.hasBMS {
            let bmsLength = readUInt24(data: data, offset: pos)
            pos += Int(bmsLength)
        }
        
        // Parse BDS and decode values
        let bdsOffset = pos
        let bds = try parseBinaryDataSection(data: data, offset: &pos)
        
        var values: [Float] = []
        if let grid = gds {
            values = decodeValues(data: data, bds: bds, numValues: grid.totalPoints, dataOffset: bdsOffset)
        }
        
        // Build public message
        let parameter = GribParameter(
            id: pds.parameterId,
            name: parameterName(for: pds.parameterId),
            unit: parameterUnit(for: pds.parameterId)
        )
        
        let level = GribLevel(
            type: pds.levelType,
            typeName: levelTypeName(for: pds.levelType),
            value: Double(pds.levelValue)
        )
        
        let timestamp = makeTimestamp(pds: pds)
        
        let grid = gds.map { gdsSection -> GribGrid in
            GribGrid(
                ni: Int(gdsSection.ni),
                nj: Int(gdsSection.nj),
                bounds: GribBounds(
                    minLatitude: Double(min(gdsSection.lat1, gdsSection.lat2)),
                    maxLatitude: Double(max(gdsSection.lat1, gdsSection.lat2)),
                    minLongitude: Double(min(gdsSection.lon1, gdsSection.lon2)),
                    maxLongitude: Double(max(gdsSection.lon1, gdsSection.lon2))
                ),
                latitudeIncrement: Double(gdsSection.dj),
                longitudeIncrement: Double(gdsSection.di),
                scanningMode: gdsSection.scanningMode
            )
        }
        
        return GribMessage(
            messageNumber: messageNumber,
            totalLength: totalLength,
            parameter: parameter,
            level: level,
            timestamp: timestamp,
            grid: grid,
            values: values,
            rawGDS: gds
        )
    }
    
    // MARK: - Section Parsers
    
    private func parseIndicatorSection(data: Data, offset: inout Int) throws -> (totalLength: Int, edition: UInt8) {
        guard offset + 8 <= data.count else {
            throw GribError.truncatedData("Indicator section")
        }
        
        guard let magic = String(data: data[offset..<offset+4], encoding: .ascii),
              magic == "GRIB" else {
            throw GribError.invalidMagic
        }
        
        let totalLength = (Int(data[offset+4]) << 16) |
                         (Int(data[offset+5]) << 8) |
                         Int(data[offset+6])
        let edition = data[offset+7]
        
        offset += 8
        return (totalLength, edition)
    }
    
    private func parseProductDefinitionSection(data: Data, offset: inout Int) throws -> PDSInfo {
        guard offset + 28 <= data.count else {
            throw GribError.truncatedData("PDS")
        }
        
        let startOffset = offset
        let length = readUInt24(data: data, offset: offset)
        
        let flag = data[offset+7]
        let hasGDS = (flag & 0x80) != 0
        let hasBMS = (flag & 0x40) != 0
        
        let parameterId = data[offset+8]
        let levelType = data[offset+9]
        let levelValue = (UInt16(data[offset+10]) << 8) | UInt16(data[offset+11])
        
        let year = data[offset+12]
        let month = data[offset+13]
        let day = data[offset+14]
        let hour = data[offset+15]
        let minute = data[offset+16]
        
        offset = startOffset + Int(length)
        
        return PDSInfo(
            hasGDS: hasGDS,
            hasBMS: hasBMS,
            parameterId: parameterId,
            levelType: levelType,
            levelValue: levelValue,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
    }
    
    private func parseGridDefinitionSection(data: Data, offset: inout Int) throws -> GridDefinition {
        guard offset + 32 <= data.count else {
            throw GribError.truncatedData("GDS")
        }
        
        let startOffset = offset
        let length = readUInt24(data: data, offset: offset)
        
        let dataRepType = data[offset+5]
        let ni = (UInt16(data[offset+6]) << 8) | UInt16(data[offset+7])
        let nj = (UInt16(data[offset+8]) << 8) | UInt16(data[offset+9])
        
        // GRIB1 uses MSB as sign bit for coordinates
        let lat1 = parseSignMagnitude24(data: data, offset: offset+10) / 1000.0
        let lon1 = parseSignMagnitude24(data: data, offset: offset+13) / 1000.0
        let lat2 = parseSignMagnitude24(data: data, offset: offset+17) / 1000.0
        let lon2 = parseSignMagnitude24(data: data, offset: offset+20) / 1000.0
        
        let di = Float((UInt16(data[offset+23]) << 8) | UInt16(data[offset+24])) / 1000.0
        let dj = Float((UInt16(data[offset+25]) << 8) | UInt16(data[offset+26])) / 1000.0
        let scanningMode = data[offset+27]
        
        offset = startOffset + Int(length)
        
        return GridDefinition(
            dataRepresentationType: dataRepType,
            ni: ni,
            nj: nj,
            lat1: lat1,
            lon1: lon1,
            lat2: lat2,
            lon2: lon2,
            di: di,
            dj: dj,
            scanningMode: scanningMode
        )
    }
    
    private func parseBinaryDataSection(data: Data, offset: inout Int) throws -> BDSInfo {
        guard offset + 11 <= data.count else {
            throw GribError.truncatedData("BDS")
        }
        
        let startOffset = offset
        let length = readUInt24(data: data, offset: offset)
        let flag = data[offset+3]
        
        // GRIB1 uses sign-magnitude for binary scale factor
        let byte4 = data[offset+4]
        let byte5 = data[offset+5]
        let isNegative = (byte4 & 0x80) != 0
        let magnitude = Int16(((Int(byte4) & 0x7F) << 8) | Int(byte5))
        let binaryScale = isNegative ? -magnitude : magnitude
        
        // Reference value (IEEE 754 float)
        let refUInt32 = (UInt32(data[offset+6]) << 24) |
                        (UInt32(data[offset+7]) << 16) |
                        (UInt32(data[offset+8]) << 8) |
                        UInt32(data[offset+9])
        let referenceValue = Float(bitPattern: refUInt32)
        
        let bitsPerValue = data[offset+10]
        
        offset = startOffset + Int(length)
        
        return BDSInfo(
            length: Int(length),
            flag: flag,
            binaryScaleFactor: binaryScale,
            referenceValue: referenceValue,
            bitsPerValue: bitsPerValue
        )
    }
    
    // MARK: - Data Decoding
    
    private func decodeValues(data: Data, bds: BDSInfo, numValues: Int, dataOffset: Int) -> [Float] {
        let bitsPerValue = Int(bds.bitsPerValue)
        
        guard bitsPerValue > 0 && bitsPerValue <= 32 else {
            return Array(repeating: bds.referenceValue, count: numValues)
        }
        
        var values: [Float] = []
        values.reserveCapacity(numValues)
        
        let dataStart = dataOffset + 11
        var bitOffset = 0
        let scaleFactor = pow(2.0, Float(bds.binaryScaleFactor))
        
        for _ in 0..<numValues {
            let packedValue = extractBits(from: data, startByte: dataStart, bitOffset: bitOffset, bitCount: bitsPerValue)
            let decodedValue = bds.referenceValue + (Float(packedValue) * scaleFactor)
            values.append(decodedValue)
            bitOffset += bitsPerValue
        }
        
        return values
    }
    
    private func extractBits(from data: Data, startByte: Int, bitOffset: Int, bitCount: Int) -> UInt32 {
        let byteOffset = bitOffset / 8
        let bitInByte = bitOffset % 8
        
        var accumulator: UInt64 = 0
        let bytesToRead = min(5, data.count - startByte - byteOffset)
        
        for i in 0..<bytesToRead {
            if startByte + byteOffset + i < data.count {
                accumulator = (accumulator << 8) | UInt64(data[startByte + byteOffset + i])
            }
        }
        
        let totalBitsRead = bytesToRead * 8
        let shift = totalBitsRead - bitInByte - bitCount
        let mask: UInt64 = (1 << bitCount) - 1
        
        return UInt32((accumulator >> shift) & mask)
    }
    
    // MARK: - Helpers
    
    private func readUInt24(data: Data, offset: Int) -> UInt32 {
        return (UInt32(data[offset]) << 16) |
               (UInt32(data[offset+1]) << 8) |
               UInt32(data[offset+2])
    }
    
    private func parseSignMagnitude24(data: Data, offset: Int) -> Float {
        let byte0 = data[offset]
        let byte1 = data[offset+1]
        let byte2 = data[offset+2]
        
        let isNegative = (byte0 & 0x80) != 0
        let magnitude = ((Int(byte0 & 0x7F) << 16) | (Int(byte1) << 8) | Int(byte2))
        
        return Float(isNegative ? -magnitude : magnitude)
    }
    
    private func makeTimestamp(pds: PDSInfo) -> Date {
        var components = DateComponents()
        // GRIB1 century handling: year is stored as 2-digit value
        // Years 0-99 could be 1900s or 2000s depending on the century indicator
        // Most modern files use 2000+ convention
        let year = Int(pds.year)
        components.year = year < 100 ? (year >= 50 ? 1900 + year : 2000 + year) : year
        components.month = Int(pds.month)
        components.day = Int(pds.day)
        components.hour = Int(pds.hour)
        components.minute = Int(pds.minute)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        return Calendar(identifier: .gregorian).date(from: components) ?? Date()
    }
    
    private func parameterName(for id: UInt8) -> String {
        switch id {
        case 1: return "Pressure"
        case 2: return "Pressure reduced to MSL"
        case 7: return "Geopotential height"
        case 11: return "Temperature"
        case 33: return "U-component of wind"
        case 34: return "V-component of wind"
        case 52: return "Relative humidity"
        case 61: return "Total precipitation"
        case 71: return "Total cloud cover"
        default: return "Unknown"
        }
    }
    
    private func parameterUnit(for id: UInt8) -> String {
        switch id {
        case 1, 2: return "Pa"
        case 7: return "gpm"
        case 11: return "K"
        case 33, 34: return "m/s"
        case 52: return "%"
        case 61: return "kg/m²"
        case 71: return "%"
        default: return ""
        }
    }
    
    private func levelTypeName(for type: UInt8) -> String {
        switch type {
        case 1: return "Surface"
        case 2: return "Cloud base level"
        case 3: return "Cloud top level"
        case 100: return "Isobaric surface"
        case 102: return "Mean sea level"
        case 103, 105: return "Height above ground"
        case 106: return "Depth below land surface"
        case 200: return "Entire atmosphere"
        default: return "Unknown"
        }
    }
}

// MARK: - Internal Types

private struct PDSInfo {
    let hasGDS: Bool
    let hasBMS: Bool
    let parameterId: UInt8
    let levelType: UInt8
    let levelValue: UInt16
    let year: UInt8
    let month: UInt8
    let day: UInt8
    let hour: UInt8
    let minute: UInt8
}

private struct BDSInfo {
    let length: Int
    let flag: UInt8
    let binaryScaleFactor: Int16
    let referenceValue: Float
    let bitsPerValue: UInt8
}
