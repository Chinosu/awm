import AppKit
import Carbon.HIToolbox

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
    guard
        event.flags.contains(.maskNonCoalesced)
            && event.flags.isDisjoint(with: [.maskShift, .maskControl, .maskHelp, .maskSecondaryFn])
    else { return Unmanaged.passUnretained(event) }

    let alt = event.flags.contains(.maskAlternate)
    let cmd = event.flags.contains(.maskCommand)
    let key = Int(event.getIntegerValueField(.keyboardEventKeycode))
    let autorepeat = 0 != event.getIntegerValueField(.keyboardEventAutorepeat)

    // print("=> \(key) \(autorepeat) \(kind) \(alt)+\(cmd)")

    switch (kind, key, autorepeat, (alt, cmd)) {
    case (.keyDown, kVK_ANSI_1, false, (false, true)):
        let wm = userInfo!.assumingMemoryBound(to: WindowManager.self)
        wm.pointee.raise(index: 0)
    case (.keyDown, kVK_ANSI_1, true, (false, true)):
        break

    case (.keyDown, kVK_ANSI_2, false, (false, true)):
        let wm = userInfo!.assumingMemoryBound(to: WindowManager.self)
        wm.pointee.raise(index: 1)
    case (.keyDown, kVK_ANSI_2, true, (false, true)):
        break

    case (.keyDown, kVK_ANSI_3, false, (false, true)):
        let wm = userInfo!.assumingMemoryBound(to: WindowManager.self)
        wm.pointee.raise(index: 2)
    case (.keyDown, kVK_ANSI_3, true, (false, true)):
        break

    case (.keyDown, kVK_ANSI_4, false, (false, true)):
        let wm = userInfo!.assumingMemoryBound(to: WindowManager.self)
        wm.pointee.raise(index: 3)
    case (.keyDown, kVK_ANSI_4, true, (false, true)):
        break

    case (.keyDown, kVK_ANSI_5, false, (false, true)):
        let wm = userInfo!.assumingMemoryBound(to: WindowManager.self)
        wm.pointee.raise(index: 4)
    case (.keyDown, kVK_ANSI_5, true, (false, true)):
        break

    case (.keyDown, kVK_ANSI_6, false, (false, true)):
        let wm = userInfo!.assumingMemoryBound(to: WindowManager.self)
        wm.pointee.raise(index: 5)
    case (.keyDown, kVK_ANSI_6, true, (false, true)):
        break

    case (.keyDown, kVK_ANSI_7, false, (false, true)):
        let wm = userInfo!.assumingMemoryBound(to: WindowManager.self)
        wm.pointee.raise(index: 6)
    case (.keyDown, kVK_ANSI_7, true, (false, true)):
        break

    case (.keyDown, kVK_ANSI_8, false, (false, true)):
        let wm = userInfo!.assumingMemoryBound(to: WindowManager.self)
        wm.pointee.raise(index: 7)
    case (.keyDown, kVK_ANSI_8, true, (false, true)):
        break

    case (.keyDown, kVK_ANSI_9, false, (false, true)):
        let wm = userInfo!.assumingMemoryBound(to: WindowManager.self)
        wm.pointee.raise(index: 8)
    case (.keyDown, kVK_ANSI_9, true, (false, true)):
        break

    case (.keyDown, kVK_ANSI_Grave, false, (false, true)),
        (.keyDown, kVK_Tab, false, (false, true)):
        let wm = userInfo!.assumingMemoryBound(to: WindowManager.self)
        wm.pointee.raisePrev()
    case (.keyDown, kVK_ANSI_Grave, true, (false, true)),
        (.keyDown, kVK_Tab, true, (false, true)):
        break

    default:
        return Unmanaged.passUnretained(event)
    }

    return nil
}
