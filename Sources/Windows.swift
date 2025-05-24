import AppKit
import Collections

@available(macOS 15.4.0, *)
actor WindowConductor {
    var winds: LinkedSet<Wind>
    var history: LinkedSet<Wind>

    var winObservers = [pid_t: AXObserver]()
    var launchAppObserver: (any NSObjectProtocol)? = nil
    var activateAppObserver: (any NSObjectProtocol)? = nil
    var terminateAppObserver: (any NSObjectProtocol)? = nil

    var walk = false
    var walkHistoryIndex = 2
    var suppressUpdate = 0

    var preCatalog = [(Wind, CGPoint, CGSize)]()

    init() async {
        self.winds = []
        for wind in Wind.all() { self.winds.append(wind) }
        guard self.winds.count != 0 else { fatalError() }
        guard let top = Wind.top() else { fatalError() }
        self.history = [top]

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

    isolated deinit {
        if let observer = self.launchAppObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(
                observer,
                name: NSWorkspace.didLaunchApplicationNotification,
                object: nil
            )
        }
        if let observer = self.activateAppObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(
                observer,
                name: NSWorkspace.didActivateApplicationNotification,
                object: nil
            )
        }
        if let observer = self.terminateAppObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(
                observer,
                name: NSWorkspace.didTerminateApplicationNotification,
                object: nil
            )
        }
    }

    func updateHistory() {
        if self.suppressUpdate != 0 {
            self.suppressUpdate -= 1
            return
        }

        guard let wind = Wind.top() else { return }
        // print("[!] topwin \(wind.pid, default:"nopid")")

        self.history.append(wind)
        self.winds.append(wind, deleteExisting: false)
    }

    func pruneWinds() {
        self.winds.delete(where: { !$0.alive() })
        self.history.delete(where: { !$0.alive() })

        // let app = AXUIElementCreateApplication(pid)
        // var value: CFTypeRef?
        // AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
        // let windows = value as! CFArray
        // print("found \(CFArrayGetCount(windows)) terminals")
        // let window = unsafeBitCast(CFArrayGetValueAtIndex(windows, 0), to: AXUIElement.self)

        // var newPos = CGPoint(x: 100, y: 100)
        // let pos = AXValueCreate(.cgPoint, &newPos)!
        // AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pos)

        // var newSize = CGSize(width: 100, height: 100)
        // let size = AXValueCreate(.cgPoint, &newSize)!
        // AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, size)
    }

    func doRaise(index: Int) {
        self.pruneWinds()
        guard 0 <= index && index < self.winds.count else { return }
        raise(win: self.winds[index])
    }

    func doPrev() {
        self.pruneWinds()
        guard self.history.count >= 2 else { return }
        if self.walk {
            self.raise(win: self.history[self.history.count - 1])
        } else {
            self.raise(win: self.history[self.history.count - 2])
        }
    }

    func doWalk() {
        self.pruneWinds()
        guard self.history.count > 2 else { return }

        // print("[doRaiseWalk] \(self.walkHistoryIndex)")
        // for w in self.history {
        //     print("- \(w.title!)")
        // }

        self.raise(
            win: self.history[self.history.count - 1 - self.walkHistoryIndex],
            updateHistory: false
        )
        self.walk = true
        self.walkHistoryIndex = max(2, (self.walkHistoryIndex + 1) % self.history.count)
    }

    func doCatalog() async {
        self.pruneWinds()
        guard self.winds.count != 0 else { return }

        if self.preCatalog.isEmpty {
            var i = 1
            for wind in self.winds {
                self.preCatalog.append((wind, wind.position(), wind.size()))
                wind.position(set: CGPoint(x: (i - 1) * 75, y: i * 50))
                wind.size(set: CGSize(width: 1000, height: 1000))

                try! await Task.sleep(nanoseconds: 20_000_000)
                self.raise(win: wind, updateHistory: false)

                i += 1
            }
        } else {
            for (wind, position, size) in self.preCatalog {
                wind.position(set: position)
                wind.size(set: size)
            }

            self.preCatalog.removeAll(keepingCapacity: true)
            self.raise(win: self.history.last!, updateHistory: false)
        }
    }

    private func raise(win wind: Wind, updateHistory: Bool = true) {
        if updateHistory {
            if self.walk, let top = Wind.top() {
                self.walk = false
                self.history.append(top)
            }
            self.history.append(wind)
        }

        let app = NSRunningApplication(processIdentifier: wind.pid())!
        if app != NSWorkspace.shared.frontmostApplication {
            self.suppressUpdate += 2
            app.activate()
            wind.raise()
        } else {
            if !wind.focused() {
                self.suppressUpdate += 1
                wind.raise()
            }
        }
    }

    func observe(pid: pid_t) {
        let observer = {
            var o: AXObserver?
            AXObserverCreate(
                pid,
                { ob, win, noti, ptr in
                    // print("--> \(win)")
                    let wc = Unmanaged<WindowConductor>.fromOpaque(ptr!).takeUnretainedValue()
                    Task { await wc.updateHistory() }
                },
                &o
            )
            return o!
        }()

        AXObserverAddNotification(
            observer,
            AXUIElementCreateApplication(pid),
            kAXMainWindowChangedNotification as CFString,
            Unmanaged.passUnretained(self).toOpaque()
        )
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)

        self.winObservers[pid] = observer
    }

    func onLaunchApp(noti: Notification) {
        let app = noti.userInfo![NSWorkspace.applicationUserInfoKey] as! NSRunningApplication
        guard app.activationPolicy == .regular else { return }

        // print("[*] \(app.localizedName!)")
        self.observe(pid: app.processIdentifier)
    }

    func onActivateApp(noti: Notification) {
        // print(
        //     "=> \((noti.userInfo![NSWorkspace.applicationUserInfoKey] as! NSRunningApplication).processIdentifier)"
        // )
        Task { self.updateHistory() }
    }

    func onTerminateApp(noti: Notification) {
        let app = noti.userInfo![NSWorkspace.applicationUserInfoKey] as! NSRunningApplication
        guard app.activationPolicy == .regular else { return }

        // print("[ ] \(app.localizedName!)")
        let observer = self.winObservers[app.processIdentifier]!
        AXObserverRemoveNotification(
            observer,
            AXUIElementCreateApplication(app.processIdentifier),
            kAXFocusedWindowChangedNotification as CFString
        )
        CFRunLoopRemoveSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )
        self.winObservers.removeValue(forKey: app.processIdentifier)
    }

}

struct Wind: Equatable, Hashable {
    let inner: AXUIElement

    init(_ inner: AXUIElement) {
        self.inner = inner
    }

    func keys() -> [String] {
        var value: CFArray?
        AXUIElementCopyAttributeNames(self.inner, &value)
        return value as! [String]
    }

    func alive() -> Bool {
        var value: CFTypeRef?
        return .success
            == AXUIElementCopyAttributeValue(self.inner, kAXMainAttribute as CFString, &value)
    }

    func focused() -> Bool {
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(self.inner, kAXFocusedAttribute as CFString, &value)
                == .success
        else { preconditionFailure() }
        return (value as! Bool)
    }

    func title() -> String {
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(self.inner, kAXTitleAttribute as CFString, &value)
                == .success
        else { preconditionFailure() }
        return value as! String
    }

    func pid() -> pid_t {
        var pid: pid_t = 0
        guard AXUIElementGetPid(self.inner, &pid) == .success else { preconditionFailure() }
        return pid
    }

    func position() -> CGPoint {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(self.inner, kAXPositionAttribute as CFString, &value)

        var point = CGPoint()
        AXValueGetValue(value as! AXValue, .cgPoint, &point)
        return point
    }

    func position(set newValue: CGPoint) {
        var point = newValue
        let value = AXValueCreate(.cgPoint, &point)!
        AXUIElementSetAttributeValue(self.inner, kAXPositionAttribute as CFString, value)
    }

    func size() -> CGSize {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(self.inner, kAXSizeAttribute as CFString, &value)

        var size = CGSize()
        AXValueGetValue(value as! AXValue, .cgSize, &size)
        return size
    }

    func size(set newValue: CGSize) {
        var size = newValue
        let value = AXValueCreate(.cgSize, &size)!
        AXUIElementSetAttributeValue(self.inner, kAXSizeAttribute as CFString, value)
    }

    func raise() {
        guard AXUIElementPerformAction(self.inner, kAXRaiseAction as CFString) == .success else {
            preconditionFailure()
        }
    }

    static func top() -> Wind? {
        guard let nsApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = nsApp.processIdentifier
        let app = AXUIElementCreateApplication(pid)

        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value)
        guard value != nil else { return nil }
        return Wind(value as! AXUIElement)
    }

    static func all() -> [Wind] {
        var wins = [Wind]()
        let apps = NSWorkspace.shared.runningApplications
            .lazy
            .filter { $0.activationPolicy == .regular }
        for app in apps {
            let axApp = AXUIElementCreateApplication(app.processIdentifier)

            var value: CFTypeRef?
            AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value)
            guard let winds = value as? [AXUIElement] else { continue }

            if app.bundleIdentifier == "com.apple.finder" {
                // finder always has one dummy/hidden window
                // therefore skip it
                wins.append(contentsOf: winds[1...].lazy.map({ w in Wind.self(w) }))
            } else {
                wins.append(contentsOf: winds.lazy.map({ w in Wind.self(w) }))
            }
        }

        return wins
    }
}
