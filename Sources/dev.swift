import Cocoa

nonisolated(unsafe) private var ghosttyLastIndex: Int = -1
nonisolated(unsafe) private var x: AXUIElement?
nonisolated(unsafe) private var obs: [AXObserver] = []
nonisolated(unsafe) private var ghosttys: Set<Wind> = []

func dev() {
    `fixGhostty??`()
    // `screens!!!`()
}

func `fixGhostty??`() {
    // let ghostty =
    //     NSWorkspace.shared.runningApplications
    //     .lazy
    //     .filter({ $0.activationPolicy == .regular })
    //     .filter({ $0.bundleIdentifier == "com.mitchellh.ghostty" })
    //     .first!
    NSWorkspace.shared.notificationCenter.addObserver(
        forName: NSWorkspace.didLaunchApplicationNotification,
        object: nil,
        queue: .main,
        using: { noti in
            let app = noti.userInfo![NSWorkspace.applicationUserInfoKey] as! NSRunningApplication
            if app.bundleIdentifier != "com.mitchellh.ghostty" { return }
            print("hello, ghostty!")

            var observer: AXObserver?
            check(
                AXObserverCreate(
                    app.processIdentifier,
                    { ob, element, noti, ptr in
                        print()

                        switch noti as String {
                        case kAXMainWindowChangedNotification:
                            var pid = pid_t()
                            AXUIElementGetPid(element, &pid)
                            let app = NSRunningApplication(processIdentifier: pid)!
                            if app.bundleIdentifier == "com.mitchellh.ghostty" {
                                var value: AnyObject!
                                check(
                                    AXUIElementCopyAttributeValue(
                                        AXUIElementCreateApplication(pid),
                                        "AXChildrenInNavigationOrder" as CFString, &value
                                    ))
                                let childs = value as! [AXUIElement]

                                print("\(x == element)")
                                x = element

                                let i = childs.firstIndex(of: element) ?? -1
                                if ghosttyLastIndex == i {
                                    print("same!")
                                    // ghosttys.removeAll()
                                    // ghosttys.insert(Wind(element))
                                    return
                                }
                                print("diff!")
                                ghosttyLastIndex = i
                                ghosttys.removeAll()
                                ghosttys.insert(Wind(element))
                            }
                        case kAXUIElementDestroyedNotification:
                            print("element destroyed")
                        default: fatalError()
                        }
                    },
                    &observer
                ))
            check(
                AXObserverAddNotification(
                    observer!, AXUIElementCreateApplication(app.processIdentifier),
                    kAXMainWindowChangedNotification as CFString,
                    nil))
            check(
                AXObserverAddNotification(
                    observer!, AXUIElementCreateApplication(app.processIdentifier),
                    kAXUIElementDestroyedNotification as CFString,
                    nil))
            CFRunLoopAddSource(
                CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer!), .defaultMode)
            obs.append(observer!)
        }
    )

    let stdinSource = DispatchSource.makeReadSource(
        fileDescriptor: FileHandle.standardInput.fileDescriptor, queue: .main)
    stdinSource.setEventHandler {
        let inputData = FileHandle.standardInput.availableData
        guard !inputData.isEmpty,
            let input = String(data: inputData, encoding: .utf8)
        else {
            return
        }

        switch input.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "size":
            print("[size] \(ghosttys.count)")
            for w in ghosttys {
                print("- \(w.title())")
                w.size(set: .init(width: 500, height: 600), unchecked: true)
            }
        case "exit":
            stdinSource.cancel()
            CFRunLoopStop(CFRunLoopGetMain())
        default:
            print("You entered: \(input.trimmingCharacters(in: .whitespacesAndNewlines))")
            break
        }
    }
    stdinSource.resume()

    CFRunLoopRun()
}

func `screens!!!`() {
    print("> \(NSScreen.screens)")

}

// postfix operator &
// postfix func & <T>(left: inout T) -> UnsafeMutablePointer<T> {
//     withUnsafeMutablePointer(to: &left, \.self)
// }

// postfix operator *
// postfix func * <T>(left: UnsafeMutablePointer<T>) -> T {
//     left.pointee
// }

// infix operator =*
// func =* <T>(left: UnsafeMutablePointer<T>, right: T) {
//     left.pointee = right
// }

// extension UnsafeMutablePointer {
//     var a: Int {
//         return 2
//     }
// }

// postfix operator &~
// postfix func &~ <T>(left: inout T) -> UnsafeMutableRawPointer {
//     UnsafeMutableRawPointer(left&)
// }

// infix operator => : CastingPrecedence
// func => <T>(left: UnsafeMutableRawPointer, right: T.Type) -> UnsafeMutablePointer<T> {
//     left.assumingMemoryBound(to: right)
// }

// func operators() {
//     var x = 42
//     let ptr = x&
//     print(ptr*)
//     ptr =* 2
//     // print(ptr.*)  // 42
// }
