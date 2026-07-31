import Foundation

/// Pure geometry and ordering for the menubar Space row. Split out from `Menubar` because the
/// interesting cases — overflow past the ninth Space, several display groups — cannot be reproduced
/// on a single-display machine, so they are covered by tests instead of by clicking.
struct MenubarSpaceRow {
    static let segmentWidth = CGFloat(28)
    static let groupGap = CGFloat(6)
    /// Segments beyond this count per display collapse into an overflow segment.
    static let maxDirectSegmentsPerGroup = 9

    /// How many Spaces of a group get their own segment. Once a group overflows, one slot is given up
    /// to the overflow segment, so the group never exceeds `maxDirectSegmentsPerGroup` slots in total.
    static func directSegmentCount(_ spaceCount: Int) -> Int {
        spaceCount > maxDirectSegmentsPerGroup ? maxDirectSegmentsPerGroup - 1 : max(0, spaceCount)
    }

    static func hasOverflow(_ spaceCount: Int) -> Bool {
        spaceCount > directSegmentCount(spaceCount)
    }

    /// One-based Space indexes that the overflow menu has to offer.
    static func overflowIndexes(_ spaceCount: Int) -> [Int] {
        let direct = directSegmentCount(spaceCount)
        guard spaceCount > direct else { return [] }
        return Array((direct + 1)...spaceCount)
    }

    static func groupWidth(_ spaceCount: Int) -> CGFloat {
        CGFloat(hasOverflow(spaceCount) ? directSegmentCount(spaceCount) + 1 : max(0, spaceCount)) * segmentWidth
    }

    /// Total width of the row: every group plus a gap on each side of the dividers between them.
    static func totalWidth(_ spaceCounts: [Int]) -> CGFloat {
        spaceCounts.reduce(CGFloat(0)) { $0 + groupWidth($1) }
            + CGFloat(max(0, spaceCounts.count - 1)) * groupGap * 2
    }

    /// Optical heights, measured against the system status items on a Tahoe menubar: the shield sits at
    /// about 14pt and the keyboard glyph at 11pt, while the status button AltTab+ draws into is only 22pt
    /// tall inside a 33pt bar. Deriving a height by insetting that button produced a 17pt bordered box,
    /// the tallest thing in the menubar, which reads as misaligned next to smaller unbordered glyphs.
    /// Fixed target heights keep the row in the same optical band whatever the button turns out to be.
    static let segmentHeight = CGFloat(16)
    static let iconHeight = CGFloat(18)
    static let dividerHeight = CGFloat(12)

    /// Vertical placement of one element inside the status button. `y` follows from the height so the
    /// element is centred by construction: pinning `y` and clamping the height upwards, as this did
    /// before, moves the element up by half the clamp.
    static func centeredRect(x: CGFloat, width: CGFloat, availableHeight: CGFloat, preferredHeight: CGFloat) -> NSRect {
        let height = min(preferredHeight, availableHeight)
        return NSRect(x: x, y: (availableHeight - height) / 2, width: width, height: height)
    }

    /// Displays that currently have a screen come first, left to right. A display that still owns
    /// Spaces but has no live screen is appended in a stable order: taking them in dictionary order
    /// would let the row reshuffle between refreshes for no visible reason.
    static func orderedDisplays(screensInOrder: [String], displaysWithSpaces: [String]) -> [String] {
        let withSpaces = Set(displaysWithSpaces)
        var seen = Set<String>()
        var ordered = screensInOrder.filter { withSpaces.contains($0) && seen.insert($0).inserted }
        displaysWithSpaces.sorted().forEach {
            if seen.insert($0).inserted {
                ordered.append($0)
            }
        }
        return ordered
    }
}
