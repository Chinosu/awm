import AppKit

func hotkeys(_ wm: inout WindowManager) {
    let eventTap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: 1 << CGEventType.keyDown.rawValue | 1 << CGEventType.keyUp.rawValue,
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

private func keyHandler(
    proxy: CGEventTapProxy,
    kind: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    let key =
        switch event.getIntegerValueField(.keyboardEventKeycode) {
        case 50: 0  // backtick
        case 18: 1
        case 19: 2
        case 20: 3
        case 21: 4
        case 23: 5
        case 22: 6
        case 26: 7
        case 28: 8
        case 25: 9
        default: -1
        }
    guard
        key != -1
            && event.flags.contains(.maskNonCoalesced)
            && event.flags.isDisjoint(with: [.maskShift, .maskControl, .maskHelp, .maskSecondaryFn])
    else { return Unmanaged.passUnretained(event) }

    switch (event.flags.contains(.maskAlternate), event.flags.contains(.maskCommand), kind) {
    case (false, true, .keyDown):
        let wm = userInfo!.assumingMemoryBound(to: WindowManager.self)
        wm.pointee.updateWindows()
        if key == 0 {
            wm.pointee.flipRecent()
        } else {
            wm.pointee.flipTo(index: key - 1)
        }

    case (false, true, .keyUp):
        let wm = userInfo!.assumingMemoryBound(to: WindowManager.self)
        wm.pointee.updateWindows()
        wm.pointee.undoFlip()

    case (true, true, .keyDown):
        let wm = userInfo!.assumingMemoryBound(to: WindowManager.self)
        wm.pointee.updateWindows()
        wm.pointee.swapWins(index: key - 1)

    default:
        return Unmanaged.passUnretained(event)
    }

    return nil
}
