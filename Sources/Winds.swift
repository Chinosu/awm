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

    func updateHistory() async {
        if self.suppressUpdate != 0 {
            self.suppressUpdate -= 1
            return
        }

        guard let top = await Wind.top() else { return }
        self.history.append(top)
        self.winds.append(top, deleteExisting: false)
    }

    func updateHistory(pid: pid_t) async {
        if self.suppressUpdate != 0 {
            self.suppressUpdate -= 1
            return
        }

        guard let top = await Wind.top(pid: pid) else { return }
        self.history.append(top)
        self.winds.append(top, deleteExisting: false)
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

    func doPrev() async {
        self.pruneWinds()

        guard !self.inCatalog else { return }

        guard self.history.count >= 2 else { return }
        await self.raise(win: self.history[self.history.count - 2])
    }

    func doHistCatalog() async {
        self.pruneWinds()
        guard self.winds.count != 0 else { return }
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
            try! await Task.sleep(nanoseconds: 15_000_000)
        }

        self.catalogRearranged = true
    }

    func undoCatalog() async {
        guard self.inCatalog else { return }
        guard let top = await Wind.top() else { return }

        for (wind, position, size) in self.catalog {
            wind.position(set: position)
            wind.size(set: size)
        }

        if self.catalogRearranged {
            for (wind, _, _) in catalog {
                await self.raise(win: wind, updateHistory: false)
                try! await Task.sleep(for: .milliseconds(15))
            }
        }

        // might remove
        let operand = if self.catalogRearranged { self.winds.last } else { self.history.last }
        if top != operand { await self.raise(win: top) }

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
                { ob, element, noti, ptr in
                    let wc = Unmanaged<WindConductor>.fromOpaque(ptr!).takeUnretainedValue()
                    Task { await wc.updateHistory() }
                },
                &observer
            ))
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
}

struct Wind: Equatable, Hashable {
    let inner: AXUIElement

    init(_ inner: AXUIElement) {
        self.inner = inner
    }

    func keys() -> [String] {
        var value: CFArray?
        check(AXUIElementCopyAttributeNames(self.inner, &value))
        return value as! [String]
    }

    func alive() -> Bool {
        var value: AnyObject?
        // specifically ask for `AXTitle` as Finder's "hidden"
        // window does *not* have a title, so this will
        // conveniently ignore that specific window
        let result = AXUIElementCopyAttributeValue(
            self.inner, kAXTitleAttribute as CFString, &value)
        return result == .success
    }

    func focused() -> Bool {
        var value: AnyObject?
        check(AXUIElementCopyAttributeValue(self.inner, kAXFocusedAttribute as CFString, &value))
        return value as! Bool
    }

    func title() -> String {
        var value: AnyObject?
        check(AXUIElementCopyAttributeValue(self.inner, kAXTitleAttribute as CFString, &value))
        return value as! String
    }

    func pid() -> pid_t {
        var pid: pid_t = 0
        check(AXUIElementGetPid(self.inner, &pid))
        return pid
    }

    func position() -> CGPoint {
        var value: AnyObject?
        check(AXUIElementCopyAttributeValue(self.inner, kAXPositionAttribute as CFString, &value))
        var point = CGPoint()
        check(AXValueGetValue(value as! AXValue, .cgPoint, &point))
        return point
    }

    func position(set newValue: CGPoint) {
        var point = newValue
        let value = AXValueCreate(.cgPoint, &point)
        check(AXUIElementSetAttributeValue(self.inner, kAXPositionAttribute as CFString, value!))
    }

    func size() -> CGSize {
        var value: AnyObject?
        check(AXUIElementCopyAttributeValue(self.inner, kAXSizeAttribute as CFString, &value))
        var size = CGSize()
        check(AXValueGetValue(value as! AXValue, .cgSize, &size))
        return size
    }

    func size(set newValue: CGSize) {
        var size = newValue
        let value = AXValueCreate(.cgSize, &size)
        check(AXUIElementSetAttributeValue(self.inner, kAXSizeAttribute as CFString, value!))
    }

    func raise() {
        check(AXUIElementPerformAction(self.inner, kAXRaiseAction as CFString))
    }

    static func top() async -> Wind? {
        return await Self.top(pid: NSWorkspace.shared.frontmostApplication!.processIdentifier)
    }

    static func top(pid: pid_t) async -> Wind? {
        var value: AnyObject?
        while AXUIElementCopyAttributeValue(
            AXUIElementCreateApplication(pid), kAXMainWindowAttribute as CFString, &value)
            == .cannotComplete
        {
            // app might still be starting up; wait
            try! await Task.sleep(for: .milliseconds(100))
        }
        if value == nil { return nil }
        return Wind(value as! AXUIElement)
    }

    static func all() -> [Wind] {
        var wins = [Wind]()
        let apps = NSWorkspace.shared.runningApplications
            .lazy
            .filter { $0.activationPolicy == .regular }
        for app in apps {
            let axApp = AXUIElementCreateApplication(app.processIdentifier)

            var value: AnyObject?
            check(AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value))
            let winds = value as! [AXUIElement]

            if app.bundleIdentifier == "com.apple.finder" {
                // finder always has one dummy/hidden window
                // therefore skip it
                wins.append(contentsOf: winds[1...].lazy.map({ w in Wind(w) }))
            } else {
                wins.append(contentsOf: winds.lazy.map({ w in Wind(w) }))
            }
        }

        return wins
    }
}

@inlinable func check(_ value: AXError) {
    assert(value == .success, "\(value.rawValue)")
}

@inlinable func check(_ value: Bool) {
    assert(value)
}

@inlinable func check(_ value: Any?) {
    assert(value != nil)
}
