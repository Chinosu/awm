import AppKit
import ObjectiveC.runtime

actor ObserverConductor {
    var obs = [NSRunningApplication: (AXObserver, Box<String>)]()

    init() async {
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        for app in apps {
            observe(app: app)
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { noti in
            let app = noti.userInfo![NSWorkspace.applicationUserInfoKey] as! NSRunningApplication
            print("=> \(app.localizedName!)")
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main,
            using: onLaunchApp
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main,
            using: onTerminateApp
        )
    }

    func observe(app: NSRunningApplication) {
        let obser = {
            var ob: AXObserver?
            AXObserverCreate(
                app.processIdentifier,
                { ob, elem, noti, ptr in print("--> \(Box<String>.from(raw: ptr!))") },
                &ob
            )
            return ob!
        }()

        let box = Box(app.localizedName!)
        AXObserverAddNotification(
            obser,
            AXUIElementCreateApplication(app.processIdentifier),
            kAXFocusedWindowChangedNotification as CFString,
            box.raw()
        )
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obser), .defaultMode)

        self.obs[app] = (obser, box)
    }

    func onLaunchApp(noti: Notification) {
        let app = noti.userInfo![NSWorkspace.applicationUserInfoKey] as! NSRunningApplication
        guard app.activationPolicy == .regular else { return }

        print("[*] \(app.localizedName!)")
        self.observe(app: app)
    }

    func onTerminateApp(noti: Notification) {
        let app = noti.userInfo![NSWorkspace.applicationUserInfoKey] as! NSRunningApplication
        guard app.activationPolicy == .regular else { return }

        print("[ ] \(app.localizedName!)")
        self.obs.removeValue(forKey: app)
    }
}
