import Foundation

if #available(macOS 15.4.0, *) {
    let argv = CommandLine.arguments
    guard argv.count == 1 else {
        print("extra arguments detected-\u{10}doing experiments only")
        // operators()
        // let w = Wind.top()!
        // for k in w.keys() {
        //     print("- \(k)")
        // }

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

        exit(0)
    }

    Task {
        let wc = await WindowConductor()
        hotkeys(wc)
    }
    RunLoop.current.run()
}
