import AppKit

func hotkeys() {
    let eventTap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: 1 << CGEventType.keyDown.rawValue,
        callback: keyHandler,
        userInfo: nil
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
    print("hotkey cmd+\(key)", terminator: " ")
    print("\u{1b}[0;35m\(bitsPadded)\u{1b}[0m")

    // let windows =
    //     CGWindowListCopyWindowInfo(
    //         [.optionOnScreenOnly, .excludeDesktopElements],
    //         kCGNullWindowID
    //     )
    //     as! [[String: AnyObject]]

    // for window in windows {
    //     // print(window.keys.count)
    //     if window[kCGWindowIsOnscreen as String] as! Int == 0 { continue }
    //     if window[kCGWindowStoreType as String] as! Int == 0 { continue }
    //     print()
    //     for kv in window {
    //         print(kv)
    //     }
    //     // print(window)
    // }

    return nil
}
