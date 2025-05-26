import AppKit

actor WindConductor {
    var winds: LinkedSet<Wind> = []
    var history: LinkedSet<Wind> = []

    var windObservers = [pid_t: AXObserver]()
    var launchAppObserver: (any NSObjectProtocol)?
    var activateAppObserver: (any NSObjectProtocol)?
    var terminateAppObserver: (any NSObjectProtocol)?

    var suppressUpdate = 0
    var catalog = [(Wind, CGPoint, CGSize)]()
    var inCatalog: Bool { !catalog.isEmpty }
    var catalogRearranged = false

    init() async {
        for wind in Wind.all() {
            self.winds.append(wind)
            self.history.append(wind)
        }
        guard self.winds.count != 0 else { fatalError() }
        if let top = await Wind.top() { self.history.append(top) } else { fatalError() }

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

        guard let top = await Wind.top(pid: pid) else { return }
        self.history.append(top)
        self.winds.append(top, deleteExisting: false)
        if self.inCatalog {
            await self.undoCatalog()
            await self.raise(win: top, updateHistory: false)
        }
    }

    func updateHistory(wind: Wind) async {
        if self.suppressUpdate != 0 {
            self.suppressUpdate -= 1
            return
        }

        self.history.append(wind)
        self.winds.append(wind, deleteExisting: false)
        if self.inCatalog {
            await self.undoCatalog()
            await self.raise(win: wind, updateHistory: false)
        }
    }

    func pruneWinds() {
        self.winds.delete(where: { !$0.alive() })
        self.history.delete(where: { !$0.alive() })
        self.catalog.removeAll(where: { !$0.0.alive() })
    }

    func doRaise(index: Int) async {
        self.pruneWinds()

        guard !self.inCatalog else {
            let order = if self.catalogRearranged { self.winds } else { self.history }
            guard 0 <= index && index < order.count else { return }
            await self.undoCatalog()
            await self.raise(win: order[index])
            return
        }

        guard 0 <= index && index < self.winds.count else { return }
        await self.raise(win: self.winds[index])
    }

    func doRearrange(index: Int) async {
        self.pruneWinds()

        guard !self.inCatalog else { return }  // todo upgrade
        guard !self.winds.isEmpty else { return }
        assert(self.winds.count == self.history.count)
        self.winds.insert(at: index, self.history.last!)
    }

    func doPrev() async {
        self.pruneWinds()

        guard !self.inCatalog else { return }

        guard self.history.count >= 2 else { return }
        await self.raise(win: self.history[self.history.count - 2])
    }

    func doHistCatalog() async {
        self.pruneWinds()
        guard self.winds.count != 0 else { return }
        print("[\(self.winds.count)]")

        guard !self.inCatalog else { return await self.undoCatalog() }

        assert(self.history.count == self.winds.count)

        for (i, wind) in self.history.enumerated() {
            self.catalog.append((wind, wind.position(), wind.size()))
            wind.position(set: CGPoint(x: i * 75, y: (1 + i) * 50))
            wind.size(set: CGSize(width: 1000, height: 1000))
        }
    }

    func doWindsCatalog() async {
        self.pruneWinds()
        guard self.winds.count != 0 else { return }
        guard !self.inCatalog else { return await self.undoCatalog() }

        assert(self.history.count == self.winds.count)

        for wind in self.history { self.catalog.append((wind, wind.position(), wind.size())) }
        for (i, wind) in self.winds.enumerated() {
            wind.position(set: CGPoint(x: i * 75, y: (1 + i) * 50))
            wind.size(set: CGSize(width: 1000, height: 1000))
        }
        for wind in self.winds {
            await self.raise(win: wind, updateHistory: false)
            try! await Task.sleep(for: .milliseconds(50))
        }

        self.catalogRearranged = true
    }

    func undoCatalog() async {
        guard self.inCatalog else { return }
        // guard let top = await Wind.top() else { return }

        for (wind, position, size) in self.catalog {
            wind.position(set: position)
            wind.size(set: size)
        }

        if self.catalogRearranged {
            for (wind, _, _) in catalog {
                await self.raise(win: wind, updateHistory: false)
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

    func raise(win wind: Wind, updateHistory: Bool = true) async {
        if updateHistory { self.history.append(wind) }

        let app = NSRunningApplication(processIdentifier: wind.pid())!
        if app != NSWorkspace.shared.frontmostApplication {
            self.suppressUpdate += 2
            app.activate()
            wind.raise()
        } else {
            if await Wind.top() != wind {
                self.suppressUpdate += 1
                wind.raise()
            }
        }
    }

    func observe(pid: pid_t) {
        var observer: AXObserver?
        check(
            AXObserverCreate(
                pid,
                { ob, elem, noti, ptr in
                    let wc = Unmanaged<WindConductor>.fromOpaque(ptr!).takeUnretainedValue()
                    nonisolated(unsafe) let e = elem
                    Task { @Sendable in await wc.onActivateWindow(elem: e) }
                }, &observer))
        check(
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
        check(self.windObservers.removeValue(forKey: app.processIdentifier))
    }

    func onActivateWindow(elem: AXUIElement) async {
        var pid = pid_t()
        AXUIElementGetPid(elem, &pid)
        if NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == "com.mitchellh.ghostty"
        {
            var value: AnyObject?
            check(
                AXUIElementCopyAttributeValue(
                    AXUIElementCreateApplication(pid), "AXChildrenInNavigationOrder" as CFString,
                    &value))
            let childs = value as! [AXUIElement]
            let index = childs.firstIndex(of: elem)!
            guard ghosttyLastIndex != index else {
                return
            }
            ghosttyLastIndex = index  // todo isolate ghosttyLastIndex
        }

        await self.updateHistory(wind: Wind(elem))
    }
}

nonisolated(unsafe) private var ghosttyLastIndex: Int = -1
