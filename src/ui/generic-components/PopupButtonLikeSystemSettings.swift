import Cocoa

class PopupButtonLikeSystemSettings: NSPopUpButton {
    convenience init() {
        self.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
//        showsBorderOnlyWhileMouseInside = true
//        isBordered = false
//        setButtonType(.switch)
//        let cell = cell! as! NSPopUpButtonCell
//        onAction = { _ in self.sizeToFit() }
//        cell.bezelStyle = .regularSquare
//        cell.arrowPosition = .arrowAtBottom
//        cell.imagePosition = .imageOverlaps
    }

    /// Measuring builds a throwaway popup and sizes it; since macOS 26 that runs through SwiftUI, and Auto
    /// Layout asks many times per pass. Measured 2026-09-18: about 0.65 s of the 3 s the Settings window took
    /// to open. The size depends only on the inputs in the key, so it is measured once per key.
    private var measuredSize: (key: String, size: NSSize)?

    override var intrinsicContentSize: NSSize {
        if let selectedItem {
            let currentCell = cell! as! NSPopUpButtonCell
            let image = selectedItem.image.map { "\(ObjectIdentifier($0))" } ?? "-"
            let key = "\(title)|\(image)|\(currentCell.bezelStyle.rawValue)|\(currentCell.arrowPosition.rawValue)|\(currentCell.imagePosition.rawValue)|\(showsBorderOnlyWhileMouseInside)"
            if let measuredSize, measuredSize.key == key {
                return measuredSize.size
            }
            let fakePopUpButton = NSPopUpButton()
            fakePopUpButton.addItem(withTitle: title)
            fakePopUpButton.item(at: 0)!.image = selectedItem.image
            let fakeCell = fakePopUpButton.cell! as! NSPopUpButtonCell
            fakeCell.bezelStyle = currentCell.bezelStyle
            fakeCell.arrowPosition = currentCell.arrowPosition
            fakeCell.imagePosition = currentCell.imagePosition
            fakePopUpButton.showsBorderOnlyWhileMouseInside = showsBorderOnlyWhileMouseInside
            fakePopUpButton.sizeToFit()
            let size = fakePopUpButton.intrinsicContentSize
            measuredSize = (key, size)
            return size
        } else {
            return super.intrinsicContentSize
        }
    }
}
