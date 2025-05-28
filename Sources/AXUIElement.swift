import Cocoa

public enum AXErr: Error {
    /** A system error occurred, such as the failure to allocate an object. */
    case failure
    /** An illegal argument was passed to the function. */
    case illegalArgument
    /** The AXUIElementRef passed to the function is invalid. */
    case invalidUIElement
    /** The AXObserverRef passed to the function is not a valid observer. */
    case invalidUIElementObserver
    /** The function cannot complete because messaging failed in some way or because the application with which the function is communicating is busy or unresponsive. */
    case cannotComplete
    /** The attribute is not supported by the AXUIElementRef. */
    case attributeUnsupported
    /** The action is not supported by the AXUIElementRef. */
    case actionUnsupported
    /** The notification is not supported by the AXUIElementRef. */
    case notificationUnsupported
    /** Indicates that the function or method is not implemented (this can be returned if a process does not support the accessibility API). */
    case notImplemented
    /** This notification has already been registered for. */
    case notificationAlreadyRegistered
    /** Indicates that a notification is not registered yet. */
    case notificationNotRegistered
    /** The accessibility API is disabled (as when, for example, the user deselects "Enable access for assistive devices" in Universal Access Preferences). */
    case apiDisabled
    /** The requested value or AXUIElementRef does not exist. */
    case noValue
    /** The parameterized attribute is not supported by the AXUIElementRef. */
    case parameterizedAttributeUnsupported
    /** Not enough precision. */
    case notEnoughPrecision

    @inlinable
    init(_ e: AXError) {
        switch e {
        case .success:
            preconditionFailure()
        case .failure:
            self = .failure
        case .illegalArgument:
            self = .illegalArgument
        case .invalidUIElement:
            self = .invalidUIElement
        case .invalidUIElementObserver:
            self = .invalidUIElementObserver
        case .cannotComplete:
            self = .cannotComplete
        case .attributeUnsupported:
            self = .attributeUnsupported
        case .actionUnsupported:
            self = .actionUnsupported
        case .notificationUnsupported:
            self = .notificationUnsupported
        case .notImplemented:
            self = .notImplemented
        case .notificationAlreadyRegistered:
            self = .notificationAlreadyRegistered
        case .notificationNotRegistered:
            self = .notificationNotRegistered
        case .apiDisabled:
            self = .apiDisabled
        case .noValue:
            self = .noValue
        case .parameterizedAttributeUnsupported:
            self = .parameterizedAttributeUnsupported
        case .notEnoughPrecision:
            self = .notEnoughPrecision
        @unknown default:
            preconditionFailure()
        }
    }
}

@inlinable
func ch(_ result: AXError) throws {
    if result != .success {
        throw AXErr(result)
    }
}

extension AXUIElement {
    @inlinable
    func attributes() throws -> [String] {
        var value: CFArray?
        try ch(AXUIElementCopyAttributeNames(self, &value))
        return value as! [String]
    }

    @inlinable
    func actions() throws -> [String] {
        var value: CFArray?
        try ch(AXUIElementCopyActionNames(self, &value))
        return value as! [String]
    }

    @inlinable
    func main() throws -> Bool {
        var value: AnyObject?
        try ch(AXUIElementCopyAttributeValue(self, kAXMainAttribute as CFString, &value))
        let main = value as! Int
        assert(main == 0 || main == 1)
        return main != 0
    }

    @inlinable
    func title() throws -> String {
        var value: AnyObject?
        try ch(AXUIElementCopyAttributeValue(self, kAXTitleAttribute as CFString, &value))
        return value as! String
    }

    @inlinable
    func pid() throws -> pid_t {
        var pid = pid_t()
        try ch(AXUIElementGetPid(self, &pid))
        return pid
    }

    @inlinable
    func position() throws -> CGPoint {
        var value: AnyObject?
        try ch(AXUIElementCopyAttributeValue(self, kAXPositionAttribute as CFString, &value))

        var point = CGPoint()
        guard AXValueGetValue(value as! AXValue, .cgPoint, &point) else { preconditionFailure() }
        return point
    }

    @inlinable
    func position(set new: CGPoint) throws {
        var point = new
        guard let value = AXValueCreate(.cgPoint, &point) else { preconditionFailure() }
        try ch(AXUIElementSetAttributeValue(self, kAXPositionAttribute as CFString, value))
    }

    @inlinable
    func size() throws -> CGSize {
        var value: AnyObject?
        try ch(AXUIElementCopyAttributeValue(self, kAXSizeAttribute as CFString, &value))

        var size = CGSize()
        guard AXValueGetValue(value as! AXValue, .cgSize, &size) else { preconditionFailure() }
        return size
    }

    @inlinable
    func size(set new: CGSize) throws {
        var size = new
        guard let value = AXValueCreate(.cgSize, &size) else { preconditionFailure() }
        try ch(AXUIElementSetAttributeValue(self, kAXSizeAttribute as CFString, value))
    }

    @inlinable
    func alive() -> Bool {
        var value: AnyObject?
        return nil
            != (try? ch(AXUIElementCopyAttributeValue(self, kAXTitleAttribute as CFString, &value)))
    }

    @inlinable
    func raise() throws {
        try ch(AXUIElementPerformAction(self, kAXRaiseAction as CFString))
    }

    @inlinable
    static func topWind() async throws -> AXUIElement? {
        return try await Self.topWind(
            of: NSWorkspace.shared.frontmostApplication!.processIdentifier)
    }

    @inlinable
    static func topWind(of pid: pid_t) async throws -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        var value: AnyObject?
        while true {
            do {
                try ch(
                    AXUIElementCopyAttributeValue(
                        app, kAXFocusedWindowAttribute as CFString, &value))
            } catch AXErr.cannotComplete {
                // app might still be starting up; wait
                try! await Task.sleep(for: .milliseconds(100))
                continue
            }

            break
        }

        if value == nil { return nil }
        return (value as! AXUIElement)
    }

    @inlinable
    static func allWinds() throws -> [AXUIElement] {
        var winds = [AXUIElement]()

        for app in NSWorkspace.shared.runningApplications {
            if app.activationPolicy != .regular { continue }
            let ax = AXUIElementCreateApplication(app.processIdentifier)

            var value: AnyObject?
            try ch(AXUIElementCopyAttributeValue(ax, kAXWindowsAttribute as CFString, &value))
            let w = value as! [AXUIElement]

            if app.bundleIdentifier == "com.apple.finder" {
                // finder always has one dummy window
                // therefore skip it
                winds.append(contentsOf: w[1...])
            } else {
                winds.append(contentsOf: w)
            }
        }

        return winds
    }

    @inlinable
    subscript(position: String) -> AnyObject? {
        var value: AnyObject?
        if nil == (try? ch(AXUIElementCopyAttributeValue(self, position as CFString, &value))) {
            return nil
        }
        return value
    }
}
