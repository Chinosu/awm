import AppKit

struct Wind: Equatable, Hashable {
    let inner: AXUIElement

    init(_ inner: AXUIElement) {
        self.inner = inner
    }

    func keys() -> [String] {
        var value: CFArray?
        check(AXUIElementCopyAttributeNames(self.inner, &value))
        return value as! [String]
    }

    func alive() -> Bool {
        var value: AnyObject?
        // specifically ask for `AXTitle` as Finder's "hidden"
        // window does *not* have a title, so this will
        // conveniently ignore that specific window
        let result = AXUIElementCopyAttributeValue(
            self.inner, kAXTitleAttribute as CFString, &value)
        return result == .success
    }

    func focused() -> Bool {
        var value: AnyObject?
        check(AXUIElementCopyAttributeValue(self.inner, kAXFocusedAttribute as CFString, &value))
        return value as! Bool
    }

    func title() -> String {
        var value: AnyObject?
        check(AXUIElementCopyAttributeValue(self.inner, kAXTitleAttribute as CFString, &value))
        return value as! String
    }

    func pid() -> pid_t {
        var pid = pid_t()
        check(AXUIElementGetPid(self.inner, &pid))
        return pid
    }

    func position() -> CGPoint {
        var value: AnyObject?
        check(AXUIElementCopyAttributeValue(self.inner, kAXPositionAttribute as CFString, &value))
        var point = CGPoint()
        check(AXValueGetValue(value as! AXValue, .cgPoint, &point))
        return point
    }

    func position(set newValue: CGPoint) {
        var point = newValue
        let value = AXValueCreate(.cgPoint, &point)
        check(AXUIElementSetAttributeValue(self.inner, kAXPositionAttribute as CFString, value!))
    }

    func size() -> CGSize {
        var value: AnyObject?
        check(AXUIElementCopyAttributeValue(self.inner, kAXSizeAttribute as CFString, &value))
        var size = CGSize()
        check(AXValueGetValue(value as! AXValue, .cgSize, &size))
        return size
    }

    func size(set newValue: CGSize, unchecked: Bool = false) {
        var size = newValue
        let value = AXValueCreate(.cgSize, &size)
        if !unchecked {
            check(AXUIElementSetAttributeValue(self.inner, kAXSizeAttribute as CFString, value!))
        } else {
            AXUIElementSetAttributeValue(self.inner, kAXSizeAttribute as CFString, value!)
        }
    }

    func raise() {
        check(AXUIElementPerformAction(self.inner, kAXRaiseAction as CFString))
    }

    static func top() async -> Wind? {
        return await Self.top(pid: NSWorkspace.shared.frontmostApplication!.processIdentifier)
    }

    static func top(pid: pid_t) async -> Wind? {
        var value: AnyObject?
        while AXUIElementCopyAttributeValue(
            AXUIElementCreateApplication(pid), kAXFocusedWindowAttribute as CFString, &value)
            == .cannotComplete
        {
            // app might still be starting up; wait
            try! await Task.sleep(for: .milliseconds(100))
        }
        if value == nil { return nil }
        return Wind(value as! AXUIElement)
    }

    static func all() -> [Wind] {
        var wins = [Wind]()
        let apps = NSWorkspace.shared.runningApplications
            .lazy
            .filter { $0.activationPolicy == .regular }
        for app in apps {
            let axApp = AXUIElementCreateApplication(app.processIdentifier)

            var value: AnyObject?
            check(AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value))
            let winds = value as! [AXUIElement]

            if app.bundleIdentifier == "com.apple.finder" {
                // finder always has one dummy/hidden window
                // therefore skip it
                wins.append(contentsOf: winds[1...].lazy.map({ w in Wind(w) }))
            } else {
                wins.append(contentsOf: winds.lazy.map({ w in Wind(w) }))
            }
        }

        return wins
    }
}

@inlinable func check(_ value: AXError) {
    assert(value == .success, "\(value.rawValue)")
}

@inlinable func check(_ value: Bool) {
    assert(value)
}

@inlinable func check(_ value: Any?) {
    assert(value != nil)
}
