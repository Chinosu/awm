import AppKit

@inlinable func opaq(_ origin: CFString) -> UnsafeMutableRawPointer {
    return Unmanaged.passUnretained(origin).toOpaque()
}

@MainActor func main() {
    // var pidMaybe: pid_t? = nil
    // let infos = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)!

    // for i in 0..<CFArrayGetCount(infos) {
    //     let info = unsafeBitCast(CFArrayGetValueAtIndex(infos, i), to: CFDictionary.self)
    //     let name = unsafeBitCast(
    //         CFDictionaryGetValue(info, opaq(kCGWindowOwnerName)), to: CFString.self)

    //     if name != "Terminal" as CFString {
    //         continue
    //     }

    //     let cfpid = unsafeBitCast(
    //         CFDictionaryGetValue(info, opaq(kCGWindowOwnerPID)), to: CFNumber.self)
    //     var pid: Int32 = 0
    //     CFNumberGetValue(cfpid, .sInt32Type, &pid)
    //     pidMaybe = pid
    // }

    // guard let pid = pidMaybe else {
    //     print("could not find app `Terminal`. Try launching one :3")
    //     return
    // }

    // let nsApp = NSRunningApplication(processIdentifier: pid)!
    // nsApp.activate(options: [.activateAllWindows])
    // nsApp.hide()
    // nsApp.unhide()

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

    hotkeys()
}

main()
