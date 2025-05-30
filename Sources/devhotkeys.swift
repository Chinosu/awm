import AppKit
import Carbon.HIToolbox

func dev_hotkeys(_ wc: WC) {
    let ptr = Unmanaged.passRetained(wc)
    // ptr.release()
    let eventTap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: 1 << CGEventType.keyDown.rawValue | 1 << CGEventType.keyUp.rawValue,
        callback: dev_keyDispatch,
        userInfo: ptr.toOpaque()
    )!

    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)!

    print("‧₊˚ ⋅\u{10}ready wen u are :3")
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)
}

private func dev_keyDispatch(
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

    let wc = Unmanaged<WC>.fromOpaque(userInfo!).takeUnretainedValue()
    switch (kind, key, autorepeat, (alt, cmd, shift)) {
    case (.keyDown, kVK_ANSI_1, false, (false, true, false)):
        Task { await wc.raiseAction(index: 0) }
    // case (.keyDown, kVK_ANSI_1, false, (true, true, false)): Task { await wc.doRearrange(index: 0) }
    case (.keyDown, kVK_ANSI_1, true, (_, true, false)): break

    case (.keyDown, kVK_ANSI_2, false, (false, true, false)):
        Task { await wc.raiseAction(index: 1) }
    // case (.keyDown, kVK_ANSI_2, false, (true, true, false)): Task { await wc.doRearrange(index: 1) }
    case (.keyDown, kVK_ANSI_2, true, (_, true, false)): break

    case (.keyDown, kVK_ANSI_3, false, (false, true, false)):
        Task { await wc.raiseAction(index: 2) }
    // case (.keyDown, kVK_ANSI_3, false, (true, true, false)): Task { await wc.doRearrange(index: 2) }
    case (.keyDown, kVK_ANSI_3, true, (_, true, false)): break

    case (.keyDown, kVK_ANSI_4, false, (false, true, false)):
        Task { await wc.raiseAction(index: 3) }
    // case (.keyDown, kVK_ANSI_4, false, (true, true, false)): Task { await wc.doRearrange(index: 3) }
    case (.keyDown, kVK_ANSI_4, true, (_, true, false)): break

    case (.keyDown, kVK_ANSI_5, false, (false, true, false)):
        Task { await wc.raiseAction(index: 4) }
    // case (.keyDown, kVK_ANSI_5, false, (true, true, false)): Task { await wc.doRearrange(index: 4) }
    case (.keyDown, kVK_ANSI_5, true, (_, true, false)): break

    case (.keyDown, kVK_ANSI_6, false, (false, true, false)):
        Task { await wc.raiseAction(index: 5) }
    // case (.keyDown, kVK_ANSI_6, false, (true, true, false)): Task { await wc.doRearrange(index: 5) }
    case (.keyDown, kVK_ANSI_6, true, (_, true, false)): break

    case (.keyDown, kVK_ANSI_7, false, (false, true, false)):
        Task { await wc.raiseAction(index: 6) }
    // case (.keyDown, kVK_ANSI_7, false, (true, true, false)): Task { await wc.doRearrange(index: 6) }
    case (.keyDown, kVK_ANSI_7, true, (_, true, false)): break

    case (.keyDown, kVK_ANSI_8, false, (false, true, false)):
        Task { await wc.raiseAction(index: 7) }
    // case (.keyDown, kVK_ANSI_8, false, (true, true, false)): Task { await wc.doRearrange(index: 7) }
    case (.keyDown, kVK_ANSI_8, true, (_, true, false)): break

    case (.keyDown, kVK_ANSI_9, false, (false, true, false)):
        Task { await wc.raiseAction(index: 8) }
    // case (.keyDown, kVK_ANSI_9, false, (true, true, false)): Task { await wc.doRearrange(index: 8) }
    case (.keyDown, kVK_ANSI_9, true, (_, true, false)): break

    case (.keyDown, kVK_Tab, false, (false, true, false)): Task { await wc.prevAction() }
    case (.keyDown, kVK_Tab, true, (false, true, false)): break
    case (.keyDown, kVK_Tab, false, (false, true, true)): break
    case (.keyDown, kVK_Tab, true, (false, true, true)): break

    // case (.keyDown, kVK_ANSI_Grave, false, (false, true, false)): Task { await wc.doHistCatalog() }
    // case (.keyDown, kVK_ANSI_Grave, true, (false, true, false)): break

    // case (.keyDown, kVK_Escape, false, (false, true, false)): Task { await wc.doWindsCatalog() }
    // case (.keyDown, kVK_Escape, true, (false, true, false)): break

    // case (.keyDown, kVK_ANSI_Quote, _, (false, true, false)): print("hiii")

    default: return Unmanaged.passUnretained(event)
    }

    return nil
}
