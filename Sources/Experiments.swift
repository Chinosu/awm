import AppKit

func experiments() async {
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
}

func pjson(_ item: Any) {
    let json = try! JSONSerialization.data(
        withJSONObject: item, options: [.prettyPrinted, .sortedKeys])
    let str = String(data: json, encoding: .utf8)!
    print(str)
}

// NSWorkspace.shared.notificationCenter.addObserver(
//     forName: NSWorkspace.didActivateApplicationNotification,
//     object: nil,
//     queue: .main
// ) { notif in
//     guard let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
//     else { return }

//     print("appswitch \(app.localizedName ?? "unkn")")

//     let element = AXUIElementCreateApplication(app.processIdentifier)
//     var observer: AXObserver?
//     AXObserverCreate(
//         app.processIdentifier,
//         { obs, elem, notification, contex in
//             if notification as String == kAXFocusedWindowChangedNotification {
//                 print("foc win change")
//                 // broken
//             }
//         },
//         &observer
//     )

//     if let observer = observer {
//         AXObserverAddNotification(
//             observer,
//             element,
//             kAXFocusedWindowChangedNotification as CFString,
//             nil
//         )
//         CFRunLoopAddSource(
//             CFRunLoopGetCurrent(),
//             AXObserverGetRunLoopSource(observer),
//             .defaultMode
//         )
//     }
// }
