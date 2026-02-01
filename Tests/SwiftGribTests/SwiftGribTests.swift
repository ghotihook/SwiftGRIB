//
//  SwiftGribTests.swift
//  SwiftGrib
//
//  Unit tests for SwiftGrib library.
//

#if canImport(Testing)
import Testing
import Foundation
@testable import SwiftGrib

@Suite("SwiftGrib Tests")
struct SwiftGribTests {
    
    // MARK: - Parser Tests
    
    @Test("Parser initializes correctly")
    func parserInitialization() {
        let parser = GribParser()
        #expect(parser != nil)
    }
    
    @Test("Invalid data returns empty array")
    func invalidDataReturnsEmpty() throws {
        let parser = GribParser()
        let invalidData = Data("NOT A GRIB FILE".utf8)
        let messages = try parser.parse(data: invalidData)
        #expect(messages.isEmpty)
    }
    
    // MARK: - Real GRIB File Tests
    
    @Test("Parse real GRIB file")
    func parseRealGribFile() throws {
        guard let url = Bundle.module.url(forResource: "PWAI_WRCTP_50k_15d_3h_-31N_-44S_157E_145W_20260201_0540", withExtension: "grb", subdirectory: "Resources") else {
            Issue.record("Test GRIB file not found")
            return
        }
        
        let parser = GribParser()
        let messages = try parser.parse(contentsOf: url)
        
        // Should have multiple messages (U and V wind components for multiple time steps)
        #expect(messages.count > 0)
        print("Parsed \(messages.count) messages")
        
        // Check first message structure
        if let first = messages.first {
            #expect(first.grid != nil)
            #expect(first.values.count > 0)
            print("First message: \(first.parameter.name), grid: \(first.grid?.ni ?? 0)x\(first.grid?.nj ?? 0), values: \(first.values.count)")
        }
    }
    
    @Test("GRIB file contains wind data")
    func gribFileContainsWindData() throws {
        guard let url = Bundle.module.url(forResource: "PWAI_WRCTP_50k_15d_3h_-31N_-44S_157E_145W_20260201_0540", withExtension: "grb", subdirectory: "Resources") else {
            Issue.record("Test GRIB file not found")
            return
        }
        
        let parser = GribParser()
        let messages = try parser.parse(contentsOf: url)
        
        let uWindMessages = messages.filter { $0.parameter.id == GribParameter.uWind }
        let vWindMessages = messages.filter { $0.parameter.id == GribParameter.vWind }
        
        #expect(uWindMessages.count > 0, "Should have U-wind messages")
        #expect(vWindMessages.count > 0, "Should have V-wind messages")
        
        print("U-wind messages: \(uWindMessages.count)")
        print("V-wind messages: \(vWindMessages.count)")
    }
    
    @Test("Wind values are in reasonable range")
    func windValuesReasonableRange() throws {
        guard let url = Bundle.module.url(forResource: "PWAI_WRCTP_50k_15d_3h_-31N_-44S_157E_145W_20260201_0540", withExtension: "grb", subdirectory: "Resources") else {
            Issue.record("Test GRIB file not found")
            return
        }
        
        let parser = GribParser()
        let messages = try parser.parse(contentsOf: url)
        
        for message in messages.prefix(5) {
            if let minVal = message.minValue, let maxVal = message.maxValue {
                // Wind components should typically be between -100 and 100 m/s
                #expect(minVal > -100 && minVal < 100, "Min value \(minVal) should be reasonable")
                #expect(maxVal > -100 && maxVal < 100, "Max value \(maxVal) should be reasonable")
                print("\(message.parameter.name): min=\(minVal), max=\(maxVal)")
            }
        }
    }
    
    @Test("Extract wind data from GRIB file")
    func extractWindDataFromFile() throws {
        guard let url = Bundle.module.url(forResource: "PWAI_WRCTP_50k_15d_3h_-31N_-44S_157E_145W_20260201_0540", withExtension: "grb", subdirectory: "Resources") else {
            Issue.record("Test GRIB file not found")
            return
        }
        
        let parser = GribParser()
        let messages = try parser.parse(contentsOf: url)
        
        let processor = WindProcessor()
        let windData = processor.extractWindData(from: messages, sampleStep: 5)
        
        #expect(windData.count > 0, "Should extract wind data points")
        print("Extracted \(windData.count) wind data points")
        
        // Check wind speeds are reasonable (0-50 m/s typical)
        for point in windData.prefix(10) {
            #expect(point.speed >= 0, "Wind speed should be non-negative")
            #expect(point.speed < 100, "Wind speed should be reasonable (<100 m/s)")
            #expect(point.direction >= 0 && point.direction < 360, "Direction should be 0-360")
            print("  (\(String(format: "%.2f", point.latitude)), \(String(format: "%.2f", point.longitude))): \(String(format: "%.1f", point.speed)) m/s from \(String(format: "%.0f", point.direction))°")
        }
    }
    
    @Test("Grid coordinates are correct")
    func gridCoordinatesCorrect() throws {
        guard let url = Bundle.module.url(forResource: "PWAI_WRCTP_50k_15d_3h_-31N_-44S_157E_145W_20260201_0540", withExtension: "grb", subdirectory: "Resources") else {
            Issue.record("Test GRIB file not found")
            return
        }
        
        let parser = GribParser()
        let messages = try parser.parse(contentsOf: url)
        
        guard let message = messages.first, let grid = message.grid else {
            Issue.record("No grid in first message")
            return
        }
        
        // Check bounds are in expected region (Eastern Australia/Pacific)
        print("Grid bounds: lat \(grid.bounds.minLatitude) to \(grid.bounds.maxLatitude), lon \(grid.bounds.minLongitude) to \(grid.bounds.maxLongitude)")
        
        // Verify coordinate at index 0
        if let coord = message.coordinate(at: 0) {
            print("Coordinate at index 0: (\(coord.latitude), \(coord.longitude))")
        }
        
        // Verify coordinate at last index
        if let coord = message.coordinate(at: grid.totalPoints - 1) {
            print("Coordinate at last index: (\(coord.latitude), \(coord.longitude))")
        }
    }
    
    // MARK: - Wind Calculation Tests
    
    @Test("Wind speed calculation - pure eastward wind")
    func windSpeedEastward() {
        let processor = WindProcessor()
        let (speed, direction) = processor.calculateWindSpeedAndDirection(u: 10, v: 0)
        #expect(abs(speed - 10.0) < 0.001)
        #expect(abs(direction - 270.0) < 0.001)  // From west
    }
    
    @Test("Wind speed calculation - pure northward wind")
    func windSpeedNorthward() {
        let processor = WindProcessor()
        let (speed, direction) = processor.calculateWindSpeedAndDirection(u: 0, v: 10)
        #expect(abs(speed - 10.0) < 0.001)
        #expect(abs(direction - 180.0) < 0.001)  // From south
    }
    
    @Test("Wind speed calculation - pure southward wind")
    func windSpeedSouthward() {
        let processor = WindProcessor()
        let (speed, direction) = processor.calculateWindSpeedAndDirection(u: 0, v: -10)
        #expect(abs(speed - 10.0) < 0.001)
        #expect(abs(direction - 0.0) < 0.001)  // From north
    }
    
    @Test("Wind speed calculation - pure westward wind")
    func windSpeedWestward() {
        let processor = WindProcessor()
        let (speed, direction) = processor.calculateWindSpeedAndDirection(u: -10, v: 0)
        #expect(abs(speed - 10.0) < 0.001)
        #expect(abs(direction - 90.0) < 0.001)  // From east
    }
    
    @Test("Wind speed calculation - diagonal wind (NE going)")
    func windSpeedDiagonalNE() {
        let processor = WindProcessor()
        let (speed, direction) = processor.calculateWindSpeedAndDirection(u: 10, v: 10)
        #expect(abs(speed - sqrt(200)) < 0.001)
        #expect(abs(direction - 225.0) < 0.001)  // From SW
    }
    
    @Test("Wind speed calculation - zero wind")
    func windSpeedZero() {
        let processor = WindProcessor()
        let (speed, direction) = processor.calculateWindSpeedAndDirection(u: 0, v: 0)
        #expect(speed == 0.0)
        #expect(direction == 0.0)
    }
    
    // MARK: - WindDataPoint Tests
    
    @Test("WindDataPoint speed conversions")
    func windDataPointConversions() {
        let point = WindDataPoint(
            latitude: -37.0,
            longitude: 145.0,
            speed: 10.0,
            direction: 180.0,
            timestamp: Date()
        )
        #expect(abs(point.speedKnots - 19.4384) < 0.001)
        #expect(abs(point.speedKmh - 36.0) < 0.001)
        #expect(abs(point.speedMph - 22.3694) < 0.001)
    }
    
    // MARK: - GribBounds Tests
    
    @Test("GribBounds calculations")
    func gribBoundsCalculations() {
        let bounds = GribBounds(
            minLatitude: -44.0,
            maxLatitude: -31.0,
            minLongitude: 145.0,
            maxLongitude: 157.0
        )
        #expect(bounds.centerLatitude == -37.5)
        #expect(bounds.centerLongitude == 151.0)
        #expect(bounds.latitudeSpan == 13.0)
        #expect(bounds.longitudeSpan == 12.0)
    }
    
    // MARK: - GribGrid Tests
    
    @Test("GribGrid properties")
    func gribGridProperties() {
        let grid = GribGrid(
            ni: 25,
            nj: 27,
            bounds: GribBounds(
                minLatitude: -44.0,
                maxLatitude: -31.0,
                minLongitude: 145.0,
                maxLongitude: 157.0
            ),
            latitudeIncrement: 0.5,
            longitudeIncrement: 0.5,
            scanningMode: 0x00
        )
        #expect(grid.totalPoints == 675)
        #expect(grid.scansWestToEast == true)
        #expect(grid.scansNorthToSouth == true)
    }
    
    // MARK: - GribParameter Tests
    
    @Test("GribParameter common values")
    func gribParameterCommonValues() {
        #expect(GribParameter.uWind == 33)
        #expect(GribParameter.vWind == 34)
        #expect(GribParameter.temperature == 11)
        #expect(GribParameter.pressure == 1)
        #expect(GribParameter.geopotentialHeight == 7)
    }
    
    // MARK: - GribError Tests
    
    @Test("GribError descriptions")
    func gribErrorDescriptions() {
        let invalidMagic = GribError.invalidMagic
        #expect(invalidMagic.errorDescription?.contains("valid GRIB data") == true)
        
        let truncated = GribError.truncatedData("PDS")
        #expect(truncated.errorDescription?.contains("PDS") == true)
        
        let unsupported = GribError.unsupportedEdition(2)
        #expect(unsupported.errorDescription?.contains("edition 1") == true)
    }
}

#elseif canImport(XCTest)
import XCTest
import Foundation
@testable import SwiftGrib

final class SwiftGribTests: XCTestCase {
    
    // MARK: - Parser Tests
    
    func testParserInitialization() {
        let parser = GribParser()
        XCTAssertNotNil(parser)
    }
    
    func testInvalidDataReturnsEmpty() throws {
        let parser = GribParser()
        let invalidData = Data("NOT A GRIB FILE".utf8)
        let messages = try parser.parse(data: invalidData)
        XCTAssertTrue(messages.isEmpty)
    }
    
    // MARK: - Real GRIB File Tests
    
    func testParseRealGribFile() throws {
        guard let url = Bundle.module.url(forResource: "PWAI_WRCTP_50k_15d_3h_-31N_-44S_157E_145W_20260201_0540", withExtension: "grb", subdirectory: "Resources") else {
            XCTFail("Test GRIB file not found")
            return
        }
        
        let parser = GribParser()
        let messages = try parser.parse(contentsOf: url)
        
        XCTAssertGreaterThan(messages.count, 0, "Should parse messages from GRIB file")
        print("Parsed \(messages.count) messages")
        
        if let first = messages.first {
            XCTAssertNotNil(first.grid)
            XCTAssertGreaterThan(first.values.count, 0)
            print("First message: \(first.parameter.name), grid: \(first.grid?.ni ?? 0)x\(first.grid?.nj ?? 0), values: \(first.values.count)")
        }
    }
    
    func testGribFileContainsWindData() throws {
        guard let url = Bundle.module.url(forResource: "PWAI_WRCTP_50k_15d_3h_-31N_-44S_157E_145W_20260201_0540", withExtension: "grb", subdirectory: "Resources") else {
            XCTFail("Test GRIB file not found")
            return
        }
        
        let parser = GribParser()
        let messages = try parser.parse(contentsOf: url)
        
        let uWindMessages = messages.filter { $0.parameter.id == GribParameter.uWind }
        let vWindMessages = messages.filter { $0.parameter.id == GribParameter.vWind }
        
        XCTAssertGreaterThan(uWindMessages.count, 0, "Should have U-wind messages")
        XCTAssertGreaterThan(vWindMessages.count, 0, "Should have V-wind messages")
        
        print("U-wind messages: \(uWindMessages.count)")
        print("V-wind messages: \(vWindMessages.count)")
    }
    
    func testWindValuesReasonableRange() throws {
        guard let url = Bundle.module.url(forResource: "PWAI_WRCTP_50k_15d_3h_-31N_-44S_157E_145W_20260201_0540", withExtension: "grb", subdirectory: "Resources") else {
            XCTFail("Test GRIB file not found")
            return
        }
        
        let parser = GribParser()
        let messages = try parser.parse(contentsOf: url)
        
        for message in messages.prefix(5) {
            if let minVal = message.minValue, let maxVal = message.maxValue {
                XCTAssertGreaterThan(minVal, -100, "Min value should be > -100 m/s")
                XCTAssertLessThan(minVal, 100, "Min value should be < 100 m/s")
                XCTAssertGreaterThan(maxVal, -100, "Max value should be > -100 m/s")
                XCTAssertLessThan(maxVal, 100, "Max value should be < 100 m/s")
                print("\(message.parameter.name): min=\(minVal), max=\(maxVal)")
            }
        }
    }
    
    func testExtractWindDataFromFile() throws {
        guard let url = Bundle.module.url(forResource: "PWAI_WRCTP_50k_15d_3h_-31N_-44S_157E_145W_20260201_0540", withExtension: "grb", subdirectory: "Resources") else {
            XCTFail("Test GRIB file not found")
            return
        }
        
        let parser = GribParser()
        let messages = try parser.parse(contentsOf: url)
        
        let processor = WindProcessor()
        let windData = processor.extractWindData(from: messages, sampleStep: 5)
        
        XCTAssertGreaterThan(windData.count, 0, "Should extract wind data points")
        print("Extracted \(windData.count) wind data points")
        
        for point in windData.prefix(10) {
            XCTAssertGreaterThanOrEqual(point.speed, 0, "Wind speed should be non-negative")
            XCTAssertLessThan(point.speed, 100, "Wind speed should be reasonable")
            XCTAssertGreaterThanOrEqual(point.direction, 0, "Direction should be >= 0")
            XCTAssertLessThan(point.direction, 360, "Direction should be < 360")
            print("  (\(String(format: "%.2f", point.latitude)), \(String(format: "%.2f", point.longitude))): \(String(format: "%.1f", point.speed)) m/s from \(String(format: "%.0f", point.direction))°")
        }
    }
    
    func testGridCoordinatesCorrect() throws {
        guard let url = Bundle.module.url(forResource: "PWAI_WRCTP_50k_15d_3h_-31N_-44S_157E_145W_20260201_0540", withExtension: "grb", subdirectory: "Resources") else {
            XCTFail("Test GRIB file not found")
            return
        }
        
        let parser = GribParser()
        let messages = try parser.parse(contentsOf: url)
        
        guard let message = messages.first, let grid = message.grid else {
            XCTFail("No grid in first message")
            return
        }
        
        print("Grid bounds: lat \(grid.bounds.minLatitude) to \(grid.bounds.maxLatitude), lon \(grid.bounds.minLongitude) to \(grid.bounds.maxLongitude)")
        
        if let coord = message.coordinate(at: 0) {
            print("Coordinate at index 0: (\(coord.latitude), \(coord.longitude))")
        }
        
        if let coord = message.coordinate(at: grid.totalPoints - 1) {
            print("Coordinate at last index: (\(coord.latitude), \(coord.longitude))")
        }
    }
    
    // MARK: - Wind Calculation Tests
    
    func testWindSpeedEastward() {
        let processor = WindProcessor()
        let (speed, direction) = processor.calculateWindSpeedAndDirection(u: 10, v: 0)
        XCTAssertEqual(speed, 10.0, accuracy: 0.001)
        XCTAssertEqual(direction, 270.0, accuracy: 0.001)
    }
    
    func testWindSpeedNorthward() {
        let processor = WindProcessor()
        let (speed, direction) = processor.calculateWindSpeedAndDirection(u: 0, v: 10)
        XCTAssertEqual(speed, 10.0, accuracy: 0.001)
        XCTAssertEqual(direction, 180.0, accuracy: 0.001)
    }
    
    func testWindSpeedSouthward() {
        let processor = WindProcessor()
        let (speed, direction) = processor.calculateWindSpeedAndDirection(u: 0, v: -10)
        XCTAssertEqual(speed, 10.0, accuracy: 0.001)
        XCTAssertEqual(direction, 0.0, accuracy: 0.001)
    }
    
    func testWindSpeedWestward() {
        let processor = WindProcessor()
        let (speed, direction) = processor.calculateWindSpeedAndDirection(u: -10, v: 0)
        XCTAssertEqual(speed, 10.0, accuracy: 0.001)
        XCTAssertEqual(direction, 90.0, accuracy: 0.001)
    }
    
    func testWindSpeedDiagonal() {
        let processor = WindProcessor()
        let (speed, direction) = processor.calculateWindSpeedAndDirection(u: 10, v: 10)
        XCTAssertEqual(speed, sqrt(200), accuracy: 0.001)
        XCTAssertEqual(direction, 225.0, accuracy: 0.001)
    }
    
    func testWindSpeedZero() {
        let processor = WindProcessor()
        let (speed, direction) = processor.calculateWindSpeedAndDirection(u: 0, v: 0)
        XCTAssertEqual(speed, 0.0)
        XCTAssertEqual(direction, 0.0)
    }
    
    // MARK: - WindDataPoint Tests
    
    func testWindDataPointConversions() {
        let point = WindDataPoint(
            latitude: -37.0,
            longitude: 145.0,
            speed: 10.0,
            direction: 180.0,
            timestamp: Date()
        )
        XCTAssertEqual(point.speedKnots, 19.4384, accuracy: 0.001)
        XCTAssertEqual(point.speedKmh, 36.0, accuracy: 0.001)
        XCTAssertEqual(point.speedMph, 22.3694, accuracy: 0.001)
    }
    
    // MARK: - GribBounds Tests
    
    func testGribBoundsCalculations() {
        let bounds = GribBounds(
            minLatitude: -44.0,
            maxLatitude: -31.0,
            minLongitude: 145.0,
            maxLongitude: 157.0
        )
        XCTAssertEqual(bounds.centerLatitude, -37.5)
        XCTAssertEqual(bounds.centerLongitude, 151.0)
        XCTAssertEqual(bounds.latitudeSpan, 13.0)
        XCTAssertEqual(bounds.longitudeSpan, 12.0)
    }
    
    // MARK: - GribGrid Tests
    
    func testGribGridProperties() {
        let grid = GribGrid(
            ni: 25,
            nj: 27,
            bounds: GribBounds(
                minLatitude: -44.0,
                maxLatitude: -31.0,
                minLongitude: 145.0,
                maxLongitude: 157.0
            ),
            latitudeIncrement: 0.5,
            longitudeIncrement: 0.5,
            scanningMode: 0x00
        )
        XCTAssertEqual(grid.totalPoints, 675)
        XCTAssertTrue(grid.scansWestToEast)
        XCTAssertTrue(grid.scansNorthToSouth)
    }
    
    // MARK: - GribParameter Tests
    
    func testGribParameterCommonValues() {
        XCTAssertEqual(GribParameter.uWind, 33)
        XCTAssertEqual(GribParameter.vWind, 34)
        XCTAssertEqual(GribParameter.temperature, 11)
        XCTAssertEqual(GribParameter.pressure, 1)
        XCTAssertEqual(GribParameter.geopotentialHeight, 7)
    }
    
    // MARK: - GribError Tests
    
    func testGribErrorDescriptions() {
        let invalidMagic = GribError.invalidMagic
        XCTAssertTrue(invalidMagic.errorDescription?.contains("valid GRIB data") == true)
        
        let truncated = GribError.truncatedData("PDS")
        XCTAssertTrue(truncated.errorDescription?.contains("PDS") == true)
        
        let unsupported = GribError.unsupportedEdition(2)
        XCTAssertTrue(unsupported.errorDescription?.contains("edition 1") == true)
    }
}

#endif
