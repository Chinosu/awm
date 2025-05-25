import Foundation

if #available(macOS 15.4.0, *) {
    let argv = CommandLine.arguments
    guard argv.count == 1 else {
        print("extra arguments detected-\u{10}doing experiments only")
        dev()
        exit(0)
    }

    Task {
        let wc = await WindowConductor()
        hotkeys(wc)
    }
    RunLoop.current.run()
}
