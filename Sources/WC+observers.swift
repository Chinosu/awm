import AppKit

extension WC {
    func iniWatchers() {
        for app in NSWorkspace.shared.runningApplications {
            if app.activationPolicy != .regular { continue }
            watch(app: app.processIdentifier)
        }

        // todo: NSWorkspace.shared.notificationCenter.removeObserver
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main,
            using: { not in
                let app = not.userInfo![NSWorkspace.applicationUserInfoKey] as! NSRunningApplication
                if app.activationPolicy != .regular { return }
                let pid = app.processIdentifier
                Task { await self.watch(app: pid) }
            })

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main,
            using: { not in
                let app = not.userInfo![NSWorkspace.applicationUserInfoKey] as! NSRunningApplication
                if app.activationPolicy != .regular { return }
                let pid = app.processIdentifier
                Task { await self.onAppActivate(pid) }
            })

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main,
            using: { not in
                let app = not.userInfo![NSWorkspace.applicationUserInfoKey] as! NSRunningApplication
                if app.activationPolicy != .regular { return }
                let pid = app.processIdentifier
                Task { await self.unwatch(app: pid) }
            })
    }

    func watch(app: pid_t) {
        var observer: AXObserver!
        AXObserverCreate(
            app,
            { ob, elem, not, ptr in
                let wc = Unmanaged<WC>.fromOpaque(ptr!).takeUnretainedValue()
                nonisolated(unsafe) let e = elem
                Task { @Sendable in await wc.onTabActivate(e) }
            }, &observer)
        assert(observer != nil)

        AXObserverAddNotification(
            observer, AXUIElementCreateApplication(app),
            kAXMainWindowChangedNotification as CFString, Unmanaged.passUnretained(self).toOpaque())

        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        assert(
            CFRunLoopContainsSource(
                CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode))

        assert(appObservers[app] == nil)
        appObservers[app] = observer
    }

    func unwatch(app: pid_t) {
        let observer = appObservers.removeValue(forKey: app)!
        CFRunLoopRemoveSource(
            CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        assert(
            !CFRunLoopContainsSource(
                CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode))
    }

    func onAppActivate(_ pid: pid_t) async {
        guard suppressAppActivate == 0 else {
            // print("[*] != \(suppressAppActivate)")
            suppressAppActivate -= 1
            assert(suppressAppActivate >= 0)
            return
        }

        do {
            let w = recent.last!
            let last = winds[w].last!
            try! await Task.sleep(for: .milliseconds(8.5))

            // if data structure has changed, the tab activate handler
            // has already been called and we don't need to do anything
            // (this happens when the user switches apps and tabs simultaneously)
            guard w == recent.last! && last == winds[recent.last!].last! else { return }
        }

        if let i = recent.lastIndex(where: { pids[$0] == pid }) {
            let w = recent.remove(at: i)
            recent.append(w)
        } else {
            // a new app just launched
            // insert the new window into the data structure
            nonisolated(unsafe) let new = try! await AXUIElement.topTab(of: pid)!
            assert(winds.allSatisfy({ @Sendable in !$0.contains(new) }))
            assert(!pids.contains(pid))

            if let w = free.popFirst() {
                winds[w] = [new]
                pids[w] = pid
                assert(winds.count == pids.count)

                canon.append(w)
                recent.append(w)
                assert(canon.count == recent.count)
            } else {
                winds.append([new])
                pids.append(pid)
                assert(winds.count == pids.count)

                canon.append(winds.count - 1)
                recent.append(winds.count - 1)
                assert(canon.count == recent.count)
            }
        }

        print("[*] \(Date().timeIntervalSince1970)")
    }

    func onTabActivate(_ tab: AXUIElement) async {
        guard suppressTabActivate == 0 else {
            // print("[ ] != \(suppressTabActivate)")
            suppressTabActivate -= 1
            assert(suppressTabActivate >= 0)
            return
        }

        nonisolated(unsafe) let tab = tab

        if let i = recent.lastIndex(where: { winds[$0].contains(tab) }) {
            let w = recent.remove(at: i)
            assert(pids[w] == NSWorkspace.shared.frontmostApplication?.processIdentifier)
            recent.append(w)
        } else {
            let pid = try! tab.pid()
            if let w = free.popFirst() {
                winds[w] = [tab]
                pids[w] = pid
                assert(winds.count == pids.count)

                canon.append(w)
                recent.append(w)
                assert(canon.count == recent.count)
            } else {
                winds.append([tab])
                pids.append(pid)
                assert(winds.count == pids.count)

                canon.append(winds.count - 1)
                recent.append(winds.count - 1)
                assert(canon.count == recent.count)
            }

            // // updating suspicious tab
            // let pid = try! tab.pid()
            // let w = pids.firstIndex(of: pid)!
            // winds[w].append(tab)

            // recent.remove(at: recent.lastIndex(of: w)!)
            // recent.append(w)
        }

        print("[ ] \(Date().timeIntervalSince1970)")

        // var pid = pid_t()
        // try! ax(AXUIElementGetPid(tab, &pid))
        // assert(pid == NSWorkspace.shared.frontmostApplication?.processIdentifier)

        // // var pid = pid_t()
        // // try! ax(AXUIElementGetPid(tab, &pid))
        // // let app = AXUIElementCreateApplication(pid)
        // // print(">> \(app[kAXFrontmostAttribute] as Any)")
        // print(">> \(NSWorkspace.shared.frontmostApplication!.bundleIdentifier!)")

        // let childs = tab[kAXChildrenAttribute] as! [AXUIElement]
        // let suspicious = childs.contains(where: {
        //     (try? $0.role()) == kAXTabGroupRole  // && (try? $0.title()) == "tab bar"
        // })

        // // if winds.contains(where: { $0.contains(tab) }) { return }
        // if suspicious { print("this window has evil tabs!") }
    }
}
