import AppKit

struct WindowManager {
    var flipHold = -1

    var windows: [AXUIElement]
    var curr: AXUIElement
    var prev: AXUIElement

    init() {
        self.windows = getWindows()
        guard self.windows.count > 0 else {
            fatalError("0 windows D:")
        }

        self.curr = self.windows[0]
        self.prev = self.windows[0]
        activate(win: self.windows[0])
    }

    mutating func updateWindows() {
        let wins = getWindows()
        self.windows.removeAll { win in !wins.contains(win) }
        for win in wins {
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

    mutating func flipPrev() {
        if self.flipHold == -1 {
            activate(win: self.prev)
            swap(&self.curr, &self.prev)
            self.flipHold = 0
        } else if self.flipHold < 2 {
            self.flipHold += 1
        }
    }

    mutating func flipTo(index: Int) {
        guard 0 <= index && index < self.windows.count else { return }
        let win = self.windows[index]
        if win != self.curr {
            self.prev = self.curr
            self.curr = win
            activate(win: win)

            self.flipHold = 0
        } else {
            if 0 <= self.flipHold && self.flipHold < 2 {
                self.flipHold += 1
            }
        }
    }

    mutating func undoFlip() {
        if self.flipHold >= 2 {
            activate(win: self.prev)
            swap(&self.curr, &self.prev)
        }

        self.flipHold = -1
    }

    mutating func swapWins(index: Int) {
        guard 0 <= index && index <= self.windows.count else { return }
        guard let i = self.windows.firstIndex(of: self.curr) else { return }
        self.windows.swapAt(i, index)

        self.prev = self.curr
        self.curr = self.windows[i]
        activate(win: self.windows[i])
    }
}

private func blacklisted(windowOwnerName: String) -> Bool {
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

private func activate(win: AXUIElement) {
    var pid: pid_t = 0
    AXUIElementGetPid(win, &pid)
    let app = NSRunningApplication(processIdentifier: pid)!
    app.activate()

    AXUIElementPerformAction(win, kAXRaiseAction as CFString)
}

private func getWindows() -> [AXUIElement] {
    let pids =
        (CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID)
        as! [[CFString: AnyObject]])
        .lazy
        .reversed()
        .filter { win in
            guard
                win[kCGWindowLayer] as! Int == 0
                    && !blacklisted(windowOwnerName: win[kCGWindowOwnerName] as! String)
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
