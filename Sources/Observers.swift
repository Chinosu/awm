import AppKit
import ObjectiveC.runtime

struct Observers {
    var obs = [AXObserver]()
    var names = [Box<String>]()

    mutating func observeApps() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil,
            queue: .main
        ) { noti in
            let newApp = noti.userInfo![NSWorkspace.applicationUserInfoKey] as! NSRunningApplication
            print("==> \(newApp.localizedName!)")
        }
    }

    mutating func observeWins() {
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        for app in apps {
            let box = Box(app.localizedName!)
            self.names.append(box)

            var observer: AXObserver?
            AXObserverCreate(
                app.processIdentifier,
                { obs, elem, notif, ptr in
                    let box = Box<String>.unleak(ptr: ptr!)
                    print(" --> \(box.item)")
                },
                &observer
            )

            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            AXObserverAddNotification(
                observer!, axApp, kAXFocusedWindowChangedNotification as CFString, box.leak()
            )
            CFRunLoopAddSource(
                CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer!), .defaultMode
            )

            self.obs.append(observer!)
        }
    }
}
