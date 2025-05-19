import AppKit

func experiments() {
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

    let observer = {
        var observer: AXObserver?
        AXObserverCreate(
            app.processIdentifier,
            { obs, elem, notif, userData in print("winch") },
            &observer
        )
        return observer!
    }()

    AXObserverAddNotification(
        observer, axApp, kAXFocusedWindowChangedNotification as CFString, nil)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)

    NSWorkspace.shared.notificationCenter.addObserver(
        forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
    ) { notif in
        print("appch")
    }

    RunLoop.current.run()
}

func pjson(_ item: Any) {
    let json = try! JSONSerialization.data(
        withJSONObject: item, options: [.prettyPrinted, .sortedKeys])
    let str = String(data: json, encoding: .utf8)!
    print(str)
}
