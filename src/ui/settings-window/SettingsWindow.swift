import Cocoa

private final class SettingsFlippedView: NSView {
    override var isFlipped: Bool { true }
}

class SettingsWindow: NSWindow {
    static let contentWidth = CGFloat(620)
    static let width = contentWidth
    private static let sidebarWidth = CGFloat(210)
    private static let contentHorizontalPadding = CGFloat(20)
    private static let contentTopPadding = CGFloat(0)
    private static let topSectionTitlePadding = CGFloat(20)
    private static let contentBottomPadding = CGFloat(20)
    private static let sectionTitleSpacing = CGFloat(-5)
    private static let sectionInterSectionSpacing = CGFloat(15)
    private static let sectionBottomSpacing = CGFloat(30) - sectionInterSectionSpacing
    private static let sectionScrollTopPadding = CGFloat(20)
    private static let sectionSelectionTriggerRatioWhenScrollingDown = CGFloat(0.4)
    private static let sectionSelectionTriggerRatioWhenScrollingUp = CGFloat(0.6)
    private static let sectionSelectionDirectionDeltaThreshold = CGFloat(0.25)
    private static let minWindowHeight = CGFloat(500)
    private static let sidebarTopInset = CGFloat(40)
    private static let sidebarHorizontalPadding = CGFloat(10)
    static let roundedHighlightLayerName = "settingsSearchRoundedHighlight"
    static let roundedHighlightCornerRadius = CGFloat(4)
    static let roundedHighlightHorizontalInset = CGFloat(1.5)
    static let roundedHighlightVerticalInset = CGFloat(0.8)
    static let roundedHighlightLeadingTrim = CGFloat(1.4)
    static let controlHighlightLayerName = "settingsSearchControlHighlight"
    static let segmentedControlHighlightLayerName = "settingsSearchSegmentHighlight"
    static let controlHighlightInset = CGFloat(1)
    static let controlHighlightMinCornerRadius = CGFloat(4)
    static let controlHighlightMaxCornerRadius = CGFloat(9)
    static var shared: SettingsWindow!

    static var canBecomeKey_ = true
    override var canBecomeKey: Bool { Self.canBecomeKey_ }

    private let splitViewController = NSSplitViewController()
    private let sidebarContainer = NSView()
    private let contentContainer = NSView()
    private let searchField = NSSearchField(frame: .zero)
    private let sidebarScrollView = NSScrollView()
    let sidebarTableView = NSTableView()
    private let rightScrollView = NSScrollView()
    private let sectionsDocumentView = SettingsFlippedView(frame: .zero)
    private let sectionsStack = NSStackView()
    var sections = [SettingsSection]()
    private var visibleSections = [SettingsSection]()
    /// Story 16: without a query only the selected page is shown; with one, every match is stacked.
    private var isSearching = false
    /// The page the user picked; leaving the search returns to it.
    var chosenSectionId: String?
    var sidebarRows = [SettingsSidebarRow]()
    var selectedSectionId: String?
    private var liveResizeOriginX: CGFloat?
    private var sectionSelectionTriggerRatio = SettingsWindow.sectionSelectionTriggerRatioWhenScrollingDown
    private var lastContentScrollY: CGFloat?
    private var ignoresContentScrollSelection = false

    convenience init() {
        let windowWidth = Self.sidebarWidth + Self.contentWidth + 3 * Self.contentHorizontalPadding
        self.init(contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: 605),
                  styleMask: [.titled, .miniaturizable, .closable, .resizable, .fullSizeContentView],
                  backing: .buffered, defer: false)
        minSize = NSSize(width: windowWidth, height: Self.minWindowHeight)
        maxSize = NSSize(width: windowWidth, height: CGFloat.greatestFiniteMagnitude)
        setupWindow()
        setupView()
        setFrameAutosaveName("SettingsWindow")
        // a frame saved by a build whose content was wider must not keep the window stretched
        if frame.width != windowWidth { setFrame(NSRect(x: frame.minX, y: frame.minY, width: windowWidth, height: frame.height), display: false) }
        Self.shared = self
    }

    private func setupWindow() {
        delegate = self
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        let toolbar = NSToolbar(identifier: "SettingsToolbar")
        toolbar.showsBaselineSeparator = false
        self.toolbar = toolbar
        if #available(macOS 11.0, *) {
            toolbarStyle = .unified
            titlebarSeparatorStyle = .none
        }
    }

    private func setupView() {
        setupSplitView()
        setupSidebar()
        setupContentPane()
        let definitions = sectionDefinitions()
        assert(definitions.allSatisfy { SettingsSidebarLayout.allSectionIds.contains($0.id) },
               "a section id is missing from SettingsSidebarLayout.allSectionIds and would silently fall back to .actions")
        SettingsSidebarLayout.order(definitions.map(\.id)).compactMap { id in definitions.first { $0.id == id } }.forEach { addSection($0) }
        refreshControlsFromSettings()
        // Builds only the page that opens (the chosen one, or the first) synchronously, so first
        // show is not gated on all 15 pages. The rest build one per main-queue turn afterwards.
        applySearch("")
        scheduleIdleSectionBuilds()
    }

    /// Builds `section`'s content view if it has not been built yet — the page is about to become
    /// visible (selection, search, reveal) or its turn in the idle chain has come up. Shortcut
    /// recorders built here run their normal change callback for UI sync only: this flag keeps
    /// them from re-registering shortcuts that are already registered at launch.
    private func buildSectionIfNeeded(_ section: SettingsSection) {
        guard !section.isBuilt else { return }
        ControlsTab.isBuildingUI = true
        section.ensureBuilt()
        ControlsTab.isBuildingUI = false
    }

    private func buildAllSectionsIfNeeded() {
        sections.forEach { buildSectionIfNeeded($0) }
    }

    /// Builds every page that is still unbuilt after first show, one per main-queue turn, so a
    /// long idle chain never blocks user interaction with the (already visible) selected page.
    private func scheduleIdleSectionBuilds() {
        var remaining = sections.filter { !$0.isBuilt }
        func buildNext() {
            guard !remaining.isEmpty else { return }
            let next = remaining.removeFirst()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.buildSectionIfNeeded(next)
                buildNext()
            }
        }
        buildNext()
    }

    private func setupSplitView() {
        let sidebarVC = NSViewController()
        sidebarVC.view = sidebarContainer
        let contentVC = NSViewController()
        contentVC.view = contentContainer
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarVC)
        sidebarItem.canCollapse = false
        sidebarItem.minimumThickness = Self.sidebarWidth
        sidebarItem.maximumThickness = Self.sidebarWidth
        let contentItem = NSSplitViewItem(viewController: contentVC)
        splitViewController.splitViewItems = [sidebarItem, contentItem]
        splitViewController.splitView.dividerStyle = .thin
        contentViewController = splitViewController
    }

    private func setupSidebar() {
        setupSearchField(sidebarContainer)
        setupSidebarTable(sidebarContainer)
    }

    private func setupContentPane() {
        rightScrollView.drawsBackground = false
        rightScrollView.hasVerticalScroller = true
        rightScrollView.hasHorizontalScroller = false
        rightScrollView.scrollerStyle = .overlay
        if #available(macOS 11.0, *) {
            rightScrollView.automaticallyAdjustsContentInsets = false
        }
        rightScrollView.contentInsets = NSEdgeInsetsZero
        rightScrollView.scrollerInsets = NSEdgeInsetsZero
        rightScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(rightScrollView)
        sectionsDocumentView.translatesAutoresizingMaskIntoConstraints = false
        rightScrollView.documentView = sectionsDocumentView
        sectionsStack.orientation = .vertical
        sectionsStack.spacing = 0
        sectionsStack.alignment = .leading
        sectionsStack.translatesAutoresizingMaskIntoConstraints = false
        sectionsDocumentView.addSubview(sectionsStack)
        installContentScrollObserver()
        NSLayoutConstraint.activate([
            rightScrollView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            rightScrollView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            rightScrollView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            rightScrollView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
            sectionsStack.topAnchor.constraint(equalTo: sectionsDocumentView.topAnchor, constant: Self.contentTopPadding),
            sectionsStack.leadingAnchor.constraint(equalTo: sectionsDocumentView.leadingAnchor, constant: Self.contentHorizontalPadding),
            sectionsStack.trailingAnchor.constraint(equalTo: sectionsDocumentView.trailingAnchor, constant: -Self.contentHorizontalPadding),
            sectionsStack.bottomAnchor.constraint(equalTo: sectionsDocumentView.bottomAnchor, constant: -Self.contentBottomPadding),
            sectionsDocumentView.widthAnchor.constraint(equalTo: rightScrollView.contentView.widthAnchor),
        ])
    }

    private func installContentScrollObserver() {
        rightScrollView.contentView.postsBoundsChangedNotifications = true
        lastContentScrollY = rightScrollView.contentView.bounds.minY
        NotificationCenter.default.addObserver(self, selector: #selector(contentViewBoundsDidChange), name: NSView.boundsDidChangeNotification, object: rightScrollView.contentView)
    }

    private func setupSearchField(_ parent: NSView) {
        searchField.delegate = self
        // the clear button sends the action but no text-change notification
        searchField.target = self
        searchField.action = #selector(searchFieldActionFired)
        searchField.placeholderString = NSLocalizedString("Search", comment: "")
        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = true
        searchField.bezelStyle = .roundedBezel
        if #available(macOS 13.0, *) {
            searchField.controlSize = .large
        }
        searchField.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(searchField)
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: parent.topAnchor, constant: Self.sidebarTopInset),
            searchField.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: Self.sidebarHorizontalPadding),
            searchField.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -Self.sidebarHorizontalPadding),
        ])
    }

    private func setupSidebarTable(_ parent: NSView) {
        sidebarScrollView.drawsBackground = false
        sidebarScrollView.hasVerticalScroller = true
        sidebarScrollView.hasHorizontalScroller = false
        sidebarScrollView.scrollerStyle = .overlay
        sidebarTableView.headerView = nil
        sidebarTableView.intercellSpacing = NSSize(width: 0, height: 2)
        sidebarTableView.rowHeight = 30
        sidebarTableView.style = .sourceList // selectionHighlightStyle = .sourceList was deprecated in 12.0
        sidebarTableView.backgroundColor = .clear
        sidebarTableView.focusRingType = .none
        sidebarTableView.usesAlternatingRowBackgroundColors = false
        if #available(macOS 11.0, *) {
            sidebarTableView.style = .sourceList
        }
        sidebarTableView.delegate = self
        sidebarTableView.dataSource = self
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "SettingsSidebarColumn"))
        column.resizingMask = .autoresizingMask
        sidebarTableView.addTableColumn(column)
        sidebarScrollView.documentView = sidebarTableView
        sidebarScrollView.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(sidebarScrollView)
        NSLayoutConstraint.activate([
            sidebarScrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 12),
            sidebarScrollView.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: Self.sidebarHorizontalPadding - 2),
            sidebarScrollView.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -(Self.sidebarHorizontalPadding - 2)),
            sidebarScrollView.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -10),
        ])
    }

    private func sectionDefinitions() -> [SettingsSectionDefinition] {
        [
            // Order is presentation only: nothing persists a section index, and `id` is the in-memory
            // selection, so this list can be rearranged freely. It does decide one behaviour — the window
            // opens on the first entry when nothing is selected yet.
            //
            // The grouping runs from what applies to the whole machine down to what applies to single apps:
            // General, then the three system-wide modules, then the window switcher, then per-app lists.
            SettingsSectionDefinition(id: "general", title: NSLocalizedString("General", comment: ""), description: NSLocalizedString("Manage startup, menu bar, language, and settings files.", comment: ""), imageName: "general", systemSymbolName: "gearshape", builder: { GeneralTab.initTab() }),
            SettingsSectionDefinition(id: "hyperkey", title: NSLocalizedString("Hyperkey", comment: ""), description: NSLocalizedString("Use Caps Lock as a system-wide combination of modifier keys.", comment: ""), imageName: "controls", systemSymbolName: "capslock", builder: { HyperkeyTab.initTab() }),
            SettingsSectionDefinition(id: "pointer-scroll", title: NSLocalizedString("Pointer & Scroll", comment: ""), description: NSLocalizedString("Adjust pointer acceleration and speed, and the direction of the mouse wheel.", comment: ""), imageName: "controls", systemSymbolName: "cursorarrow", builder: { PointerScrollTab.initTab() }),
            SettingsSectionDefinition(id: "spaces", title: NSLocalizedString("Spaces", comment: ""), description: NSLocalizedString("Show, activate, and move between macOS Spaces.", comment: ""), imageName: "controls", systemSymbolName: "square.grid.2x2", builder: { SpacesTab.initTab() }),
            // not named in the requested order; placed next to Spaces because both arrange windows across
            // the system rather than inside the switcher
            SettingsSectionDefinition(id: "window-layouts", title: NSLocalizedString("Window Layouts", comment: ""), description: NSLocalizedString("Assign shortcuts for arranging the focused window.", comment: ""), imageName: "controls", systemSymbolName: "rectangle.split.3x1", builder: { WindowLayoutsTab.initTab() }),
            // `leaderSlotAction*` is written by a custom popup with no `identifier` (see LeaderTab), so
            // the view-tree collector cannot find it; declared here instead. Resetting it does not by
            // itself rebuild the cached lookup trie those actions run through, hence `afterReset`.
            SettingsSectionDefinition(id: "leader", title: NSLocalizedString("Leader", comment: ""), description: NSLocalizedString("Run actions from nested key sequences after a trigger key.", comment: ""), imageName: "controls", systemSymbolName: "keyboard", builder: { LeaderTab.initTab() },
                extraResettableKeys: { PreferencesResetLogic.keysWithPrefix("leaderSlotAction", in: Preferences.defaultValues) },
                afterReset: { LeaderController.rebuildTrie() }),
            // `flickRing{Up,Right,Down,Left}` are written by custom popups with no `identifier` (see
            // FlickRingTab); declared here instead. Unlike Leader's trie, bindings are read live from
            // `CachedUserDefaults` on every flick, so no extra rebuild step is needed after a reset.
            SettingsSectionDefinition(id: "flick-ring", title: NSLocalizedString("FlickRing", comment: ""), description: NSLocalizedString("Open a four-direction action ring on a mouse button.", comment: ""), imageName: "controls", systemSymbolName: "circle.grid.cross", builder: { FlickRingTab.initTab() },
                extraResettableKeys: { PreferencesResetLogic.keysWithPrefix("flickRing", in: Preferences.defaultValues) }),
            // No reset button: a profile is user-created content (name, apps, layout, space), not a
            // setting, so "Reset to Defaults" must not delete it.
            SettingsSectionDefinition(id: ProfilesTab.sectionId, title: NSLocalizedString("Profiles", comment: ""), description: NSLocalizedString("Group apps into a profile, optionally bound to a space, and filter the switcher to it.", comment: ""), imageName: "controls", systemSymbolName: "square.stack.3d.up", builder: { ProfilesTab.initTab() },
                hidesResetButton: true),
            SettingsSectionDefinition(id: "appearance", title: NSLocalizedString("Cmd-Tab", comment: ""), description: NSLocalizedString("Choose how the window switcher looks and where it appears.", comment: ""), imageName: "appearance", systemSymbolName: "paintpalette", builder: { AppearanceTab.initTab() }),
            // Only the selected shortcut slot's editor is normally built (see
            // `ControlsTab.ensureShortcutEditorBuilt`); `extraResettableKeys` builds every slot's editor
            // first so "Reset to Defaults" can find and restore controls in slots nobody has opened.
            SettingsSectionDefinition(id: "controls", title: NSLocalizedString("Cmd-Tab Controls", comment: ""), description: NSLocalizedString("Set how you open and navigate the window switcher.", comment: ""), imageName: "controls", systemSymbolName: "command", builder: { ControlsTab.initTab() },
                extraResettableKeys: { ControlsTab.ensureAllShortcutEditorsBuilt(); return [] }),
            SettingsSectionDefinition(id: ShortcutOverviewTab.sectionId, title: NSLocalizedString("Shortcuts", comment: ""), description: NSLocalizedString("Every action shortcut and its conflicts. Switcher triggers stay in Cmd-Tab Controls, the Leader key in Leader, and the FlickRing button in FlickRing.", comment: ""), imageName: "controls", systemSymbolName: "keyboard", builder: { ShortcutOverviewTab.initTab() }),
            SettingsSectionDefinition(id: SystemActionsTab.sectionId, title: NSLocalizedString("System Actions", comment: ""), description: NSLocalizedString("Configure Auto-Quit, Cat Mode, and the function key mode.", comment: ""), imageName: "controls", systemSymbolName: "switch.2", builder: { SystemActionsTab.initTab() }),
            SettingsSectionDefinition(id: "keep-awake", title: NSLocalizedString("Keep Awake", comment: ""), description: NSLocalizedString("Keep the Mac awake for a while, with battery protection.", comment: ""), imageName: "controls", systemSymbolName: "cup.and.saucer", builder: { KeepAwakeTab.initTab() }),
            // No reset button: the launch-app/open-URL entries are user-created content, not settings.
            SettingsSectionDefinition(id: AppsUrlsTab.sectionId, title: NSLocalizedString("Apps & URLs", comment: ""), description: NSLocalizedString("Assign shortcuts to launch apps or open URLs.", comment: ""), imageName: "controls", systemSymbolName: "app.badge", builder: { AppsUrlsTab.initTab() },
                hidesResetButton: true),
            // `exceptions` is stored as one JSON blob (see `Preferences.exceptions`), not through
            // individually identified controls, so `SettingsResetKeysCollector` cannot find it; declared
            // here instead. `afterReset` is implicit: `builder` already rebuilds the page from the
            // restored default list.
            SettingsSectionDefinition(id: ExceptionsTab.sectionId, title: NSLocalizedString("Exceptions", comment: ""), description: NSLocalizedString("Choose apps whose windows should not appear in the switcher.", comment: ""), imageName: "exceptions", systemSymbolName: "hand.raised", builder: { ExceptionsTab.initTab() },
                extraResettableKeys: { ["exceptions"] }),
        ]
    }

    private func sidebarImage(_ definition: SettingsSectionDefinition) -> NSImage {
        if #available(macOS 11.0, *), let image = NSImage(systemSymbolName: definition.systemSymbolName, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
            let configured = image.withSymbolConfiguration(config) ?? image
            configured.isTemplate = true
            return configured
        }
        let image = NSImage.initCopy(definition.imageName)
        image.isTemplate = true
        return image
    }

    private func addSection(_ definition: SettingsSectionDefinition) {
        let pathLabel = TableGroupView.makeText("")
        pathLabel.font = NSFont.systemFont(ofSize: 11)
        pathLabel.textColor = .secondaryLabelColor
        pathLabel.lineBreakMode = .byTruncatingTail
        pathLabel.isHidden = true
        let sectionTitle = TableGroupView.makeText(definition.title, bold: true)
        sectionTitle.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        sectionTitle.lineBreakMode = .byWordWrapping
        sectionTitle.maximumNumberOfLines = 0
        let sectionDescription = TableGroupView.makeText(definition.description)
        sectionDescription.textColor = .secondaryLabelColor
        sectionDescription.lineBreakMode = .byWordWrapping
        sectionDescription.maximumNumberOfLines = 0
        // without a wrapping width a long description asks for its one-line width and stretches the window
        sectionDescription.preferredMaxLayoutWidth = Self.contentWidth
        // Reset button, in the title row, vertically centered on the title and right-aligned to the
        // content tables; hidden on pages with nothing to reset. Kept in the tree unconditionally so
        // the constraint chain below the header stays the same whether or not the button is shown.
        // Sentence case, matching the codebase's more recent settings button titles (e.g. "Show preview")
        // over the older Title Case ones ("Open System Settings").
        let resetButton = NSButton(title: NSLocalizedString("Reset to defaults", comment: ""), target: nil, action: nil)
        resetButton.bezelStyle = .inline
        resetButton.controlSize = .small
        resetButton.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        // [title ... flexible space ... button]: the title's low horizontal hugging (the NSTextField
        // default) lets it stretch to fill the row, while the button keeps its intrinsic size and sits
        // flush with the trailing edge — the same edge the content tables end at.
        let titleRow = NSStackView(views: [sectionTitle, resetButton])
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 8
        // The content view is wrapped in a stable slot so a rebuilt page can be swapped in without
        // recreating the constraints that anchor it to the header above and the spacer below.
        let contentSlot = NSView()
        let container = NSView()
        let spacer = NSView()
        container.addSubview(pathLabel)
        container.addSubview(titleRow)
        container.addSubview(sectionDescription)
        container.addSubview(contentSlot)
        container.addSubview(spacer)
        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        titleRow.translatesAutoresizingMaskIntoConstraints = false
        sectionDescription.translatesAutoresizingMaskIntoConstraints = false
        contentSlot.translatesAutoresizingMaskIntoConstraints = false
        spacer.translatesAutoresizingMaskIntoConstraints = false
        container.translatesAutoresizingMaskIntoConstraints = false
        // Content is built on demand (see `buildContent` below); `contentSlot` starts empty.
        // `titleTopConstraint` now anchors the breadcrumb (the topmost element); the isFirst/spacing
        // logic in updateVisibleSectionsSpacing is unaffected since it only changes this constant.
        let titleTopConstraint = pathLabel.topAnchor.constraint(equalTo: container.topAnchor)
        let pathLabelHeightConstraint = pathLabel.heightAnchor.constraint(equalToConstant: 0)
        let pathToTitleSpacingConstraint = titleRow.topAnchor.constraint(equalTo: pathLabel.bottomAnchor, constant: 0)
        let interSectionSpacingConstraint = spacer.topAnchor.constraint(equalTo: contentSlot.bottomAnchor, constant: Self.sectionInterSectionSpacing)
        let spacerHeightConstraint = spacer.heightAnchor.constraint(equalToConstant: Self.sectionBottomSpacing)
        NSLayoutConstraint.activate([
            titleTopConstraint,
            pathLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            pathLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            pathLabelHeightConstraint,
            pathToTitleSpacingConstraint,
            titleRow.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleRow.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            sectionDescription.topAnchor.constraint(equalTo: titleRow.bottomAnchor, constant: 4),
            sectionDescription.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            sectionDescription.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            // Matches `TableGroupSetView.spacing`, the same rhythm used between table groups within a
            // page, so the header-to-first-table gap reads as part of the same vertical grid.
            contentSlot.topAnchor.constraint(equalTo: sectionDescription.bottomAnchor, constant: TableGroupSetView.spacing),
            contentSlot.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            contentSlot.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
            interSectionSpacingConstraint,
            spacer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            spacer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            spacer.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            spacerHeightConstraint,
        ])
        sectionsStack.addArrangedSubview(container)
        container.widthAnchor.constraint(equalTo: sectionsStack.widthAnchor).isActive = true
        // Tracks whichever view is currently pinned into `contentSlot`, so both a reset (which swaps it
        // for a freshly built one) and an in-place mutation (e.g. AppearanceTab's CustomizeStyle
        // disclosure) walk/index the view that is actually on screen, not the one from construction time.
        // `nil` until the page is built (see `buildContent` below).
        var currentContentView: NSView?
        let knownDefaultKeys = Set(Preferences.defaultValues.keys)
        let resettableKeysProvider: () -> [String] = {
            guard let currentContentView else { return [] }
            // `extraResettableKeys` runs first: for "controls" it also builds every shortcut slot's
            // editor (normally only the selected slot is built) as a side effect, so the collector
            // below can find their controls too.
            let extraKeys = definition.extraResettableKeys()
            var seen = Set<String>()
            return (extraKeys + SettingsResetKeysCollector.collectResettableKeys(in: currentContentView))
                .filter { knownDefaultKeys.contains($0) && seen.insert($0).inserted }
        }
        var section: SettingsSection!
        func refreshResetButtonVisibility() {
            let showsResetButton = section.canResetToDefaults
            // Hiding an arranged subview collapses its space in the stack view, so no extra
            // height/spacing bookkeeping is needed here (unlike the old below-description layout).
            resetButton.isHidden = !showsResetButton
            if showsResetButton {
                resetButton.target = self
                resetButton.action = #selector(resetSectionToDefaults(_:))
                // Identifies the section by id rather than a positional index: this closure also runs
                // from `reindexSearchContent()` long after `addSection` finishes, by which point
                // `sections.count` is the total section count, not this section's index.
                resetButton.identifier = NSUserInterfaceItemIdentifier(definition.id)
            }
        }
        let rebuildContent: ([String]) -> Void = { [weak self] changedKeys in
            // "Reset to Defaults" is only reachable once the page (and its resettable keys) exist.
            guard let self, let section, section.isBuilt else { return }
            contentSlot.subviews.forEach { $0.removeFromSuperview() }
            let newContentView = definition.builder()
            currentContentView = newContentView
            self.pinContentView(newContentView, into: contentSlot)
            let (searchableStrings, highlightTargets) = self.collectSearchContent(sectionTitle, sectionDescription, newContentView)
            section.updateSearchContent(searchableStrings, highlightTargets)
            if !changedKeys.isEmpty {
                let changedKeysSet = Set(changedKeys)
                SettingsResetKeysCollector.collectResettableControls(in: newContentView)
                    .filter { changedKeysSet.contains($0.identifier?.rawValue ?? "") }
                    // Replays the same target/action `LabelAndControl.setupControl` wired up for an
                    // interactive edit, so a control's `extraAction` (releasing pointer ownership,
                    // clearing `AppleLanguages`, rebuilding a cached trie, …) applies to the default
                    // value too, instead of the reset only clearing the preference underneath it.
                    .forEach { $0.sendAction($0.action, to: $0.target) }
            }
            definition.afterReset?()
            refreshResetButtonVisibility()
        }
        let reindex: () -> Void = { [weak self] in
            guard let self, let section, let currentContentView else { return }
            let (searchableStrings, highlightTargets) = self.collectSearchContent(sectionTitle, sectionDescription, currentContentView)
            section.updateSearchContent(searchableStrings, highlightTargets)
        }
        let buildContent: () -> Void = { [weak self] in
            guard let self, let section else { return }
            let newContentView = definition.builder()
            currentContentView = newContentView
            self.pinContentView(newContentView, into: contentSlot)
            let (searchableStrings, highlightTargets) = self.collectSearchContent(sectionTitle, sectionDescription, newContentView)
            section.updateSearchContent(searchableStrings, highlightTargets)
            refreshResetButtonVisibility()
        }
        section = SettingsSection(definition.id,
                                      definition.title,
                                      sidebarImage(definition),
                                      container,
                                      sectionTitle,
                                      [],
                                      [],
                                      interSectionSpacingConstraint,
                                      spacerHeightConstraint,
                                      titleTopConstraint,
                                      pathLabel,
                                      pathLabelHeightConstraint,
                                      pathToTitleSpacingConstraint,
                                      resettableKeysProvider,
                                      definition.hidesResetButton,
                                      rebuildContent,
                                      reindex,
                                      buildContent,
                                      refreshResetButtonVisibility)
        refreshResetButtonVisibility()
        sections.append(section)
    }

    /// Re-indexes settings search for a section from its current content, without rebuilding it. For a
    /// page that mutates its own content in place outside of a reset (e.g. AppearanceTab's CustomizeStyle
    /// disclosure), so search does not keep pointing at the discarded content view.
    func reindexSection(_ id: String) {
        sections.first { $0.id == id }?.reindexSearchContent()
    }

    /// Pins a page's content view to fill `slot` on all four edges, matching the layout the
    /// content view previously had directly inside the section container.
    private func pinContentView(_ view: NSView, into slot: NSView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        slot.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: slot.topAnchor),
            view.leadingAnchor.constraint(equalTo: slot.leadingAnchor),
            view.trailingAnchor.constraint(lessThanOrEqualTo: slot.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: slot.bottomAnchor),
        ])
    }

    @objc private func resetSectionToDefaults(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue, let section = sections.first(where: { $0.id == id }) else { return }
        let alert = NSAlert()
        alert.messageText = String(format: NSLocalizedString("Reset %@ to defaults?", comment: ""), section.title)
        alert.informativeText = NSLocalizedString("This page's settings return to their default values.", comment: "")
        alert.addButton(withTitle: NSLocalizedString("Reset", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        alert.alertStyle = .warning
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        section.resetToDefaults()
    }

    private func updateVisibleSectionsSpacing(_ displayed: [SettingsSection]) {
        displayed.enumerated().forEach { index, section in
            let isFirst = index == 0
            let isLast = index == displayed.count - 1
            section.titleTopConstraint.constant = isFirst ? Self.topSectionTitlePadding : 0
            section.interSectionSpacingConstraint.constant = isLast ? 0 : Self.sectionInterSectionSpacing
            section.bottomSpacingConstraint.constant = isLast ? 0 : Self.sectionBottomSpacing
        }
    }

    /// Called every time the window is shown, not only when it is built.
    ///
    /// `setupView` runs once and the window is then reused, so a state that changed while it was closed —
    /// another tool taking the pointer value, a crash recovery relinquishing it — was never re-read.
    /// Measured on 2026-08-14: after System Settings took the value, closing and reopening the window still
    /// showed `Managed by AltTab+`. The backlog recorded this as fixed in 2026-08-03; it was not, because
    /// building and showing are not the same moment.
    func refreshControlsFromSettings() {
        GeneralTab.refreshControlsFromPreferences()
        PointerScrollTab.refreshControlsFromPreferences()
    }

    @objc private func contentViewBoundsDidChange(_ notification: Notification) {
        let currentY = rightScrollView.contentView.bounds.minY
        guard isSearching, !ignoresContentScrollSelection else {
            lastContentScrollY = currentY
            return
        }
        updateSectionSelectionTriggerRatio(currentY)
        guard let section = sectionAtCurrentScrollPosition(sectionSelectionTriggerRatio) else { return }
        guard selectedSectionId != section.id else { return }
        selectSection(section, scroll: false)
    }

    private func updateSectionSelectionTriggerRatio(_ currentY: CGFloat) {
        defer { lastContentScrollY = currentY }
        guard let lastContentScrollY else { return }
        let deltaY = currentY - lastContentScrollY
        if deltaY > Self.sectionSelectionDirectionDeltaThreshold {
            sectionSelectionTriggerRatio = Self.sectionSelectionTriggerRatioWhenScrollingDown
            return
        }
        if deltaY < -Self.sectionSelectionDirectionDeltaThreshold {
            sectionSelectionTriggerRatio = Self.sectionSelectionTriggerRatioWhenScrollingUp
        }
    }

    private func sectionAtCurrentScrollPosition(_ triggerRatio: CGFloat) -> SettingsSection? {
        guard !visibleSections.isEmpty else { return nil }
        sectionsDocumentView.layoutSubtreeIfNeeded()
        let visibleBounds = rightScrollView.contentView.bounds
        let sectionTopY = visibleBounds.minY + visibleBounds.height * triggerRatio
        return visibleSections.last {
            $0.anchor.convert($0.anchor.bounds, to: sectionsDocumentView).minY <= sectionTopY
        } ?? visibleSections[0]
    }

    func selectSection(_ section: SettingsSection, scroll: Bool, selectInSidebar: Bool = true) {
        buildSectionIfNeeded(section)
        selectedSectionId = section.id
        if selectInSidebar, let row = sidebarRows.firstIndex(of: .section(section.id)), sidebarTableView.selectedRow != row {
            sidebarTableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
        if !isSearching { showDisplayedSections() }
        if section.id == ShortcutOverviewTab.sectionId { ShortcutOverviewTab.pageShown() }
        guard scroll else { return }
        isSearching ? scrollToSection(section) : scrollToTop()
    }

    private func showDisplayedSections() {
        let ids = SettingsSidebarLayout.displayed(all: sections.map(\.id), matching: visibleSections.map(\.id),
                                                  selected: selectedSectionId, searching: isSearching)
        sections.forEach { $0.container.isHidden = !ids.contains($0.id) }
        updateVisibleSectionsSpacing(sections.filter { ids.contains($0.id) })
    }

    private func scrollToTop() {
        ignoresContentScrollSelection = true
        rightScrollView.contentView.scroll(to: .zero)
        rightScrollView.reflectScrolledClipView(rightScrollView.contentView)
        lastContentScrollY = 0
        ignoresContentScrollSelection = false
    }

    private func scrollToSection(_ section: SettingsSection) {
        guard isVisible else { return }
        sectionsDocumentView.layoutSubtreeIfNeeded()
        let anchorFrame = section.anchor.convert(section.anchor.bounds, to: sectionsDocumentView)
        let targetY = max(anchorFrame.minY - Self.sectionScrollTopPadding, 0)
        ignoresContentScrollSelection = true
        rightScrollView.contentView.scroll(to: NSPoint(x: 0, y: targetY))
        rightScrollView.reflectScrolledClipView(rightScrollView.contentView)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lastContentScrollY = self.rightScrollView.contentView.bounds.minY
            self.ignoresContentScrollSelection = false
        }
    }

    func isShowingSection(_ id: String) -> Bool {
        isVisible && !isSearching && selectedSectionId == id
    }

    /// Opens a page from elsewhere in the window and briefly marks the row with this title.
    func reveal(sectionId: String, rowTitle: String) {
        searchField.stringValue = ""
        chosenSectionId = sectionId
        applySearch("")
        guard let section = sections.first(where: { $0.id == sectionId }),
              let label = Self.findLabel(rowTitle, in: section.container) else { return }
        scrollToVisibleAndFlash(label)
    }

    /// Jumps to the first highlighted match on Return without touching the search query, so the
    /// user can keep refining it. See `control(_:textView:doCommandBy:)` for why this isn't driven
    /// by the search field's action.
    private func jumpToFirstMatch() {
        guard isSearching, let firstSection = visibleSections.first,
              let target = Self.firstHighlightedView(in: firstSection.container) else { return }
        scrollToVisibleAndFlash(target)
    }

    private func scrollToVisibleAndFlash(_ view: NSView) {
        sectionsDocumentView.layoutSubtreeIfNeeded()
        view.scrollToVisible(view.bounds.insetBy(dx: 0, dy: -80))
        Self.flash(view)
    }

    private func searchPath(for section: SettingsSection) -> String {
        let groupTitle = Self.groupTitle(SettingsSidebarLayout.group(of: section.id))
        let sectionTitles = Self.matchedDisclosureSectionTitles(in: section.container)
        return SettingsSidebarLayout.searchPath(groupTitle: groupTitle, pageTitle: section.title, sectionTitles: sectionTitles)
    }

    /// Titles of the `DisclosureSection`s (in document order) that contain a highlighted match,
    /// found by looking for the highlight sublayers `SettingsSearchHighlighting` applies to a
    /// matching view. Relies on `highlightMatches` having already run for this query.
    private static func matchedDisclosureSectionTitles(in view: NSView) -> [String] {
        var titles = [String]()
        func walk(_ view: NSView) {
            if let disclosure = view as? DisclosureSection, containsHighlight(disclosure) {
                titles.append(disclosure.title)
            }
            view.subviews.forEach(walk)
        }
        walk(view)
        return titles
    }

    private static func firstHighlightedView(in view: NSView) -> NSView? {
        if isHighlighted(view) { return view }
        for subview in view.subviews {
            if let found = firstHighlightedView(in: subview) { return found }
        }
        return nil
    }

    private static func isHighlighted(_ view: NSView) -> Bool {
        guard let sublayers = view.layer?.sublayers else { return false }
        let highlightLayerNames: Set<String> = [roundedHighlightLayerName, controlHighlightLayerName, segmentedControlHighlightLayerName]
        return sublayers.contains { highlightLayerNames.contains($0.name ?? "") }
    }

    private static func containsHighlight(_ view: NSView) -> Bool {
        isHighlighted(view) || view.subviews.contains { containsHighlight($0) }
    }

    private static func findLabel(_ title: String, in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField, field.stringValue == title { return field }
        for subview in view.subviews {
            if let found = findLabel(title, in: subview) { return found }
        }
        return nil
    }

    private static func flash(_ view: NSView) {
        view.wantsLayer = true
        view.layer?.cornerRadius = 4
        view.layer?.backgroundColor = NSColor.findHighlightColor.withAlphaComponent(0.6).cgColor
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.4
                view.layer?.backgroundColor = NSColor.clear.cgColor
            }
        }
    }

    @objc private func searchFieldActionFired() {
        applySearch(searchField.stringValue)
    }

    private func applySearch(_ query: String) {
        Popover.shared.updateSearchContext(query) { query, text in
            SettingsSearch.match(query, in: text)?.ranges ?? []
        }
        isSearching = !SettingsSearch.isQueryEmpty(query)
        // The search "waits": build every page still missing before matching against it, so a
        // query typed right after the window opens still finds pages the idle chain has not
        // reached yet.
        if isSearching { buildAllSectionsIfNeeded() }
        visibleSections = sections.filter { !isSearching || $0.matches(query) }
        let matchingIds = Set(visibleSections.map(\.id))
        sections.forEach { section in
            guard isSearching, matchingIds.contains(section.id) else {
                section.clearHighlights()
                return section.updateSearchPath(nil)
            }
            section.highlightMatches(query)
            section.updateSearchPath(searchPath(for: section))
        }
        sidebarRows = SettingsSidebarLayout.rows(visibleSections.map(\.id))
        sidebarTableView.reloadData()
        let preferred = isSearching ? selectedSectionId : (chosenSectionId ?? selectedSectionId)
        selectedSectionId = SettingsSidebarLayout.selection(visible: visibleSections.map(\.id), preferred: preferred)
        showDisplayedSections()
        guard let selectedSectionId, let section = sections.first(where: { $0.id == selectedSectionId }) else {
            sidebarTableView.deselectAll(nil)
            return
        }
        selectSection(section, scroll: true)
    }

    func chooseSectionFromSidebar(_ sectionId: String) {
        chosenSectionId = SettingsSidebarLayout.chosenSection(current: chosenSectionId, selected: sectionId, searching: isSearching)
    }

    override func close() {
        hideAppIfLastWindowIsClosed()
        super.close()
    }
}

extension SettingsWindow: NSWindowDelegate {
    func windowWillStartLiveResize(_ notification: Notification) {
        liveResizeOriginX = frame.origin.x
    }

    func windowDidResize(_ notification: Notification) {
        guard inLiveResize, let liveResizeOriginX else { return }
        guard abs(frame.origin.x - liveResizeOriginX) > 0 else { return }
        setFrameOrigin(NSPoint(x: liveResizeOriginX, y: frame.origin.y))
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        liveResizeOriginX = nil
    }
}

extension SettingsWindow: NSSearchFieldDelegate {
    func controlTextDidChange(_ notification: Notification) {
        applySearch(searchField.stringValue)
        // The cell was created at frame .zero (before Auto Layout resolved its real bounds) and its
        // cancel button only appears once the field is non-empty, shrinking the text area on the first
        // keystroke. Without an explicit redraw here, AppKit doesn't always invalidate the placeholder
        // glyphs it drew at the old (wider) bounds, leaving a leftover fragment behind the typed text.
        searchField.needsDisplay = true
    }

    // `sendsSearchStringImmediately` fires the field's action on every keystroke, so Return can't be
    // told apart from typing there; `doCommandBySelector` gets the actual key command instead.
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard commandSelector == #selector(NSResponder.insertNewline(_:)) else { return false }
        jumpToFirstMatch()
        return true
    }
}
