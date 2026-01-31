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
    
    @Test("Wind speed calculation - pure eastward wind")
    func windSpeedEastward() {
        let processor = WindProcessor()
        let (speed, direction) = processor.calculateWindSpeedAndDirection(u: 10, v: 0)
        #expect(abs(speed - 10.0) < 0.001)
        #expect(abs(direction - 270.0) < 0.001)
    }
    
    @Test("Wind speed calculation - pure northward wind")
    func windSpeedNorthward() {
        let processor = WindProcessor()
        let (speed, direction) = processor.calculateWindSpeedAndDirection(u: 0, v: 10)
        #expect(abs(speed - 10.0) < 0.001)
        #expect(abs(direction - 180.0) < 0.001)
    }
    
    @Test("Wind speed calculation - pure southward wind")
    func windSpeedSouthward() {
        let processor = WindProcessor()
        let (speed, direction) = processor.calculateWindSpeedAndDirection(u: 0, v: -10)
        #expect(abs(speed - 10.0) < 0.001)
        #expect(abs(direction - 0.0) < 0.001)
    }
    
    @Test("Wind speed calculation - diagonal wind")
    func windSpeedDiagonal() {
        let processor = WindProcessor()
        let (speed, direction) = processor.calculateWindSpeedAndDirection(u: 10, v: 10)
        #expect(abs(speed - sqrt(200)) < 0.001)
        #expect(abs(direction - 225.0) < 0.001)
    }
    
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
    
    @Test("GribParameter common values")
    func gribParameterCommonValues() {
        #expect(GribParameter.uWind == 33)
        #expect(GribParameter.vWind == 34)
        #expect(GribParameter.temperature == 11)
        #expect(GribParameter.pressure == 1)
        #expect(GribParameter.geopotentialHeight == 7)
    }
    
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
    
    func testWindSpeedDiagonal() {
        let processor = WindProcessor()
        let (speed, direction) = processor.calculateWindSpeedAndDirection(u: 10, v: 10)
        XCTAssertEqual(speed, sqrt(200), accuracy: 0.001)
        XCTAssertEqual(direction, 225.0, accuracy: 0.001)
    }
    
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
    
    func testGribParameterCommonValues() {
        XCTAssertEqual(GribParameter.uWind, 33)
        XCTAssertEqual(GribParameter.vWind, 34)
        XCTAssertEqual(GribParameter.temperature, 11)
        XCTAssertEqual(GribParameter.pressure, 1)
        XCTAssertEqual(GribParameter.geopotentialHeight, 7)
    }
    
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
