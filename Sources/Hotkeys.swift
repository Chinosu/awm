import AppKit

func hotkeys(_ wm: inout WindowManager) {
    let eventTap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: 1 << CGEventType.keyDown.rawValue,
        callback: keyHandler,
        userInfo: withUnsafeMutablePointer(to: &wm) { UnsafeMutableRawPointer($0) }
    )!

    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)!

    print("‧₊˚ ⋅")
    print("ready wen u are :3")

    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)
    CFRunLoopRun()
    print("byeee")
}

private let flagsUnset: CGEventFlags = [
    // .maskAlphaShift,
    .maskShift,
    .maskControl,
    .maskAlternate,
    // .maskHelp,
    .maskSecondaryFn,
    // .maskNumericPad,
]

private let flagsSet: CGEventFlags = [
    .maskCommand,
    .maskNonCoalesced,
]

private func keyHandler(
    proxy: CGEventTapProxy,
    kind: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard kind == .keyDown else { return Unmanaged.passUnretained(event) }
    let key =
        switch event.getIntegerValueField(.keyboardEventKeycode) {
        case 50: 0  // '`'
        case 18: 1
        case 19: 2
        case 20: 3
        case 21: 4
        case 23: 5
        case 22: 6
        case 26: 7
        case 28: 8
        case 25: 9
        case 29: 0
        default: -1
        }
    guard key != -1 else { return Unmanaged.passUnretained(event) }
    guard event.flags.isDisjoint(with: flagsUnset) && event.flags.contains(flagsSet) else {
        return Unmanaged.passUnretained(event)
    }

    let bits = String(event.flags.rawValue, radix: 2)
    let bitsPadded = String(repeating: "0", count: 32 - bits.count) + bits
    print("\u{1b}[0;36mhotkey cmd+\(key)\u{1b}[0m", terminator: " ")
    print("\u{1b}[0;35m\(bitsPadded)\u{1b}[0m")

    let wm = userInfo!.assumingMemoryBound(to: WindowManager.self)
    wm.pointee.update()
    if key == 0 {
        if let win = wm.pointee.prev {
            swap(&wm.pointee.curr, &wm.pointee.prev)

            var pid = pid_t(0)
            AXUIElementGetPid(win, &pid)
            let app = NSRunningApplication(processIdentifier: pid)!
            app.activate()

            AXUIElementPerformAction(win, kAXRaiseAction as CFString)
        }
    } else if key - 1 < wm.pointee.windows.count {
        print("raising window (\(key))")
        let win = wm.pointee.windows[key - 1]
        if win != wm.pointee.curr {
            wm.pointee.prev = wm.pointee.curr
            wm.pointee.curr = win
        }

        var pid = pid_t(0)
        AXUIElementGetPid(win, &pid)
        let app = NSRunningApplication(processIdentifier: pid)!
        app.activate()

        AXUIElementPerformAction(win, kAXRaiseAction as CFString)
    }

    return nil
}
