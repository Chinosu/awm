import AppKit

struct WindowManager {
    var windows = [AXUIElement]()
    var flipHold = -1
    var curr: AXUIElement? = nil
    var prev: AXUIElement? = nil
    var swapWin: AXUIElement? = nil

    mutating func updateWindows() {
        let pids =
            Array(
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
                        let height = bounds["Height"]!
                        let width = bounds["Width"]!
                        let x = bounds["X"]!
                        let y = bounds["Y"]!
                        guard
                            height >= 100 && width >= 100
                                && (height != 500 || width != 500 || x != 0 || y != 669)
                        else { return false }
                        return true
                    }
                    .map { win in win[kCGWindowOwnerPID] as! pid_t }
            )

        var pid_seen = Set<pid_t>()
        var win_seen = Set<AXUIElement>()
        for pid in pids {
            guard !pid_seen.contains(pid) else { continue }
            pid_seen.insert(pid)

            let app = AXUIElementCreateApplication(pid)

            // var v: CFArray?
            // AXUIElementCopyAttributeNames(elem, &v)
            // print(v!)

            var value: CFTypeRef?
            AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
            let wins = value as! [AXUIElement]

            for win in wins {
                // var value: CFArray?
                // AXUIElementCopyAttributeNames(win, &value)
                // print(value!)
                win_seen.insert(win)
                guard !self.windows.contains(win) else { continue }
                self.windows.append(win)
            }
        }
        self.windows.removeAll { win in !win_seen.contains(win) }

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

    mutating func flipRecent() {
        guard let win = self.prev else { return }
        swap(&self.curr, &self.prev)
        self.flipHold = 0
        activate(win: win)
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
            if self.flipHold >= 0 {
                self.flipHold += 1
            }
        }
    }

    mutating func undoFlip() {
        if self.flipHold > 1 {
            self.flipRecent()
        }

        self.flipHold = -1
    }

    mutating func swapWins(index: Int) {
        guard 0 <= index && index <= self.windows.count else { return }
        let win = self.windows[index]
        if let other = self.swapWin {
            let i = self.windows.firstIndex(of: other)!
            self.windows.swapAt(i, index)
        } else {
            self.swapWin = win
        }
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
