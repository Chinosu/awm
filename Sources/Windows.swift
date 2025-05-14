import AppKit

class WindowManager {
    var windows = [AXUIElement]()

    var curr = AXUIElement?(nil)
    var prev = AXUIElement?(nil)

    func update() {
        let pids =
            Array(
                (CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID)
                    as! [[CFString: AnyObject]])
                    .lazy
                    .reversed()
                    .filter { win in
                        guard win[kCGWindowLayer] as! Int == 0 else {
                            return false
                        }
                        guard !blacklisted(windowOwnerName: win[kCGWindowOwnerName] as! String)
                        else {
                            return false
                        }

                        let bounds = win[kCGWindowBounds] as! [String: Int]
                        let height = bounds["Height"]!
                        let width = bounds["Width"]!
                        let x = bounds["X"]!
                        let y = bounds["Y"]!
                        guard height >= 100 && width >= 100 else {
                            return false
                        }
                        guard height != 500 || width != 500 || x != 0 || y != 669 else {
                            return false
                        }

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
            let windows = value as! [AXUIElement]

            for win in windows {
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
}

func blacklisted(windowOwnerName: String) -> Bool {
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
