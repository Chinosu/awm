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
            suppressAppActivate -= 1
            assert(suppressAppActivate >= 0)
            return
        }

        await prune()

        do {
            let w = recent.last!
            let last = winds[w].last!

            let app = AXUIElementCreateApplication(pid)
            var value: AnyObject?
            while true {
                do {
                    try ax(
                        AXUIElementCopyAttributeValue(
                            app, kAXFocusedWindowAttribute as CFString, &value))
                } catch AXErr.cannotComplete, AXErr.noValue {
                    try! await Task.sleep(for: .milliseconds(128))
                    continue
                } catch { preconditionFailure("\(error)") }
                break
            }

            try! await Task.sleep(for: .milliseconds(8.5))

            // if data structure has changed, the tab activate handler
            // has already been called and we don't need to do anything
            // (this happens when the user switches apps and tabs simultaneously)
            guard w == recent.last! && last == winds[recent.last!].last! else { return }
        }

        info("[*] \(Date().timeIntervalSince1970)")

        if let i = recent.lastIndex(where: { pids[$0] == pid }) {
            let w = recent.remove(at: i)
            recent.append(w)
        } else {
            // a new app just launched
            // insert the new window into the data structure
            let tab = try! await AXUIElement.topTab(of: pid)!
            assert((try? tab.role()) == kAXWindowRole)
            for wind in winds { assert(!wind.contains(tab)) }
            assert(!pids.contains(pid), "found \(pid) in \(pids)")

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
        }

        await debug()
    }

    func onTabActivate(_ tab: AXUIElement) async {
        guard suppressTabActivate == 0 else {
            suppressTabActivate -= 1
            assert(suppressTabActivate >= 0)
            return
        }

        await prune()

        nonisolated(unsafe) let tab = tab
        guard (try? tab.role()) == kAXWindowRole else { return }

        info("[ ] \(Date().timeIntervalSince1970)")

        if let i = recent.lastIndex(where: { winds[$0].contains(tab) }) {
            let w = recent.remove(at: i)
            assert(pids[w] == NSWorkspace.shared.frontmostApplication?.processIdentifier)
            recent.append(w)

            if let last = winds[w].lastIndex(of: tab), winds[w].count > 1 {
                winds[w].append(winds[w].remove(at: last))
            }
        } else {
            let pid = try! tab.pid()

            let childs = tab[kAXChildrenAttribute] as! [AXUIElement]
            let suspicious = childs.contains(where: { ch in
                (try? ch.role()) == kAXTabGroupRole && (try? ch.title()) == "tab bar"
            })

            if suspicious {
                let w = recent.last(where: { w in pids[w] == pid })!
                winds[w].append(tab)
            } else {
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
            }
        }

        await debug()
    }
}
