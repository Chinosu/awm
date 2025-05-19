import AppKit

struct WindowManager {
    var windows: [AXUIElement]
    var curr: AXUIElement
    var prev: AXUIElement

    init() {
        self.windows = Windows.getAll()
        guard self.windows.count > 0 else {
            fatalError("0 windows D:")
        }

        self.curr = Windows.getTop()
        self.prev = self.curr
    }

    mutating func updateWindows() {
        let wins = Windows.getAll()
        self.windows.removeAll { win in !wins.contains(win) }
        for win in wins {
            if !self.windows.contains(win) {
                self.windows.append(win)
            }
        }

        let win = Windows.getTop()
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

    mutating func raise(index: Int) {
        self.updateWindows()
        guard 0 <= index && index < self.windows.count else { return }
        self.push(win: self.windows[index])
    }

    mutating func raisePrev() {
        self.updateWindows()
        self.push(win: self.prev)
    }

    private mutating func push(win: AXUIElement) {
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

struct Windows {
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
        let pids =
            (CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID)
            as! [[CFString: AnyObject]])
            .lazy
            .reversed()
            .filter { win in
                guard
                    win[kCGWindowLayer] as! Int == 0
                        && !Windows.blacklisted(windowOwnerName: win[kCGWindowOwnerName] as! String)
                else { return false }

                let bounds = win[kCGWindowBounds] as! [String: Int]
                let height = bounds[kCGDisplayHeight]!
                let width = bounds[kCGDisplayWidth]!
                let x = bounds["X"]!
                let y = bounds["Y"]!
                guard
                    height >= 100 && width >= 100
                        && (height != 500 || width != 500 || x != 0 || y != 669)
                else { return false }
                return true
            }
            .map { win in win[kCGWindowOwnerPID] as! pid_t }
            .makeIterator()

        var uniqPids = Set<pid_t>()
        var wins = [AXUIElement]()
        for pid in pids {
            guard !uniqPids.contains(pid) else { continue }
            uniqPids.insert(pid)
            let app = AXUIElementCreateApplication(pid)

            var value: CFTypeRef?
            AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
            wins.append(contentsOf: value as! [AXUIElement])
        }

        return wins
    }

    static func blacklisted(windowOwnerName: String) -> Bool {
        switch windowOwnerName {
        case "Window Server",
            "CursorUIViewService",
            "Open and Save Panel Service",
            "Spotlight",
            "SiriNCService",
            "Emoji & Symbols",
            "Universal Control",
            "loginwindow":
            true
        default:
            false
        }
    }
}
