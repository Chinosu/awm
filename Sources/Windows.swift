import AppKit
import Collections

@available(macOS 15.4.0, *)
actor WindowConductor {
    var windows: [Wind]
    var history: [Wind]

    var winObservers = [pid_t: AXObserver]()
    var launchAppObserver: (any NSObjectProtocol)? = nil
    var activateAppObserver: (any NSObjectProtocol)? = nil
    var terminateAppObserver: (any NSObjectProtocol)? = nil

    init() async {
        self.windows = Wind.all()
        guard !self.windows.isEmpty else { fatalError() }
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

    func pushHistory() {
        guard let win = Wind.top() else { return }
        guard win == self.history.last! else { return }
        // self.history.append(win)
    }

    func dbg() {
        print("=== dbg ===")
        print("  \(self.windows.map(\.title))")
        print("  \(self.history.map(\.title))")
    }

    func updateWindows() {
        let new = Wind.all()
        self.windows.removeAll(where: { !new.contains($0) })
        for win in new {
            if !self.windows.contains(win) {
                self.windows.append(win)
            }
        }

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

    func raise(index: Int) {
        self.updateWindows()
        guard 0 <= index && index < self.windows.count else { return }
        push(win: self.windows[index])

        self.dbg()
    }

    func raisePrev() {
        self.updateWindows()
        if self.history.count > 1 {
            self.push(win: self.history[self.history.count - 2])
        }
    }

    private func push(win: Wind) {
        print("(pus) [\(win.title!)] [\(self.history.last!.title!)]")

        if win != self.history.last! {
            self.history.append(win)
        }

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
                    Task { await wc.pushHistory() }
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

        print("[*] \(app.localizedName!)")
        self.observe(pid: app.processIdentifier)
    }

    func onActivateApp(noti: Notification) {
        let app = noti.userInfo![NSWorkspace.applicationUserInfoKey] as! NSRunningApplication
        // guard app.activationPolicy == .regular else { return }

        // print("=> \(app.localizedName!)")
        self.pushHistory()
    }

    func onTerminateApp(noti: Notification) {
        let app = noti.userInfo![NSWorkspace.applicationUserInfoKey] as! NSRunningApplication
        guard app.activationPolicy == .regular else { return }

        print("[ ] \(app.localizedName!)")
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

struct Wind: Equatable {
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
