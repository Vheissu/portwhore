import XCTest
@testable import Portwhore

final class SmokeTests: XCTestCase {
  func testPaletteOwnershipColorsResolve() {
    XCTAssertNotNil(PortOwnershipTone.mine.color)
    XCTAssertNotNil(PortOwnershipTone.protected.color)
  }
}
