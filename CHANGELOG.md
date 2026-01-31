# Changelog

All notable changes to SwiftGrib will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-02-01

### Added
- Initial release of SwiftGrib
- GRIB Edition 1 parsing support
- `GribParser` for reading GRIB files from URLs or raw data
- `GribMessage` type representing parsed GRIB messages
- `GribParameter` type with common meteorological parameter IDs
- `GribLevel` type for vertical level information
- `GribGrid` type for grid definition with coordinate utilities
- `GribBounds` type for geographic bounds
- `WindProcessor` for combining U/V wind components into speed/direction
- `WindDataPoint` type with unit conversions (m/s, knots, km/h, mph)
- `GribError` enum for comprehensive error handling
- Sendable conformance for all types (Swift concurrency support)
- Support for macOS 13+, iOS 16+, tvOS 16+, watchOS 9+, visionOS 1+
- Comprehensive documentation and code examples
- Unit tests for core functionality

### Supported GRIB1 Features
- Indicator Section (IS)
- Product Definition Section (PDS)
- Grid Definition Section (GDS) for lat/lon grids
- Binary Data Section (BDS) with bit-packed data extraction
- Sign-magnitude encoding for coordinates and scale factors

### Not Yet Supported
- GRIB Edition 2
- Complex packing schemes
- Bitmap sections (BMS)
- Non-rectangular grids (polar stereographic, Lambert conformal, etc.)
