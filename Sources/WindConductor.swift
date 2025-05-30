import AppKit

actor WindConductor {
    var winds: [[AXUIElement]] = []
    var pids: [pid_t] = []
    var free: Set<Int> = []

    var canon: [Int] = []
    var recent: [Int] = []

    var appObservers: [pid_t: AXObserver] = [:]
    var suppressAppActivate = 0
    var suppressTabActivate = 0

    init() async {
        for app in NSWorkspace.shared.runningApplications {
            if app.activationPolicy != .regular { continue }
            let axapp = AXUIElementCreateApplication(app.processIdentifier)
            for wind in axapp[kAXWindowsAttribute] as! [AXUIElement] {
                guard (try? wind.role()) == kAXWindowRole else { continue }
                winds.append([wind])
                pids.append(app.processIdentifier)
            }
        }
        precondition(!winds.isEmpty && !pids.isEmpty)

        canon.append(contentsOf: winds.indices)
        recent.append(contentsOf: winds.indices)

        iniWatchers()
    }

    func raise(wind w: Int) async {
        assert(!free.contains(w))

        let tab = winds[w].last!
        let pid = pids[w]
        if pid != NSWorkspace.shared.frontmostApplication?.processIdentifier {
            suppressTabActivate += 1
            try! tab.raise()
            suppressAppActivate += 1
            if !NSRunningApplication(processIdentifier: pid)!.activate() { preconditionFailure() }
        } else if try! await AXUIElement.topTab() != tab {
            suppressTabActivate += 1
            try! tab.raise()
        }
    }

    func prune() async {
        let count = free.count

        for i in winds.indices {
            winds[i].removeAll(where: { !$0.alive() })
            if winds[i].isEmpty {
                free.insert(i)
            }
        }

        canon.removeAll(where: { free.contains($0) })
        recent.removeAll(where: { free.contains($0) })

        let delta = free.count - count
        if delta != 0 { info("-\(delta) tab(s)") }
    }

    func debug() async {
        print("debug!")
        print("recen: \(recent)")
        for w in recent {
            for (i, wind) in winds[w].enumerated() {
                if i == 0 {
                    print(
                        "- [\(try? wind.title(), default: "(/)")] [\(try? wind.role(), default: "(/)")]"
                    )
                } else {
                    print(
                        "  [\(try? wind.title(), default: "(/)")] [\(try? wind.role(), default: "(/)")]"
                    )
                }
            }
        }
        print()
    }
}
