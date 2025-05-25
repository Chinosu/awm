import Cocoa

func dev() {
    // ls()

    // let sys = AXUIElementCreateSystemWide()
    // print(element)
    // print()
    // let app = AXUIElementCreateApplication(
    //     NSWorkspace.shared.frontmostApplication!.processIdentifier)
    // var v: AnyObject?
    // AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &v)
    // let element = v as! AXUIElement

    // var items: CFArray?
    // check(AXUIElementCopyAttributeNames(element, &items))
    // let names = items as! [String]
    // print("anames:")
    // for n in names { print("- \(n)") }
    // print()

    // check(AXUIElementCopyParameterizedAttributeNames(element, &items))
    // let pnames = items as! [String]
    // print("panames:")
    // for n in pnames { print("- \(n)") }
    // print()

    // var value: AnyObject?
    // check(
    //     AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value))
    // print("(\(value, default: "nil"))")

    var observer: AXObserver?
    check(
        AXObserverCreate(
            NSWorkspace.shared.frontmostApplication!.processIdentifier,
            { ob, ele, noti, ptr in
                print("elem destroyed!! \(ele)")
                print("\(type(of: ele))")
                assert(ele == ele)
            },
            &observer
        ))
    // kAXUIElementDestroyedNotification
    check(
        AXObserverAddNotification(
            observer!,
            AXUIElementCreateApplication(
                NSWorkspace.shared.frontmostApplication!.processIdentifier),
            kAXUIElementDestroyedNotification as CFString,
            nil))
    CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer!), .defaultMode)

    RunLoop.main.run()
}

func ls() {
    var ls = LinkedSet<String>()
    let p = {
        print("LinkedSet")
        print("--> items \(ls.items)")
        print("--> mem:")
        for m in ls.mem { print("    \(m)") }
        print("--> free \(ls.free)")
        print("--> items:")
        for s in ls { print("    \(s)") }
        print()
    }
    p()
    ls.append("first")
    ls.append("second")
    ls.append("third")
    p()
    ls.append("first")
    p()
    ls.delete("third")
    p()
    ls.append("fourth")
    p()
    ls.delete("first")
    ls.delete("second")
    ls.delete("fourth")
    p()
    ls = ["hi", "hello", "bye"]
    p()
    print("»\(ls[0])«")
    print("»\(ls[1])«")
    print("»\(ls[2])«")
    print(">> \(ls.map(\.count))")
    ls.append("yeti")
    ls.delete(where: { $0.count & 1 == 0 })
    p()
    ls.prepend("frontmost")
    p()
}
