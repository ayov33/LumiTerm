import XCTest
import CoreGraphics

// =============================================================================
// Frame Calculation Tests
// =============================================================================
// These tests validate the collapsed/expanded frame math from WindowStateManager
// without importing the main executable target. The constants and formulas are
// replicated here so we can verify correctness for all 4 dock edges.

// MARK: - Replicated constants from WindowStateManager

private let stripW: CGFloat = 30
private let stripH: CGFloat = 100

private let sideWidth: CGFloat = 650
private let sideHeightRatio: CGFloat = 0.6

private let horizWidthRatio: CGFloat = 0.5
private let horizHeight: CGFloat = 300

private enum DockEdge: String, CaseIterable {
    case right, left, top, bottom
}

// MARK: - Replicated frame formulas

private func collapsedFrame(sf: NSRect, edge: DockEdge) -> NSRect {
    switch edge {
    case .right:
        return NSRect(x: sf.maxX - stripW, y: sf.midY - stripH/2, width: stripW, height: stripH)
    case .left:
        return NSRect(x: sf.minX, y: sf.midY - stripH/2, width: stripW, height: stripH)
    case .top:
        return NSRect(x: sf.midX - stripH/2, y: sf.maxY - stripW, width: stripH, height: stripW)
    case .bottom:
        return NSRect(x: sf.midX - stripH/2, y: sf.minY, width: stripH, height: stripW)
    }
}

private func expandedFrame(sf: NSRect, edge: DockEdge) -> NSRect {
    switch edge {
    case .right:
        let ph = sf.height * sideHeightRatio
        let cy = sf.midY - ph / 2
        return NSRect(x: sf.maxX - sideWidth, y: cy, width: sideWidth, height: ph)
    case .left:
        let ph = sf.height * sideHeightRatio
        let cy = sf.midY - ph / 2
        return NSRect(x: sf.minX, y: cy, width: sideWidth, height: ph)
    case .top:
        let pw = sf.width * horizWidthRatio
        let cx = sf.midX - pw / 2
        return NSRect(x: cx, y: sf.maxY - horizHeight, width: pw, height: horizHeight)
    case .bottom:
        let pw = sf.width * horizWidthRatio
        let cx = sf.midX - pw / 2
        return NSRect(x: cx, y: sf.minY, width: pw, height: horizHeight)
    }
}

// MARK: - Tests

final class FrameCalculationTests: XCTestCase {

    // A typical 1440×900 screen with a visible frame that accounts for menu bar and dock
    private let standardScreen = NSRect(x: 0, y: 0, width: 1440, height: 855)
    // A 2560×1440 Retina display
    private let retinaScreen = NSRect(x: 0, y: 25, width: 2560, height: 1415)
    // An offset secondary screen (positioned to the right of main)
    private let secondaryScreen = NSRect(x: 1440, y: 0, width: 1920, height: 1055)

    // MARK: - Collapsed Frame Tests

    func testCollapsedRight_standardScreen() {
        let frame = collapsedFrame(sf: standardScreen, edge: .right)

        // Should be flush with right edge
        XCTAssertEqual(frame.maxX, standardScreen.maxX, accuracy: 0.01,
                       "Collapsed right: right edge should be flush with screen")
        XCTAssertEqual(frame.width, stripW)
        XCTAssertEqual(frame.height, stripH)
        // Should be vertically centered
        XCTAssertEqual(frame.midY, standardScreen.midY, accuracy: 0.01,
                       "Collapsed right: should be vertically centered")
    }

    func testCollapsedLeft_standardScreen() {
        let frame = collapsedFrame(sf: standardScreen, edge: .left)

        // Should be flush with left edge
        XCTAssertEqual(frame.minX, standardScreen.minX, accuracy: 0.01,
                       "Collapsed left: left edge should be flush with screen")
        XCTAssertEqual(frame.width, stripW)
        XCTAssertEqual(frame.height, stripH)
        XCTAssertEqual(frame.midY, standardScreen.midY, accuracy: 0.01,
                       "Collapsed left: should be vertically centered")
    }

    func testCollapsedTop_standardScreen() {
        let frame = collapsedFrame(sf: standardScreen, edge: .top)

        // Should be flush with top edge
        XCTAssertEqual(frame.maxY, standardScreen.maxY, accuracy: 0.01,
                       "Collapsed top: top edge should be flush with screen")
        // For top/bottom, width and height are swapped (horizontal strip)
        XCTAssertEqual(frame.width, stripH)
        XCTAssertEqual(frame.height, stripW)
        XCTAssertEqual(frame.midX, standardScreen.midX, accuracy: 0.01,
                       "Collapsed top: should be horizontally centered")
    }

    func testCollapsedBottom_standardScreen() {
        let frame = collapsedFrame(sf: standardScreen, edge: .bottom)

        // Should be flush with bottom edge
        XCTAssertEqual(frame.minY, standardScreen.minY, accuracy: 0.01,
                       "Collapsed bottom: bottom edge should be flush with screen")
        XCTAssertEqual(frame.width, stripH)
        XCTAssertEqual(frame.height, stripW)
        XCTAssertEqual(frame.midX, standardScreen.midX, accuracy: 0.01,
                       "Collapsed bottom: should be horizontally centered")
    }

    // MARK: - Expanded Frame Tests

    func testExpandedRight_standardScreen() {
        let frame = expandedFrame(sf: standardScreen, edge: .right)
        let expectedH = standardScreen.height * sideHeightRatio

        // Should be flush with right edge
        XCTAssertEqual(frame.maxX, standardScreen.maxX, accuracy: 0.01,
                       "Expanded right: right edge should be flush with screen")
        XCTAssertEqual(frame.width, sideWidth)
        XCTAssertEqual(frame.height, expectedH, accuracy: 0.01)
        XCTAssertEqual(frame.midY, standardScreen.midY, accuracy: 0.01,
                       "Expanded right: should be vertically centered")
    }

    func testExpandedLeft_standardScreen() {
        let frame = expandedFrame(sf: standardScreen, edge: .left)
        let expectedH = standardScreen.height * sideHeightRatio

        // Should be flush with left edge
        XCTAssertEqual(frame.minX, standardScreen.minX, accuracy: 0.01,
                       "Expanded left: left edge should be flush with screen")
        XCTAssertEqual(frame.width, sideWidth)
        XCTAssertEqual(frame.height, expectedH, accuracy: 0.01)
        XCTAssertEqual(frame.midY, standardScreen.midY, accuracy: 0.01,
                       "Expanded left: should be vertically centered")
    }

    func testExpandedTop_standardScreen() {
        let frame = expandedFrame(sf: standardScreen, edge: .top)
        let expectedW = standardScreen.width * horizWidthRatio

        // Should be flush with top edge
        XCTAssertEqual(frame.maxY, standardScreen.maxY, accuracy: 0.01,
                       "Expanded top: top edge should be flush with screen")
        XCTAssertEqual(frame.width, expectedW, accuracy: 0.01)
        XCTAssertEqual(frame.height, horizHeight)
        XCTAssertEqual(frame.midX, standardScreen.midX, accuracy: 0.01,
                       "Expanded top: should be horizontally centered")
    }

    func testExpandedBottom_standardScreen() {
        let frame = expandedFrame(sf: standardScreen, edge: .bottom)
        let expectedW = standardScreen.width * horizWidthRatio

        // Should be flush with bottom edge
        XCTAssertEqual(frame.minY, standardScreen.minY, accuracy: 0.01,
                       "Expanded bottom: bottom edge should be flush with screen")
        XCTAssertEqual(frame.width, expectedW, accuracy: 0.01)
        XCTAssertEqual(frame.height, horizHeight)
        XCTAssertEqual(frame.midX, standardScreen.midX, accuracy: 0.01,
                       "Expanded bottom: should be horizontally centered")
    }

    // MARK: - Expanded frame stays within screen bounds

    func testExpandedFrameWithinScreenBounds_allEdges() {
        let screens = [standardScreen, retinaScreen, secondaryScreen]

        for screen in screens {
            for edge in DockEdge.allCases {
                let frame = expandedFrame(sf: screen, edge: edge)
                XCTAssertGreaterThanOrEqual(frame.minX, screen.minX - 0.01,
                    "Edge \(edge) on screen \(screen): left overflow")
                XCTAssertLessThanOrEqual(frame.maxX, screen.maxX + 0.01,
                    "Edge \(edge) on screen \(screen): right overflow")
                XCTAssertGreaterThanOrEqual(frame.minY, screen.minY - 0.01,
                    "Edge \(edge) on screen \(screen): bottom overflow")
                XCTAssertLessThanOrEqual(frame.maxY, screen.maxY + 0.01,
                    "Edge \(edge) on screen \(screen): top overflow")
            }
        }
    }

    // MARK: - Collapsed frame stays within screen bounds

    func testCollapsedFrameWithinScreenBounds_allEdges() {
        let screens = [standardScreen, retinaScreen, secondaryScreen]

        for screen in screens {
            for edge in DockEdge.allCases {
                let frame = collapsedFrame(sf: screen, edge: edge)
                XCTAssertGreaterThanOrEqual(frame.minX, screen.minX - 0.01,
                    "Edge \(edge) on screen \(screen): left overflow")
                XCTAssertLessThanOrEqual(frame.maxX, screen.maxX + 0.01,
                    "Edge \(edge) on screen \(screen): right overflow")
                XCTAssertGreaterThanOrEqual(frame.minY, screen.minY - 0.01,
                    "Edge \(edge) on screen \(screen): bottom overflow")
                XCTAssertLessThanOrEqual(frame.maxY, screen.maxY + 0.01,
                    "Edge \(edge) on screen \(screen): top overflow")
            }
        }
    }

    // MARK: - Retina screen tests

    func testExpandedRight_retinaScreen() {
        let frame = expandedFrame(sf: retinaScreen, edge: .right)
        let expectedH = retinaScreen.height * sideHeightRatio

        XCTAssertEqual(frame.maxX, retinaScreen.maxX, accuracy: 0.01)
        XCTAssertEqual(frame.width, sideWidth)
        XCTAssertEqual(frame.height, expectedH, accuracy: 0.01)
    }

    func testExpandedTop_retinaScreen() {
        let frame = expandedFrame(sf: retinaScreen, edge: .top)
        let expectedW = retinaScreen.width * horizWidthRatio

        XCTAssertEqual(frame.maxY, retinaScreen.maxY, accuracy: 0.01)
        XCTAssertEqual(frame.width, expectedW, accuracy: 0.01)
        XCTAssertEqual(frame.height, horizHeight)
    }

    // MARK: - Secondary (offset) screen tests

    func testCollapsedRight_secondaryScreen() {
        let frame = collapsedFrame(sf: secondaryScreen, edge: .right)

        // The right edge should be at secondaryScreen.maxX (1440 + 1920 = 3360)
        XCTAssertEqual(frame.maxX, secondaryScreen.maxX, accuracy: 0.01)
        XCTAssertEqual(frame.minX, secondaryScreen.maxX - stripW, accuracy: 0.01)
    }

    func testCollapsedLeft_secondaryScreen() {
        let frame = collapsedFrame(sf: secondaryScreen, edge: .left)

        // The left edge should start at the secondary screen's origin (1440)
        XCTAssertEqual(frame.minX, secondaryScreen.minX, accuracy: 0.01)
    }

    // MARK: - Dimension consistency tests

    func testCollapsedDimensions_sideEdges() {
        // Left and right collapsed strips should have the same dimensions
        let right = collapsedFrame(sf: standardScreen, edge: .right)
        let left = collapsedFrame(sf: standardScreen, edge: .left)

        XCTAssertEqual(right.width, left.width)
        XCTAssertEqual(right.height, left.height)
        XCTAssertEqual(right.width, stripW)
        XCTAssertEqual(right.height, stripH)
    }

    func testCollapsedDimensions_horizEdges() {
        // Top and bottom collapsed strips should have swapped width/height
        let top = collapsedFrame(sf: standardScreen, edge: .top)
        let bottom = collapsedFrame(sf: standardScreen, edge: .bottom)

        XCTAssertEqual(top.width, bottom.width)
        XCTAssertEqual(top.height, bottom.height)
        XCTAssertEqual(top.width, stripH)
        XCTAssertEqual(top.height, stripW)
    }

    func testExpandedDimensions_sideEdgesSymmetric() {
        // Left and right expanded panels should have the same size
        let right = expandedFrame(sf: standardScreen, edge: .right)
        let left = expandedFrame(sf: standardScreen, edge: .left)

        XCTAssertEqual(right.width, left.width)
        XCTAssertEqual(right.height, left.height)
    }

    func testExpandedDimensions_horizEdgesSymmetric() {
        // Top and bottom expanded panels should have the same size
        let top = expandedFrame(sf: standardScreen, edge: .top)
        let bottom = expandedFrame(sf: standardScreen, edge: .bottom)

        XCTAssertEqual(top.width, bottom.width)
        XCTAssertEqual(top.height, bottom.height)
    }

    // MARK: - Expanded frame is larger than collapsed frame

    func testExpandedIsLargerThanCollapsed_allEdges() {
        for edge in DockEdge.allCases {
            let collapsed = collapsedFrame(sf: standardScreen, edge: edge)
            let expanded = expandedFrame(sf: standardScreen, edge: edge)

            XCTAssertGreaterThan(expanded.width * expanded.height,
                                 collapsed.width * collapsed.height,
                                 "Edge \(edge): expanded area should be larger than collapsed")
        }
    }
}
