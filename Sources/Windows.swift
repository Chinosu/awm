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

    var walkHistoryIndex = 1
    var walkHistoryTimestamp = 0.0

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

    func doRaisePrev() {
        self.pruneWinds()
        guard self.history.count >= 2 else { return }
        self.raise(win: self.history[self.history.count - 2])
    }

    func doRaiseWalk() {
        self.pruneWinds()
        guard self.history.count > 1 else { return }

        print("[doRaiseWalk] \(self.walkHistoryIndex)")
        for w in self.history {
            print("- \(w.title!)")
        }

        // let now = Date().timeIntervalSince1970
        // if now > 1 + self.walkHistoryTimestamp {
        //     self.walkHistoryIndex = 1
        // }
        // self.walkHistoryTimestamp = now

        self.raise(
            win: self.history[self.history.count - 1 - self.walkHistoryIndex], updateHistory: false)
        self.walkHistoryIndex = max(1, (self.walkHistoryIndex + 1) % self.history.count)
    }

    private func raise(win: Wind, updateHistory: Bool = true) {
        NSRunningApplication(processIdentifier: win.pid!)!.activate()
        win.raise()!
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

    var focused: Bool? {
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(self.inner, kAXFocusedAttribute as CFString, &value)
                == .success
        else { return nil }
        return value as? Bool
    }

    var title: String? {
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(self.inner, kAXTitleAttribute as CFString, &value)
                == .success
        else { return nil }
        return value as? String
    }

    var pid: pid_t? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(self.inner, &pid) == .success else { return nil }
        return pid
    }

    func raise() -> ()? {
        guard AXUIElementPerformAction(self.inner, kAXRaiseAction as CFString) == .success else {
            return nil
        }
        return ()
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
        var uniqPids = Set<pid_t>()
        var wins = [Wind]()

        let apps = NSWorkspace.shared.runningApplications
            .lazy
            .filter { $0.activationPolicy == .regular }
        for app in apps {
            guard !uniqPids.contains(app.processIdentifier) else { continue }
            uniqPids.insert(app.processIdentifier)
            let axApp = AXUIElementCreateApplication(app.processIdentifier)

            guard
                let appWins = {
                    var value: CFTypeRef?
                    AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value)
                    return value as? [AXUIElement]
                }()
            else { continue }
            if app.bundleIdentifier == "com.apple.finder" {
                // finder always has one dummy/hidden window
                // therefore skip it
                wins.append(contentsOf: appWins[1...].lazy.map({ w in Wind.self(w) }))
            } else {
                wins.append(contentsOf: appWins.lazy.map({ w in Wind.self(w) }))
            }
        }

        return wins
    }
}
