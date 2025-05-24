import AppKit
import Carbon.HIToolbox

@available(macOS 15.4.0, *)
func hotkeys(_ wc: WindowConductor) {
    let ptr = Unmanaged.passRetained(wc)
    // ptr.release()
    let eventTap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: 1 << CGEventType.keyDown.rawValue | 1 << CGEventType.keyUp.rawValue,
        callback: keyDispatch,
        userInfo: ptr.toOpaque()
    )!

    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)!

    print("‧₊˚ ⋅\u{10}ready wen u are :3")
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)
}

@available(macOS 15.4.0, *)
private func keyDispatch(
    proxy: CGEventTapProxy,
    kind: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard
        event.flags.contains(.maskNonCoalesced)
            && event.flags.isDisjoint(with: [.maskControl, .maskHelp, .maskSecondaryFn])
    else { return Unmanaged.passUnretained(event) }

    let alt = event.flags.contains(.maskAlternate)
    let cmd = event.flags.contains(.maskCommand)
    let shift = event.flags.contains(.maskShift)
    let key = Int(event.getIntegerValueField(.keyboardEventKeycode))
    let autorepeat = 0 != event.getIntegerValueField(.keyboardEventAutorepeat)

    // print("=> \(key) \(autorepeat) \(kind) \(alt)+\(cmd)")

    let wc = Unmanaged<WindowConductor>.fromOpaque(userInfo!).takeUnretainedValue()
    switch (kind, key, autorepeat, (alt, cmd, shift)) {
    case (.keyDown, kVK_ANSI_1, false, (false, true, false)): Task { await wc.doRaise(index: 0) }
    case (.keyDown, kVK_ANSI_1, true, (false, true, false)): break

    case (.keyDown, kVK_ANSI_2, false, (false, true, false)): Task { await wc.doRaise(index: 1) }
    case (.keyDown, kVK_ANSI_2, true, (false, true, false)): break

    case (.keyDown, kVK_ANSI_3, false, (false, true, false)): Task { await wc.doRaise(index: 2) }
    case (.keyDown, kVK_ANSI_3, true, (false, true, false)): break

    case (.keyDown, kVK_ANSI_4, false, (false, true, false)): Task { await wc.doRaise(index: 3) }
    case (.keyDown, kVK_ANSI_4, true, (false, true, false)): break

    case (.keyDown, kVK_ANSI_5, false, (false, true, false)): Task { await wc.doRaise(index: 4) }
    case (.keyDown, kVK_ANSI_5, true, (false, true, false)): break

    case (.keyDown, kVK_ANSI_6, false, (false, true, false)): Task { await wc.doRaise(index: 5) }
    case (.keyDown, kVK_ANSI_6, true, (false, true, false)): break

    case (.keyDown, kVK_ANSI_7, false, (false, true, false)): Task { await wc.doRaise(index: 6) }
    case (.keyDown, kVK_ANSI_7, true, (false, true, false)): break

    case (.keyDown, kVK_ANSI_8, false, (false, true, false)): Task { await wc.doRaise(index: 7) }
    case (.keyDown, kVK_ANSI_8, true, (false, true, false)): break

    case (.keyDown, kVK_ANSI_9, false, (false, true, false)): Task { await wc.doRaise(index: 8) }
    case (.keyDown, kVK_ANSI_9, true, (false, true, false)): break

    case (.keyDown, kVK_Tab, false, (false, true, false)): Task { await wc.doPrev() }
    case (.keyDown, kVK_Tab, true, (false, true, false)): break

    case (.keyDown, kVK_Tab, false, (false, true, true)): Task { await wc.doWalk() }
    case (.keyDown, kVK_Tab, true, (false, true, true)): break

    case (.keyDown, kVK_ANSI_Grave, false, (false, true, false)): Task { await wc.doWalk() }
    case (.keyDown, kVK_ANSI_Grave, true, (false, true, false)): break

    // case (.keyDown, kVK_Escape, false, (false, true, false)): Task { await wc.doCatalog() }
    case (.keyDown, kVK_Escape, false, (false, true, false)): Task { await wc.doHistoryCatalog() }
    case (.keyDown, kVK_Escape, true, (false, true, false)): break

    default: return Unmanaged.passUnretained(event)
    }

    return nil
}
