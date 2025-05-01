import AppKit

@inlinable func opaq(_ origin: CFString) -> UnsafeMutableRawPointer {
    return Unmanaged.passUnretained(origin).toOpaque()
}

@MainActor func main() {
    var pidMaybe = Optional<pid_t>.none
    let infos = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)!
    for i in 0..<CFArrayGetCount(infos) {
        let info = unsafeBitCast(CFArrayGetValueAtIndex(infos, i), to: CFDictionary.self)
        let name = unsafeBitCast(
            CFDictionaryGetValue(info, opaq(kCGWindowOwnerName)), to: CFString.self)
        if name != "Terminal" as CFString {
            continue
        }

        let cfpid = unsafeBitCast(
            CFDictionaryGetValue(info, opaq(kCGWindowOwnerPID)), to: CFNumber.self)
        var pid = Int32(0)
        CFNumberGetValue(cfpid, .sInt32Type, &pid)
        pidMaybe = Optional.some(pid)
    }

    guard let pid = pidMaybe else {
        print("could not find app `Terminal`. Try launching one :3")
        return
    }

    let nsApp = NSRunningApplication(processIdentifier: pid)!
    nsApp.activate(options: [.activateAllWindows])

    let app = AXUIElementCreateApplication(pid)
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
    let windows = value as! CFArray
    print("found \(CFArrayGetCount(windows)) terminals")
    let window = unsafeBitCast(CFArrayGetValueAtIndex(windows, 0), to: AXUIElement.self)

    var newPos = CGPoint(x: 100, y: 100)
    let pos = AXValueCreate(.cgPoint, &newPos)!
    AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pos)

    var newSize = CGSize(width: 100, height: 100)
    let size = AXValueCreate(.cgPoint, &newSize)!
    AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, size)

    hotkeys()
}

func hotkeys() {
    // let mask: CGEventMask =
    //     1 << CGEventType.keyDown.rawValue | 1 << CGEventType.keyUp.rawValue
    //     | 1 << CGEventType.mouseMoved.rawValue
    let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: CGEventMask.max,  // danger
        callback: keyHandler, userInfo: nil)!

    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)!
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    CFRunLoopRun()
}

func keyHandler(
    proxy: CGEventTapProxy, kind: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    let keycode = event.getIntegerValueField(.keyboardEventKeycode)
    switch kind {
    case .leftMouseDown: print("help")
    case .keyDown:
        if event.flags.contains(.maskCommand) {
            print("kdown cmd+\(keycode)")
        } else {
            print("kdown \(keycode)")
        }

    case .keyUp: print("kup \(keycode)")
    case .flagsChanged: print("modsch \(keycode)")
    default: ()
    }

    return Unmanaged.passUnretained(event)
}

main()
