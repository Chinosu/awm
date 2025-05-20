import AppKit

actor WindowConductor {
    var wins: [AXUIElement]
    var curr: AXUIElement
    var prev: AXUIElement

    init() {
        print("\(argv) <--- todo")  // ???????

        self.wins = Window.getAll()
        guard self.wins.count > 0 else {
            fatalError("0 windows D:")
        }

        self.curr = Window.getTop()
        self.prev = self.curr
    }

    func updateWindows() {
        let newWins = Window.getAll()
        self.wins.removeAll { win in !newWins.contains(win) }
        for win in newWins {
            if !self.wins.contains(win) {
                self.wins.append(win)
            }
        }

        let win = Window.getTop()
        if win != curr {
            self.prev = self.curr
            self.curr = win
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
            guard win != self.curr else { return }
            self.prev = self.curr
            self.curr = win
        }

        var pid: pid_t = 0
        AXUIElementGetPid(win, &pid)
        let app = NSRunningApplication(processIdentifier: pid)!
        app.activate()
        AXUIElementPerformAction(win, kAXRaiseAction as CFString)
    }
}

struct Window {
    static func getTop() -> AXUIElement {
        let pid = NSWorkspace.shared.frontmostApplication!.processIdentifier
        let app = AXUIElementCreateApplication(pid)
        let focusedWin = {
            var value: CFTypeRef?
            AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value)
            return value as! AXUIElement
        }()
        return focusedWin
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

            let appWins = {
                var value: CFTypeRef?
                AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value)
                return value as! [AXUIElement]
            }()
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
