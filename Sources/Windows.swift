import AppKit

actor WindowConductor {
    var wins: [AXUIElement]

    // bug: curr needs to be pruned of closed windows
    var curr: AXUIElement
    var prev: AXUIElement

    var winObservers = [pid_t: AXObserver]()
    var launchAppObserver: (any NSObjectProtocol)? = nil
    var activateAppObserver: (any NSObjectProtocol)? = nil
    var terminateAppObserver: (any NSObjectProtocol)? = nil

    init() async {
        self.wins = Window.getAll()
        guard self.wins.count > 0 else { fatalError() }
        guard let top = Window.getTop() else { fatalError() }
        self.curr = top
        self.prev = top

        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular else { continue }
            observe(pid: app.processIdentifier)
        }
        self.launchAppObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main,
            using: onLaunchApp
        )
        self.activateAppObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main,
            using: onActivateApp
        )
        self.terminateAppObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main,
            using: onTerminateApp
        )
    }

    // // Swift 6.2
    // nonisolated deinit {
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
    // }

    func windowChange() {
        guard let win = Window.getTop() else { return }
        guard win != self.curr else { return }
        self.prev = self.curr
        self.curr = win
    }

    func updateWindows() {
        let newWins = Window.getAll()
        self.wins.removeAll { win in !newWins.contains(win) }
        for win in newWins {
            if !self.wins.contains(win) {
                self.wins.append(win)
            }
        }

        if let win = Window.getTop() {
            if win != curr {
                self.prev = self.curr
                self.curr = win
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
        guard 0 <= index && index < self.wins.count else { return }
        self.push(win: self.wins[index])
    }

    func raisePrev() {
        self.updateWindows()
        self.push(win: self.prev)
    }

    private func push(win: AXUIElement) {
        if win != self.curr {
            self.prev = self.curr
            self.curr = win
        }

        var pid: pid_t = 0
        AXUIElementGetPid(win, &pid)
        let app = NSRunningApplication(processIdentifier: pid)!
        app.activate()
        AXUIElementPerformAction(win, kAXRaiseAction as CFString)
    }

    func observe(pid: pid_t) {
        let observer = {
            var o: AXObserver?
            AXObserverCreate(
                pid,
                { ob, win, noti, ptr in
                    print("--> \(win)")
                    let wc = Unmanaged<WindowConductor>.fromOpaque(ptr!).takeUnretainedValue()
                    Task { await wc.windowChange() }
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

        print("=> \(app.localizedName!)")
        self.windowChange()
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

struct Window {
    static func getTop() -> AXUIElement? {
        guard let nsApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = nsApp.processIdentifier
        let app = AXUIElementCreateApplication(pid)

        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value)
        guard value != nil else { return nil }
        return (value as! AXUIElement)
    }

    static func getAll() -> [AXUIElement] {
        var uniqPids = Set<pid_t>()
        var wins = [AXUIElement]()

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
                wins.append(contentsOf: appWins[1...])
            } else {
                wins.append(contentsOf: appWins)
            }
        }

        return wins
    }
}
