import AppKit

let blacklist: Set = [
    "Window Server",
    "CursorUIViewService",
    "Open and Save Panel Service",
    "Spotlight",
    "CursorUIViewService",
    "SiriNCService",
    "Emoji & Symbols",
    "Universal Control",
    "loginwindow",
    "Window Server",
]

func windowDetect() async {
    let cgWindows =
        (CGWindowListCopyWindowInfo(
            [.optionAll, .excludeDesktopElements],
            kCGNullWindowID
        )
        as! [[CFString: AnyObject]])
        .filter { win in
            guard win[kCGWindowLayer] as! Int == 0 else {
                return false
            }
            guard !blacklist.contains(win[kCGWindowOwnerName] as! String) else {
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

    // print(windows)
    // let d = try! JSONSerialization.data(withJSONObject: cgWindows, options: .prettyPrinted)
    // try! d.write(to: URL(fileURLWithPath: "./a.json"))

    let pids = Set(cgWindows.lazy.map { $0[kCGWindowOwnerPID] as! pid_t })
    var originWins = [AXUIElement]()
    for pid in pids {
        var value: CFTypeRef?

        let elem = AXUIElementCreateApplication(pid)
        AXUIElementCopyAttributeValue(elem, kAXWindowsAttribute as CFString, &value)
        let axWindows = value as! [AXUIElement]
        originWins.append(contentsOf: axWindows)
        print(axWindows)

        for win in axWindows {
            AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &value)
            let title = value as! String
            print("\t\(title)")
        }
    }

    for pid in pids {
        var value: CFTypeRef?

        let elem = AXUIElementCreateApplication(pid)
        AXUIElementCopyAttributeValue(elem, kAXWindowsAttribute as CFString, &value)
        let axWindows = value as! [AXUIElement]

        for win in axWindows {
            for originWin in originWins {
                if win == originWin {
                    // this shows we can manage windows references ourselves
                    // despite `AXUIElement` addresses being different
                    print("match!!")
                }
            }
        }
    }
}
