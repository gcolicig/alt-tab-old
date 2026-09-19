import CoreGraphics

/// Pure geometry for the Spaces preview panel. Kept free of AppKit state so the display arrangement can be
/// unit-tested with synthetic frames.
enum SpacesPreviewLayout {
    struct Display {
        let id: String
        /// Cocoa coordinates: origin at the bottom-left of the primary screen, y grows upwards.
        let frame: CGRect
    }

    /// Groups the displays into rows as they stand on the desk: the topmost row first, each row left to right.
    ///
    /// Two displays share a row when they overlap vertically by at least half of the shorter one. Only the
    /// relative position counts, so a 4K display and a laptop screen give strips of the same size.
    static func rows(_ displays: [Display]) -> [[String]] {
        var rows = [[Display]]()
        displays.sorted { $0.frame.midY > $1.frame.midY }.forEach { display in
            if let rowIndex = rows.firstIndex(where: { sharesRow($0[0].frame, display.frame) }) {
                rows[rowIndex].append(display)
            } else {
                rows.append([display])
            }
        }
        return rows.map { row in row.sorted { $0.frame.minX < $1.frame.minX }.map { $0.id } }
    }

    private static func sharesRow(_ a: CGRect, _ b: CGRect) -> Bool {
        let overlap = min(a.maxY, b.maxY) - max(a.minY, b.minY)
        return overlap >= min(a.height, b.height) / 2
    }

    /// Converts a Cocoa screen frame to Quartz (origin at the top-left of the primary screen, y grows downwards),
    /// which is the space window positions are reported in.
    static func quartzFrame(cocoaFrame: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: cocoaFrame.minX, y: primaryScreenHeight - cocoaFrame.maxY, width: cocoaFrame.width, height: cocoaFrame.height)
    }

    /// Scales a window into a tile that represents its whole screen. Both frames are in Quartz; the result is in
    /// the tile's flipped coordinates (origin top-left), clipped to the tile. Returns nil when nothing is visible.
    static func windowRect(windowFrame: CGRect, screenFrame: CGRect, tileSize: CGSize) -> CGRect? {
        guard screenFrame.width > 0, screenFrame.height > 0 else { return nil }
        let scaleX = tileSize.width / screenFrame.width
        let scaleY = tileSize.height / screenFrame.height
        let scaled = CGRect(x: (windowFrame.minX - screenFrame.minX) * scaleX,
                            y: (windowFrame.minY - screenFrame.minY) * scaleY,
                            width: windowFrame.width * scaleX,
                            height: windowFrame.height * scaleY)
        let clipped = scaled.intersection(CGRect(origin: .zero, size: tileSize))
        return clipped.isNull || clipped.isEmpty ? nil : clipped
    }
}
