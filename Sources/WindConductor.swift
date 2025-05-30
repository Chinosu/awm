import AppKit

actor WindConductor {
    var tabs: [AXUIElement] = []
    var free: [Int] = []
    // var winds: [[Int]] = []

    var order: [Int] = []
    var recent: [Int] = []

    var windObservers = [pid_t: AXObserver]()
    var launchAppObserver: (any NSObjectProtocol)?
    var activateAppObserver: (any NSObjectProtocol)?
    var terminateAppObserver: (any NSObjectProtocol)?

    var suppressUpdate = 0
    var catalog = [(Int, CGPoint, CGSize)]()
    var inCatalog: Bool { !catalog.isEmpty }
    var catalogRearranged = false

    init() async {
        for wind in try! AXUIElement.allTabs() {
            let i = self.ini(wind: wind)
            self.order.reappend(i)
            self.recent.reappend(i)
        }
        guard self.order.count != 0 else { fatalError() }
        guard let top = try! await AXUIElement.topTab() else { fatalError() }
        let i = self.ini(wind: top)
        self.recent.reappend(i)

        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular else { continue }
            self.observe(pid: app.processIdentifier)
        }
        self.launchAppObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main,
            using: self.onLaunchApp
        )
        self.activateAppObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main,
            using: self.onActivateApp
        )
        self.terminateAppObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main,
            using: self.onTerminateApp
        )
    }

    // // compiler >= 6.2
    // isolated deinit {
    //     if let observer = self.launchAppObserver {
    //         NSWorkspace.shared.notificationCenter.removeObserver(
    //             observer,
    //             name: NSWorkspace.didLaunchApplicationNotification,
    //             object: nil
    //         )
    //     }
    //     if let observer = self.activateAppObserver {
    //         NSWorkspace.shared.notificationCenter.removeObserver(
    //             observer,
    //             name: NSWorkspace.didActivateApplicationNotification,
    //             object: nil
    //         )
    //     }
    //     if let observer = self.terminateAppObserver {
    //         NSWorkspace.shared.notificationCenter.removeObserver(
    //             observer,
    //             name: NSWorkspace.didTerminateApplicationNotification,
    //             object: nil
    //         )
    //     }
    //     for obser in self.windObservers.values {
    //         CFRunLoopRemoveSource(
    //             CFRunLoopGetMain(), AXObserverGetRunLoopSource(obser), .defaultMode)
    //         assert(
    //             !CFRunLoopContainsSource(
    //                 CFRunLoopGetMain(), AXObserverGetRunLoopSource(obser), .defaultMode))
    //     }
    // }

    // func updateHistory() async {
    //     if self.suppressUpdate != 0 {
    //         self.suppressUpdate -= 1
    //         return
    //     }

    //     guard let top = await Wind.top() else { return }
    //     self.history.append(top)
    //     self.winds.append(top, deleteExisting: false)
    //     if self.inCatalog {
    //         await self.undoCatalog()
    //         await self.raise(win: top, updateHistory: false)
    //     }
    // }

    func updateHistory(pid: pid_t) async {
        if self.suppressUpdate != 0 {
            self.suppressUpdate -= 1
            return
        }

        guard let top = try! await AXUIElement.topTab(of: pid) else { return }
        let i = self.ini(wind: top)

        self.recent.reappend(i)
        self.order.uppend(i)

        if self.inCatalog {
            await self.undoCatalog()
            await self.raise(wind: i, updateHistory: false)
        }
    }

    func updateHistory(wind: AXUIElement) async {
        if self.suppressUpdate != 0 {
            self.suppressUpdate -= 1
            return
        }

        let i = self.ini(wind: wind)
        self.recent.reappend(i)
        self.order.uppend(i)

        if self.inCatalog {
            await self.undoCatalog()
            await self.raise(wind: i, updateHistory: false)
        }
    }

    func pruneWinds() {
        var gone = Set<Int>()
        for (i, wind) in self.tabs.enumerated() {
            if self.free.contains(i) { continue }
            if !wind.alive() {
                gone.insert(i)
                self.del(wind: i)
            }
        }

        self.order.removeAll(where: { gone.contains($0) })
        self.recent.removeAll(where: { gone.contains($0) })
        assert(self.order.count == self.recent.count, "\(self.order) vs \(self.recent)")
        self.catalog.removeAll(where: { gone.contains($0.0) })
    }

    func doRaise(index: Int) async {
        self.pruneWinds()

        guard !self.inCatalog else {
            let order = if self.catalogRearranged { self.order } else { self.recent }
            guard 0 <= index && index < order.count else { return }
            await self.undoCatalog()
            await self.raise(wind: order[index])
            return
        }

        guard 0 <= index && index < self.order.count else { return }
        await self.raise(wind: self.order[index])
    }

    func doRearrange(index: Int) async {
        self.pruneWinds()

        guard !self.inCatalog else { return }  // todo upgrade
        guard !self.order.isEmpty else { return }
        assert(self.order.count == self.recent.count)
        self.order.reinsert(self.recent.last!, at: index)
    }

    func doPrev() async {
        self.pruneWinds()

        guard !self.inCatalog else { return }

        guard self.recent.count >= 2 else { return }
        await self.raise(wind: self.recent[self.recent.count - 2])
    }

    func doHistCatalog() async {
        self.pruneWinds()
        guard self.order.count != 0 else { return }
        guard !self.inCatalog else { return await self.undoCatalog() }

        assert(self.recent.count == self.order.count)

        for (i, w) in self.recent.enumerated() {
            self.catalog.append((w, try! self.tabs[w].position(), try! self.tabs[w].size()))
            try! self.tabs[w].position(set: CGPoint(x: i * 75, y: (1 + i) * 50))
            try! self.tabs[w].size(set: CGSize(width: 1000, height: 1000))
        }
    }

    func doWindsCatalog() async {
        self.pruneWinds()
        guard self.order.count != 0 else { return }
        guard !self.inCatalog else { return await self.undoCatalog() }

        assert(self.recent.count == self.order.count)

        for w in self.recent {
            self.catalog.append((w, try! self.tabs[w].position(), try! self.tabs[w].size()))
        }
        for (i, w) in self.order.enumerated() {
            try! self.tabs[w].position(set: CGPoint(x: i * 75, y: (1 + i) * 50))
            try! self.tabs[w].size(set: CGSize(width: 1000, height: 1000))
        }
        for w in self.order {
            await self.raise(wind: w, updateHistory: false)
            try! await Task.sleep(for: .milliseconds(50))
        }

        self.catalogRearranged = true
    }

    func undoCatalog() async {
        guard self.inCatalog else { return }
        // guard let top = await Wind.top() else { return }

        for (w, position, size) in self.catalog {
            try! self.tabs[w].position(set: position)
            try! self.tabs[w].size(set: size)
        }

        if self.catalogRearranged {
            for (w, _, _) in catalog {
                await self.raise(wind: w, updateHistory: false)
                try! await Task.sleep(for: .milliseconds(50))
            }
        }

        // might remove
        // let operand = if self.catalogRearranged { self.winds.last } else { self.history.last }
        // assert(operand == top)
        // if top != operand { await self.raise(win: top) }

        self.catalog.removeAll(keepingCapacity: true)
        self.catalogRearranged = false
    }

    func raise(wind w: Int, updateHistory: Bool = true) async {
        if updateHistory { self.recent.reappend(w) }

        let app = NSRunningApplication(processIdentifier: try! self.tabs[w].pid())!
        if app != NSWorkspace.shared.frontmostApplication {
            self.suppressUpdate += 2
            app.activate()
            try! self.tabs[w].raise()
        } else {
            if try! await AXUIElement.topTab() != self.tabs[w] {
                self.suppressUpdate += 1
                try! self.tabs[w].raise()
            }
        }
    }

    func observe(pid: pid_t) {
        var observer: AXObserver?
        switch NSRunningApplication(processIdentifier: pid)!.bundleIdentifier {
        // case "com.apple.Terminal":
        // case "com.apple.Safari":
        case "com.mitchellh.ghostty":
            try! ax(
                AXObserverCreate(
                    pid,
                    { ob, elem, noti, ptr in
                        let wc = Unmanaged<WindConductor>.fromOpaque(ptr!).takeUnretainedValue()
                        nonisolated(unsafe) let e = elem
                        Task { @Sendable in await wc.onActivateGhosttyWindow(elem: e) }
                    }, &observer))
        default:
            try! ax(
                AXObserverCreate(
                    pid,
                    { ob, elem, noti, ptr in
                        let wc = Unmanaged<WindConductor>.fromOpaque(ptr!).takeUnretainedValue()
                        nonisolated(unsafe) let e = elem
                        Task { @Sendable in await wc.onActivateWindow(elem: e) }
                    }, &observer))
        }

        try! ax(
            AXObserverAddNotification(
                observer!, AXUIElementCreateApplication(pid),
                kAXMainWindowChangedNotification as CFString,
                Unmanaged.passUnretained(self).toOpaque()))
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer!), .defaultMode)

        self.windObservers[pid] = observer
    }

    func onLaunchApp(noti: Notification) {
        let app = noti.userInfo![NSWorkspace.applicationUserInfoKey] as! NSRunningApplication
        guard app.activationPolicy == .regular else { return }
        self.observe(pid: app.processIdentifier)
    }

    func onActivateApp(noti: Notification) {
        let app = noti.userInfo![NSWorkspace.applicationUserInfoKey] as! NSRunningApplication
        Task { await self.updateHistory(pid: app.processIdentifier) }
    }

    func onTerminateApp(noti: Notification) {
        let app = noti.userInfo![NSWorkspace.applicationUserInfoKey] as! NSRunningApplication
        guard app.activationPolicy == .regular else { return }
        let observer = self.windObservers[app.processIdentifier]!
        CFRunLoopRemoveSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )
        assert(
            !CFRunLoopContainsSource(
                CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode))
        if nil == self.windObservers.removeValue(forKey: app.processIdentifier) {
            assertionFailure()
        }
    }

    func onActivateWindow(elem: AXUIElement) async {
        await self.updateHistory(wind: elem)
    }

    var elems = [AXUIElement]()

    func crashout(elem: AXUIElement) async {
        // var pid = pid_t()
        // if AXUIElementGetPid(elem, &pid) != .success { preconditionFailure() }
        // let app = AXUIElementCreateApplication(pid)

        /*
        Strategy
        --------
        - store previous `AXMain` to track last window
        - use count of `AXChildren` (5 vs 6) to determine if the new window is actually a new window
        */

        let elemChilds = elem[kAXChildrenAttribute] as! [AXUIElement]
        switch elemChilds.count {
        case 5:
            // sole window
            break
        case 6:
            // not sole window
            break
        default: preconditionFailure()
        }
    }

    var toolbars = Set<AXUIElement>()
    var containers = Set<AXUIElement>()
    var contents = Set<AXUIElement>()
    var seen = Set<AXUIElement>()
    func onActivateGhosttyWindow(elem: AXUIElement) async {
        var pid = pid_t()
        AXUIElementGetPid(elem, &pid)

        let app = AXUIElementCreateApplication(pid)

        print("\u{1b}[2J\u{1b}[H", terminator: "")

        let menubar = app["AXMenuBar"] as! AXUIElement
        elems.append(menubar)
        print("menubar: (\(elems.firstIndex(of: menubar)!))")

        // ordered by creation (menubar always first)
        let orderedchildren = app["AXChildrenInNavigationOrder"] as! [AXUIElement]
        elems.append(contentsOf: orderedchildren)
        print("orderedChildren: ", terminator: "")
        for w in orderedchildren { print("(\(elems.firstIndex(of: w)!)) ", terminator: "") }
        print()

        // ordered by recency (menubar always last)
        let children = app["AXChildren"] as! [AXUIElement]
        elems.append(contentsOf: children)
        print("children: ", terminator: "")
        for w in children { print("(\(elems.firstIndex(of: w)!)) ", terminator: "") }
        print()

        // ordered by recency
        let windows = app["AXWindows"] as! [AXUIElement]
        elems.append(contentsOf: windows)
        print("windows: ", terminator: "")
        for w in windows { print("(\(elems.firstIndex(of: w)!)) ", terminator: "") }
        print()

        let mainwindow = app["AXMainWindow"] as! AXUIElement
        elems.append(mainwindow)
        print("mainwindow: (\(elems.firstIndex(of: mainwindow)!))")

        let focusedwindow = app["AXFocusedWindow"] as! AXUIElement
        elems.append(focusedwindow)
        print("focusedwindow: (\(elems.firstIndex(of: focusedwindow)!))")

        let focused = elem["AXFocused"] as! Int
        print("focused: \(focused)")

        let main = elem["AXMain"] as! Int
        print("main: \(main)")

        let AXChildren = elem["AXChildren"] as! [AXUIElement]
        print(">> AXChildren \(AXChildren)")
        let AXSections = elem["AXSections"]
        print(">> AXSections \(AXSections, default: "nil")")
        let AXActivationPoint = elem["AXActivationPoint"]
        print(">> AXActivationPoint \(AXActivationPoint, default: "nil")")
        let AXParent = elem["AXParent"]
        print(">> AXParent \(AXParent, default: "nil")")
        let AXFullScreenButton = elem["AXFullScreenButton"]
        print(">> AXFullScreenButton \(AXFullScreenButton, default: "nil")")
        let AXCloseButton = elem["AXCloseButton"]
        print(">> AXCloseButton \(AXCloseButton, default: "nil")")
        let AXMinimizeButton = elem["AXMinimizeButton"]
        print(">> AXMinimizeButton \(AXMinimizeButton, default: "nil")")

        assert(mainwindow == focusedwindow)
        assert(focusedwindow == elem)

        let nthRecent = windows.firstIndex(of: elem)!
        var old: AXUIElement!
        var n = 0
        for i in stride(from: self.recent.count - 1, through: 0, by: -1) {
            var i_pid = pid_t()
            try! ax(AXUIElementGetPid(self.tabs[self.recent[i]], &i_pid))
            if i_pid != pid { continue }
            if n != nthRecent {
                n += 1
                continue
            }

            old = self.tabs[self.recent[i]]
            self.tabs[self.recent[i]] = elem
        }

        for i in 0..<self.order.count {
            if self.tabs[self.order[i]] == old {
                self.tabs[self.order[i]] = elem
                break
            }
        }

        await self.updateHistory(wind: elem)

        do {
            for w in windows {
                seen.insert(w)
            }

            seen = seen.filter({ $0["AXMain"] != nil })
            for w in seen {
                print("- \(w) \(w["AXMain"] as Any)")
            }

        }
    }

    func ini(wind: AXUIElement) -> Int {
        if let i = self.tabs.firstIndex(of: wind) { return i }

        if let i = self.free.popLast() {
            // assert(self.winds[i].isEmpty)
            self.tabs[i] = wind
            return i
        } else {
            self.tabs.append(wind)
            return self.tabs.count - 1
        }
    }

    func del(wind: Int) {
        self.free.append(wind)
    }
}

extension Array where Element: Equatable {
    mutating func reappend(_ newElement: Element) {
        precondition(self.firstIndex(of: newElement) == self.lastIndex(of: newElement))
        if let index = self.firstIndex(of: newElement) { self.remove(at: index) }
        self.append(newElement)
    }

    mutating func uppend(_ newElement: Element) {
        precondition(self.firstIndex(of: newElement) == self.lastIndex(of: newElement))
        if self.firstIndex(of: newElement) == nil {
            self.append(newElement)
        }
    }

    mutating func reinsert(_ newElement: Element, at: Int) {
        precondition(self.firstIndex(of: newElement) == self.lastIndex(of: newElement))
        if let index = self.firstIndex(of: newElement) { self.remove(at: index) }
        self.insert(newElement, at: at)
    }
}

nonisolated(unsafe) private var ghosttyLastIndex: Int = -1
