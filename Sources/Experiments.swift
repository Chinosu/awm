import AppKit

struct Experiments {
    static func topWindow() {
        print(Windows.getTop())
        // let pid = NSWorkspace.shared.frontmostApplication!.processIdentifier

        // // do {
        // //     let wins =
        // //         CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID)
        // //         as! [[CFString: AnyObject]]
        // //     for win in wins {
        // //         guard win[kCGWindowOwnerPID] as! pid_t == pid else { continue }
        // //         let bounds = CGRect(
        // //             dictionaryRepresentation: win[kCGWindowBounds] as! CFDictionary)!
        // //         guard bounds.width >= 50 && bounds.height >= 50 else { continue }

        // //         print("top CGWindow:")
        // //         print(win)  // what to do with a CG window?
        // //         break
        // //     }
        // // }

        // do {
        //     let app = AXUIElementCreateApplication(pid)
        //     let appKeys = {
        //         var value: CFArray?
        //         AXUIElementCopyAttributeNames(app, &value)
        //         return value as! [String]
        //     }()

        //     pjson(appKeys)

        //     let wins = {
        //         var value: CFTypeRef?
        //         AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
        //         return value as! [AXUIElement]
        //     }()
        //     print(wins)

        //     // do {
        //     //     var value: CFTypeRef?
        //     //     AXUIElementCopyAttributeValue(app, kAXFrontmostAttribute as CFString, &value)
        //     //     print(value)
        //     // }
        // }
    }

    static func observers() {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            print("frontmost app was null, bye!")
            return
        }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let names = {
            var value: CFArray?
            AXUIElementCopyAttributeNames(axApp, &value)
            return value as! [String]
        }()
        pjson(names)

        let mainWin = {
            var value: CFTypeRef?
            AXUIElementCopyAttributeValue(axApp, kAXMainWindowAttribute as CFString, &value)
            return value as! AXUIElement
        }()

        let focusedWin = {
            var value: CFTypeRef?
            AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &value)
            return value as! AXUIElement
        }()

        print(mainWin)
        print(focusedWin)

        let winObs = {
            var observer: AXObserver?
            AXObserverCreate(
                app.processIdentifier,
                { obs, elem, notif, userData in print("win ch") },
                &observer
            )
            return observer!
        }()
        let appObs = {
            var observer: AXObserver?
            AXObserverCreate(
                app.processIdentifier,
                { obs, elem, notif, userData in print("app ch (ax) // only observes one app") },
                &observer
            )
            return observer!
        }()

        AXObserverAddNotification(
            winObs, axApp, kAXFocusedWindowChangedNotification as CFString, nil)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(winObs), .defaultMode)
        AXObserverAddNotification(
            appObs, axApp, kAXApplicationActivatedNotification as CFString, nil)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(appObs), .defaultMode)

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { notif in
            print("app ch (ns)")
        }

        RunLoop.current.run()
    }
}

func pjson(_ item: Any) {
    let json = try! JSONSerialization.data(
        withJSONObject: item, options: [.prettyPrinted, .sortedKeys])
    let str = String(data: json, encoding: .utf8)!
    print(str)
}
